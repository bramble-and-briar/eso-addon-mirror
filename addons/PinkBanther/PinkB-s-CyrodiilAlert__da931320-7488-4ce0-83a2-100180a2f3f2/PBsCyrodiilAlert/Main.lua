-- PB's CyrodiilAlert
-- Author: PinkBanther
--
-- Your alliance's keeps, in your chat window, the moment someone starts hitting one.
--
-- Cyrodiil already tells you a keep is under attack -- but only on the campaign map, as a
-- crossed-swords pin you have to open the map to see. If you are riding, farming a resource or
-- fighting somewhere else, the siege that takes your home keep happens in silence. This
-- add-on reads that same pin data on a timer and says it in chat, in colour:
--
--     red     a holding of yours has come under attack, and again while it lasts
--     blue    the attack is over and the holding is still yours -- defended
--     yellow  the holding changed hands -- lost
--
-- and, if you switch it on, the same watch pointed the other way:
--
--     green   a fight has started at a holding another alliance owns
--     blue    that holding is now yours -- taken
--
-- ---------------------------------------------------------------------------------------
-- WHERE THE INFORMATION COMES FROM
-- ---------------------------------------------------------------------------------------
--
-- Five public functions, the same ones the client's own map uses in
-- esoui/ingame/map/worldmap.lua (RefreshKeeps) and esoui/ingame/map/cmaphandlers.lua
-- (CMapHandlers:RefreshKeeps):
--
--     GetNumKeeps()                                 how many holdings the client knows
--     GetKeepKeysByIndex(index)  -> keepId, bgContext
--     GetKeepType(keepId)        -> KEEPTYPE_*
--     GetKeepAlliance(keepId, bgContext)  -> ALLIANCE_*      who owns it
--     GetKeepUnderAttack(keepId, bgContext) -> bool          the crossed swords
--
-- All five are reads of state the client already holds. Nothing here asks the server for
-- anything, nothing here writes anything, and taking the add-on out leaves no trace.
--
-- bgContext is the campaign the row belongs to: the client reports the same keep once for the
-- campaign you are standing in and once for the campaign you are homed to. IsLocalBattleground-
-- Context(bgContext) is the client's own test for "this is the campaign in front of you", and
-- cmaphandlers.lua uses exactly that to decide which keeps to pin. This add-on uses it to
-- decide which keeps to watch, so what it alerts on is what the map in front of you draws.
--
-- ---------------------------------------------------------------------------------------
-- WHY A TIMER AND NOT THE EVENT
-- ---------------------------------------------------------------------------------------
--
-- EVENT_KEEP_UNDER_ATTACK_CHANGED exists and fires with (keepId, bgContext, underAttack). A
-- timer was asked for, and a timer is what this is -- but the choice is not a compromise:
--
--   * the interval is a setting, so how noisy the add-on can get is a number you control
--     rather than whatever the server sends;
--   * a poll cannot miss an edge. If an event is dropped while zoning, or arrives before the
--     add-on registered, the next pass still sees the true state and corrects itself;
--   * "still under attack after a minute" is a question about now, not about an edge, and it
--     has to be asked on a timer whatever the first alert came from.
--
-- The cost is nothing worth measuring: one pass reads a few dozen values already in memory.
-- The only thing given up is sub-interval latency -- at the default five seconds, an alert is
-- at most five seconds late.
--
-- ---------------------------------------------------------------------------------------
-- THE STATE MACHINE
-- ---------------------------------------------------------------------------------------
--
-- One entry per watched holding, created when it first comes under attack and dropped when the
-- attack is over. The entry remembers whose the holding was when it was created, and everything
-- the add-on says is a transition of that entry:
--
--     no entry  + mine + attacked        -> RED, entry created
--     entry     + mine + attacked        -> RED again, once per repeat interval
--     entry     + mine + not attacked    -> BLUE, entry dropped         (held)
--     entry     + mine -> not mine       -> YELLOW, entry dropped       (lost)
--
--     no entry  + theirs + attacked      -> GREEN, entry created        (offense, optional)
--     entry     + theirs + attacked      -> GREEN again, once per repeat interval
--     entry     + theirs -> mine         -> BLUE, entry dropped         (taken)
--     entry     + theirs + not attacked  -> entry dropped, nothing said
--
-- The endings that change hands are read off the owning alliance, not off the attack flag,
-- because a keep that has just flipped usually stays under attack -- the side that lost it is
-- already hitting it back. Ownership is what decides which ending it was.
--
-- The last line is the one asymmetry, and it is deliberate: a fight at somebody else's holding
-- that ends with that holding still theirs has changed nothing about your campaign, and a line
-- saying so is a line you learn to scroll past.
--
-- ---------------------------------------------------------------------------------------
-- WHO IS ATTACKING -- WHAT THE CLIENT WILL AND WILL NOT SAY
-- ---------------------------------------------------------------------------------------
--
-- GetKeepUnderAttack is a bare yes/no. There is no "attacking alliance" anywhere in the keep
-- API, and in a three-way campaign a fight at an enemy keep is as likely to be the third
-- alliance's as yours. So the green line says "a fight has started there" -- which is what is
-- actually known -- and never claims your side started it.
--
-- The one piece of evidence that bears on it is GetNumSieges(keepId, bgContext, alliance),
-- which the client's own keep tooltip uses (keeptooltip.lua:163) to show each alliance's siege
-- count. Your own alliance having siege standing at a holding it does not own is a push of
-- yours. It is evidence, not proof -- an attack does not need siege at all -- so it is reported
-- as the count it is, appended to the line, rather than rewritten into a claim. It is gated on
-- DoesKeepTypeHaveSiegeLimit, exactly as the tooltip gates it: a resource has no siege count.
--
-- Whether that count is live for a keep on the other side of the map is the one thing here
-- that has to be measured rather than read: /pbalert list prints it for every holding.
--
-- ---------------------------------------------------------------------------------------
-- WHAT IT DOES WHEN IT IS NOT SURE
-- ---------------------------------------------------------------------------------------
--
-- It says nothing. There is no state in which this add-on guesses out loud:
--
--   * keep API missing on this client            -> the timer never starts, /pbalert says so
--   * outside an AvA zone                        -> the pass is skipped and the watch cleared,
--                                                   so coming back re-reads reality
--   * a holding that drops out of the keep list  -> its entry is dropped without an ending,
--     (campaign change, zoning)                     because there is nothing left to report on
--   * who is attacking an enemy holding          -> not claimed; the siege count is shown
--   * a name the client will not give            -> printed as its keep id rather than blank
--
-- The one thing worth knowing: the clock on an alert starts when the add-on first SAW the
-- attack, not when the attack began. Zone in on a siege already in progress and "3:20 so far"
-- means three minutes twenty of watching, not of siege.
--
-- ---------------------------------------------------------------------------------------

if PBS_CYRODIIL_ALERT then
	return
end

local addon = {
	name = "PBsCyrodiilAlert",
}

local em = EVENT_MANAGER

-- The display name is a Lua constant and the version comes from the manifest, the same way
-- PB's ChatFilter does it -- reading the name back out of "## Title" mangles the "PB's "
-- prefix in the settings library.
--
-- TYPOGRAPHIC apostrophe (U+2019), and exactly one half-width space before the name.
--
-- The apostrophe is not a typographic preference, it is what the settings library will accept.
-- With an ASCII ' here the panel showed "CyrodiilAlert" -- the whole "PB's " was eaten -- while
-- the in-game add-on list, which is fed by "## Title" and not by this, showed it correctly.
-- Every other PB's add-on has carried U+2019 in this constant for the same reason, and their
-- panels are named properly.
--
-- So the manifest keeps the ASCII form (the add-on list is happy with it and that is the name
-- the store listing uses) and this one carries U+2019. The two differ by one character that
-- reads the same, which is the price of both surfaces showing the name at all.
--
-- Written as the character itself, not as "\u{2019}": that escape is Lua 5.3, the client is
-- 5.1, and it would be a syntax error on the machine that matters rather than on this one.
local DISPLAY_NAME = "PB’s CyrodiilAlert"
local AUTHOR = "PinkBanther"
local SLASH = "/pbalert"
local SHORT_SLASH = "/pbca"

local MIN_INTERVAL, MAX_INTERVAL = 1, 60
local MIN_REPEAT, MAX_REPEAT = 15, 600
local LIST_LIMIT = 40

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
-- Alerts go out as system messages, which is the one route no chat filter of ours or anyone
-- else's is in the business of dropping.
--
-- An alert is a single line in a single colour, with no add-on name in front of it. That is
-- deliberate: it has to be readable at a glance in a chat window that is already moving, and a
-- pink prefix in front of a red line is one colour change too many. The colours themselves are
-- what identifies it.
--
-- A message printed at EVENT_ADD_ON_LOADED is thrown away because chat is not up yet, so
-- anything user-facing is either a command response or fires on EVENT_PLAYER_ACTIVATED.
-- ---------------------------------------------------------------------------------------

local function SayInChat(text)
	if CHAT_ROUTER and CHAT_ROUTER.AddSystemMessage then
		CHAT_ROUTER:AddSystemMessage(text)
	elseif CHAT_SYSTEM and CHAT_SYSTEM.AddMessage then
		CHAT_SYSTEM:AddMessage(text)
	else
		d(text)
	end
end

-- Everything the add-on says goes through here -- alerts, command replies, the list, the
-- summary. One funnel, so where the add-on speaks is one decision rather than forty.
--
-- The window is asked first and answers whether it took the line. It refuses when it is not
-- the destination, and when it could not be created at all; either way the line goes to chat.
-- An add-on that quietly swallows its own output is worse than one that fills a chat window.
local function Say(text)
	local taken = addon.log:Push(text)
	if not taken or (addon.sv and addon.sv.log and addon.sv.log.destination == "both") then
		SayInChat(text)
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

local PREFIX = "|cFF69B4" .. DISPLAY_NAME .. "|r: "

local function Print(text, ...)
	if select("#", ...) > 0 then
		local ok, formatted = pcall(string.format, text, ...)
		Line(PREFIX .. (ok and formatted or text))
	else
		Line(PREFIX .. text)
	end
end

addon.Line = Line
addon.Print = Print
addon.Say = Say

-- ---------------------------------------------------------------------------------------
-- The five things this add-on can say
--
-- Everything below is keyed by these five: the colour it is drawn in, on each of the two
-- surfaces, and whether it reaches the screen at all. Adding a sixth kind means adding a row
-- here and nothing else structural.
-- ---------------------------------------------------------------------------------------

local KIND_ATTACK = "attack"
local KIND_HELD = "held"
local KIND_LOST = "lost"
local KIND_FIGHT = "fight"
local KIND_TAKEN = "taken"
local KIND_SCROLL = "scroll"

local KINDS = {
	{ key = KIND_ATTACK, label = "SI_PBSCA_KIND_ATTACK", colour = "FF4040" }, -- red
	{ key = KIND_HELD, label = "SI_PBSCA_KIND_HELD", colour = "66B0FF" },     -- blue
	{ key = KIND_LOST, label = "SI_PBSCA_KIND_LOST", colour = "FFC820" },     -- yellow
	{ key = KIND_FIGHT, label = "SI_PBSCA_KIND_FIGHT", colour = "5CD65C" },   -- green
	{ key = KIND_TAKEN, label = "SI_PBSCA_KIND_TAKEN", colour = "66B0FF" },   -- blue
	{ key = KIND_SCROLL, label = "SI_PBSCA_KIND_SCROLL", colour = "C08CFF" }, -- purple
}
addon.KINDS = KINDS

local KIND_BY_KEY = {}
for _, kind in ipairs(KINDS) do
	KIND_BY_KEY[kind.key] = kind
end
addon.KIND_BY_KEY = KIND_BY_KEY

local SURFACE_CHAT = "chat"
local SURFACE_HUD = "hud"
addon.SURFACE_CHAT, addon.SURFACE_HUD = SURFACE_CHAT, SURFACE_HUD

-- The shades offered in the panel. Twelve is enough to tell five alerts apart twice over and
-- short enough to scroll on a controller; anything else goes in as a hex code through
-- /pbalert colour, which is what the dropdown is a convenience for rather than a limit on.
addon.PALETTE = {
	{ hex = "FFFFFF", word = "white", label = "SI_PBSCA_COLOUR_WHITE" },
	{ hex = "FF4040", word = "red", label = "SI_PBSCA_COLOUR_RED" },
	{ hex = "FF8C33", word = "orange", label = "SI_PBSCA_COLOUR_ORANGE" },
	{ hex = "FFC820", word = "gold", label = "SI_PBSCA_COLOUR_GOLD" },
	{ hex = "FFF066", word = "yellow", label = "SI_PBSCA_COLOUR_YELLOW" },
	{ hex = "5CD65C", word = "green", label = "SI_PBSCA_COLOUR_GREEN" },
	{ hex = "3FD6B0", word = "teal", label = "SI_PBSCA_COLOUR_TEAL" },
	{ hex = "66B0FF", word = "blue", label = "SI_PBSCA_COLOUR_BLUE" },
	{ hex = "5C7CFF", word = "indigo", label = "SI_PBSCA_COLOUR_INDIGO" },
	{ hex = "C08CFF", word = "purple", label = "SI_PBSCA_COLOUR_PURPLE" },
	{ hex = "FF7FD0", word = "pink", label = "SI_PBSCA_COLOUR_PINK" },
	{ hex = "B0B0B0", word = "grey", label = "SI_PBSCA_COLOUR_GREY" },
}

-- The name typed at /pbalert colour, in English or in the panel's own language. Returns nil
-- rather than a fallback colour: a mistyped shade must be refused, not silently applied.
function addon:HexForColourWord(word)
	if type(word) ~= "string" or word == "" then
		return nil
	end
	local wanted = word:lower()
	if wanted == "gray" then
		wanted = "grey"
	end
	for _, entry in ipairs(self.PALETTE) do
		if entry.word == wanted then
			return entry.hex
		end
		local name = GetString(_G[entry.label])
		if name and name:lower() == wanted then
			return entry.hex
		end
	end
	return nil
end

