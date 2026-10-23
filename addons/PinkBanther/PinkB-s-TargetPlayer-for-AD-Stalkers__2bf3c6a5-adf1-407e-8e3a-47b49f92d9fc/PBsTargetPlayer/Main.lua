-- PB's TargetPlayer for AD Stalkers
-- Author: PinkBanther
--
-- Puts the game's own target marker on chosen players, so they stand out above their
-- nameplate.
--
-- ---------------------------------------------------------------------------------------
-- WHO MAY USE IT
-- ---------------------------------------------------------------------------------------
--
-- Two PSN IDs only: SO1-WYLDE and PinkBanther. At load the add-on reads the console ID of the
-- player who is logged in (GetPlatformDisplayName) and runs only if it is on the list. The ESO
-- @account is deliberately not consulted: the IDs were given as PSN IDs, and an account that
-- happens to be spelled like one of them is not that person. Anyone else gets one line in chat
-- after login and nothing more: no events, no settings panel, no saved variables. The check is in
-- the Lua, which is plain text on the player's machine, so it keeps the add-on from being used by
-- accident or by the casual installer; it is not protection against someone who edits the file.
--
-- ---------------------------------------------------------------------------------------
-- HOW
-- ---------------------------------------------------------------------------------------
--
-- The engine draws target markers over a unit's nameplate (Settings > Nameplates > Target
-- Markers), and the client's own marker wheel sets one with
--
--     AssignTargetMarkerToReticleTarget(markerType)
--
-- (esoui/ingame/targetmarker/targetmarkerwheel_shared.lua). The same call, made when the
-- reticle lands on a registered player, puts a real marker on them: drawn by the engine, above
-- the nameplate, in the game's own style. The client also puts the marker's icon in front of
-- the name in the unit frames (unitframes.lua, UpdateName), so the add-on draws nothing of its
-- own. It writes to no control, hooks nothing and runs no timer: one event handler.
--
-- ---------------------------------------------------------------------------------------
-- WHAT THE GAME'S RULES MEAN FOR IT
-- ---------------------------------------------------------------------------------------
--
--   * The call takes no unit, only "the reticle target". A player is marked the first time the
--     reticle is on them, not when they come into view: nothing in the API lists the players
--     around you, and a marker cannot be set on a unit that is not under the reticle. (Unit
--     tags exist only for the group and reticleover, EVENT_UNIT_CREATED included.)
--   * A marker type sits on one unit at a time. One mark for every registered player means it
--     moves to whichever of them was looked at last.
--   * Setting the same marker on the same unit again may toggle it off, so it is set once per
--     contact, from the reticle event -- never from a timer that could ask twice before the
--     server has answered -- and a retry window keeps a flickering reticle from asking again.
--   * A marker someone else put on the unit is left alone.
--
-- ---------------------------------------------------------------------------------------
-- NOT MARKING THE WRONG PERSON
-- ---------------------------------------------------------------------------------------
--
-- AssignTargetMarkerToReticleTarget names no player: the marker goes to whoever is under the
-- reticle when the game acts on it, not to whoever was when the add-on asked. In a crowd those can
-- differ, and a death makes them differ: the registered player falls with the reticle on them, the
-- marker leaves them, the add-on (seeing a registered player with no marker) asks for it again, and
-- by the time the game acts the player has respawned elsewhere and the reticle is on a bystander.
-- Three things follow.
--
--   * Nothing is set on a dead target, nor on a player who died in the last few seconds (the kill
--     feed and the target's own death event both say so).
--   * The marker is not set the moment the reticle lands: the target has to still be the same
--     registered player a quarter of a second later, or the request is dropped.
--   * Whatever goes wrong anyway is undone. A marker of the kind the add-on set, found on a player
--     who is not registered and not in the group, is cleared -- right after the add-on set one, and
--     again whenever the reticle meets such a player. Clearing is AssignTargetMarkerToReticleTarget
--     with TARGET_MARKER_TYPE_NONE, which has NOT been measured on a console; if the marker is
--     still there a second later the add-on gives up clearing for the session and says so.
--
-- ---------------------------------------------------------------------------------------
-- WHEN THEY ARE NOT UNDER THE RETICLE: AN ALERT
-- ---------------------------------------------------------------------------------------
--
-- A player who is neither in the group nor under the reticle cannot be marked or located (no
-- unit tag, no position -- see FINDINGS.md). What can be known is that they are around: the
-- game tells add-ons their names in two places.
--
--   EVENT_PVP_KILL_FEED_DEATH   the Cyrodiil kill feed: killer and victim, with the @account,
--                               the character name and the place (a keep). Delivered whatever
--                               the chat option says; PB's KillLog uses it on a PS5.
--   EVENT_COMBAT_EVENT          character names only, and only for what involves the player
--                               or the group. Filtered by the engine to the "other" unit type.
--
-- A registered player showing up in either raises a short on-screen message and a sound. This
-- does not point at them -- it says "he is here", and from the kill feed, where.
--
-- Combat events carry character names, not the @account a player was registered under. The
-- name is learned instead: every time the reticle lands on a registered player their character
-- name is kept with the entry, and from then on combat events naming that character match.
-- (A character name can be registered directly and needs no learning.) Whether combat events
-- reach this far out is not known; /pbtarget status counts what arrives.
--
-- ---------------------------------------------------------------------------------------
-- WHERE THEY ARE, AND WHEN THEY ENTER CYRODIIL
-- ---------------------------------------------------------------------------------------
--
-- Friends and guild members are the one group of players the game reports on wherever they are:
-- GetFriendInfo / GetFriendCharacterInfo and GetGuildMemberInfo / GetGuildMemberCharacterInfo give
-- the status, the character, the zone and the zone id, and the game raises an event when a friend
-- or guild member changes zone or comes online. So for a registered player who is on the friend
-- list or in one of the player's guilds:
--
--   * /pbtarget where, and a Location row in each entry of the settings panel, say where they are
--     (zone level: "Cyrodiil", "Eastmarch" -- not which keep) or when they were last online;
--   * entering Cyrodiil, or coming online in it, raises the alert.
--
-- A registered player who is neither a friend nor in a shared guild cannot be located at all: no
-- roster lists them. The add-on says so rather than guessing.
--
-- Cyrodiil is found by asking the game, not by a number written here: GetCyrodiilMapIndex ->
-- GetMapInfoByIndex -> GetZoneId. A roster entry is in Cyrodiil if its zone id is that zone or a
-- zone inside it; failing that, if its zone name is Cyrodiil's.
--
-- ---------------------------------------------------------------------------------------
-- NEVER CALLED BLIND
-- ---------------------------------------------------------------------------------------
--
-- Whether an add-on may call AssignTargetMarkerToReticleTarget is not something the
-- documentation can settle: its private/protected marker has been wrong before (SetSetting
-- carries none and is private), and a private call raises a UI error that pcall does not
-- catch. The API's own way to ask is IsPrivateFunction / IsProtectedFunction, so that is asked
-- first, once. If either says yes, the question cannot be asked, or the function is missing,
-- the add-on does not call it, says why in chat, and does nothing else.
--
-- ---------------------------------------------------------------------------------------
-- WHO COUNTS AS "THE PLAYER"
-- ---------------------------------------------------------------------------------------
--
-- A console player is known by three names: the @account (GetUnitDisplayName), the platform
-- ID (GetUnitPlatformDisplayName -- the PSN/Xbox name) and the character name (GetUnitName,
-- which carries a "^Fx" gender suffix). Any of them can be registered, and a unit is matched
-- on all three. Comparison ignores case, a leading @ (full-width too) and the gender suffix.

if PBS_TARGET_PLAYER then
	return
end

local addon = {
	name = "PBsTargetPlayer",
}
PBS_TARGET_PLAYER = addon

local em = EVENT_MANAGER

-- The display name is a Lua constant and the version comes from the manifest, the same way
-- PB's ChatFilter does it -- reading the name back out of "## Title" mangles the apostrophe
-- in the settings library. Typographic apostrophe (U+2019), not ASCII '.
local DISPLAY_NAME = "PB’s TargetPlayer for AD Stalkers"
-- What goes in front of a chat line. The full name is long, and it would head every line.
local CHAT_NAME = "PB’s TargetPlayer"
local AUTHOR = "PinkBanther"
local SLASH = "/pbtarget"
local SHORT_SLASH = "/pbtp"

local MAX_PLAYERS = 20
local MAX_ID_CHARS = 40
local MARK_RETRY_MS = 3000
local MARK_DWELL_MS = 250 -- the target must still be the same player this long after the reticle landed
local MARK_AFTER_DEATH_MS = 10000 -- nothing is set on a registered player who died this recently
local STRAY_CHECK_WINDOW_MS = 3000 -- after setting a marker, marker updates are checked for a mismark
local STRAY_RETRY_MS = 5000 -- the same stray player is not cleared more often than this
local STRAY_RECENT_MS = 600000 -- a marker is only "ours" if the add-on set one this recently
local CLEAR_VERIFY_MS = 1000
local ALERT_SHOW_MS = 6000
local ALERT_COOLDOWN_MS = { combat = 20000, kill = 4000, cyro = 30000, near = 20000 }
local LOCATE_TTL_MS = 10000 -- a roster scan is not repeated inside this
local LOCATE_SEED_MS = 20000 -- after login, once, so that who is already in Cyrodiil is not news
local MAX_LEARNED = 6
local NAME_CACHE_MAX = 300

addon.MAX_PLAYERS = MAX_PLAYERS
addon.MAX_ID_CHARS = MAX_ID_CHARS

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
-- The marks
--
-- The game's eight target markers, by number. They are written out by hand rather than
-- derived from TARGET_MARKER_TYPE_ONE: the enum's numeric values are not documented, and an
-- offset calculation on a renumbered client would silently set the wrong marker.
-- ---------------------------------------------------------------------------------------

local MARK_TYPE_NAMES = {
	"TARGET_MARKER_TYPE_ONE",
	"TARGET_MARKER_TYPE_TWO",
	"TARGET_MARKER_TYPE_THREE",
	"TARGET_MARKER_TYPE_FOUR",
	"TARGET_MARKER_TYPE_FIVE",
	"TARGET_MARKER_TYPE_SIX",
	"TARGET_MARKER_TYPE_SEVEN",
	"TARGET_MARKER_TYPE_EIGHT",
}
local MAX_MARK = #MARK_TYPE_NAMES
addon.MAX_MARK = MAX_MARK

-- ---------------------------------------------------------------------------------------
-- Defaults
--
-- Nothing here is ever nil -- see PBsNamePlateChanger's FINDINGS.md for what a nil setting
-- does to a combo box -- and an empty slot is an empty string.
-- ---------------------------------------------------------------------------------------

local DEFAULTS = {
	enabled = true,
	-- One mark for every registered player, chosen by the user: 1..8 are the game's target
	-- markers. 7 is the red crossed swords.
	mark = 7,
	-- A message and a sound when a registered player turns up in the kill feed or in combat.
	alert = true,
	sound = true,
	-- A message and a sound when a registered friend or guild member enters Cyrodiil.
	cyrodiil = true,
	-- Take the add-on's marker off a bystander it ended up on.
	cleanup = true,
	banner = true,
	players = {},
}
for slot = 1, MAX_PLAYERS do
	-- chars: the normalised character names learned for this player (see Learn).
	DEFAULTS.players[slot] = { id = "", chars = {} }
end
addon.DEFAULTS = DEFAULTS

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

local PREFIX = "|cFF69B4" .. CHAT_NAME .. "|r: "

local function Print(text, ...)
	if select("#", ...) > 0 then
		local ok, formatted = pcall(string.format, text, ...)
		Say(PREFIX .. (ok and formatted or text))
	else
		Say(PREFIX .. text)
	end
end

addon.Print = Print

-- ---------------------------------------------------------------------------------------
-- Names
-- ---------------------------------------------------------------------------------------

local lower = zo_strlower or string.lower

local FULLWIDTH_AT = "\239\188\160" -- U+FF20, what a Japanese keyboard types for @
local IDEOGRAPHIC_SPACE = "\227\128\128" -- U+3000

local function Trim(s)
	return (s:gsub(IDEOGRAPHIC_SPACE, " "):match("^%s*(.-)%s*$"))
end

-- What two spellings of the same player have in common. "@Foo", "foo", "＠FOO" and a
-- character name still carrying its "^Fx" gender suffix all land on the same key.
local function Normalize(raw)
	if type(raw) ~= "string" or raw == "" then
		return ""
	end
	local s = Trim(raw:gsub("%^%a+$", ""))
	if s:sub(1, 3) == FULLWIDTH_AT then
		s = s:sub(4)
	elseif s:sub(1, 1) == "@" then
		s = s:sub(2)
	end
	return lower(Trim(s))
end
addon.Normalize = Normalize

-- Names from the game can carry a grammar suffix ("Luceda^Fx", "Cyrodiil^n"). For showing, not for
-- comparing: Normalize does the comparing.
local function CleanName(raw)
	return (tostring(raw or ""):gsub("%^.*$", ""))
end

-- ---------------------------------------------------------------------------------------
-- Who may use it
-- ---------------------------------------------------------------------------------------

-- Compared the way player names are everywhere else here: case, a leading @ and a gender suffix
-- do not matter.
local ALLOWED_USERS = {
	["so1-wylde"] = true,
	["pinkbanther"] = true,
}

-- Shown in Japanese whatever the client language is: the wording was asked for exactly.
local DENIED_MESSAGE = "あなたはこのアドオンを使用できません"

-- The console ID of the logged-in player (PSN online ID). It is read at load, like the account
-- name ZO_SavedVars reads then. An empty answer is "unknown", which is not on the list.
local function PlatformId()
	return GetPlatformDisplayName and GetPlatformDisplayName() or ""
end

local function IsAllowedUser()
	return ALLOWED_USERS[Normalize(PlatformId())] == true
end
addon.IsAllowedUser = IsAllowedUser

-- Everyone else: the message once after login (chat is not up at load, so it waits for the first
-- activation) and again whenever the slash command is tried. The command also says which ID was
-- read, so the owner can tell a refused stranger from a mis-read ID.
local function RefuseToRun()
	addon.denied = true

	local function SayIdentity()
		Print(DENIED_MESSAGE)
	end

	local function handler()
		SayIdentity()
		Say("PSN ID: " .. tostring(PlatformId()))
	end
	SLASH_COMMANDS[SLASH] = handler
	SLASH_COMMANDS[SHORT_SLASH] = handler

	local told = false
	em:RegisterForEvent(addon.name, EVENT_PLAYER_ACTIVATED, function()
		if not told then
			told = true
			SayIdentity()
		end
	end)
end

-- ---------------------------------------------------------------------------------------
-- State
-- ---------------------------------------------------------------------------------------

local sv
local keys = {} -- normalised ID -> slot
local hasKeys = false
local keysVersion = 0
local matchCache = {} -- unit tag -> what was last matched, so a contact does not re-normalise
local nameCache = {} -- raw name from an event -> slot, or false; a combat fight sends thousands
local nameCacheSize = 0
local alertsActive = false -- the master switch, the alert switch and at least one name
local watchActive = false -- the master switch, the Cyrodiil switch and at least one name
local trackActive = false -- the master switch and at least one name: sightings are recorded
local sightings = {} -- slot -> the last time the add-on came across that player (see Sighted)
local locateCache, locateAt = nil, 0 -- the last roster scan
local presence = {} -- slot -> true while a registered player is known to be in Cyrodiil
local diedAt = {} -- slot -> when that registered player was last known to die
local pendingMark = nil -- the player the reticle landed on, waiting out MARK_DWELL_MS
local lastAssignAt = -1000000 -- when the add-on last asked for a marker
local strayTried = {} -- player name -> when a stray marker on them was last cleared
local clearCheck = nil -- the clear being checked
local cleanupBroken = false -- clearing did not work: stop trying
local lastAlert = {} -- kind .. slot -> when it last fired

-- What the add-on did, for /pbtarget status. `last` is a plain identifier, not a sentence: it
-- is for reading a measurement, not for display.
local diag = {
	assigned = 0, last = "no contact yet", combat = 0, kills = 0, matched = 0, shown = 0, lastAlert = "none",
	rosterSeen = 0, rosterMatched = 0, scans = 0,
	chat = 0, sightings = 0,
	aborted = 0, deadSkips = 0, deaths = 0, stray = 0, cleared = 0, clearFailed = false,
}
addon.diag = diag

-- ---------------------------------------------------------------------------------------
-- The game's marker
-- ---------------------------------------------------------------------------------------

local engine = { checked = false, usable = false, why = "not checked yet" }
addon.engine = engine
local lastMarkTry = {} -- slot -> when we last set the marker on that player
local weSet = {} -- marker type -> true, for the ones this session has set

local function EngineMarkUsable()
	if engine.checked then
		return engine.usable
	end
	engine.checked = true
	engine.usable = false

	if type(AssignTargetMarkerToReticleTarget) ~= "function" or type(GetUnitTargetMarkerType) ~= "function" then
		engine.why = "the function does not exist"
	elseif type(IsPrivateFunction) ~= "function" or type(IsProtectedFunction) ~= "function" then
		-- Cannot ask, so cannot know. Not calling is the only safe answer.
		engine.why = "cannot check whether it is allowed"
	else
		local ok, isPrivate = pcall(IsPrivateFunction, "AssignTargetMarkerToReticleTarget")
		local ok2, isProtected = pcall(IsProtectedFunction, "AssignTargetMarkerToReticleTarget")
		if not ok or not ok2 then
			engine.why = "the check itself failed"
		elseif isPrivate then
			engine.why = "the game marks it private"
		elseif isProtected then
			engine.why = "the game marks it protected"
		else
			engine.usable = true
			engine.why = "allowed"
		end
	end

	if not engine.usable then
		Print(GetString(SI_PBTP_ENGINE_UNAVAILABLE), engine.why)
	end
	return engine.usable
end

-- The reticle is on a registered player. Returns nothing; says what it did in diag.last.
local function ReticleIsDead()
	if IsUnitDeadOrReincarnating then
		return IsUnitDeadOrReincarnating("reticleover") and true or false
	end
	return IsUnitDead and IsUnitDead("reticleover") and true or false
end

local function MarkInWorld(slot)
	if not EngineMarkUsable() then
		diag.last = "not allowed: " .. engine.why
		return
	end
	-- A dead player has lost the marker, and asking for it again is how it ends up on whoever is
	-- standing where they fell once they have respawned. See "Not marking the wrong person".
	if ReticleIsDead() then
		diag.deadSkips = diag.deadSkips + 1
		diag.last = "the target is dead"
		return
	end
	if diedAt[slot] and GetGameTimeMilliseconds() - diedAt[slot] < MARK_AFTER_DEATH_MS then
		diag.deadSkips = diag.deadSkips + 1
		diag.last = "died a moment ago"
		return
	end
	local wanted = _G[MARK_TYPE_NAMES[sv.mark]]
	if not wanted then
		diag.last = "this client has no such marker"
		return
	end

	-- What is already on the unit decides. Ours means the job is done. A marker of a type this
	-- session has set (an earlier choice of the user's) is ours too, and is replaced by the
	-- current one. Anything else is somebody else's and is not ours to take.
	local current = GetUnitTargetMarkerType("reticleover")
	if current == wanted then
		diag.last = "already marked"
		return
	end
	if current ~= TARGET_MARKER_TYPE_NONE and not weSet[current] then
		diag.last = "carries somebody else's marker"
		return
	end

	local now = GetGameTimeMilliseconds()
	if lastMarkTry[slot] and now - lastMarkTry[slot] < MARK_RETRY_MS then
		diag.last = "waiting out the retry window"
		return
	end
	lastMarkTry[slot] = now
	lastAssignAt = now
	weSet[wanted] = true
	AssignTargetMarkerToReticleTarget(wanted)
	diag.assigned = diag.assigned + 1
	diag.last = "marker set"
end

-- ---------------------------------------------------------------------------------------
-- Who is this unit
-- ---------------------------------------------------------------------------------------

local function Identify(tag)
	if not DoesUnitExist(tag) or not IsUnitPlayer(tag) then
		return nil
	end
	local display = GetUnitDisplayName(tag)
	local platform = GetUnitPlatformDisplayName and GetUnitPlatformDisplayName(tag) or ""
	local character = GetUnitName(tag)

	local c = matchCache[tag]
	if c and c.version == keysVersion and c.display == display and c.platform == platform and c.character == character then
		return c.slot
	end

	local slot = keys[Normalize(display)] or keys[Normalize(platform)] or keys[Normalize(character)]
	if not c then
		c = {}
		matchCache[tag] = c
	end
	c.version, c.display, c.platform, c.character, c.slot = keysVersion, display, platform, character, slot
	if slot then
		-- However the player was registered, the other names they go by are kept with the entry:
		-- combat events carry the character name, the rosters the @account, the kill feed both.
		-- The character first: it is the one combat events need.
		addon:Learn(slot, character)
		addon:Learn(slot, display)
		addon:Learn(slot, platform)
	end
	return slot
end

-- ---------------------------------------------------------------------------------------
-- The alert
--
-- A small band at the top of the screen, built in PBsTargetPlayer.xml and shown through a
-- scene fragment the way PB's KillLog does it, so it appears on the HUD and not over menus.
-- The band's two children are shown and hidden here; the fragment owns the window itself.
-- The font is ZoFontGamepad34, the face the console UI already draws the group frames with:
-- a face nothing else is using has to be built on use, and that has crashed a PS5.
-- ---------------------------------------------------------------------------------------

local alertWindow, alertBackground, alertText

local function HideAlert()
	em:UnregisterForUpdate(addon.name .. "Alert")
	if alertBackground then
		alertBackground:SetHidden(true)
		alertText:SetHidden(true)
	end
end

local function ShowAlert(text)
	if not alertText then
		return
	end
	alertText:SetText(text)
	alertBackground:SetHidden(false)
	alertText:SetHidden(false)
	-- Re-registering under the same name restarts the clock: a second alert gets its full time.
	em:UnregisterForUpdate(addon.name .. "Alert")
	em:RegisterForUpdate(addon.name .. "Alert", ALERT_SHOW_MS, HideAlert)
end

local function PlayAlertSound()
	if not sv.sound or not SOUNDS then
		return
	end
	local sound = SOUNDS.DUEL_START or SOUNDS.NEW_NOTIFICATION
	if sound then
		PlaySound(sound)
	end
end

-- One alert for a registered player. `kind` is "combat" or "kill"; each has its own cooldown,
-- per player, so a fight does not repeat itself every hit and the kill feed's two reports of
-- one kill are one alert.
local function Alert(slot, kind, text)
	local now = GetGameTimeMilliseconds()
	local key = kind .. slot
	if lastAlert[key] and now - lastAlert[key] < ALERT_COOLDOWN_MS[kind] then
		return
	end
	lastAlert[key] = now
	diag.shown = diag.shown + 1
	diag.lastAlert = kind
	ShowAlert(text)
	PlayAlertSound()
	Print(text)
end

local function NamedText(slot)
	return "|cFFD24A" .. sv.players[slot].id .. "|r"
end

-- The name of the zone the player is standing in, which is where anyone "nearby" is too.
local function HereName()
	return CleanName(GetUnitZone and GetUnitZone("player") or "")
end

-- A registered player came across the add-on: in the kill feed, in a fight, in chat, under the
-- reticle. Only the latest is kept, with when and -- where there is one -- the place. This is what
-- /pbtarget where falls back on for a player who is on no roster: not where they are, but where
-- and when they last were. Nothing here is saved; a sighting is about this session.
local function Sighted(slot, kind, place)
	diag.sightings = diag.sightings + 1
	local record = sightings[slot]
	if not record then
		record = {}
		sightings[slot] = record
	end
	record.at, record.kind, record.place = GetTimeStamp(), kind, place
end

-- The slot a name from an event belongs to. Event names arrive raw ("Luceda^Fx", "@Foo"), so
-- the answer is kept by the raw string: a fight repeats the same few names thousands of times,
-- and the second time is one table lookup.
local function NameSlot(raw)
	if raw == nil or raw == "" then
		return nil
	end
	local cached = nameCache[raw]
	if cached ~= nil then
		return cached or nil
	end
	if nameCacheSize >= NAME_CACHE_MAX then
		nameCache, nameCacheSize = {}, 0
	end
	local slot = keys[Normalize(raw)] or false
	nameCache[raw] = slot
	nameCacheSize = nameCacheSize + 1
	return slot or nil
end

local function OnCombatSource(_, result, isError, abilityName, abilityGraphic, abilitySlotType, sourceName)
	if not trackActive then
		return
	end
	diag.combat = diag.combat + 1
	local slot = NameSlot(sourceName)
	if slot then
		diag.matched = diag.matched + 1
		Sighted(slot, "combat", HereName())
		if sv.alert then
			Alert(slot, "combat", string.format(GetString(SI_PBTP_ALERT_COMBAT), NamedText(slot)))
		end
	end
end

local function OnCombatTarget(_, result, isError, abilityName, abilityGraphic, abilitySlotType, sourceName, sourceType, targetName)
	if not trackActive then
		return
	end
	diag.combat = diag.combat + 1
	local slot = NameSlot(targetName)
	if slot then
		diag.matched = diag.matched + 1
		Sighted(slot, "combat", HereName())
		if sv.alert then
			Alert(slot, "combat", string.format(GetString(SI_PBTP_ALERT_COMBAT), NamedText(slot)))
		end
	end
end

local function Where(location)
	if location and location ~= "" then
		return string.format(GetString(SI_PBTP_ALERT_AT), location)
	end
	return ""
end

-- The Cyrodiil kill feed names the @account as well, so a player registered by @account or console
-- ID matches here without ever having been looked at; their character name is learned from it.
local function OnKillFeed(_, killLocation, killerDisplayName, killerCharacterName, _, _, victimDisplayName, victimCharacterName)
	if not trackActive then
		return
	end
	diag.kills = diag.kills + 1
	local killer = NameSlot(killerDisplayName) or NameSlot(killerCharacterName)
	local victim = NameSlot(victimDisplayName) or NameSlot(victimCharacterName)
	-- The kill feed is the one place a player outside every roster is given a place: "near" a keep.
	local place = CleanName(killLocation)
	if place == "" then
		place = nil
	end
	if killer then
		diag.matched = diag.matched + 1
		addon:Learn(killer, killerCharacterName)
		Sighted(killer, "kill", place)
		if sv.alert then
			Alert(killer, "kill", string.format(GetString(SI_PBTP_ALERT_KILL), NamedText(killer), tostring(victimCharacterName ~= "" and victimCharacterName or victimDisplayName)) .. Where(killLocation))
		end
	end
	if victim then
		diag.matched = diag.matched + 1
		diedAt[victim] = GetGameTimeMilliseconds()
		diag.deaths = diag.deaths + 1
		addon:Learn(victim, victimCharacterName)
		Sighted(victim, "death", place)
		if sv.alert then
			Alert(victim, "kill", string.format(GetString(SI_PBTP_ALERT_DEATH), NamedText(victim), tostring(killerCharacterName ~= "" and killerCharacterName or killerDisplayName)) .. Where(killLocation))
		end
	end
end

-- ---------------------------------------------------------------------------------------
-- Where a registered player is
-- ---------------------------------------------------------------------------------------

local cyrodiil = { checked = false, zoneId = nil, name = nil }

local function CyrodiilZone()
	if cyrodiil.checked then
		return cyrodiil
	end
	cyrodiil.checked = true
	if GetCyrodiilMapIndex and GetMapInfoByIndex and GetZoneId then
		local mapIndex = GetCyrodiilMapIndex()
		if mapIndex then
			local mapName, _, _, zoneIndex = GetMapInfoByIndex(mapIndex)
			if zoneIndex then
				cyrodiil.zoneId = GetZoneId(zoneIndex)
				cyrodiil.name = GetZoneNameByIndex and GetZoneNameByIndex(zoneIndex) or mapName
			else
				cyrodiil.name = mapName
			end
		end
	end
	return cyrodiil
end

local function IsCyrodiil(zoneId, zoneName)
	local c = CyrodiilZone()
	if c.zoneId and type(zoneId) == "number" and zoneId > 0 then
		if zoneId == c.zoneId then
			return true
		end
		if GetParentZoneId and GetParentZoneId(zoneId) == c.zoneId then
			return true
		end
	end
	return c.name ~= nil and zoneName ~= nil and zoneName ~= "" and Normalize(zoneName) == Normalize(c.name)
end

local function Record(source, status, secs, hasCharacter, characterName, zoneName, alliance, level, championRank, zoneId)
	local online = status ~= PLAYER_STATUS_OFFLINE
	return {
		source = source,
		online = online,
		status = status,
		secs = secs or 0,
		characterName = hasCharacter and CleanName(characterName) or "",
		zoneName = hasCharacter and CleanName(zoneName) or "",
		alliance = alliance,
		level = level,
		championRank = championRank,
		inCyrodiil = online and hasCharacter and IsCyrodiil(zoneId, zoneName) or false,
	}
end

-- Online beats offline; among the same, the more recent.
local function Better(a, b)
	if not b then
		return true
	end
	if a.online ~= b.online then
		return a.online
	end
	return a.secs < b.secs
end

-- One pass over the friend list and every guild roster, for every registered player at once.
-- Display names (the @account) are matched first and are cheap; character names need the
-- character record of every member, so that second pass runs only when a registered player has
-- not been found by the first. Returns slot -> record. Kept for LOCATE_TTL_MS, because a scan is
-- a few thousand names and the settings panel may ask for a row at a time.
function addon:Locate(force)
	local now = GetGameTimeMilliseconds()
	if not force and locateCache and now - locateAt < LOCATE_TTL_MS then
		return locateCache
	end
	diag.scans = diag.scans + 1

	local found = {}
	local function Keep(slot, record)
		if Better(record, found[slot]) then
			found[slot] = record
		end
	end

	-- Friends: a short list, so both names are checked in one go.
	for i = 1, GetNumFriends() do
		local displayName, _, status, secs = GetFriendInfo(i)
		local hasCharacter, characterName, zoneName, _, alliance, level, championRank, zoneId = GetFriendCharacterInfo(i)
		local slot = keys[Normalize(displayName)] or (hasCharacter and keys[Normalize(characterName)]) or nil
		if slot then
			Keep(slot, Record(nil, status, secs, hasCharacter, characterName, zoneName, alliance, level, championRank, zoneId))
		end
	end

	-- Guilds, by display name.
	local guilds = {}
	for g = 1, GetNumGuilds() do
		local guildId = GetGuildId(g)
		guilds[#guilds + 1] = guildId
		local guildName = GetGuildName(guildId)
		for i = 1, GetNumGuildMembers(guildId) do
			local name, _, _, status, secs = GetGuildMemberInfo(guildId, i)
			local slot = keys[Normalize(name)]
			if slot then
				local hasCharacter, characterName, zoneName, _, alliance, level, championRank, zoneId = GetGuildMemberCharacterInfo(guildId, i)
				Keep(slot, Record(guildName, status, secs, hasCharacter, characterName, zoneName, alliance, level, championRank, zoneId))
			end
		end
	end

	-- Guilds, by character name -- only for registered players still missing.
	local missing = false
	for slot = 1, MAX_PLAYERS do
		if sv.players[slot].id ~= "" and not found[slot] then
			missing = true
			break
		end
	end
	if missing then
		for _, guildId in ipairs(guilds) do
			local guildName = GetGuildName(guildId)
			for i = 1, GetNumGuildMembers(guildId) do
				local hasCharacter, characterName, zoneName, _, alliance, level, championRank, zoneId = GetGuildMemberCharacterInfo(guildId, i)
				local slot = hasCharacter and keys[Normalize(characterName)] or nil
				if slot and not found[slot] then
					local _, _, _, status, secs = GetGuildMemberInfo(guildId, i)
					Keep(slot, Record(guildName, status, secs, hasCharacter, characterName, zoneName, alliance, level, championRank, zoneId))
				end
			end
		end
	end

	-- What the scan saw is the baseline for "entered Cyrodiil": a player already there is not news.
	for slot, record in pairs(found) do
		if record.online then
			presence[slot] = record.inCyrodiil
		else
			presence[slot] = false
		end
	end

	locateCache, locateAt = found, now
	return found
end

local function AgoText(secs)
	secs = secs or 0
	if secs >= 86400 then
		return string.format(GetString(SI_PBTP_WHERE_DAYS), math.floor(secs / 86400))
	elseif secs >= 3600 then
		return string.format(GetString(SI_PBTP_WHERE_HOURS), math.floor(secs / 3600))
	end
	return string.format(GetString(SI_PBTP_WHERE_MINUTES), math.max(1, math.floor(secs / 60)))
end

-- "Cyrodiil  [Luceda, Lv50, friend]", "offline (3 h ago)", or that they cannot be found.
local function DescribeRecord(record)
	if not record then
		return GetString(SI_PBTP_WHERE_UNKNOWN)
	end
	if not record.online then
		return string.format(GetString(SI_PBTP_WHERE_OFFLINE), AgoText(record.secs))
	end
	local details = {}
	if record.characterName ~= "" then
		details[#details + 1] = record.characterName
	end
	if record.championRank and record.championRank > 0 then
		details[#details + 1] = "CP" .. record.championRank
	elseif record.level and record.level > 0 then
		details[#details + 1] = "Lv" .. record.level
	end
	details[#details + 1] = record.source or GetString(SI_PBTP_WHERE_FRIEND)
	local zone = record.zoneName ~= "" and record.zoneName or GetString(SI_PBTP_WHERE_NOWHERE)
	return string.format(GetString(SI_PBTP_WHERE_ONLINE), zone, table.concat(details, ", "))
end

-- What the add-on came across last: "last seen 4 min ago: killed someone  [Chalman Keep]".
local SIGHTING_KINDS = {
	kill = "SI_PBTP_SEEN_KILL",
	death = "SI_PBTP_SEEN_DEATH",
	combat = "SI_PBTP_SEEN_COMBAT",
	say = "SI_PBTP_SEEN_SAY",
	yell = "SI_PBTP_SEEN_YELL",
	emote = "SI_PBTP_SEEN_EMOTE",
	zone = "SI_PBTP_SEEN_ZONE",
	reticle = "SI_PBTP_SEEN_RETICLE",
}

local function SightingText(sighting)
	local what = GetString(_G[SIGHTING_KINDS[sighting.kind] or "SI_PBTP_SEEN_COMBAT"])
	local text = string.format(GetString(SI_PBTP_WHERE_SEEN), AgoText(math.max(0, GetTimeStamp() - sighting.at)), what)
	if sighting.place and sighting.place ~= "" then
		text = text .. string.format(GetString(SI_PBTP_ALERT_AT), sighting.place)
	end
	return text
end

-- Where a registered player is, as well as the add-on can say. A roster entry is live and wins
-- while the player is online; otherwise the last sighting, if any; otherwise that nothing is known.
function addon:Describe(slot, record)
	if record and record.online then
		return DescribeRecord(record)
	end
	local sighting = sightings[slot]
	if sighting then
		-- An offline roster entry says when they logged off; a sighting after that is news, and
		-- cannot be, so the roster's word stands.
		if record then
			return DescribeRecord(record)
		end
		return SightingText(sighting)
	end
	return DescribeRecord(record)
end

function addon:WhereText(slot)
	if sv.players[slot].id == "" then
		return GetString(SI_PBTP_WHERE_EMPTY)
	end
	return self:Describe(slot, self:Locate()[slot])
end

-- ---------------------------------------------------------------------------------------
-- Entering Cyrodiil
-- ---------------------------------------------------------------------------------------

local function EnteredText(slot, characterName)
	local text = string.format(GetString(SI_PBTP_ALERT_CYRODIIL), NamedText(slot))
	characterName = CleanName(characterName)
	if characterName ~= "" then
		text = text .. string.format(GetString(SI_PBTP_ALERT_AT), characterName)
	end
	return text
end

-- Where a registered player now is. Only the step from "not in Cyrodiil" (or unknown) to "in
-- Cyrodiil" is news.
local function NoteLocation(slot, inCyrodiil, characterName)
	local was = presence[slot]
	presence[slot] = inCyrodiil and true or false
	if inCyrodiil and not was then
		Alert(slot, "cyro", EnteredText(slot, characterName))
	end
end

-- A name from a roster event, matched; and every name it carries is kept as the same player.
local function MatchRoster(displayName, characterName)
	local slot = NameSlot(displayName) or NameSlot(characterName)
	if slot then
		addon:Learn(slot, displayName)
		if characterName and characterName ~= "" then
			addon:Learn(slot, characterName)
		end
	end
	return slot
end

local function OnFriendZone(_, displayName, characterName, zoneName)
	if not watchActive then
		return
	end
	diag.rosterSeen = diag.rosterSeen + 1
	local slot = MatchRoster(displayName, characterName)
	if slot then
		diag.rosterMatched = diag.rosterMatched + 1
		NoteLocation(slot, IsCyrodiil(nil, zoneName), characterName)
	end
end

local function OnGuildZone(_, guildId, displayName, characterName, zoneName)
	if not watchActive then
		return
	end
	diag.rosterSeen = diag.rosterSeen + 1
	local slot = MatchRoster(displayName, characterName)
	if slot then
		diag.rosterMatched = diag.rosterMatched + 1
		NoteLocation(slot, IsCyrodiil(nil, zoneName), characterName)
	end
end

-- Coming online carries no zone, so the roster is asked.
local function OnFriendStatus(_, displayName, characterName, oldStatus, newStatus)
	if not watchActive then
		return
	end
	diag.rosterSeen = diag.rosterSeen + 1
	local slot = MatchRoster(displayName, characterName)
	if not slot then
		return
	end
	diag.rosterMatched = diag.rosterMatched + 1
	if newStatus == PLAYER_STATUS_OFFLINE then
		presence[slot] = false
	elseif oldStatus == PLAYER_STATUS_OFFLINE then
		for i = 1, GetNumFriends() do
			if GetFriendInfo(i) == displayName then
				local hasCharacter, name, zoneName, _, _, _, _, zoneId = GetFriendCharacterInfo(i)
				NoteLocation(slot, hasCharacter and IsCyrodiil(zoneId, zoneName), hasCharacter and name or characterName)
				return
			end
		end
	end
end

local function OnGuildStatus(_, guildId, displayName, oldStatus, newStatus)
	if not watchActive then
		return
	end
	diag.rosterSeen = diag.rosterSeen + 1
	local slot = MatchRoster(displayName, nil)
	if not slot then
		return
	end
	diag.rosterMatched = diag.rosterMatched + 1
	if newStatus == PLAYER_STATUS_OFFLINE then
		presence[slot] = false
	elseif oldStatus == PLAYER_STATUS_OFFLINE then
		local index = GetGuildMemberIndexFromDisplayName(guildId, displayName)
		if index then
			local hasCharacter, name, zoneName, _, _, _, _, zoneId = GetGuildMemberCharacterInfo(guildId, index)
			NoteLocation(slot, hasCharacter and IsCyrodiil(zoneId, zoneName), hasCharacter and name or nil)
		end
	end
end

-- ---------------------------------------------------------------------------------------
-- Chat as a sign of where someone is
--
-- /say, /yell and emotes reach only players close by; zone chat reaches the zone. A registered
-- player appearing in one of them is therefore near (say, yell, emote) or in the same zone (zone),
-- whatever roster they are or are not on. The message text is never read. A message names the
-- sender's @account as well as the character, so a player registered by @account matches here.
-- ---------------------------------------------------------------------------------------

local CHAT_KIND_BY_NAME = {
	CHAT_CHANNEL_SAY = "say",
	CHAT_CHANNEL_YELL = "yell",
	CHAT_CHANNEL_EMOTE = "emote",
	CHAT_CHANNEL_ZONE = "zone",
	CHAT_CHANNEL_ZONE_LANGUAGE_1 = "zone",
	CHAT_CHANNEL_ZONE_LANGUAGE_2 = "zone",
	CHAT_CHANNEL_ZONE_LANGUAGE_3 = "zone",
	CHAT_CHANNEL_ZONE_LANGUAGE_4 = "zone",
	CHAT_CHANNEL_ZONE_LANGUAGE_5 = "zone",
	CHAT_CHANNEL_ZONE_LANGUAGE_6 = "zone",
	CHAT_CHANNEL_ZONE_LANGUAGE_7 = "zone",
}
-- Looked up by the channel's value; a name the client does not define is simply left out.
local chatKinds = {}
for name, kind in pairs(CHAT_KIND_BY_NAME) do
	local value = _G[name]
	if value ~= nil then
		chatKinds[value] = kind
	end
end

local function OnChatMessage(_, channelType, fromName, text, isCustomerService, fromDisplayName)
	-- Every chat message in the game comes through here; all but five channels leave on this line.
	local kind = chatKinds[channelType]
	if not kind or not trackActive then
		return
	end
	diag.chat = diag.chat + 1
	local slot = NameSlot(fromDisplayName) or NameSlot(fromName)
	if not slot then
		return
	end
	diag.matched = diag.matched + 1
	addon:Learn(slot, fromDisplayName)
	addon:Learn(slot, fromName)
	Sighted(slot, kind, HereName())
	-- Zone chat only says "in your zone", which in Cyrodiil is a great many people; the other three
	-- are close enough to be worth an alert.
	if kind ~= "zone" and sv.alert then
		Alert(slot, "near", string.format(GetString(SI_PBTP_ALERT_CHAT), NamedText(slot)))
	end
end

-- ---------------------------------------------------------------------------------------
-- Settling, and undoing a mismark
-- ---------------------------------------------------------------------------------------

local function CancelPending()
	if pendingMark then
		pendingMark = nil
		em:UnregisterForUpdate(addon.name .. "Settle")
	end
end

-- The reticle has rested on the same registered player for MARK_DWELL_MS: now, and only now, ask.
local function FinishPending()
	local pending = pendingMark
	CancelPending()
	if not pending or not sv.enabled then
		return
	end
	local slot = Identify("reticleover")
	if slot ~= pending.slot or GetUnitDisplayName("reticleover") ~= pending.display or GetUnitName("reticleover") ~= pending.character then
		diag.aborted = diag.aborted + 1
		diag.last = "the reticle moved on before the marker was set"
		return
	end
	MarkInWorld(slot)
end

local function SettleThenMark(slot)
	CancelPending()
	pendingMark = {
		slot = slot,
		display = GetUnitDisplayName("reticleover"),
		character = GetUnitName("reticleover"),
	}
	em:RegisterForUpdate(addon.name .. "Settle", MARK_DWELL_MS, FinishPending)
end

local function MarkTypeIndex(marker)
	for index, name in ipairs(MARK_TYPE_NAMES) do
		if _G[name] == marker then
			return index
		end
	end
	return nil
end

-- A second after a clear: is the marker gone? If it is not, clearing does not work this way and
-- asking again would only add noise (or, if the game treats it as a toggle, undo itself).
local function VerifyClear()
	em:UnregisterForUpdate(addon.name .. "ClearCheck")
	local check = clearCheck
	clearCheck = nil
	if not check then
		return
	end
	if DoesUnitExist("reticleover") and GetUnitName("reticleover") == check.name then
		local marker = GetUnitTargetMarkerType("reticleover")
		if marker ~= TARGET_MARKER_TYPE_NONE and weSet[marker] then
			cleanupBroken = true
			diag.clearFailed = true
			diag.last = "clearing a marker did not work: stray clean-up is off for this session"
			return
		end
	end
	diag.last = "stray marker cleared"
end

-- The reticle is on someone. If they are not ours to mark -- not registered, not in the group --
-- and carry the kind of marker this add-on sets, the add-on put it there by mistake: take it off.
local function CheckStray(reason)
	if not sv.cleanup or cleanupBroken then
		return
	end
	if not DoesUnitExist("reticleover") or not IsUnitPlayer("reticleover") then
		return
	end
	-- Cheapest first: almost every player the reticle meets carries no marker at all.
	local marker = GetUnitTargetMarkerType("reticleover")
	if marker == TARGET_MARKER_TYPE_NONE or not weSet[marker] then
		return
	end
	if Identify("reticleover") or IsUnitGrouped("reticleover") or AreUnitsEqual("reticleover", "player") then
		return
	end
	local now = GetGameTimeMilliseconds()
	if now - lastAssignAt > STRAY_RECENT_MS then
		return
	end
	-- Asked of the game only now that there is something to clear.
	if not EngineMarkUsable() then
		return
	end
	local name = GetUnitName("reticleover")
	if strayTried[name] and now - strayTried[name] < STRAY_RETRY_MS then
		return
	end
	strayTried[name] = now
	diag.stray = diag.stray + 1
	diag.cleared = diag.cleared + 1
	diag.last = "stray marker on a bystander (" .. reason .. "): clearing it"
	AssignTargetMarkerToReticleTarget(TARGET_MARKER_TYPE_NONE)
	clearCheck = { name = name }
	em:UnregisterForUpdate(addon.name .. "ClearCheck")
	em:RegisterForUpdate(addon.name .. "ClearCheck", CLEAR_VERIFY_MS, VerifyClear)
end

-- The game says a marker changed. Soon after the add-on set one, that is when to look at whom
-- the reticle is on.
local function OnTargetMarkerUpdate()
	if sv and sv.enabled and GetGameTimeMilliseconds() - lastAssignAt < STRAY_CHECK_WINDOW_MS then
		CheckStray("just after setting a marker")
	end
end

-- The reticle target died: remember it, so that nothing is set on them until they are well and truly
-- somewhere else.
local function OnUnitDeathState(_, unitTag, isDead)
	if not sv or not sv.enabled or not hasKeys or not isDead then
		return
	end
	local slot = Identify(unitTag)
	if slot then
		diedAt[slot] = GetGameTimeMilliseconds()
		diag.deaths = diag.deaths + 1
		CancelPending()
	end
end

local function OnReticleTargetChanged()
	if not sv or not sv.enabled then
		return
	end
	local slot = hasKeys and Identify("reticleover") or nil
	if slot then
		Sighted(slot, "reticle", HereName())
		SettleThenMark(slot)
	else
		CancelPending()
		CheckStray("reticle")
	end
end

-- ---------------------------------------------------------------------------------------
-- The list
-- ---------------------------------------------------------------------------------------

-- Saved data comes back from disk, so it is checked rather than trusted: a hand-edited or
-- half-written entry must not be able to throw inside the handler. Fields that older versions
-- of this add-on saved (a colour per player, the frame and box switches) are dropped here.
local OBSOLETE_OPTIONS = { "colorTarget", "colorGroup", "box", "overhead" }

local function Sanitize()
	if type(sv.mark) ~= "number" or sv.mark < 1 or sv.mark > MAX_MARK or sv.mark ~= math.floor(sv.mark) then
		sv.mark = DEFAULTS.mark
	end
	for _, name in ipairs(OBSOLETE_OPTIONS) do
		sv[name] = nil
	end
	for slot = 1, MAX_PLAYERS do
		local p = sv.players[slot]
		if type(p) ~= "table" then
			p = {}
			sv.players[slot] = p
		end
		if type(p.id) ~= "string" then
			p.id = ""
		end
		if type(p.chars) ~= "table" then
			p.chars = {}
		end
		for i = #p.chars, 1, -1 do
			if type(p.chars[i]) ~= "string" or p.chars[i] == "" then
				table.remove(p.chars, i)
			end
		end
		while #p.chars > MAX_LEARNED do
			table.remove(p.chars, 1)
		end
		p.r, p.g, p.b = nil, nil, nil
	end
end

-- What the add-on remembers about a slot belongs to the player in it. When the slot gets another
-- player, or none, none of it may carry over: the old player's "in Cyrodiil" would hide the new
-- one's arrival, and the old cooldown would swallow their first alert.
local function ForgetSlotState(slot)
	presence[slot] = nil
	diedAt[slot] = nil
	sightings[slot] = nil
	lastMarkTry[slot] = nil
	for kind in pairs(ALERT_COOLDOWN_MS) do
		lastAlert[kind .. slot] = nil
	end
end

function addon:Rebuild()
	keys = {}
	hasKeys = false
	if sv then
		-- The IDs first, so an ID always wins over a learned character name that happens to
		-- collide with it.
		for slot = 1, MAX_PLAYERS do
			local norm = Normalize(sv.players[slot].id)
			if norm ~= "" and keys[norm] == nil then
				keys[norm] = slot
				hasKeys = true
			end
		end
		for slot = 1, MAX_PLAYERS do
			if sv.players[slot].id ~= "" then
				for _, name in ipairs(sv.players[slot].chars) do
					if keys[name] == nil then
						keys[name] = slot
					end
				end
			end
		end
	end
	keysVersion = keysVersion + 1
	nameCache, nameCacheSize = {}, 0
	alertsActive = sv ~= nil and sv.enabled and sv.alert and hasKeys
	watchActive = sv ~= nil and sv.enabled and sv.cyrodiil and hasKeys
	trackActive = sv ~= nil and sv.enabled and hasKeys
	locateCache = nil
end

-- Keep the character name of a registered player, so that combat events (which carry character
-- names only) can be matched to them. Called when the reticle is on them or the kill feed names
-- them. A name already known is ignored; the list keeps the last MAX_LEARNED.
function addon:Learn(slot, characterName)
	local norm = Normalize(characterName)
	if norm == "" or keys[norm] ~= nil then
		return
	end
	local chars = sv.players[slot].chars
	chars[#chars + 1] = norm
	if #chars > MAX_LEARNED then
		table.remove(chars, 1)
	end
	self:Rebuild()
end

function addon:GetPlayer(slot)
	return sv and sv.players[slot]
end

function addon:CountPlayers()
	local n = 0
	if sv then
		for slot = 1, MAX_PLAYERS do
			if sv.players[slot].id ~= "" then
				n = n + 1
			end
		end
	end
	return n
end

-- A slot by its number, or by the ID that was typed. Returns nil for neither.
function addon:FindSlot(what)
	local number = tonumber(what)
	if number and number >= 1 and number <= MAX_PLAYERS and number == math.floor(number) then
		return number
	end
	local norm = Normalize(what)
	if norm ~= "" then
		for slot = 1, MAX_PLAYERS do
			if Normalize(sv.players[slot].id) == norm then
				return slot
			end
		end
	end
	return nil
end

function addon:FirstFreeSlot()
	for slot = 1, MAX_PLAYERS do
		if sv.players[slot].id == "" then
			return slot
		end
	end
	return nil
end

-- Returns true, or false and the reason: "empty", "duplicate" (and the slot that has it).
-- An empty string is a deletion, which is how the panel's text box removes an entry.
function addon:SetPlayerId(slot, text)
	local p = sv.players[slot]
	local id = Trim(text or "")
	if id == "" then
		self:ClearPlayer(slot)
		return true
	end
	if #id > MAX_ID_CHARS then
		id = id:sub(1, MAX_ID_CHARS)
	end
	local norm = Normalize(id)
	if norm == "" then
		return false, "empty"
	end
	for other = 1, MAX_PLAYERS do
		if other ~= slot and Normalize(sv.players[other].id) == norm then
			return false, "duplicate", other
		end
	end
	if p.id ~= id then
		p.id = id
		p.chars = {}
		ForgetSlotState(slot)
		self:Rebuild()
	end
	return true
end

-- Deleting an entry does not take a marker off the player: nothing in the API removes the
-- marker from a unit that is not under the reticle. The game clears it on its own terms.
function addon:ClearPlayer(slot)
	sv.players[slot].id = ""
	sv.players[slot].chars = {}
	ForgetSlotState(slot)
	self:Rebuild()
end

function addon:ClearAll()
	for slot = 1, MAX_PLAYERS do
		sv.players[slot].id = ""
		sv.players[slot].chars = {}
		ForgetSlotState(slot)
	end
	self:Rebuild()
end

function addon:SetOption(name, value)
	sv[name] = value and true or false
	-- The alert switch and the master switch decide whether the event handlers do anything.
	self:Rebuild()
end

function addon:GetOption(name)
	return sv[name]
end

-- 1..8. Returns false for anything else.
function addon:SetMark(index)
	if type(index) ~= "number" or index < 1 or index > MAX_MARK or index ~= math.floor(index) then
		return false
	end
	sv.mark = index
	return true
end

-- ---------------------------------------------------------------------------------------
-- Words for a slot (shared by the panel and the commands)
-- ---------------------------------------------------------------------------------------

function addon:SlotLabel(slot)
	local p = sv.players[slot]
	if p.id == "" then
		return string.format(GetString(SI_PBTP_SLOT_EMPTY), slot)
	end
	return string.format(GetString(SI_PBTP_SLOT_FORMAT), slot, p.id)
end

function addon:RefreshPanel()
	if self.settingsControls and self.settingsControls.UpdateControls then
		self.settingsControls:UpdateControls()
	end
end

-- ---------------------------------------------------------------------------------------
-- Commands
--
-- A console has the chat box and little else, so the panel is the main way in; the commands
-- are for the cases where typing "/pbtarget add Name" is quicker, and for /pbtarget status,
-- which is how a console test round gets measured.
-- ---------------------------------------------------------------------------------------

local function OnOff(value)
	return GetString(value and SI_PBTP_ON or SI_PBTP_OFF)
end

local function MarkName(index)
	return GetString(_G["SI_PBTP_MARK_" .. index])
end

local function PrintList()
	if addon:CountPlayers() == 0 then
		Print(GetString(SI_PBTP_LIST_NONE))
		return
	end
	Print(GetString(SI_PBTP_LIST_HEADER))
	for slot = 1, MAX_PLAYERS do
		local p = sv.players[slot]
		if p.id ~= "" then
			Say(string.format(GetString(SI_PBTP_LIST_LINE), slot, p.id))
		end
	end
end

-- Where each registered player is. Always a fresh scan: asking is the point.
local function PrintWhere()
	if addon:CountPlayers() == 0 then
		Print(GetString(SI_PBTP_LIST_NONE))
		return
	end
	local found = addon:Locate(true)
	Print(GetString(SI_PBTP_WHERE_HEADER))
	for slot = 1, MAX_PLAYERS do
		local p = sv.players[slot]
		if p.id ~= "" then
			Say(string.format(GetString(SI_PBTP_WHERE_LINE), slot, p.id, addon:Describe(slot, found[slot])))
		end
	end
end

local function PrintHelp()
	Print(GetString(SI_PBTP_HELP_HEADER))
	for _, id in ipairs({
		SI_PBTP_HELP_LIST,
		SI_PBTP_HELP_ADD,
		SI_PBTP_HELP_REMOVE,
		SI_PBTP_HELP_MARK,
		SI_PBTP_HELP_WHERE,
		SI_PBTP_HELP_UNMARK,
		SI_PBTP_HELP_TEST,
		SI_PBTP_HELP_SWITCH,
		SI_PBTP_HELP_STATUS,
		SI_PBTP_HELP_CLEAR,
	}) do
		Say(GetString(id))
	end
end

-- What the add-on sees on the reticle right now, and what it did the last time it was on a
-- registered player. The first thing to read when the marker does not appear.
local function PrintStatus()
	Print(GetString(SI_PBTP_STATUS_HEAD), OnOff(sv.enabled), MarkName(sv.mark), addon:CountPlayers())
	EngineMarkUsable()
	Say(string.format(GetString(SI_PBTP_STATUS_ENGINE), engine.why, diag.assigned, diag.last))

	Say(
		string.format(
			GetString(SI_PBTP_STATUS_WATCH),
			OnOff(sv.cyrodiil and sv.enabled),
			tostring(CyrodiilZone().zoneId or "?"),
			diag.rosterSeen,
			diag.rosterMatched,
			diag.scans
		)
	)

	Say(string.format(GetString(SI_PBTP_STATUS_SIGHT), diag.chat, diag.sightings))
	Say(
		string.format(
			GetString(SI_PBTP_STATUS_STRAY),
			OnOff(sv.cleanup and not cleanupBroken),
			diag.stray,
			diag.cleared,
			tostring(diag.clearFailed),
			diag.deaths,
			diag.deadSkips,
			diag.aborted
		)
	)

	local learned = 0
	for slot = 1, MAX_PLAYERS do
		learned = learned + #sv.players[slot].chars
	end
	Say(
		string.format(
			GetString(SI_PBTP_STATUS_ALERT),
			OnOff(sv.alert and sv.enabled),
			diag.kills,
			diag.combat,
			diag.matched,
			diag.shown,
			diag.lastAlert,
			learned
		)
	)

	if DoesUnitExist("reticleover") then
		local slot = Identify("reticleover")
		local marker = GetUnitTargetMarkerType("reticleover")
		Say(
			string.format(
				GetString(SI_PBTP_STATUS_UNIT),
				"reticleover",
				tostring(GetUnitDisplayName("reticleover")),
				tostring(GetUnitPlatformDisplayName and GetUnitPlatformDisplayName("reticleover") or ""),
				tostring(GetUnitName("reticleover")),
				slot and tostring(slot) or "-",
				marker == TARGET_MARKER_TYPE_NONE and "-" or tostring(marker)
			)
		)
	else
		Say(GetString(SI_PBTP_STATUS_NO_UNITS))
	end
end

local function DoAdd(rest)
	local id = Trim(rest)
	if id == "" then
		Print(GetString(SI_PBTP_NEED_ID))
		return
	end
	local existing = addon:FindSlot(id)
	if existing and tonumber(id) == nil then
		Print(GetString(SI_PBTP_DUPLICATE), id, existing)
		return
	end
	local slot = addon:FirstFreeSlot()
	if not slot then
		Print(GetString(SI_PBTP_FULL), MAX_PLAYERS)
		return
	end
	local ok, reason, other = addon:SetPlayerId(slot, id)
	if not ok then
		if reason == "duplicate" then
			Print(GetString(SI_PBTP_DUPLICATE), id, other)
		else
			Print(GetString(SI_PBTP_NEED_ID))
		end
		return
	end
	Print(GetString(SI_PBTP_ADDED), slot, sv.players[slot].id)
	addon:RefreshPanel()
end

local function DoRemove(rest)
	local slot = rest ~= "" and addon:FindSlot(rest)
	if not slot or sv.players[slot].id == "" then
		Print(GetString(SI_PBTP_NOT_FOUND), rest)
		return
	end
	local id = sv.players[slot].id
	addon:ClearPlayer(slot)
	Print(GetString(SI_PBTP_REMOVED), slot, id)
	addon:RefreshPanel()
end

-- "/pbtarget mark <1-8>"
local function DoMark(rest)
	local index = rest:match("^(%d+)$") and tonumber(rest)
	if not index or not addon:SetMark(index) then
		Print(GetString(SI_PBTP_BAD_MARK))
		return
	end
	Print(GetString(SI_PBTP_MARKED), MarkName(index))
	addon:RefreshPanel()
end

local function MarkTypeName(marker)
	local index = MarkTypeIndex(marker)
	return index and MarkName(index) or GetString(SI_PBTP_MARK_NONE_WORD)
end

-- Takes the marker off whoever is under the reticle, whoever put it there. Also the way to learn, on
-- a console, whether TARGET_MARKER_TYPE_NONE clears a marker at all: it says what was there before
-- and what is there a second later.
local function DoUnmark()
	if not DoesUnitExist("reticleover") then
		Print(GetString(SI_PBTP_STATUS_NO_UNITS))
		return
	end
	if not EngineMarkUsable() then
		return
	end
	local before = GetUnitTargetMarkerType("reticleover")
	local name = GetUnitName("reticleover")
	AssignTargetMarkerToReticleTarget(TARGET_MARKER_TYPE_NONE)
	em:UnregisterForUpdate(addon.name .. "Unmark")
	em:RegisterForUpdate(addon.name .. "Unmark", CLEAR_VERIFY_MS, function()
		em:UnregisterForUpdate(addon.name .. "Unmark")
		local same = DoesUnitExist("reticleover") and GetUnitName("reticleover") == name
		Print(
			GetString(SI_PBTP_UNMARK_RESULT),
			CleanName(name),
			MarkTypeName(before),
			same and MarkTypeName(GetUnitTargetMarkerType("reticleover")) or GetString(SI_PBTP_UNMARK_MOVED)
		)
	end)
end

local SWITCHES = {
	on = { "enabled", SI_PBTP_SWITCH_ENABLED },
	cleanup = { "cleanup", SI_PBTP_SWITCH_CLEANUP },
	alert = { "alert", SI_PBTP_SWITCH_ALERT },
	cyrodiil = { "cyrodiil", SI_PBTP_SWITCH_CYRODIIL },
	sound = { "sound", SI_PBTP_SWITCH_SOUND },
	banner = { "banner", SI_PBTP_SWITCH_BANNER },
}

-- Shows the alert once, with the sound, whatever the cooldowns and switches say: the way to see
-- on the console what the band looks like and what the sound is.
local function DoTest()
	local text
	for slot = 1, MAX_PLAYERS do
		if sv.players[slot].id ~= "" then
			text = string.format(GetString(SI_PBTP_ALERT_TEST), NamedText(slot))
			break
		end
	end
	text = text or GetString(SI_PBTP_ALERT_TEST_NOBODY)
	ShowAlert(text)
	PlayAlertSound()
end

local function DoSwitch(name, word)
	word = lower(word or "")
	if word ~= "on" and word ~= "off" then
		PrintHelp()
		return
	end
	local entry = SWITCHES[name]
	addon:SetOption(entry[1], word == "on")
	Print(GetString(SI_PBTP_SWITCH), GetString(entry[2]), OnOff(sv[entry[1]]))
	addon:RefreshPanel()
end

function addon:InitSlashCommand()
	local function handler(argumentString)
		local cmd, rest = (argumentString or ""):match("^%s*(%S*)%s*(.-)%s*$")
		cmd = lower(cmd or "")
		rest = rest or ""

		if cmd == "list" then
			PrintList()
		elseif cmd == "add" then
			DoAdd(rest)
		elseif cmd == "remove" or cmd == "delete" or cmd == "del" then
			DoRemove(rest)
		elseif cmd == "mark" then
			DoMark(rest)
		elseif cmd == "test" then
			DoTest()
		elseif cmd == "unmark" then
			DoUnmark()
		elseif cmd == "where" or cmd == "locate" then
			PrintWhere()
		elseif cmd == "on" or cmd == "off" then
			-- "/pbtarget on" is the master switch; banner takes its own word.
			DoSwitch("on", cmd)
		elseif SWITCHES[cmd] then
			DoSwitch(cmd, rest)
		elseif cmd == "status" then
			PrintStatus()
		elseif cmd == "clear" then
			addon:ClearAll()
			Print(GetString(SI_PBTP_CLEARED))
			addon:RefreshPanel()
		else
			PrintHelp()
		end
	end
	SLASH_COMMANDS[SLASH] = handler
	SLASH_COMMANDS[SHORT_SLASH] = handler
end

-- ---------------------------------------------------------------------------------------
-- Load
-- ---------------------------------------------------------------------------------------

local bannerShown = false

local seeded = false

local function OnPlayerActivated()
	-- One roster scan a little after login, to know who is already in Cyrodiil: the first event
	-- about such a player must not read as their arrival. The rosters are not loaded the moment
	-- the world is.
	if not seeded then
		seeded = true
		em:RegisterForUpdate(addon.name .. "Seed", LOCATE_SEED_MS, function()
			em:UnregisterForUpdate(addon.name .. "Seed")
			if sv.enabled and hasKeys then
				addon:Locate(true)
			end
		end)
	end
	if sv.banner and not bannerShown then
		bannerShown = true
		Print(GetString(SI_PBTP_BANNER_LINE), addon.title, addon:CountPlayers())
	end
end

local function OnAddOnLoaded(_, name)
	if name ~= addon.name then
		return
	end
	em:UnregisterForEvent(addon.name, EVENT_ADD_ON_LOADED)

	-- Nothing below this check runs for anyone who is not on the list: no saved variables, no
	-- commands, no panel, no events.
	if not IsAllowedUser() then
		RefuseToRun()
		return
	end

	sv = ZO_SavedVars:NewAccountWide("PBsTargetPlayer_Data", 1, nil, DEFAULTS)
	addon.sv = sv
	Sanitize()
	addon:Rebuild()

	addon:InitSlashCommand()
	if addon.InitSettings then
		addon:InitSettings()
	end

	-- The alert band, shown through scene fragments the way PB's KillLog's window is.
	alertWindow = PBsTargetPlayerAlert
	if alertWindow then
		alertBackground = alertWindow:GetNamedChild("Background")
		alertText = alertWindow:GetNamedChild("Text")
		local fragment = ZO_SimpleSceneFragment:New(alertWindow)
		HUD_SCENE:AddFragment(fragment)
		HUD_UI_SCENE:AddFragment(fragment)
	end

	em:RegisterForEvent(addon.name, EVENT_RETICLE_TARGET_CHANGED, OnReticleTargetChanged)
	em:RegisterForEvent(addon.name .. "Marker", EVENT_TARGET_MARKER_UPDATE, OnTargetMarkerUpdate)
	em:RegisterForEvent(addon.name .. "Death", EVENT_UNIT_DEATH_STATE_CHANGED, OnUnitDeathState)
	if REGISTER_FILTER_UNIT_TAG then
		em:AddFilterForEvent(addon.name .. "Death", EVENT_UNIT_DEATH_STATE_CHANGED, REGISTER_FILTER_UNIT_TAG, "reticleover")
	end
	em:RegisterForEvent(addon.name, EVENT_PLAYER_ACTIVATED, OnPlayerActivated)

	-- Two registrations for combat events, because the engine's filters are ANDed: one narrows
	-- the source to "another unit", the other the target. Without the filters every combat event
	-- the game has would reach Lua.
	-- Friends and guild members: where they are, and when they come into Cyrodiil.
	em:RegisterForEvent(addon.name .. "FriendZone", EVENT_FRIEND_CHARACTER_ZONE_CHANGED, OnFriendZone)
	em:RegisterForEvent(addon.name .. "FriendStatus", EVENT_FRIEND_PLAYER_STATUS_CHANGED, OnFriendStatus)
	em:RegisterForEvent(addon.name .. "GuildZone", EVENT_GUILD_MEMBER_CHARACTER_ZONE_CHANGED, OnGuildZone)
	em:RegisterForEvent(addon.name .. "GuildStatus", EVENT_GUILD_MEMBER_PLAYER_STATUS_CHANGED, OnGuildStatus)

	em:RegisterForEvent(addon.name .. "Chat", EVENT_CHAT_MESSAGE_CHANNEL, OnChatMessage)
	em:RegisterForEvent(addon.name .. "Kills", EVENT_PVP_KILL_FEED_DEATH, OnKillFeed)
	em:RegisterForEvent(addon.name .. "CombatSource", EVENT_COMBAT_EVENT, OnCombatSource)
	em:RegisterForEvent(addon.name .. "CombatTarget", EVENT_COMBAT_EVENT, OnCombatTarget)
	if REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE and REGISTER_FILTER_TARGET_COMBAT_UNIT_TYPE and COMBAT_UNIT_TYPE_OTHER then
		em:AddFilterForEvent(addon.name .. "CombatSource", EVENT_COMBAT_EVENT,
			REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_OTHER,
			REGISTER_FILTER_IS_ERROR, false)
		em:AddFilterForEvent(addon.name .. "CombatTarget", EVENT_COMBAT_EVENT,
			REGISTER_FILTER_TARGET_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_OTHER,
			REGISTER_FILTER_IS_ERROR, false)
	end
end

em:RegisterForEvent(addon.name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