-- The panel's dropdown shows names, so a stored hex has to come back as one. A hex set through
-- the chat command that is not in the palette has no name, and nil is the honest answer.
function addon:ColourName(hex)
	for _, entry in ipairs(self.PALETTE) do
		if entry.hex == hex then
			return GetString(_G[entry.label])
		end
	end
	return nil
end

-- Six hex digits, and nothing else. A colour that fails this test is never written to the
-- saved variables, because a malformed one does not fail visibly -- "|cFF40" swallows the
-- characters after it and the line comes out with its first letters missing.
function addon:NormaliseHex(text)
	if type(text) ~= "string" then
		return nil
	end
	local hex = text:gsub("^|c", ""):gsub("^#", ""):upper()
	if hex:match("^%x%x%x%x%x%x$") then
		return hex
	end
	return nil
end

-- ---------------------------------------------------------------------------------------
-- The kinds of holding
--
-- Written out one KEEPTYPE_ at a time rather than listed in a table constructor: a client that
-- does not define one of these (KEEPTYPE_IMPERIAL_CITY_DISTRICT is the young one) would make a
-- constructor blow up on a nil key at load, and an add-on that fails to load explains nothing
-- to the person it failed for. Declared this way, an unknown type is simply not watched.
--
-- Bridges, milegates and artifact gates are absent on purpose. They are structures inside the
-- fight, not holdings that can be owned, so "your side lost it" has no meaning for them.
-- ---------------------------------------------------------------------------------------

local GROUP_KEEPS = "keeps"
local GROUP_TOWNS = "towns"
local GROUP_RESOURCES = "resources"
local GROUP_DISTRICTS = "districts"

local KEEP_TYPE_GROUP = {}
local KEEP_TYPE_LABEL = {}

local function DeclareKeepType(keepType, group, labelStringId)
	if keepType == nil then
		return
	end
	KEEP_TYPE_GROUP[keepType] = group
	KEEP_TYPE_LABEL[keepType] = labelStringId
end

DeclareKeepType(KEEPTYPE_KEEP, GROUP_KEEPS, SI_PBSCA_TYPE_KEEP)
DeclareKeepType(KEEPTYPE_OUTPOST, GROUP_KEEPS, SI_PBSCA_TYPE_OUTPOST)
DeclareKeepType(KEEPTYPE_ARTIFACT_KEEP, GROUP_KEEPS, SI_PBSCA_TYPE_ARTIFACT)
DeclareKeepType(KEEPTYPE_BORDER_KEEP, GROUP_KEEPS, SI_PBSCA_TYPE_BORDER)
DeclareKeepType(KEEPTYPE_TOWN, GROUP_TOWNS, SI_PBSCA_TYPE_TOWN)
DeclareKeepType(KEEPTYPE_RESOURCE, GROUP_RESOURCES, SI_PBSCA_TYPE_RESOURCE)
DeclareKeepType(KEEPTYPE_IMPERIAL_CITY_DISTRICT, GROUP_DISTRICTS, SI_PBSCA_TYPE_DISTRICT)

-- What the campaign summary counts as a holding. Keeps, outposts and the scroll temples --
-- the things a campaign is scored on. Resources are left out on purpose: they flip constantly,
-- and a summary whose numbers move every few seconds is not a summary of anything. Border
-- keeps are left out because they cannot change hands, so counting them only inflates every
-- alliance's total by the same amount.
local SCORED_TYPE = {}
local function DeclareScoredType(keepType)
	if keepType ~= nil then
		SCORED_TYPE[keepType] = true
	end
end

DeclareScoredType(KEEPTYPE_KEEP)
DeclareScoredType(KEEPTYPE_OUTPOST)
DeclareScoredType(KEEPTYPE_ARTIFACT_KEEP)

-- Panel and command order. The label ids are resolved when they are shown, not here.
local GROUPS = {
	{ key = GROUP_KEEPS, label = "SI_PBSCA_GROUP_KEEPS", tooltip = "SI_PBSCA_GROUP_KEEPS_TOOLTIP" },
	{ key = GROUP_TOWNS, label = "SI_PBSCA_GROUP_TOWNS", tooltip = "SI_PBSCA_GROUP_TOWNS_TOOLTIP" },
	{ key = GROUP_RESOURCES, label = "SI_PBSCA_GROUP_RESOURCES", tooltip = "SI_PBSCA_GROUP_RESOURCES_TOOLTIP" },
	{ key = GROUP_DISTRICTS, label = "SI_PBSCA_GROUP_DISTRICTS", tooltip = "SI_PBSCA_GROUP_DISTRICTS_TOOLTIP" },
}
addon.GROUPS = GROUPS

-- ---------------------------------------------------------------------------------------
-- Settings
-- ---------------------------------------------------------------------------------------

local DEFAULTS = {
	enabled = true,
	-- Five seconds: fast enough that the alert and the map pin appear together as far as
	-- anyone riding to the keep is concerned, slow enough to be free.
	intervalSeconds = 5,
	-- A minute of silence on a keep that is still being hit is about right: often enough to
	-- keep a defence moving, rare enough not to become the thing you scroll past.
	repeatSeconds = 60,
	groups = {
		[GROUP_KEEPS] = true,
		[GROUP_TOWNS] = true,
		-- Resources and districts flip constantly and mostly to one player. On by default
		-- they would bury the alerts that are worth riding for.
		[GROUP_RESOURCES] = false,
		[GROUP_DISTRICTS] = false,
	},
	-- The offensive half: fights at holdings that are not ours. Off, because being warned
	-- about your own keeps and following the campaign's fights are different jobs, and the
	-- second one is a lot more traffic.
	offense = false,
	-- "Only when it is us doing the attacking", as close as the client can be made to get:
	-- our own siege standing at a holding we do not own. On, because the question the green
	-- line is usually being asked is "is my side pushing something", and off it answers a
	-- wider one. What it costs is in the tooltip and the README, not hidden.
	offenseOursOnly = true,
	-- Colours, per alert, per surface. Two tables rather than one because the two surfaces
	-- have nothing in common behind them: chat is a dark window, the screen is whatever you
	-- are looking at, and a shade that reads on one can disappear on the other.
	colours = {
		chat = {},
		hud = {},
	},
	-- One set of colours, used on both surfaces. The two CAN differ -- the ground behind them
	-- has nothing in common -- but wanting them to differ is the unusual case, and having to
	-- recolour an alert twice to change it once is the usual one.
	hudFollowsChatColours = true,
	-- The on-screen display. Off until asked for -- an add-on that starts drawing over the
	-- game the moment it is installed is a bad guest.
	hud = {
		enabled = false,
		face = "$(BOLD_FONT)",
		size = 32,
		style = "soft-shadow-thick",
		position = "TOP",
		offsetX = 0,
		-- Below the compass, where the game puts its own alerts.
		offsetY = 220,
		seconds = 6,
		-- The two you have to react to. The rest are worth reading, not worth painting over
		-- what you are doing.
		kinds = {
			attack = true,
			held = false,
			lost = true,
			fight = false,
			taken = false,
		},
	},
	-- Where the add-on speaks. Its own window by default, which is the point of having one:
	-- chat is for the conversation, and an add-on's running commentary is not part of it.
	log = {
		destination = "window",
		width = 620,
		height = 240,
		size = 20,
		lines = 12,
		opacity = 40,
		position = "BOTTOMLEFT",
		offsetX = 24,
		offsetY = -160,
		-- In front of everything, which is where a window you are meant to read belongs. The
		-- other two are for when the corner you want is one something else is already using.
		draw = "FRONT",
	},
	-- The overview map. Off until asked for, like every other thing drawn over the game.
	-- (Its limits live here rather than in Map.lua so the settings panel can be built from
	-- this file alone: a panel row that reads a limit from a file that failed to load takes
	-- the whole panel down with it.)
	map = {
		enabled = false,
		size = 300,
		pinSize = 18,
		opacity = 90,
		position = "TOPRIGHT",
		offsetX = -24,
		offsetY = 220,
		draw = "FRONT",
		-- The transitus network, as the world map shows it.
		links = true,
		-- Your own alliance's links in the shrine's colours: green where you can travel.
		linksReady = true,
		-- The farms, mines and lumbermills around each keep.
		resources = true,
		-- Your own arrow, and how big it is. Smaller than a keep, as on the world map.
		player = true,
		playerSize = 10,
		-- The rest of the group.
		group = true,
		groupSize = 10,
	},
	-- The campaign summary. Its own switch, its own size and its own corner; the typeface and
	-- outline come from the alert display, because two on-screen texts from one add-on in two
	-- different faces looks like a mistake rather than a choice.
	board = {
		enabled = false,
		size = 22,
		position = "TOPLEFT",
		offsetX = 24,
		offsetY = 140,
		-- In front of everything, which is what it has always done. The other two are there
		-- for the case where the corner you want is a corner something else is already using.
		draw = "FRONT",
		-- The icon, not the word. The word is one tick away, and is what a client that cannot
		-- draw the icon falls back to on its own.
		populationText = false,
	},
	-- The scroll events. On: they are rare, they name a player, and each one is worth knowing.
	scrolls = true,
	onlyInAvA = true,
	announceExisting = true,
	-- No login banner. It is here because a build behaving unlike its code is the hardest
	-- thing to diagnose from inside the game, and one line at EVENT_PLAYER_ACTIVATED settles
	-- which build is actually running. Off by default: /pbalert says the same thing on demand.
	banner = false,
}

for _, kind in ipairs(KINDS) do
	DEFAULTS.colours.chat[kind.key] = kind.colour
	DEFAULTS.colours.hud[kind.key] = kind.colour
end

addon.DEFAULTS = DEFAULTS
addon.MIN_MAP_SIZE, addon.MAX_MAP_SIZE = 120, 700

-- How far any surface may be moved from its anchor: the whole screen, in either direction.
--
-- These used to be a fixed 900 by 500, which reached only part of the screen -- anchored top
-- right, a window could not be moved more than 900 units left, and on a 1920-wide interface
-- the left half was out of reach. The real size is GuiRoot's, and it depends on the player's
-- UI scale, so it is read rather than assumed: the full width and height either way means
-- every point on the screen can be reached from any of the anchors.
local FALLBACK_WIDTH, FALLBACK_HEIGHT = 1920, 1080

function addon:ScreenSize()
	if GuiRoot and GuiRoot.GetDimensions then
		local ok, width, height = pcall(GuiRoot.GetDimensions, GuiRoot)
		if ok and width and height and width > 0 and height > 0 then
			return width, height
		end
	end
	return FALLBACK_WIDTH, FALLBACK_HEIGHT
end

function addon:UpdateScreenLimits()
	local width, height = self:ScreenSize()
	self.MAX_OFFSET_X, self.MAX_OFFSET_Y = math.ceil(width), math.ceil(height)
end

addon:UpdateScreenLimits()
addon.MIN_MAP_PIN, addon.MAX_MAP_PIN = 8, 48
addon.MIN_MAP_PLAYER, addon.MAX_MAP_PLAYER = 4, 40
addon.MIN_INTERVAL, addon.MAX_INTERVAL = MIN_INTERVAL, MAX_INTERVAL
addon.MIN_REPEAT, addon.MAX_REPEAT = MIN_REPEAT, MAX_REPEAT

-- What is currently under attack, keyed by keep id and campaign. Session only: it is a
-- description of a fight happening now, and a saved one would be a lie by the next login.
addon.watch = {}
addon.firstScan = true
addon.alerted = {}
for _, kind in ipairs(KINDS) do
	addon.alerted[kind.key] = 0
end

-- Filled in by Hud.lua, which replaces these in place. Stubbed here so everything else can
-- call it without first asking whether that file loaded: with no screen display, every alert
-- still reaches chat, which is the surface that was there first.
addon.hud = {
	Push = function() end,
	Refresh = function() end,
	Clear = function() end,
	Available = function() return false end,
}

addon.board = {
	Refresh = function() end,
	Available = function() return false end,
}

-- Filled in by Map.lua.
addon.map = {
	Refresh = function() end,
	RefreshKeeps = function() end,
	Available = function() return false end,
	Probe = function() return {} end,
}

-- Also filled in by Hud.lua. Push returning false is what sends a line to chat instead, so the
-- stub's answer is the right one: with no window, everything goes where it always went.
addon.log = {
	Push = function() return false end,
	Clear = function() end,
	Refresh = function() end,
	Available = function() return false end,
}

-- What the last pass counted, per alliance: { [alliance] = { held = n, attacked = n } }.
-- Nil until a pass has run, and set back to nil when there is nothing to count -- which is how
-- the summary knows the difference between "nobody holds anything" and "we cannot see".
addon.tally = nil

local function Clamp(value, low, high)
	if value < low then
		return low
	elseif value > high then
		return high
	end
	return value
end

function addon:IntervalSeconds()
	return Clamp(tonumber(self.sv.intervalSeconds) or DEFAULTS.intervalSeconds, MIN_INTERVAL, MAX_INTERVAL)
end

function addon:RepeatSeconds()
	return Clamp(tonumber(self.sv.repeatSeconds) or DEFAULTS.repeatSeconds, MIN_REPEAT, MAX_REPEAT)
end

function addon:GroupEnabled(key)
	local value = self.sv.groups and self.sv.groups[key]
	if value == nil then
		return DEFAULTS.groups[key] or false
	end
	return value
end

function addon:SetGroupEnabled(key, enabled)
	self.sv.groups = self.sv.groups or {}
	self.sv.groups[key] = enabled and true or false
	-- A kind that has just been switched off must not be able to produce an ending later, and
	-- one switched on must not inherit a stale entry. Re-baseline instead.
	self:Forget()
end

function addon:AnyGroupEnabled()
	for _, group in ipairs(GROUPS) do
		if self:GroupEnabled(group.key) then
			return true
		end
	end
	return false
end

-- ---------------------------------------------------------------------------------------
-- Naming things
-- ---------------------------------------------------------------------------------------

local function Now()
	if GetGameTimeMilliseconds then
		return GetGameTimeMilliseconds() / 1000
	end
	return os and os.time and os.time() or 0
end

local function FormatElapsed(seconds)
	seconds = math.floor((seconds or 0) + 0.5)
	if seconds < 0 then
		seconds = 0
	end
	-- Hours once there are any: the artifact's "gone for" can run past an hour, and "134:10" is
	-- a number to work out rather than read.
	if seconds >= 3600 then
		return string.format("%d:%02d:%02d", math.floor(seconds / 3600), math.floor(seconds / 60) % 60, seconds % 60)
	end
	return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
end

-- string.format against a translated string, which is the one place a bad format string can
-- come from a language file rather than from here. pcall so a mistranslation prints the
-- unformatted line instead of taking the alert down.
local function Format(stringId, ...)
	local ok, formatted = pcall(string.format, GetString(stringId), ...)
	return ok and formatted or GetString(stringId)
end

addon.Format = Format

local function KeepKey(keepId, bgContext)
	return tostring(keepId) .. ":" .. tostring(bgContext)
end

-- "[Keep] Chalman Keep". The type is worth the four characters: "Bloodmayne" alone does not
-- say whether the thing being lost is a keep or the mine underneath it.
function addon:KeepLabel(keepId)
	local keepType = GetKeepType and GetKeepType(keepId)
	local labelId = keepType and KEEP_TYPE_LABEL[keepType]
	local name = GetKeepName and GetKeepName(keepId) or ""
	if name == nil or name == "" then
		name = "#" .. tostring(keepId)
	end
	if not labelId then
		return name
	end
	return string.format(GetString(SI_PBSCA_LABEL), GetString(labelId), name)
end

local function AllianceName(alliance)
	if alliance and alliance ~= ALLIANCE_NONE and GetAllianceName then
		local name = GetAllianceName(alliance)
		if name and name ~= "" then
			return name
		end
	end
	return GetString(SI_PBSCA_LIST_NEUTRAL)
end

addon.AllianceName = AllianceName

-- The game's own colour for an alliance, as six hex digits. ZO_ColorDef:ToHex forces the alpha
-- to opaque and returns exactly "rrggbb" (zo_colordef.lua:182), but it is put through the same
-- validation as a user-typed colour anyway: a malformed markup does not fail visibly, it eats
-- the start of the line it was meant to colour.
local function AllianceHex(alliance)
	if GetAllianceColor and alliance and alliance ~= ALLIANCE_NONE then
		local ok, hex = pcall(function()
			return GetAllianceColor(alliance):ToHex()
		end)
		if ok then
			local valid = addon:NormaliseHex(hex)
			if valid then
				return valid
			end
		end
	end
	return "FFFFFF"
end

addon.AllianceHex = AllianceHex

local function CommaNumber(value)
	if ZO_CommaDelimitNumber then
		local ok, formatted = pcall(ZO_CommaDelimitNumber, value)
		if ok and formatted then
			return tostring(formatted)
		end
	end
	return tostring(value)
end

-- ---------------------------------------------------------------------------------------
-- The campaign, roughly
--
-- Holdings and scores come from the same three functions the client's own scoreboard uses
-- (campaignscoring_shared.lua:44) -- GetTotalCampaignHoldings per holding type, and
-- GetCampaignAllianceScore -- so the numbers are the campaign's numbers rather than a private
-- count that could disagree with the map.
--
-- What is NOT the client's is the "under attack" column: that is counted off this add-on's own
-- pass, because there is no API that answers "how many of this alliance's holdings are being
-- fought over". It is the column that says where the campaign actually is right now, which is
-- the reason to have the summary on screen rather than opening the map.
--
-- Everything degrades one column at a time. No campaign (you are not in one, or the client has
-- not said yet): holdings fall back to the add-on's own count and the score reads "-". No pass
-- yet: the summary does not draw at all rather than drawing zeroes.
-- ---------------------------------------------------------------------------------------

-- ---------------------------------------------------------------------------------------
-- How busy each alliance is
--
-- The same estimate the campaign selection screen shows on the way in: Low / Medium / High /
-- Full, per alliance. It is NOT a headcount -- the game does not publish one anywhere, and
-- nothing here can turn four buckets into a number of players.
--
-- It comes off the campaign SELECTION data, which is a different table from the campaign the
-- player is standing in: indexed by selection index, not campaign id, so the id has to be
-- looked up (campaignbrowser_manager.lua:223 does the same walk). That table is filled by
-- QueryCampaignSelectionData, which is a request to the server -- the campaign browser fires
-- one each time it opens.
--
-- So it is asked for every few minutes, and no more often. A summary refreshed every five
-- seconds must not become five seconds of server requests, and an estimate in four buckets
-- does not move fast enough to be worth one.
--
-- It used to be asked for only when it was MISSING. That left a hole: once the first answer
-- was in, nothing asked again, and unless the server volunteered updates on its own -- which
-- nothing says it does -- the summary went on showing the population from the moment the
-- player rode in. Now it is refreshed on the same five-minute cadence whether it is there or
-- not, but only while the summary is on screen: nothing is asked for on behalf of a display
-- nobody is looking at. (Outside Cyrodiil the watch's timer is stopped, so nothing asks there
-- either.) Printing the summary with /pbalert board is a direct question and may ask too.
-- ---------------------------------------------------------------------------------------

local POPULATION_QUERY_SECONDS = 300

function addon:PopulationQuery(asked)
	if not QueryCampaignSelectionData then
		return
	end
	if not asked and not (self.sv and self.sv.board and self.sv.board.enabled) then
		return
	end
	local now = Now()
	if self.lastPopulationQuery and now - self.lastPopulationQuery < POPULATION_QUERY_SECONDS then
		return
	end
	self.lastPopulationQuery = now
	pcall(QueryCampaignSelectionData)
end

-- { [alliance] = CAMPAIGN_POP_* } for the campaign being played, or nil when the selection
-- data does not have it yet.
function addon:Population()
	if not (GetNumSelectionCampaigns and GetSelectionCampaignId and GetSelectionCampaignPopulationData) then
		return nil
	end
	local campaignId = GetCurrentCampaignId and GetCurrentCampaignId() or 0
	if not campaignId or campaignId == 0 then
		return nil
	end

	for index = 1, (GetNumSelectionCampaigns() or 0) do
		if GetSelectionCampaignId(index) == campaignId then
			-- Present, but maybe old. Keep it fresh on the same cadence.
			self:PopulationQuery()
			local population = {}
			for alliance = 1, (NUM_ALLIANCES or 3) do
				population[alliance] = GetSelectionCampaignPopulationData(index, alliance)
			end
			return population
		end
	end

	-- Not in the selection data. Ask for it, rarely, and say nothing until it arrives.
	self:PopulationQuery()
	return nil
end

-- The game's own campaign-browser icons, which is what makes the column readable without being
-- read. Written out one at a time and behind the client's own getter: an art path can be moved
-- between updates, and ZO_CampaignBrowser_GetPopulationIcon moves with it.
local POPULATION_ICON = {}
local function DeclarePopulationIcon(populationType, path)
	if populationType ~= nil then
		POPULATION_ICON[populationType] = path
	end
end

DeclarePopulationIcon(CAMPAIGN_POP_LOW, "EsoUI/Art/Campaign/campaignBrowser_lowPop.dds")
DeclarePopulationIcon(CAMPAIGN_POP_MEDIUM, "EsoUI/Art/Campaign/campaignBrowser_medPop.dds")
DeclarePopulationIcon(CAMPAIGN_POP_HIGH, "EsoUI/Art/Campaign/campaignBrowser_hiPop.dds")
DeclarePopulationIcon(CAMPAIGN_POP_FULL, "EsoUI/Art/Campaign/campaignBrowser_fullPop.dds")

-- The gamepad UI draws a different set (campaignbrowser_gamepad.lua:241), and on a console the
-- campaign screen the player just came through is the gamepad one. Its table is a file-local
-- with a file-local getter, so the paths are written out here; they are keyed by the same
-- constants, so nothing about the mapping is guessed.
local POPULATION_ICON_GAMEPAD = {}
local function DeclareGamepadPopulationIcon(populationType, path)
	if populationType ~= nil then
		POPULATION_ICON_GAMEPAD[populationType] = path
	end
end

DeclareGamepadPopulationIcon(CAMPAIGN_POP_LOW, "EsoUI/Art/AvA/Gamepad/Server_Empty.dds")
DeclareGamepadPopulationIcon(CAMPAIGN_POP_MEDIUM, "EsoUI/Art/AvA/Gamepad/Server_One.dds")
DeclareGamepadPopulationIcon(CAMPAIGN_POP_HIGH, "EsoUI/Art/AvA/Gamepad/Server_Two.dds")
DeclareGamepadPopulationIcon(CAMPAIGN_POP_FULL, "EsoUI/Art/AvA/Gamepad/Server_Full.dds")

local function PopulationIconPath(populationType)
	if IsInGamepadPreferredMode and IsInGamepadPreferredMode() then
		local gamepadPath = POPULATION_ICON_GAMEPAD[populationType]
		if gamepadPath then
			return gamepadPath
		end
	end
	if ZO_CampaignBrowser_GetPopulationIcon then
		local ok, path = pcall(ZO_CampaignBrowser_GetPopulationIcon, populationType)
		if ok and type(path) == "string" and path ~= "" then
			return path
		end
	end
	return POPULATION_ICON[populationType]
end

-- The client's word for a population level, mapped one constant at a time.
--
-- NOT GetString("SI_CAMPAIGNPOPULATIONTYPE", populationType). That idiom only works where the
-- enum's numbering happens to match the string suffixes, and here it does not: measured on a
-- live client, every level came out one too high -- Low read as Medium, High as Full. The
-- suffixes are 0-based and the enum is not. Keying the constants to the string ids by hand
-- costs four lines and cannot drift, which is the same reason the keep types and the map pins
-- are written out rather than derived.
local POPULATION_STRING = {}
local function DeclarePopulationWord(populationType, stringId)
	if populationType ~= nil and stringId ~= nil then
		POPULATION_STRING[populationType] = stringId
	end
end

DeclarePopulationWord(CAMPAIGN_POP_LOW, SI_CAMPAIGNPOPULATIONTYPE0)
DeclarePopulationWord(CAMPAIGN_POP_MEDIUM, SI_CAMPAIGNPOPULATIONTYPE1)
DeclarePopulationWord(CAMPAIGN_POP_HIGH, SI_CAMPAIGNPOPULATIONTYPE2)
DeclarePopulationWord(CAMPAIGN_POP_FULL, SI_CAMPAIGNPOPULATIONTYPE3)

local function PopulationWord(populationType)
	local stringId = POPULATION_STRING[populationType]
	if stringId then
		local name = GetString(stringId)
		if name and name ~= "" then
			return name
		end
	end
	return GetString(SI_PBSCA_BOARD_UNKNOWN)
end

-- Icon by default, word on request -- and word anyway if an icon cannot be produced, so the
-- column is never blank on a client that will not draw it.
--
-- Sized "100%", not in pixels: the icon then follows whatever font it lands in, which is the
-- summary's own size on screen and the chat window's when it is printed there. One rule, two
-- surfaces, no second size setting to keep in step.
local function PopulationText(populationType, asWord)
	if populationType == nil then
		return GetString(SI_PBSCA_BOARD_UNKNOWN)
	end
	if not asWord then
		local path = PopulationIconPath(populationType)
		if path and zo_iconFormat then
			local ok, markup = pcall(zo_iconFormat, path, "100%", "100%")
			if ok and markup and markup ~= "" then
				return markup
			end
		end
	end
	return PopulationWord(populationType)
end

-- The campaign being played is one of the Imperial City's. The client's own test, and the same
-- one the world map uses to decide which set of pins it is drawing (worldmap.lua:2201).
--
-- It matters here because three of the summary's columns are about keeps: the Imperial City has
-- none, its campaign is scored on districts, and nothing counted by the keep watch can be under
-- attack there. Three columns of zeroes are not a summary, they are furniture.
function addon:InImperialCityCampaign()
	local campaignId = GetCurrentCampaignId and GetCurrentCampaignId() or 0
	if not campaignId or campaignId == 0 then
		return false
	end
	if IsImperialCityCampaign then
		return IsImperialCityCampaign(campaignId) and true or false
	end
	-- No way to ask about the campaign: fall back to asking about the place.
	if IsInImperialCity then
		return IsInImperialCity() and true or false
	end
	return false
end

function addon:Situation()
	local campaignId = GetCurrentCampaignId and GetCurrentCampaignId() or 0
	local hasCampaign = campaignId ~= nil and campaignId ~= 0
	local playerAlliance = GetUnitAlliance and GetUnitAlliance("player") or ALLIANCE_NONE
	local rows = {}
	local population = self:Population()

	for alliance = 1, (NUM_ALLIANCES or 3) do
		local counted = self.tally and self.tally[alliance]
		local held, score

		if hasCampaign and GetTotalCampaignHoldings and HOLDINGTYPE_KEEP then
			held = (GetTotalCampaignHoldings(campaignId, HOLDINGTYPE_KEEP, alliance) or 0)
			if HOLDINGTYPE_OUTPOST then
				held = held + (GetTotalCampaignHoldings(campaignId, HOLDINGTYPE_OUTPOST, alliance) or 0)
			end
		end
		if not held and counted then
			held = counted.held
		end
		if hasCampaign and GetCampaignAllianceScore then
			score = GetCampaignAllianceScore(campaignId, alliance)
		end

		if held or score then
			rows[#rows + 1] = {
				alliance = alliance,
				held = held or 0,
				score = score,
				attacked = counted and counted.attacked or 0,
				population = population and population[alliance] or nil,
				mine = alliance == playerAlliance,
			}
		end
	end

	if #rows == 0 then
		return nil
	end

	-- Score order, the way the scoreboard reads. With no scores to sort on, holdings decide.
	-- In an Imperial City campaign there is neither, and sorting on two columns of zeroes would
	-- shuffle the alliances from one refresh to the next; they stay in their own order there.
	local imperialCity = self:InImperialCityCampaign()
	if not imperialCity then
		table.sort(rows, function(a, b)
			if (a.score or 0) ~= (b.score or 0) then
				return (a.score or 0) > (b.score or 0)
			end
			return a.held > b.held
		end)
	end

	local situation = { rows = rows, imperialCity = imperialCity }
	if hasCampaign and GetCampaignName then
		local name = GetCampaignName(campaignId)
		if name and name ~= "" then
			situation.campaign = name
		end
	end
	if hasCampaign and GetCampaignEmperorInfo then
		local alliance, characterName = GetCampaignEmperorInfo(campaignId)
		if alliance and alliance ~= ALLIANCE_NONE and characterName and characterName ~= "" then
			situation.emperor = { alliance = alliance, name = characterName }
		end
	end
	return situation
end

-- The campaign in front of the player, which is what the map draws. Without the client's own
-- test every keep would be seen twice -- once local, once for the home campaign -- and the
-- home campaign's copy would alert about a siege in a campaign you are not in.
local function IsThisCampaign(bgContext)
	if IsLocalBattlegroundContext then
		return IsLocalBattlegroundContext(bgContext) and true or false
	end
	return true
end

addon.IsThisCampaign = IsThisCampaign

-- ---------------------------------------------------------------------------------------
-- The Daedric artifact (Volendrung)
--
-- WHO is carrying it cannot be known. The only event that reports it,
-- EVENT_DAEDRIC_ARTIFACT_OBJECTIVE_STATE_CHANGED, carries holderAlliance and no name, and the
-- client's own centre-screen announcement says no more than "<artifact> is revealed" -- it does
-- not name a player or even an alliance. Nothing polled offers a name either. So this line
-- says the alliance, which is what there is.
--
-- The alliance is read off the map pin type, which is where the client itself keeps it:
-- MAP_PIN_TYPE_AVA_DAEDRIC_ARTIFACT_VOLENDRUNG_<alliance>, plus a NEUTRAL one for nobody.
-- ---------------------------------------------------------------------------------------

local ARTIFACT_PIN_ALLIANCE = {}
local function DeclareArtifactPin(pinType, alliance)
	if pinType ~= nil and alliance ~= nil then
		ARTIFACT_PIN_ALLIANCE[pinType] = alliance
	end
end

DeclareArtifactPin(MAP_PIN_TYPE_AVA_DAEDRIC_ARTIFACT_VOLENDRUNG_ALDMERI, ALLIANCE_ALDMERI_DOMINION)
DeclareArtifactPin(MAP_PIN_TYPE_AVA_DAEDRIC_ARTIFACT_VOLENDRUNG_EBONHEART, ALLIANCE_EBONHEART_PACT)
DeclareArtifactPin(MAP_PIN_TYPE_AVA_DAEDRIC_ARTIFACT_VOLENDRUNG_DAGGERFALL, ALLIANCE_DAGGERFALL_COVENANT)
DeclareArtifactPin(MAP_PIN_TYPE_AVA_DAEDRIC_ARTIFACT_VOLENDRUNG_NEUTRAL, ALLIANCE_NONE)

-- ---------------------------------------------------------------------------------------
-- The artifact's clock
--
-- No function says when the artifact will spawn, when it will be revealed, or when it will
-- leave; the game's own announcements carry no times either. So the add-on keeps its own
-- stopwatch against the three announcements it can hear --
--
--     EVENT_DAEDRIC_ARTIFACT_OBJECTIVE_SPAWNED_BUT_NOT_REVEALED   "seeks a wielder"
--     EVENT_DAEDRIC_ARTIFACT_OBJECTIVE_STATE_CHANGED, UNKNOWN -> known   "is revealed"
--     EVENT_DAEDRIC_ARTIFACT_OBJECTIVE_STATE_CHANGED, known -> UNKNOWN   "returns to Oblivion"
--
-- -- the same transitions the client's own announcement handler reads
-- (centerscreenannouncehandlers.lua:619), and adds the community's observed figures as a
-- forecast. Those are UESP's, not ZeniMax's: revealed 10-15 minutes after spawning, gone about
-- 30 minutes after being revealed -- or sooner, after four or five changes of hands. So every
-- forecast says "about", and when a forecast runs out it says "any moment", not a negative.
--
-- The clock only knows what it was there to see. An artifact that was already out when the
-- player arrived has no start, and the line says the time is unknown rather than guess one.
-- ---------------------------------------------------------------------------------------

local ARTIFACT_REVEAL_MIN, ARTIFACT_REVEAL_MAX = 10 * 60, 15 * 60
local ARTIFACT_STAY = 30 * 60

-- { phase = "seeking" | "revealed" | "gone", since = seconds, artifactId = n, campaignId = n }
addon.artifactClock = nil

function addon:StartArtifactClock(phase, artifactId)
	self.artifactClock = {
		phase = phase,
		since = Now(),
		artifactId = artifactId,
		campaignId = GetCurrentCampaignId and GetCurrentCampaignId() or 0,
	}
	self.board:Refresh()
end

-- The clock, if it belongs to the campaign in front of us. A reading carried over from another
-- campaign would be a precise-looking number about a different hammer.
function addon:ArtifactClock()
	local clock = self.artifactClock
	if not clock then
		return nil
	end
	local campaignId = GetCurrentCampaignId and GetCurrentCampaignId() or 0
	if clock.campaignId ~= campaignId then
		return nil
	end
	return clock
end

function addon:OnArtifactSpawned(artifactId)
	self:StartArtifactClock("seeking", artifactId)
end

function addon:OnArtifactStateChanged(bgContext, controlState, artifactId, lastControlState)
	if not IsThisCampaign(bgContext) or not OBJECTIVE_CONTROL_STATE_UNKNOWN then
		return
	end
	if lastControlState == OBJECTIVE_CONTROL_STATE_UNKNOWN and controlState ~= OBJECTIVE_CONTROL_STATE_UNKNOWN then
		self:StartArtifactClock("revealed", artifactId)
	elseif lastControlState ~= OBJECTIVE_CONTROL_STATE_UNKNOWN and controlState == OBJECTIVE_CONTROL_STATE_UNKNOWN then
		self:StartArtifactClock("gone", artifactId)
	end
end

local function Minutes(seconds)
	return math.ceil(seconds / 60)
end

-- "(6:20 ago / revealed in about 4-9 min)" and its two siblings.
local function ArtifactClockText(clock, phase)
	if not clock or clock.phase ~= phase then
		return GetString(SI_PBSCA_ARTIFACT_CLOCK_UNKNOWN)
	end
	local elapsed = Now() - clock.since
	if phase == "seeking" then
		local soonest, latest = ARTIFACT_REVEAL_MIN - elapsed, ARTIFACT_REVEAL_MAX - elapsed
		local forecast
		if latest <= 0 then
			forecast = GetString(SI_PBSCA_ARTIFACT_SOON)
		else
			forecast = Format(SI_PBSCA_ARTIFACT_RANGE, math.max(0, Minutes(soonest)), Minutes(latest))
		end
		return Format(SI_PBSCA_ARTIFACT_CLOCK_SEEKING, FormatElapsed(elapsed), forecast)
	elseif phase == "revealed" then
		local left = ARTIFACT_STAY - elapsed
		local forecast = left <= 0 and GetString(SI_PBSCA_ARTIFACT_SOON) or Format(SI_PBSCA_ARTIFACT_ABOUT, Minutes(left))
		return Format(SI_PBSCA_ARTIFACT_CLOCK_REVEALED, FormatElapsed(elapsed), forecast)
	end
	return Format(SI_PBSCA_ARTIFACT_CLOCK_GONE, FormatElapsed(elapsed))
end

local function ArtifactName(artifactId)
	if artifactId and GetDaedricArtifactDisplayName then
		local ok, name = pcall(GetDaedricArtifactDisplayName, artifactId)
		if ok and name and name ~= "" then
			return name
		end
	end
	return GetString(SI_PBSCA_KIND_SCROLL)
end

-- What is left of the carrier's hunger meter, when the carrier is us -- the one number about the
-- artifact's lifetime the client does hand over (huddaedricenergymeter.lua:312).
local function ArtifactEnergyText()
	if not (GetUnitPower and COMBAT_MECHANIC_FLAGS_DAEDRIC) then
		return ""
	end
	local ok, current, maximum = pcall(GetUnitPower, "player", COMBAT_MECHANIC_FLAGS_DAEDRIC)
	if ok and current and maximum and maximum > 0 then
		return Format(SI_PBSCA_ARTIFACT_ENERGY, math.floor(current / maximum * 100 + 0.5))
	end
	return ""
end

-- Whether an objective is in play at all. Every place the artifact CAN spawn is an objective
-- of its own -- twenty-three of them across Cyrodiil -- and each answers GetObjectivePinInfo
-- with a perfectly good pin, whether or not anything is there. The client's own map only
-- draws the ones that are enabled (mappin_manager.lua:677); without the same test the add-on
-- drew every spawn point as an artifact.
local function IsObjectiveInPlay(keepId, objectiveId, bgContext)
	if IsObjectiveEnabled and not IsObjectiveEnabled(keepId, objectiveId, bgContext) then
		return false
	end
	return true
end

-- And whether the thing itself is there to be drawn: the client's second test before it puts a
-- current-location pin down (mappin_manager.lua:680, 706).
local function IsObjectiveObjectShown(keepId, objectiveId, bgContext)
	if not IsObjectiveInPlay(keepId, objectiveId, bgContext) then
		return false
	end
	if IsObjectiveObjectVisible and not IsObjectiveObjectVisible(keepId, objectiveId, bgContext) then
		return false
	end
	return true
end

addon.IsObjectiveInPlay = IsObjectiveInPlay
addon.IsObjectiveObjectShown = IsObjectiveObjectShown

-- Every Daedric artifact currently revealed in this campaign, or nil. An artifact that has not
-- spawned reports OBJECTIVE_CONTROL_STATE_UNKNOWN and is left out: "not out yet" is not a state
-- worth a line on a summary.
function addon:Artifacts()
	if not (OBJECTIVE_DAEDRIC_WEAPON and GetNumObjectives and GetObjectiveIdsForIndex
		and GetObjectiveType and GetObjectiveInfo and GetObjectivePinInfo) then
		return nil
	end

	local rows
	for index = 1, (GetNumObjectives() or 0) do
		local keepId, objectiveId, bgContext = GetObjectiveIdsForIndex(index)
		if keepId and IsThisCampaign(bgContext)
			and GetObjectiveType(keepId, objectiveId, bgContext) == OBJECTIVE_DAEDRIC_WEAPON
			and IsObjectiveInPlay(keepId, objectiveId, bgContext) then
			local name, _, state = GetObjectiveInfo(keepId, objectiveId, bgContext)
			if state ~= OBJECTIVE_CONTROL_STATE_UNKNOWN then
				local pinType = GetObjectivePinInfo(keepId, objectiveId, bgContext)
				rows = rows or {}
				rows[#rows + 1] = {
					name = (name and name ~= "") and name or GetString(SI_PBSCA_KIND_SCROLL),
					alliance = ARTIFACT_PIN_ALLIANCE[pinType],
					mine = IsCarryableObjectiveCarriedByLocalPlayer
						and IsCarryableObjectiveCarriedByLocalPlayer(keepId, objectiveId, bgContext) or false,
				}
			end
		end
	end
	return rows
end

-- The summary as lines of text with a colour each, which is all both surfaces need: the screen
-- concatenates them into one label, chat prints them one at a time.
function addon:SituationLines()
	local situation = self:Situation()
	if not situation then
		return nil
	end

	local lines = {}
	if situation.campaign then
		lines[#lines + 1] = { text = situation.campaign, colour = "FFFFFF" }
	end

	for _, row in ipairs(situation.rows) do
		local mark = row.mine and GetString(SI_PBSCA_BOARD_MARK_MINE) or GetString(SI_PBSCA_BOARD_MARK_OTHER)
		local text
		if situation.imperialCity then
			-- Keeps, keep score and what the keep watch found under attack: none of the three
			-- means anything in a campaign fought over districts, so none of them is printed.
			text = Format(SI_PBSCA_BOARD_LINE_PLAIN, mark, AllianceName(row.alliance))
		else
			local score = row.score and CommaNumber(row.score) or GetString(SI_PBSCA_BOARD_UNKNOWN)
			-- The count is always printed, zero included. A column that appears and disappears
			-- has to be read before it can be counted; one that is always in the same place on
			-- every line can be taken in at a glance, which is the summary's whole job.
			text = Format(SI_PBSCA_BOARD_LINE, mark, AllianceName(row.alliance), row.held, score)
				.. Format(SI_PBSCA_BOARD_ATTACKED, row.attacked)
		end
		text = text .. Format(SI_PBSCA_BOARD_POPULATION, PopulationText(row.population, self.sv.board.populationText))
		lines[#lines + 1] = { text = text, colour = AllianceHex(row.alliance) }
	end

	-- The objectives are the truth about whether the artifact is out; the clock only says for how
	-- long. So a revealed artifact is always listed, with its time when the clock saw the reveal
	-- and "time unknown" when it did not, and the clock's other two phases are only listed when
	-- nothing is out to contradict them.
	local clock = self:ArtifactClock()
	local artifacts = self:Artifacts()
	for _, artifact in ipairs(artifacts or {}) do
		local text
		if artifact.mine then
			text = Format(SI_PBSCA_BOARD_ARTIFACT_YOURS, artifact.name) .. ArtifactEnergyText()
		elseif artifact.alliance and artifact.alliance ~= ALLIANCE_NONE then
			text = Format(SI_PBSCA_BOARD_ARTIFACT, artifact.name, AllianceName(artifact.alliance))
		else
			text = Format(SI_PBSCA_BOARD_ARTIFACT_LOOSE, artifact.name)
		end
		text = text .. ArtifactClockText(clock, "revealed")
		lines[#lines + 1] = { text = text, colour = AllianceHex(artifact.alliance) }
	end
	if not artifacts and clock and clock.phase == "seeking" then
		lines[#lines + 1] = {
			text = Format(SI_PBSCA_ARTIFACT_SEEKING, ArtifactName(clock.artifactId)) .. ArtifactClockText(clock, "seeking"),
			colour = "FFFFFF",
		}
	elseif not artifacts and clock and clock.phase == "gone" then
		lines[#lines + 1] = {
			text = Format(SI_PBSCA_ARTIFACT_GONE, ArtifactName(clock.artifactId)) .. ArtifactClockText(clock, "gone"),
			colour = "B0B0B0",
		}
	end

	if situation.emperor then
		lines[#lines + 1] = {
			text = Format(SI_PBSCA_BOARD_EMPEROR, situation.emperor.name, AllianceName(situation.emperor.alliance)),
			colour = AllianceHex(situation.emperor.alliance),
		}
	end

	return lines
end

function addon:PrintSituation()
	-- A direct question: allowed to ask the server even with the summary off screen.
	self:PopulationQuery(true)
	local lines = self:SituationLines()
	if not lines then
		Print(GetString(SI_PBSCA_BOARD_NO_DATA))
		return
	end
	for _, line in ipairs(lines) do
		Line("|c" .. line.colour .. line.text .. "|r")
	end
end

-- ---------------------------------------------------------------------------------------
-- The watch
-- ---------------------------------------------------------------------------------------

function addon:HasKeepApi()
	return (GetNumKeeps and GetKeepKeysByIndex and GetKeepType and GetKeepAlliance and GetKeepUnderAttack) and true or false
end

function addon:InAvAZone()
	if IsInAvAZone then
		return IsInAvAZone() and true or false
	end
	-- No way to ask: assume yes rather than switch the add-on off over a missing function.
	return true
end

function addon:IsWatchedType(keepId)
	local group = KEEP_TYPE_GROUP[GetKeepType(keepId)]
	if not group then
		return false
	end
	return self:GroupEnabled(group)
end

-- Drop everything being watched. Used whenever the ground under the watch moves -- zoning, a
-- settings change, /pbalert forget -- so the next pass reads reality instead of arguing with
-- a memory of a different campaign.
function addon:Forget()
	self.watch = {}
	self.firstScan = true
end

-- ---------------------------------------------------------------------------------------
-- Saying it
--
-- One alert, two surfaces, two colours. Everything that alerts goes through Emit: it is the
-- single place that knows a line has a kind, and therefore the single place that has to be
-- told about a new surface or a new colour setting.
--
-- The chat text and the on-screen text are written separately rather than the second being
-- the first cut short. They are read differently -- one is scrolled back through afterwards,
-- the other is caught out of the corner of an eye while riding -- and a sentence trimmed to
-- fit a glance stops being a sentence.
-- ---------------------------------------------------------------------------------------

function addon:Colour(surface, kindKey)
	-- The screen borrows chat's colour rather than copying it, so a later change to chat
	-- reaches the screen without anything having to be kept in step.
	if surface == SURFACE_HUD and self.sv and self.sv.hudFollowsChatColours then
		surface = SURFACE_CHAT
	end
	local stored = self.sv and self.sv.colours and self.sv.colours[surface]
	local hex = stored and self:NormaliseHex(stored[kindKey])
	if hex then
		return hex
	end
	local kind = KIND_BY_KEY[kindKey]
	return kind and kind.colour or "FFFFFF"
end

function addon:SetColour(surface, kindKey, value)
	local hex = self:NormaliseHex(value)
	if not hex or not KIND_BY_KEY[kindKey] or (surface ~= SURFACE_CHAT and surface ~= SURFACE_HUD) then
		return nil
	end
	self.sv.colours = self.sv.colours or {}
	self.sv.colours[surface] = self.sv.colours[surface] or {}
	self.sv.colours[surface][kindKey] = hex
	if surface == SURFACE_HUD then
		-- Choosing a colour for the screen is the whole of what "I want the screen to be
		-- different" looks like, so it is taken as saying that. Left following, the choice
		-- would be stored and ignored, which is the one outcome nobody means.
		self.brokeColourFollow = self.sv.hudFollowsChatColours
		self.sv.hudFollowsChatColours = false
		self.hud:Refresh()
	elseif self.sv.hudFollowsChatColours then
		-- Chat is the screen's colour too while it follows.
		self.hud:Refresh()
	end
	return hex
end

function addon:Emit(kindKey, chatText, hudText)
	Say("|c" .. self:Colour(SURFACE_CHAT, kindKey) .. chatText .. "|r")
	if hudText and self:HudShows(kindKey) then
		self.hud:Push(kindKey, hudText)
	end
	self.alerted[kindKey] = (self.alerted[kindKey] or 0) + 1
end

-- Whether an alert of this kind reaches the screen. Two switches, both of which have to be on:
-- the display itself, and this kind's own place on it.
function addon:HudShows(kindKey)
	local hud = self.sv and self.sv.hud
	if not (hud and hud.enabled) then
		return false
	end
	local kinds = hud.kinds
	if not kinds then
		return DEFAULTS.hud.kinds[kindKey] or false
	end
	local value = kinds[kindKey]
	if value == nil then
		return DEFAULTS.hud.kinds[kindKey] or false
	end
	return value and true or false
end

function addon:SetHudShows(kindKey, shown)
	self.sv.hud = self.sv.hud or {}
	self.sv.hud.kinds = self.sv.hud.kinds or {}
	self.sv.hud.kinds[kindKey] = shown and true or false
end

function addon:AlertAttack(keepId, elapsed)
	local label = self:KeepLabel(keepId)
	if elapsed then
		local since = FormatElapsed(elapsed)
		self:Emit(KIND_ATTACK, Format(SI_PBSCA_ALERT_ATTACK_AGAIN, label, since),
			Format(SI_PBSCA_HUD_ATTACK_AGAIN, label, since))
	else
		self:Emit(KIND_ATTACK, Format(SI_PBSCA_ALERT_ATTACK, label), Format(SI_PBSCA_HUD_ATTACK, label))
	end
end

function addon:AlertHeld(keepId, elapsed)
	local label = self:KeepLabel(keepId)
	self:Emit(KIND_HELD, Format(SI_PBSCA_ALERT_HELD, label, FormatElapsed(elapsed)),
		Format(SI_PBSCA_HUD_HELD, label))
end

function addon:AlertLost(keepId, owner, elapsed)
	-- The alliance name is deliberately NOT in the alliance's own colour: the line is yellow
	-- because it is a loss, and one word in another colour in the middle of it undoes that.
	local label = self:KeepLabel(keepId)
	local ownerName = AllianceName(owner)
	self:Emit(KIND_LOST, Format(SI_PBSCA_ALERT_LOST, label, ownerName, FormatElapsed(elapsed)),
		Format(SI_PBSCA_HUD_LOST, label, ownerName))
end

-- How many siege weapons OUR alliance has standing at a holding, or nil when the question does
-- not apply. This is the only thing the client offers that bears on WHO is attacking:
-- GetKeepUnderAttack is a bare yes/no, so a fight at an enemy keep could equally be the third
-- alliance's. Our own siege being up there is evidence the push is ours -- not proof, because
-- an attack does not need siege at all, which is why it is reported as a count rather than
-- turned into a claim.
--
-- Gated on DoesKeepTypeHaveSiegeLimit exactly as keeptooltip.lua:158 gates its own siege lines:
-- resources and the like have no siege limit and no meaningful count.
function addon:SiegeCount(keepId, bgContext, alliance)
	if not (GetNumSieges and DoesKeepTypeHaveSiegeLimit and alliance and alliance ~= ALLIANCE_NONE) then
		return nil
	end
	local keepType = GetKeepType(keepId)
	if not keepType or not DoesKeepTypeHaveSiegeLimit(keepType) then
		return nil
	end
	local count = GetNumSieges(keepId, bgContext, alliance)
	if count and count > 0 then
		return count
	end
	return nil
end

-- May a fight at this enemy holding be reported?
--
-- With the filter off, always. With it on, only where our own alliance has siege standing
-- there -- which is the whole of what the client can be made to say about who is attacking.
-- GetKeepUnderAttack has no attacker in it, so this is a proxy, and it is wrong in both
-- directions: an attack pressed without siege never satisfies it, and a holding the game keeps
-- no siege count for (SiegeCount returns nil for anything DoesKeepTypeHaveSiegeLimit refuses)
-- can never satisfy it at all.
--
-- It is a filter on the LINE, not on the watch. The entry is still made, so the holding
-- becoming ours is still reported, and a push that starts later still gets its line the moment
-- our siege goes up.
function addon:OurPushHere(keepId, bgContext, playerAlliance)
	if not self.sv.offenseOursOnly then
		return true
	end
	return self:SiegeCount(keepId, bgContext, playerAlliance) ~= nil
end

-- A fight at a holding that is not ours. The wording says "a fight has started", not "we are
-- attacking", because the client has not told us that and inventing it would make the add-on
-- lie every time the other two alliances go at each other.
function addon:AlertFight(keepId, bgContext, owner, playerAlliance, elapsed)
	local label = self:KeepLabel(keepId)
	local ownerName = AllianceName(owner)
	if elapsed then
		local since = FormatElapsed(elapsed)
		self:Emit(KIND_FIGHT, Format(SI_PBSCA_ALERT_FIGHT_AGAIN, label, ownerName, since),
			Format(SI_PBSCA_HUD_FIGHT_AGAIN, label, since))
	else
		local sieges = self:SiegeCount(keepId, bgContext, playerAlliance)
		local chatText = sieges and Format(SI_PBSCA_ALERT_FIGHT_SIEGE, label, ownerName, sieges)
			or Format(SI_PBSCA_ALERT_FIGHT, label, ownerName)
		self:Emit(KIND_FIGHT, chatText, Format(SI_PBSCA_HUD_FIGHT, label))
	end
end

function addon:AlertTaken(keepId, elapsed)
	local label = self:KeepLabel(keepId)
	self:Emit(KIND_TAKEN, Format(SI_PBSCA_ALERT_TAKEN, label, FormatElapsed(elapsed)),
		Format(SI_PBSCA_HUD_TAKEN, label))
end

-- ---------------------------------------------------------------------------------------
-- Elder Scrolls
--
-- EVENT_ARTIFACT_CONTROL_STATE is the one event in the whole AvA API that hands an add-on a
-- player's name -- characterName and displayName, both of them. So these lines can say who,
-- which nothing else here can: keeps report an alliance, and the Daedric artifact does not
-- even report that.
--
-- It is an event and not a poll. There is no scroll state to read back on a timer, and no
-- interval setting applies: what arrives, arrives.
-- ---------------------------------------------------------------------------------------

-- Which name to show. The client picks the display name in gamepad mode and the character name
-- otherwise (centerscreenannouncehandlers.lua:607), and this is a console add-on, so it follows
-- that rather than choosing for itself.
local function PlayerName(characterName, displayName)
	local wantsDisplayName = IsInGamepadPreferredMode and IsInGamepadPreferredMode()
	if wantsDisplayName and displayName and displayName ~= "" then
		if ZO_FormatUserFacingDisplayName then
			local ok, formatted = pcall(ZO_FormatUserFacingDisplayName, displayName)
			if ok and formatted and formatted ~= "" then
				return formatted
			end
		end
		return displayName
	end
	if characterName and characterName ~= "" then
		return characterName
	end
	return displayName or ""
end

local SCROLL_EVENTS = {}
local function DeclareScrollEvent(controlEvent, chatId, hudId, needsKeep)
	if controlEvent ~= nil then
		SCROLL_EVENTS[controlEvent] = { chat = chatId, hud = hudId, needsKeep = needsKeep }
	end
end

DeclareScrollEvent(OBJECTIVE_CONTROL_EVENT_FLAG_TAKEN, SI_PBSCA_SCROLL_TAKEN, SI_PBSCA_HUD_SCROLL_TAKEN, true)
DeclareScrollEvent(OBJECTIVE_CONTROL_EVENT_CAPTURED, SI_PBSCA_SCROLL_CAPTURED, SI_PBSCA_HUD_SCROLL_CAPTURED, true)
DeclareScrollEvent(OBJECTIVE_CONTROL_EVENT_FLAG_RETURNED, SI_PBSCA_SCROLL_RETURNED, SI_PBSCA_HUD_SCROLL_RETURNED, true)
DeclareScrollEvent(OBJECTIVE_CONTROL_EVENT_FLAG_DROPPED, SI_PBSCA_SCROLL_DROPPED, SI_PBSCA_HUD_SCROLL_DROPPED, false)

function addon:OnScrollEvent(artifactName, keepId, characterName, alliance, controlEvent, displayName)
	if not (self.sv and self.sv.enabled and self.sv.scrolls) then
		return
	end

	local scrollName = (artifactName and artifactName ~= "") and artifactName or GetString(SI_PBSCA_KIND_SCROLL)

	-- Returned by the timer: nobody did it, so there is no name and a different line.
	if OBJECTIVE_CONTROL_EVENT_FLAG_RETURNED_BY_TIMER and controlEvent == OBJECTIVE_CONTROL_EVENT_FLAG_RETURNED_BY_TIMER then
		local keepName = (keepId and keepId ~= 0 and GetKeepName) and GetKeepName(keepId) or ""
		self:Emit(KIND_SCROLL, Format(SI_PBSCA_SCROLL_RETURNED_TIMER, scrollName, keepName),
			Format(SI_PBSCA_HUD_SCROLL_RETURNED_TIMER, scrollName))
		return
	end

	local wording = SCROLL_EVENTS[controlEvent]
	if not wording then
		-- Some other control event. The client has a handler for four of them and ignores the
		-- rest; an add-on inventing a line for an event it has no wording for is how a chat
		-- window fills up with things nobody can act on.
		return
	end

	local who = PlayerName(characterName, displayName)
	local allianceName = AllianceName(alliance)
	local keepName = (keepId and keepId ~= 0 and GetKeepName) and GetKeepName(keepId) or nil

	local chatText
	if wording.needsKeep and keepName and keepName ~= "" then
		chatText = Format(wording.chat, who, allianceName, scrollName, keepName)
	elseif wording.needsKeep then
		-- Taken away from a keep is a different sentence from picked up off the ground, and the
		-- keep id being zero is how the client says which happened.
		chatText = Format(SI_PBSCA_SCROLL_PICKED, who, allianceName, scrollName)
	else
		chatText = Format(wording.chat, who, allianceName, scrollName)
	end

	local hudId = wording.hud
	if wording.needsKeep and not (keepName and keepName ~= "") then
		hudId = SI_PBSCA_HUD_SCROLL_PICKED
	end

	self:Emit(KIND_SCROLL, chatText, Format(hudId, scrollName, allianceName))
end

-- One of each, with made-up names, so the typeface, size, position and colours can be judged
-- without waiting for a campaign to oblige. It goes through Emit like everything else, which
-- is the point: what you are looking at is the real path, not a preview of it.
function addon:ShowTest()
	local label = string.format(GetString(SI_PBSCA_LABEL), GetString(SI_PBSCA_TYPE_KEEP), GetString(SI_PBSCA_TEST_KEEP))
	-- Any alliance that is not the player's, so the rehearsal reads like a real loss.
	local playerAlliance = GetUnitAlliance and GetUnitAlliance("player")
	local owner = AllianceName(nil)
	for _, alliance in ipairs({ ALLIANCE_ALDMERI_DOMINION, ALLIANCE_EBONHEART_PACT, ALLIANCE_DAGGERFALL_COVENANT }) do
		if alliance and alliance ~= playerAlliance then
			owner = AllianceName(alliance)
			break
		end
	end
	Print(GetString(SI_PBSCA_TEST_NOTE))
	self:Emit(KIND_ATTACK, Format(SI_PBSCA_ALERT_ATTACK, label), Format(SI_PBSCA_HUD_ATTACK, label))
	self:Emit(KIND_HELD, Format(SI_PBSCA_ALERT_HELD, label, "1:30"), Format(SI_PBSCA_HUD_HELD, label))
	self:Emit(KIND_LOST, Format(SI_PBSCA_ALERT_LOST, label, owner, "2:45"), Format(SI_PBSCA_HUD_LOST, label, owner))
	self:Emit(KIND_FIGHT, Format(SI_PBSCA_ALERT_FIGHT, label, owner), Format(SI_PBSCA_HUD_FIGHT, label))
	self:Emit(KIND_TAKEN, Format(SI_PBSCA_ALERT_TAKEN, label, "3:10"), Format(SI_PBSCA_HUD_TAKEN, label))
	self:Emit(KIND_SCROLL,
		Format(SI_PBSCA_SCROLL_TAKEN, GetString(SI_PBSCA_TEST_PLAYER), owner, GetString(SI_PBSCA_TEST_SCROLL), GetString(SI_PBSCA_TEST_KEEP)),
		Format(SI_PBSCA_HUD_SCROLL_TAKEN, GetString(SI_PBSCA_TEST_SCROLL), owner))
	-- The counters measure a campaign, not a rehearsal.
	for _, kind in ipairs(KINDS) do
		self.alerted[kind.key] = self.alerted[kind.key] - 1
	end
end

-- One holding, one pass. Returns true if it is a holding of ours currently under attack, which
-- is what the status line counts.
-- owner and attacked are passed in rather than read here: the campaign summary needs the same
-- two numbers for every holding, and reading them once per pass instead of twice is the whole
-- of what the summary costs.
function addon:Examine(keepId, bgContext, playerAlliance, now, owner, attacked)
	local key = KeepKey(keepId, bgContext)
	local state = self.watch[key]
	local mine = owner == playerAlliance and owner ~= ALLIANCE_NONE
	-- Neutral is nobody's fight. Only a holding another alliance actually owns can be one.
	local hostile = not mine and owner ~= nil and owner ~= ALLIANCE_NONE

	-- An entry that has changed sides is over, whichever way it went, and the ending is read
	-- off the owner rather than off the attack flag: a keep that has just flipped is normally
	-- still under attack, because the side that lost it is already hitting it back.
	if state then
		if state.mine and not mine then
			self.watch[key] = nil
			self:AlertLost(keepId, owner, now - state.since)
			return false
		elseif not state.mine and mine then
			self.watch[key] = nil
			self:AlertTaken(keepId, now - state.since)
			return false
		end
	end

	local watchThis = mine or (self.sv.offense and hostile)

	if attacked and watchThis then
		if not state then
			state = { since = now, lastAlert = now, mine = mine, announced = false }
			self.watch[key] = state
			-- An attack already running when we arrived is not news the same way a new one is,
			-- so it is the one case that can be recorded without being said. It still gets its
			-- ending, and its repeat, like any other.
			if not (self.firstScan and not self.sv.announceExisting) then
				if mine then
					self:AlertAttack(keepId, nil)
					state.announced = true
				elseif self:OurPushHere(keepId, bgContext, playerAlliance) then
					self:AlertFight(keepId, bgContext, owner, playerAlliance, nil)
					state.announced = true
				end
			end
		elseif not state.mine and not state.announced and self.sv.offenseOursOnly then
			-- A fight we have been watching without a line, because our side was not in it
			-- when it started. The moment our siege goes up it becomes a push of ours, and it
			-- is said then -- as a beginning, not as a repeat, because for us it is one.
			if self:OurPushHere(keepId, bgContext, playerAlliance) then
				state.lastAlert = now
				state.announced = true
				self:AlertFight(keepId, bgContext, owner, playerAlliance, nil)
			end
		elseif now - state.lastAlert >= self:RepeatSeconds() then
			if mine then
				state.lastAlert = now
				self:AlertAttack(keepId, now - state.since)
			elseif self:OurPushHere(keepId, bgContext, playerAlliance) then
				state.lastAlert = now
				state.announced = true
				self:AlertFight(keepId, bgContext, owner, playerAlliance, now - state.since)
			end
		end
		return mine
	end

	if not state then
		return false
	end

	self.watch[key] = nil
	if state.mine then
		self:AlertHeld(keepId, now - state.since)
	end
	-- A fight at somebody else's holding that ended without the holding changing hands is not
	-- an ending worth a line: nothing about your campaign is different from before it started.
	return false
end

-- One pass over the keep list. Returns the three numbers the status line wants: how many
-- holdings the client reported, how many of them are in this campaign and of a watched kind,
-- and how many of those are ours and under attack right now.
function addon:Scan()
	-- The same test the timer is built on, asked again here. With the timer stopped outside
	-- Cyrodiil this is the second line of defence rather than the first -- a pass can still be
	-- asked for directly, by /pbalert -- and it comes before the keep list rather than after
	-- it, so a pass that cannot see anything costs one function call instead of a walk down
	-- every keep the client knows about.
	if not self:ShouldWatchHere() then
		-- Nothing here is knowable, so nothing here is remembered: a watch kept across the
		-- gap would report an ending, on returning, for a fight that finished without us.
		if next(self.watch) ~= nil or not self.firstScan then
			self:Forget()
		end
		self.tally = nil
		self.board:Refresh()
		return 0, 0, 0
	end

	local total = GetNumKeeps() or 0
	local watched, underAttack = 0, 0

	local playerAlliance = GetUnitAlliance and GetUnitAlliance("player") or ALLIANCE_NONE
	local now = Now()
	local seen = {}
	-- Held and being fought over, per alliance, counted off the same pass. The alert switches
	-- do not narrow it: which holdings you want to be woken up for is a different question
	-- from what the campaign looks like.
	local tally = {}
	-- Whether anything can alert at all. The pass still runs when nothing can -- the summary
	-- is counted here, and switching every kind off must not blank it.
	local alerting = self:AnyGroupEnabled()

	for index = 1, total do
		local keepId, bgContext = GetKeepKeysByIndex(index)
		if keepId and IsThisCampaign(bgContext) then
			local owner = GetKeepAlliance(keepId, bgContext)
			local attacked = GetKeepUnderAttack(keepId, bgContext) and true or false

			if SCORED_TYPE[GetKeepType(keepId)] and owner and owner ~= ALLIANCE_NONE then
				local row = tally[owner]
				if not row then
					row = { held = 0, attacked = 0 }
					tally[owner] = row
				end
				row.held = row.held + 1
				if attacked then
					row.attacked = row.attacked + 1
				end
			end

			if alerting and self:IsWatchedType(keepId) then
				watched = watched + 1
				seen[KeepKey(keepId, bgContext)] = true
				if self:Examine(keepId, bgContext, playerAlliance, now, owner, attacked) then
					underAttack = underAttack + 1
				end
			end
		end
	end

	self.tally = tally
	self.board:Refresh()
	self.map:RefreshKeeps()

	-- A holding that has dropped out of the list -- campaign changed under us, or the client
	-- stopped reporting it -- is forgotten without an ending. We do not know how its fight
	-- finished, and inventing an answer is worse than staying quiet.
	for key in pairs(self.watch) do
		if not seen[key] then
			self.watch[key] = nil
		end
	end

	self.firstScan = false
	return total, watched, underAttack
end

-- ---------------------------------------------------------------------------------------
-- The timer
-- ---------------------------------------------------------------------------------------

-- Whether a pass here could see anything at all. The answer decides whether the timer exists,
-- not merely what it does when it fires: outside Cyrodiil there is nothing to read, and a timer
-- that wakes up every few seconds to establish that is a cost with nothing on the other side of
-- it. Most of a session is spent outside Cyrodiil.
function addon:ShouldWatchHere()
	if not self.sv.enabled then
		return false
	end
	if not self:HasKeepApi() then
		return false
	end
	if self.sv.onlyInAvA and not self:InAvAZone() then
		return false
	end
	return true
end

-- Called at every zone change (EVENT_PLAYER_ACTIVATED), and whenever a setting that bears on
-- the above changes. Re-applying is cheap: registering an update under a name that is already
-- registered replaces it.
function addon:ApplyTimer()
	em:UnregisterForUpdate(self.name)
	self.timerRunning = false

	if not self:ShouldWatchHere() then
		-- Nothing will be counted from here on. Anything being carried would be a memory of a
		-- different place by the time the timer comes back, so it goes now, along with the
		-- summary that was drawn from it.
		self:Forget()
		self.tally = nil
		self.board:Refresh()
		self.map:Refresh()
		return
	end
	self.map:Refresh()

	em:RegisterForUpdate(self.name, self:IntervalSeconds() * 1000, function()
		self:Scan()
	end)
	self.timerRunning = true
end

function addon:SetEnabled(enabled)
	self.sv.enabled = enabled and true or false
	self:Forget()
	-- Both directions: ApplyTimer starts, or stops and clears, according to the same test.
	self:ApplyTimer()
end

function addon:SetInterval(seconds)
	self.sv.intervalSeconds = Clamp(math.floor(seconds), MIN_INTERVAL, MAX_INTERVAL)
	self:ApplyTimer()
	return self.sv.intervalSeconds
end

function addon:SetRepeat(seconds)
	self.sv.repeatSeconds = Clamp(math.floor(seconds), MIN_REPEAT, MAX_REPEAT)
	return self.sv.repeatSeconds
end

function addon:ResetSettings()
	self.sv.enabled = DEFAULTS.enabled
	self.sv.intervalSeconds = DEFAULTS.intervalSeconds
	self.sv.repeatSeconds = DEFAULTS.repeatSeconds
	self.sv.groups = {}
	for key, value in pairs(DEFAULTS.groups) do
		self.sv.groups[key] = value
	end
	self.sv.colours = { chat = {}, hud = {} }
	for _, kind in ipairs(KINDS) do
		self.sv.colours.chat[kind.key] = DEFAULTS.colours.chat[kind.key]
		self.sv.colours.hud[kind.key] = DEFAULTS.colours.hud[kind.key]
	end
	self.sv.hudFollowsChatColours = DEFAULTS.hudFollowsChatColours
	self.sv.hud = {}
	for field, value in pairs(DEFAULTS.hud) do
		if field == "kinds" then
			self.sv.hud.kinds = {}
			for kindKey, shown in pairs(value) do
				self.sv.hud.kinds[kindKey] = shown
			end
		else
			self.sv.hud[field] = value
		end
	end
	self.sv.log = {}
	for field, value in pairs(DEFAULTS.log) do
		self.sv.log[field] = value
	end
	self.log:Clear()
	self.log:Refresh()
	self.sv.map = {}
	for field, value in pairs(DEFAULTS.map) do
		self.sv.map[field] = value
	end
	self.map:Refresh()
	self.sv.board = {}
	for field, value in pairs(DEFAULTS.board) do
		self.sv.board[field] = value
	end
	self.hud:Refresh()
	self.board:Refresh()
	self.sv.offense = DEFAULTS.offense
	self.sv.offenseOursOnly = DEFAULTS.offenseOursOnly
	self.sv.scrolls = DEFAULTS.scrolls
	self.sv.onlyInAvA = DEFAULTS.onlyInAvA
	self.sv.announceExisting = DEFAULTS.announceExisting
	self.sv.banner = DEFAULTS.banner
	self:Forget()
	self:ApplyTimer()
end

-- ---------------------------------------------------------------------------------------
-- Chat command
-- ---------------------------------------------------------------------------------------

local function OnOff(value)
	return value and GetString(SI_PBSCA_ON) or GetString(SI_PBSCA_OFF)
end

function addon:HudKindSummary()
	local parts = {}
	for _, kind in ipairs(KINDS) do
		if self:HudShows(kind.key) then
			parts[#parts + 1] = GetString(_G[kind.label])
		end
	end
	if #parts == 0 then
		return GetString(SI_PBSCA_STATUS_HUD_NONE)
	end
	return table.concat(parts, ", ")
end

function addon:GroupSummary()
	local parts = {}
	for _, group in ipairs(GROUPS) do
		if self:GroupEnabled(group.key) then
			parts[#parts + 1] = GetString(_G[group.label])
		end
	end
	return table.concat(parts, ", ")
end

function addon:PrintStatus()
	Print("%s", self.title)

	if not self:HasKeepApi() then
		Print(GetString(SI_PBSCA_STATUS_NO_API))
		return
	end

	if not self.sv.enabled then
		Print(GetString(SI_PBSCA_STATUS_DISABLED))
		return
	end

	Print(GetString(SI_PBSCA_STATUS_WATCHING), self:IntervalSeconds(), self:RepeatSeconds())

	if self:AnyGroupEnabled() then
		Print(GetString(SI_PBSCA_STATUS_GROUPS), self:GroupSummary())
	else
		Print(GetString(SI_PBSCA_STATUS_NO_GROUPS))
	end

	Print(GetString(SI_PBSCA_STATUS_OFFENSE), OnOff(self.sv.offense))
	if self.sv.offense then
		Print(GetString(SI_PBSCA_STATUS_OFFENSE_OURS), OnOff(self.sv.offenseOursOnly))
	end
	Print(GetString(SI_PBSCA_STATUS_ALLIANCE), AllianceName(GetUnitAlliance and GetUnitAlliance("player")))

	if not self:InAvAZone() then
		Print(self.sv.onlyInAvA and GetString(SI_PBSCA_STATUS_OUT_OF_AVA_IDLE) or GetString(SI_PBSCA_STATUS_OUT_OF_AVA))
	else
		-- Counted by running a pass, not by reading a cached number: the answer to "is it
		-- working?" has to come from the same code path the alerts come from.
		local total, watched, underAttack = self:Scan()
		Print(GetString(SI_PBSCA_STATUS_IN_AVA), watched, total, underAttack)
	end

	Print(GetString(SI_PBSCA_STATUS_HUD), OnOff(self.sv.hud.enabled), self:HudKindSummary())
	Print(self.sv.hudFollowsChatColours and GetString(SI_PBSCA_STATUS_COLOURS_FOLLOW)
		or GetString(SI_PBSCA_STATUS_COLOURS_OWN))
	if self.sv.hud.enabled and not self.hud:Available() then
		Print(GetString(SI_PBSCA_STATUS_HUD_FAILED))
	end

	local destination = self.sv.log.destination
	Print(GetString(SI_PBSCA_STATUS_LOG),
		GetString(destination == "chat" and SI_PBSCA_LOG_TO_CHAT
			or destination == "both" and SI_PBSCA_LOG_TO_BOTH
			or SI_PBSCA_LOG_TO_WINDOW))
	if destination ~= "chat" and not self:InAvAZone() then
		Print(GetString(SI_PBSCA_STATUS_LOG_OUT_OF_AVA))
	elseif destination ~= "chat" and not self.log:Available() then
		Print(GetString(SI_PBSCA_STATUS_LOG_FAILED))
	elseif destination ~= "chat" and self.log.drawOrderRefused then
		Print(GetString(SI_PBSCA_LOG_DRAW_REFUSED))
	end

	Print(GetString(SI_PBSCA_STATUS_BOARD), OnOff(self.sv.board.enabled))
	-- The measurement for "is the population actually being refreshed": how long since the
	-- client last received it, whoever asked.
	if self.sv.board.enabled then
		if self.lastPopulationUpdate then
			Print(GetString(SI_PBSCA_STATUS_POPULATION_AGE), FormatElapsed(Now() - self.lastPopulationUpdate))
		else
			Print(GetString(SI_PBSCA_STATUS_POPULATION_UNKNOWN))
		end
	end
	Print(GetString(SI_PBSCA_STATUS_MAP), OnOff(self.sv.map.enabled))
	if self.sv.map.enabled and self.map.failed then
		Print(GetString(SI_PBSCA_STATUS_MAP_FAILED))
	end
	if self.sv.board.enabled and self.board.drawOrderRefused then
		Print(GetString(SI_PBSCA_BOARD_DRAW_REFUSED))
	end

	Print(GetString(SI_PBSCA_STATUS_SCROLLS), OnOff(self.sv.scrolls))

	Print(GetString(SI_PBSCA_STATUS_COUNTS), self.alerted.attack, self.alerted.held,
		self.alerted.lost, self.alerted.fight, self.alerted.taken, self.alerted.scroll)
end

-- Every holding the client is reporting, with its owner and whether it is being hit. This is
-- the instrument: if an alert did not arrive, this says whether the client had the information
-- at all, whether the campaign filter kept it, and who it thinks owns the thing.
function addon:PrintList()
	if not self:HasKeepApi() then
		Print(GetString(SI_PBSCA_STATUS_NO_API))
		return
	end

	local total = GetNumKeeps() or 0
	if total == 0 then
		Print(GetString(SI_PBSCA_LIST_EMPTY))
		return
	end

	local playerAlliance = GetUnitAlliance and GetUnitAlliance("player") or ALLIANCE_NONE
	local rows, inCampaign, watched = {}, 0, 0
	for index = 1, total do
		local keepId, bgContext = GetKeepKeysByIndex(index)
		if keepId and IsThisCampaign(bgContext) then
			inCampaign = inCampaign + 1
			if self:IsWatchedType(keepId) then
				watched = watched + 1
				rows[#rows + 1] = {
					label = self:KeepLabel(keepId),
					owner = AllianceName(GetKeepAlliance(keepId, bgContext)),
					attacked = GetKeepUnderAttack(keepId, bgContext) and true or false,
					-- The measurement behind the offensive alerts: if this is always blank at
					-- a keep your alliance is visibly sieging, the siege count is not reaching
					-- this client and only the bare "a fight has started" is trustworthy.
					sieges = self:SiegeCount(keepId, bgContext, playerAlliance),
				}
			end
		end
	end

	Print(GetString(SI_PBSCA_LIST_HEADER), total, inCampaign, watched)
	for index, row in ipairs(rows) do
		if index > LIST_LIMIT then
			Line(GetString(SI_PBSCA_LIST_MORE), #rows - LIST_LIMIT)
			break
		end
		local suffix = row.attacked and GetString(SI_PBSCA_LIST_UNDER_ATTACK) or ""
		if row.sieges then
			suffix = suffix .. string.format(GetString(SI_PBSCA_LIST_SIEGE), row.sieges)
		end
		Line(GetString(SI_PBSCA_LIST_LINE), row.label, row.owner, suffix)
	end
end

function addon:PrintHelp()
	Print("%s", self.title)
	Line(GetString(SI_PBSCA_HELP_STATUS))
	Line(GetString(SI_PBSCA_HELP_LIST))
	Line(GetString(SI_PBSCA_HELP_MASTER))
	Line(GetString(SI_PBSCA_HELP_INTERVAL))
	Line(GetString(SI_PBSCA_HELP_REPEAT))
	Line(GetString(SI_PBSCA_HELP_GROUPS))
	Line(GetString(SI_PBSCA_HELP_OFFENSE))
	Line(GetString(SI_PBSCA_HELP_OFFENSE_OURS))
	Line(GetString(SI_PBSCA_HELP_SCROLLS))
	Line(GetString(SI_PBSCA_HELP_HUD))
	Line(GetString(SI_PBSCA_HELP_HUD_KIND))
	Line(GetString(SI_PBSCA_HELP_COLOUR))
	Line(GetString(SI_PBSCA_HELP_COLOUR_FOLLOW))
	Line(GetString(SI_PBSCA_HELP_LOG))
	Line(GetString(SI_PBSCA_HELP_LOG_DRAW))
	Line(GetString(SI_PBSCA_HELP_LOG_CLEAR))
	Line(GetString(SI_PBSCA_HELP_MAP))
	Line(GetString(SI_PBSCA_HELP_MAP_LINKS))
	Line(GetString(SI_PBSCA_HELP_MAP_LINKS_READY))
	Line(GetString(SI_PBSCA_HELP_MAP_RESOURCES))
	Line(GetString(SI_PBSCA_HELP_MAP_PLAYER))
	Line(GetString(SI_PBSCA_HELP_MAP_GROUP))
	Line(GetString(SI_PBSCA_HELP_MAP_PROBE))
	Line(GetString(SI_PBSCA_HELP_BOARD))
	Line(GetString(SI_PBSCA_HELP_BOARD_DRAW))
	Line(GetString(SI_PBSCA_HELP_BOARD_POP))
	Line(GetString(SI_PBSCA_HELP_TEST))
	Line(GetString(SI_PBSCA_HELP_AVA))
	Line(GetString(SI_PBSCA_HELP_EXISTING))
	Line(GetString(SI_PBSCA_HELP_BANNER))
	Line(GetString(SI_PBSCA_HELP_FORGET))
	Line(GetString(SI_PBSCA_HELP_RESET))
end

local function ParseSwitch(word)
	if word == "on" or word == "1" or word == "yes" then
		return true
	elseif word == "off" or word == "0" or word == "no" then
		return false
	end
	return nil
end

local GROUP_BY_WORD = {}
for _, group in ipairs(GROUPS) do
	GROUP_BY_WORD[group.key] = group
end
-- A couple of singulars, because "keep" is what anyone types first.
GROUP_BY_WORD["keep"] = GROUP_BY_WORD[GROUP_KEEPS]
GROUP_BY_WORD["town"] = GROUP_BY_WORD[GROUP_TOWNS]
GROUP_BY_WORD["resource"] = GROUP_BY_WORD[GROUP_RESOURCES]
GROUP_BY_WORD["district"] = GROUP_BY_WORD[GROUP_DISTRICTS]

function addon:HandleCommand(argumentString)
	local words = {}
	for word in tostring(argumentString or ""):gmatch("%S+") do
		words[#words + 1] = word:lower()
	end

	local command = words[1]
	if not command then
		self:PrintStatus()
		return
	end

	if command == "help" or command == "?" then
		self:PrintHelp()
		return
	end

	if command == "status" then
		self:PrintStatus()
		return
	end

	if command == "list" or command == "keeps?" then
		self:PrintList()
		return
	end

	if command == "forget" then
		self:Forget()
		Print(GetString(SI_PBSCA_REPLY_FORGOTTEN))
		return
	end

	if command == "reset" then
		self:ResetSettings()
		self:RefreshPanel()
		Print(GetString(SI_PBSCA_REPLY_RESET))
		return
	end

	if command == "every" or command == "interval" then
		local seconds = tonumber(words[2])
		if not seconds or seconds ~= math.floor(seconds) or seconds < MIN_INTERVAL or seconds > MAX_INTERVAL then
			Print(GetString(SI_PBSCA_ERROR_SECONDS), MIN_INTERVAL, MAX_INTERVAL)
			return
		end
		self:RefreshPanel()
		Print(GetString(SI_PBSCA_REPLY_INTERVAL), self:SetInterval(seconds))
		return
	end

	if command == "repeat" then
		local seconds = tonumber(words[2])
		if not seconds or seconds ~= math.floor(seconds) or seconds < MIN_REPEAT or seconds > MAX_REPEAT then
			Print(GetString(SI_PBSCA_ERROR_SECONDS), MIN_REPEAT, MAX_REPEAT)
			return
		end
		self:RefreshPanel()
		Print(GetString(SI_PBSCA_REPLY_REPEAT), self:SetRepeat(seconds))
		return
	end

	local group = GROUP_BY_WORD[command]
	if group then
		local value = ParseSwitch(words[2] or "")
		if value == nil then
			Print(GetString(SI_PBSCA_ERROR_ON_OR_OFF))
			return
		end
		self:SetGroupEnabled(group.key, value)
		self:RefreshPanel()
		Print(GetString(SI_PBSCA_REPLY_GROUP), GetString(_G[group.label]), OnOff(value))
		return
	end

	if command == "log" or command == "output" then
		local where = words[2] or ""
		if where == "clear" then
			self.log:Clear()
			Print(GetString(SI_PBSCA_LOG_CLEAR))
			return
		end
		-- "log front|normal|back" -- the draw order, which is a choice rather than a place.
		local draw = where:upper()
		for _, order in ipairs(self.DRAW_ORDERS or {}) do
			if order.token == draw then
				self.sv.log.draw = draw
				self.log:Refresh()
				self:RefreshPanel()
				Print(GetString(SI_PBSCA_LOG_DRAW) .. ": " .. GetString(_G[order.label]))
				if self.log.drawOrderRefused then
					Print(GetString(SI_PBSCA_LOG_DRAW_REFUSED))
				end
				return
			end
		end

		if where ~= "window" and where ~= "chat" and where ~= "both" then
			Print(GetString(SI_PBSCA_ERROR_LOG_WHERE))
			return
		end
		self.sv.log.destination = where
		self.log:Refresh()
		self:RefreshPanel()
		Print(GetString(SI_PBSCA_STATUS_LOG),
			GetString(where == "chat" and SI_PBSCA_LOG_TO_CHAT
				or where == "both" and SI_PBSCA_LOG_TO_BOTH
				or SI_PBSCA_LOG_TO_WINDOW))
		if where ~= "chat" and not self.log:Available() then
			Print(GetString(SI_PBSCA_STATUS_LOG_FAILED))
		end
		return
	end

	-- "map on|off", and "map probe" for what the map is working with.
	if command == "map" then
		local second = words[2] or ""
		if second == "probe" then
			for _, line in ipairs(self.map:Probe()) do
				Print("%s", line)
			end
			return
		end
		-- "map group on|off" -- the rest of the group.
		if second == "group" or second == "party" then
			local value = ParseSwitch(words[3] or "")
			if value == nil then
				Print(GetString(SI_PBSCA_ERROR_ON_OR_OFF))
				return
			end
			self.sv.map.group = value
			self.map:Refresh()
			self:RefreshPanel()
			Print(GetString(SI_PBSCA_MAP_GROUP) .. ": " .. OnOff(value))
			return
		end

		-- "map player on|off" -- your own arrow.
		if second == "player" or second == "me" then
			local value = ParseSwitch(words[3] or "")
			if value == nil then
				Print(GetString(SI_PBSCA_ERROR_ON_OR_OFF))
				return
			end
			self.sv.map.player = value
			self.map:Refresh()
			self:RefreshPanel()
			Print(GetString(SI_PBSCA_MAP_PLAYER) .. ": " .. OnOff(value))
			return
		end

		-- "map resources on|off" -- the farms, mines and lumbermills.
		if second == "resources" or second == "resource" then
			local value = ParseSwitch(words[3] or "")
			if value == nil then
				Print(GetString(SI_PBSCA_ERROR_ON_OR_OFF))
				return
			end
			self.sv.map.resources = value
			self.map:Refresh()
			self:RefreshPanel()
			Print(GetString(SI_PBSCA_MAP_RESOURCES) .. ": " .. OnOff(value))
			return
		end

		-- "map ready on|off" -- the shrine's green for the routes you can take.
		if second == "ready" or second == "green" then
			local value = ParseSwitch(words[3] or "")
			if value == nil then
				Print(GetString(SI_PBSCA_ERROR_ON_OR_OFF))
				return
			end
			self.sv.map.linksReady = value
			self.map:Refresh()
			self:RefreshPanel()
			Print(GetString(SI_PBSCA_MAP_LINKS_READY) .. ": " .. OnOff(value))
			return
		end

		-- "map links on|off" -- the transitus network.
		if second == "links" or second == "transitus" then
			local value = ParseSwitch(words[3] or "")
			if value == nil then
				Print(GetString(SI_PBSCA_ERROR_ON_OR_OFF))
				return
			end
			self.sv.map.links = value
			self.map:Refresh()
			self:RefreshPanel()
			Print(GetString(SI_PBSCA_MAP_LINKS) .. ": " .. OnOff(value))
			return
		end
		local value = ParseSwitch(second)
		if value == nil then
			Print(GetString(SI_PBSCA_ERROR_ON_OR_OFF))
			return
		end
		self.sv.map.enabled = value
		self.map:Refresh()
		self:RefreshPanel()
		Print(GetString(SI_PBSCA_STATUS_MAP), OnOff(value))
		if value and self.map.failed then
			Print(GetString(SI_PBSCA_STATUS_MAP_FAILED))
		end
		return
	end

	-- "board" alone prints the summary here; "board on|off" is the screen switch. Printing is
	-- the no-argument case because it is the one that answers a question rather than changing
	-- something, which is the same rule /pbalert itself follows.
	if command == "board" or command == "campaign" then
		local second = words[2]
		if not second then
			self:PrintSituation()
			return
		end
		-- "board pop icon|text" -- how the population column is drawn.
		if second == "pop" or second == "population" then
			local how = words[3] or ""
			if how ~= "icon" and how ~= "text" and how ~= "word" then
				Print(GetString(SI_PBSCA_ERROR_POP))
				return
			end
			self.sv.board.populationText = how ~= "icon"
			self.board:Refresh()
			self:RefreshPanel()
			Print(GetString(SI_PBSCA_BOARD_POP_TEXT) .. ": " .. OnOff(self.sv.board.populationText))
			return
		end

		-- "board front|normal|back" -- the draw order, which is a choice rather than a switch.
		local draw = second:upper()
		for _, order in ipairs(self.DRAW_ORDERS or {}) do
			if order.token == draw then
				self.sv.board.draw = draw
				self.board:Refresh()
				self:RefreshPanel()
				Print(GetString(SI_PBSCA_BOARD_DRAW) .. ": " .. GetString(_G[order.label]))
				if self.board.drawOrderRefused then
					Print(GetString(SI_PBSCA_BOARD_DRAW_REFUSED))
				end
				return
			end
		end

		local value = ParseSwitch(second)
		if value == nil then
			Print(GetString(SI_PBSCA_ERROR_ON_OR_OFF))
			Print(GetString(SI_PBSCA_ERROR_DRAW))
			return
		end
		self.sv.board.enabled = value
		self.board:Refresh()
		self:RefreshPanel()
		Print(GetString(SI_PBSCA_STATUS_BOARD), OnOff(value))
		if value and not self.board:Available() then
			Print(GetString(SI_PBSCA_STATUS_HUD_FAILED))
		end
		return
	end

	if command == "test" then
		self:ShowTest()
		return
	end

	-- "hud on|off", and "hud <alert> on|off" for one kind of alert.
	if command == "hud" or command == "screen" then
		local second = words[2] or ""
		local kind = KIND_BY_KEY[second]
		if kind then
			local value = ParseSwitch(words[3] or "")
			if value == nil then
				Print(GetString(SI_PBSCA_ERROR_ON_OR_OFF))
				return
			end
			self:SetHudShows(kind.key, value)
			self:RefreshPanel()
			Print(GetString(SI_PBSCA_STATUS_HUD), OnOff(self.sv.hud.enabled), self:HudKindSummary())
			return
		end

		local value = ParseSwitch(second)
		if value == nil then
			-- Not on/off and not an alert name: say which of the two it should have been.
			if second ~= "" then
				Print(GetString(SI_PBSCA_ERROR_KIND), second)
			else
				Print(GetString(SI_PBSCA_ERROR_ON_OR_OFF))
			end
			return
		end
		self.sv.hud.enabled = value
		self.hud:Refresh()
		self:RefreshPanel()
		Print(GetString(SI_PBSCA_STATUS_HUD), OnOff(value), self:HudKindSummary())
		if value and not self.hud:Available() then
			Print(GetString(SI_PBSCA_STATUS_HUD_FAILED))
		end
		return
	end

	-- "colour <alert> chat|hud <name or RRGGBB>"
	if command == "colour" or command == "color" then
		-- "colour follow on|off" -- whether the screen uses chat's colours at all.
		if (words[2] or "") == "follow" then
			local value = ParseSwitch(words[3] or "")
			if value == nil then
				Print(GetString(SI_PBSCA_ERROR_ON_OR_OFF))
				return
			end
			self.sv.hudFollowsChatColours = value
			self.hud:Refresh()
			self:RefreshPanel()
			Print(value and GetString(SI_PBSCA_STATUS_COLOURS_FOLLOW) or GetString(SI_PBSCA_STATUS_COLOURS_OWN))
			return
		end

		local kind = KIND_BY_KEY[words[2] or ""]
		if not kind then
			Print(GetString(SI_PBSCA_ERROR_KIND), words[2] or "")
			return
		end
		local surface = words[3]
		if surface ~= SURFACE_CHAT and surface ~= SURFACE_HUD then
			Print(GetString(SI_PBSCA_ERROR_SURFACE))
			return
		end
		local wanted = words[4] or ""
		local hex = self:NormaliseHex(wanted) or self:HexForColourWord(wanted)
		if not hex then
			Print(GetString(SI_PBSCA_ERROR_COLOUR))
			return
		end
		self:SetColour(surface, kind.key, hex)
		self:RefreshPanel()
		-- Answered in the colour it has just been set to, on the surface that can show it:
		-- the reply is the sample.
		local reply = Format(SI_PBSCA_REPLY_COLOUR, GetString(_G[kind.label]),
			GetString(surface == SURFACE_HUD and SI_PBSCA_SURFACE_HUD or SI_PBSCA_SURFACE_CHAT), hex)
		Line(PREFIX .. "|c" .. hex .. reply .. "|r")
		-- Say it when a screen colour has just taken the two surfaces apart.
		if self.brokeColourFollow then
			self.brokeColourFollow = nil
			Print(GetString(SI_PBSCA_REPLY_FOLLOW_OFF))
		end
		return
	end

	if command == "offense" or command == "offence" or command == "enemy" then
		-- "offense ours on|off" -- the siege filter, one word in from the switch it qualifies.
		local second = words[2] or ""
		if second == "ours" or second == "siege" or second == "mine" then
			local value = ParseSwitch(words[3] or "")
			if value == nil then
				Print(GetString(SI_PBSCA_ERROR_ON_OR_OFF))
				return
			end
			self.sv.offenseOursOnly = value
			self:Forget()
			self:RefreshPanel()
			Print(GetString(SI_PBSCA_STATUS_OFFENSE_OURS), OnOff(value))
			return
		end

		local value = ParseSwitch(second)
		if value == nil then
			Print(GetString(SI_PBSCA_ERROR_ON_OR_OFF))
			return
		end
		self.sv.offense = value
		-- Switching it off must not leave enemy entries behind that could still produce a
		-- "taken" line later, and switching it on must not inherit a stale one.
		self:Forget()
		self:RefreshPanel()
		Print(GetString(SI_PBSCA_REPLY_GROUP), GetString(SI_PBSCA_OFFENSE), OnOff(value))
		return
	end

	if command == "scrolls" or command == "scroll" then
		local value = ParseSwitch(words[2] or "")
		if value == nil then
			Print(GetString(SI_PBSCA_ERROR_ON_OR_OFF))
			return
		end
		self.sv.scrolls = value
		self:RefreshPanel()
		Print(GetString(SI_PBSCA_STATUS_SCROLLS), OnOff(value))
		return
	end

	if command == "ava" then
		local value = ParseSwitch(words[2] or "")
		if value == nil then
			Print(GetString(SI_PBSCA_ERROR_ON_OR_OFF))
			return
		end
		self.sv.onlyInAvA = value
		-- This is the switch the timer's existence hangs on, so it is applied, not just stored.
		self:ApplyTimer()
		self:RefreshPanel()
		Print(GetString(SI_PBSCA_REPLY_GROUP), GetString(SI_PBSCA_ONLY_AVA), OnOff(value))
		return
	end

	if command == "existing" then
		local value = ParseSwitch(words[2] or "")
		if value == nil then
			Print(GetString(SI_PBSCA_ERROR_ON_OR_OFF))
			return
		end
		self.sv.announceExisting = value
		self:RefreshPanel()
		Print(GetString(SI_PBSCA_REPLY_GROUP), GetString(SI_PBSCA_ANNOUNCE_EXISTING), OnOff(value))
		return
	end

	if command == "banner" then
		local value = ParseSwitch(words[2] or "")
		if value == nil then
			Print(GetString(SI_PBSCA_ERROR_ON_OR_OFF))
			return
		end
		self.sv.banner = value
		self:RefreshPanel()
		Print(GetString(SI_PBSCA_REPLY_BANNER), OnOff(value))
		return
	end

	-- The master switch. Bare "on"/"off" with nothing in front of it.
	local masterSwitch = ParseSwitch(command)
	if masterSwitch ~= nil and not words[2] then
		self:SetEnabled(masterSwitch)
		self:RefreshPanel()
		self:PrintStatus()
		return
	end

	Print(GetString(SI_PBSCA_ERROR_UNKNOWN), command)
	self:PrintHelp()
end

function addon:InitSlashCommand()
	local handler = function(argumentString)
		self:HandleCommand(argumentString)
	end
	SLASH_COMMANDS[SLASH] = handler
	SLASH_COMMANDS[SHORT_SLASH] = handler
end

-- Settings.lua fills this in when the library is there. Defined here so every command can call
-- it without asking whether a panel exists.
function addon:RefreshPanel()
	if self.settingsControls and self.settingsControls.UpdateControls then
		self.settingsControls:UpdateControls()
	end
end

-- ---------------------------------------------------------------------------------------
-- Load
-- ---------------------------------------------------------------------------------------

local function OnPlayerActivated()
	-- Before the panel is built: its sliders take their range from the screen.
	addon:UpdateScreenLimits()
	if not addon.panelBuilt then
		addon.panelBuilt = true
		if addon.InitSettings then
			addon:InitSettings()
		end
	end

	-- Every activation is a zone change, and a zone change can be a change of campaign. What
	-- was under attack in the campaign we left is not our business any more.
	addon:Forget()
	addon:ApplyTimer()
	-- Builds the on-screen window if it is switched on, so the first alert of the session is
	-- not also the first time anything is created.
	addon.hud:Refresh()
	addon.log:Refresh()
	addon.map:Refresh(true)

	if addon.sv.banner then
		addon:PrintStatus()
	end
end

local function OnAddOnLoaded(_, name)
	if name ~= addon.name then
		return
	end
	em:UnregisterForEvent(addon.name, EVENT_ADD_ON_LOADED)

	addon.sv = ZO_SavedVars:NewAccountWide("PBsCyrodiilAlert_Data", 1, nil, DEFAULTS)

	addon:InitSlashCommand()

	-- The artifact's three announcements, for its clock.
	if EVENT_DAEDRIC_ARTIFACT_OBJECTIVE_SPAWNED_BUT_NOT_REVEALED then
		em:RegisterForEvent(addon.name, EVENT_DAEDRIC_ARTIFACT_OBJECTIVE_SPAWNED_BUT_NOT_REVEALED,
			function(_, artifactId)
				addon:OnArtifactSpawned(artifactId)
			end)
	end
	if EVENT_DAEDRIC_ARTIFACT_OBJECTIVE_STATE_CHANGED then
		em:RegisterForEvent(addon.name, EVENT_DAEDRIC_ARTIFACT_OBJECTIVE_STATE_CHANGED,
			function(_, keepId, objectiveId, bgContext, controlEvent, controlState, holderAlliance,
				lastHolderAlliance, pinType, artifactId, lastControlState)
				addon:OnArtifactStateChanged(bgContext, controlState, artifactId, lastControlState)
			end)
	end

	-- The answer to a population query, whenever it arrives -- ours, or the one the campaign
	-- browser makes when the player opens it.
	if EVENT_CAMPAIGN_SELECTION_DATA_CHANGED then
		em:RegisterForEvent(addon.name, EVENT_CAMPAIGN_SELECTION_DATA_CHANGED, function()
			-- When the data actually arrived -- ours, or the campaign browser's -- which is what
			-- "last updated" in the status means.
			addon.lastPopulationUpdate = Now()
			addon.board:Refresh()
		end)
	end

	-- The scroll events are the add-on's only subscription besides load and activation. They
	-- are registered here rather than at activation because they are not tied to a zone: the
	-- handler decides whether to say anything, from the settings, every time.
	if EVENT_ARTIFACT_CONTROL_STATE then
		em:RegisterForEvent(addon.name, EVENT_ARTIFACT_CONTROL_STATE,
			function(_, artifactName, keepId, characterName, playerAlliance, controlEvent, controlState, campaignId, displayName)
				addon:OnScrollEvent(artifactName, keepId, characterName, playerAlliance, controlEvent, displayName)
			end)
	end

	-- The timer is started at EVENT_PLAYER_ACTIVATED rather than here: at load there is no
	-- world yet, so the first pass would read an empty keep list and call it the baseline.
	em:RegisterForEvent(addon.name, EVENT_PLAYER_ACTIVATED, OnPlayerActivated)
end

em:RegisterForEvent(addon.name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)

PBS_CYRODIIL_ALERT = addon
