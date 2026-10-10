-- PB's GammaAdjuster
-- Author: PinkBanther
--
-- Asks the game to apply the brightness the player saved, after the console client has come up
-- at the default instead.
--
-- Since a recent update (API 101051) the console game forgets the brightness set in "Calibrate
-- Brightness" at every login. The brightness lives in two places, and they come apart:
--
--   the live CVar        GAMMA_ADJUSTMENT. What the renderer follows and what the calibration
--                        screen shows. The pregame screen sets it to 100 on console on purpose
--                        (ESO-404970, esoui/pregame/statemanager/gamepad/pregamestates_gamepad.lua).
--   the stored setting   GetSetting(SETTING_TYPE_GRAPHICS, GRAPHICS_SETTING_GAMMA_ADJUSTMENT).
--                        What the console profile loads, and what the player saved.
--
-- Measured on PS5 right after login: CVar "100", stored setting "133" (and 138, 135 on other
-- days). The profile still has the right value; it is just no longer pushed to the live one.
--
-- What an add-on can and cannot do about it, each measured on PS5 unless said otherwise:
--
--   SetCVar("GAMMA_ADJUSTMENT", v)   returns normally and changes nothing. Add-on code is
--                                    untrusted and the console drops the write silently.
--   SetSetting(...)                  private: raises UI error 459E4D05, even under pcall.
--   CallSecureProtected              reaches only functions the client classes as protected
--                                    (IsProtectedFunction); SetCVar is not one.
--   RefreshSettings()                DESTRUCTIVE. With CVar 100 and stored 135, one call left both
--                                    at 100: it pulls the live value into the stored setting. The
--                                    client calls it whenever the options screen opens. Never
--                                    called here.
--   ApplySettings()                  WORKS. With CVar 100 and stored 133, one call left both at
--                                    133. It is the options screen's Apply button: it makes the
--                                    engine use the stored settings.
--
-- So this add-on cannot choose a brightness -- an earlier version had a slider that wrote the CVar
-- and it never did anything on console -- but it can put back the one the game itself saved. It
-- calls ApplySettings only when the live value and the stored one differ, and judges the result
-- against the stored value as it was beforehand, so a call that overwrote the saved brightness
-- (as RefreshSettings does) is reported as that, never as success, and stops further calls.
--
-- Nothing here touches client UI code, hooks or reads anything the client built: the client
-- calls are GetCVar, GetSetting, ApplySettings and the read-only IsPrivateFunction /
-- IsProtectedFunction, so there is no way to taint a closure the client creates.

if PBS_GAMMA_ADJUSTER then
	return
end

local addon = {
	name = "PBsGammaAdjuster",
}

-- The display name is a Lua constant and the version comes from the manifest, the same way
-- PB's other add-ons do it -- reading the name back out of "## Title" mangles the "PB's "
-- prefix in the settings library. Typographic apostrophe (U+2019), not ASCII '.
local DISPLAY_NAME = "PB’s GammaAdjuster"
local AUTHOR = "PinkBanther"
local SLASH = "/pbgamma"
local CVAR = "GAMMA_ADJUSTMENT"
local APPLY = "ApplySettings"

-- When to look after the player is activated. The login reset has already happened by the time
-- add-ons load, so the first look is as soon as the world is up. The later ones are for a game
-- that sets its own value again during start-up, roughly doubling, and over by fifteen seconds
-- so the add-on is out of the way long before the player opens the calibration screen.
local RECHECK_DELAYS_MS = { 1000, 5000, 15000 }

-- ApplySettings calls per session by the automatic path. Enough for a game that needs a second
-- go, few enough that a call that does nothing is not repeated for ever.
local MAX_AUTOMATIC_CALLS = 3

-- Anything the game reads as within this counts as equal. The CVar is a string and may come
-- back as "100.000000".
local TOLERANCE = 0.5

local LOG_LIMIT = 60

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

-- ---------------------------------------------------------------------------------------
-- Output
--
-- A message printed at EVENT_ADD_ON_LOADED is thrown away because chat is not up yet, so
-- anything user-facing is either a command response or fires after EVENT_PLAYER_ACTIVATED.
-- What happens is also written to a log that /pbgamma prints afterwards.
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

local function NowMs()
	return GetGameTimeMilliseconds and GetGameTimeMilliseconds() or 0
end

local loadedAtMs = NowMs()
addon.log = {}

local function Log(text, ...)
	local ok, message = pcall(string.format, text, ...)
	if not ok then
		message = text
	end
	local log = addon.log
	log[#log + 1] = string.format("+%.1fs %s", (NowMs() - loadedAtMs) / 1000, message)
	if #log > LOG_LIMIT then
		table.remove(log, 1)
	end
end

local function After(delayMs, callback)
	if zo_callLater then
		zo_callLater(callback, delayMs)
	else
		callback()
	end
end

-- ---------------------------------------------------------------------------------------
-- Reading the game's two brightness values
-- ---------------------------------------------------------------------------------------

addon.accountDefaults = {
	-- Whether the saved brightness is restored at login.
	enabled = true,
}

local function Same(a, b)
	return a ~= nil and b ~= nil and math.abs(a - b) < TOLERANCE
end

local function Quoted(ok, value)
	if not ok then
		return "error: " .. tostring(value)
	end
	return string.format("%q", tostring(value))
end

-- The live value the renderer follows, or nil if it cannot be read.
local function ReadLive()
	if not GetCVar then
		return nil
	end
	local ok, raw = pcall(GetCVar, CVAR)
	return ok and tonumber(raw) or nil
end

local function RawLive()
	if not GetCVar then
		return "n/a"
	end
	return Quoted(pcall(GetCVar, CVAR))
end

local function SettingAvailable()
	return GetSetting ~= nil and SETTING_TYPE_GRAPHICS ~= nil and GRAPHICS_SETTING_GAMMA_ADJUSTMENT ~= nil
end

-- The value the player saved, or nil if it cannot be read.
local function ReadSaved()
	if not SettingAvailable() then
		return nil
	end
	local ok, raw = pcall(GetSetting, SETTING_TYPE_GRAPHICS, GRAPHICS_SETTING_GAMMA_ADJUSTMENT)
	return ok and tonumber(raw) or nil
end

local function RawSaved()
	if not SettingAvailable() then
		return "n/a"
	end
	return Quoted(pcall(GetSetting, SETTING_TYPE_GRAPHICS, GRAPHICS_SETTING_GAMMA_ADJUSTMENT))
end

-- How the client itself classes a function: "protected" (reachable from an add-on only through
-- CallSecureProtected), "private" (client code only) or "neither". Asking has no side effects,
-- unlike calling the function to find out, which for a private one raises the UI error screen.
-- ESOUIDocumentation.txt's own markers have been wrong about this before, so the client is asked.
local function Classify(name)
	if not (IsProtectedFunction and IsPrivateFunction) then
		return "n/a"
	end
	local okProtected, protected = pcall(IsProtectedFunction, name)
	local okPrivate, private = pcall(IsPrivateFunction, name)
	if not (okProtected and okPrivate) then
		return "unreadable"
	end
	if protected and private then
		return "protected+private"
	end
	return protected and "protected" or (private and "private" or "neither")
end

-- Calls a client function the way the client says it may be called, and says what happened.
local function Invoke(name)
	local class = Classify(name)
	if class == "neither" then
		local fn = _G[name]
		if not fn then
			return "skipped (not defined)"
		end
		local ok, err = pcall(fn)
		return ok and "called" or ("ERROR " .. tostring(err))
	elseif class == "protected" and CallSecureProtected then
		local ok, success = pcall(CallSecureProtected, name)
		return ok and ("called through CallSecureProtected, returned " .. tostring(success)) or ("ERROR " .. tostring(success))
	end
	return "skipped (" .. class .. ")"
end

-- ---------------------------------------------------------------------------------------
-- Restoring the saved brightness
-- ---------------------------------------------------------------------------------------

-- Makes the game apply the brightness the player saved, if the screen is not at it.
--
-- Returns one of
--   "agree"      the live value already matches the saved one; nothing was called
--   "pushed"     ApplySettings was called and the live value now follows the saved one
--   "overwrote"  ApplySettings was called and the SAVED value was replaced instead. The saved
--                brightness is lost; the player re-saves it in the calibration screen. Stops
--                every further automatic call.
--   "unchanged"  ApplySettings was called, or skipped as private, and nothing moved
--   "unreadable" the live or the saved value cannot be read, so nothing was called
--   "halted"     not called: an earlier call this session overwrote the saved brightness
-- and logs which, with both values on either side of the call.
--
-- `manual` is the player asking (slash command, button): it ignores the call limit and the halt.
function addon:Restore(reason, manual)
	if self.halted and not manual then
		self.lastResult = "halted"
		Log("%s: not calling %s again, an earlier call overwrote the saved brightness", reason, APPLY)
		return self.lastResult
	end

	local saved, live = ReadSaved(), ReadLive()
	if saved == nil or live == nil then
		self.lastResult = "unreadable"
		Log("%s: cannot read the values (live %s, saved %s)", reason, RawLive(), RawSaved())
		return self.lastResult
	end

	if Same(live, saved) then
		self.lastResult = "agree"
		Log("%s: live %g already matches the saved brightness", reason, live)
		return self.lastResult
	end

	self.calls = (self.calls or 0) + 1
	if not manual and self.calls > MAX_AUTOMATIC_CALLS then
		self.lastResult = "unchanged"
		Log("%s: live %g, saved %g, but %s already tried %d times this session", reason, live, saved, APPLY, MAX_AUTOMATIC_CALLS)
		return self.lastResult
	end

	local outcome = Invoke(APPLY)
	local liveAfter, savedAfter = ReadLive(), ReadSaved()

	if Same(liveAfter, saved) and (savedAfter == nil or Same(savedAfter, saved)) then
		self.lastResult = "pushed"
	elseif savedAfter ~= nil and not Same(savedAfter, saved) then
		self.lastResult = "overwrote"
		self.halted = true
	else
		self.lastResult = "unchanged"
	end

	Log("%s: %s %s; live %g -> %s, saved %g -> %s => %s", reason, APPLY, outcome, live, tostring(liveAfter), saved, tostring(savedAfter), self.lastResult)
	return self.lastResult
end

-- The same, but only if the player has not turned the login restore off.
function addon:RestoreAtLogin(reason)
	if self.account and self.account.enabled == false then
		self.lastResult = "off"
		Log("%s: restoring the saved brightness at login is off, game left alone", reason)
		return self.lastResult
	end
	return self:Restore(reason, false)
end

function addon:Failed()
	local result = self.lastResult
	return result == "unchanged" or result == "overwrote" or result == "unreadable" or result == "halted"
end

function addon:ReportFailure()
	-- halted means an earlier call overwrote it, and that is the thing the player needs to hear,
	-- whatever the last look found.
	if self.lastResult == "overwrote" or self.halted then
		Line("|cFF69B4%s|r: the game overwrote your saved brightness instead. Set it again in Calibrate Brightness, then type %s and send the lines it prints.", self.title, SLASH)
	else
		Line("|cFF69B4%s|r: could not restore the saved brightness (%s). Type %s and send the lines it prints.", self.title, tostring(self.lastResult), SLASH)
	end
end

-- ---------------------------------------------------------------------------------------
-- Slash command
-- ---------------------------------------------------------------------------------------

local function Usage()
	Line(SLASH .. "              the two brightness values, what the game answered, and the log")
	Line(SLASH .. " resync       restore the saved brightness now")
	Line(SLASH .. " on | off     restore it at login, or leave it to the game")
end

local function Status()
	local account = addon.account
	local hdr
	if IsSystemUsingHDR then
		local ok, value = pcall(IsSystemUsingHDR)
		hdr = ok and tostring(value) or "unreadable"
	else
		hdr = "n/a"
	end

	Line("|cFF69B4%s|r", addon.title)
	Line("  restore at login : %s", (account and account.enabled == false) and "off" or "on")
	Line("  live brightness  : %s   (%s, HDR %s)", RawLive(), CVAR, hdr)
	Line("  saved brightness : %s   (GRAPHICS_SETTING_GAMMA_ADJUSTMENT)", RawSaved())
	Line("  client classes   : %s %s", APPLY, Classify(APPLY))
	Line("  last result      : %s", tostring(addon.lastResult))
	Line("  log:")
	for _, entry in ipairs(addon.log) do
		Line("    %s", entry)
	end
end

-- What the player is told after asking for a restore by hand.
local function Describe(result)
	if result == "pushed" then
		return "done -- the screen now follows the brightness you saved"
	elseif result == "agree" then
		return "nothing to do -- the screen is already at the brightness you saved"
	elseif result == "overwrote" then
		return "the game overwrote your saved brightness instead; set it again in Calibrate Brightness"
	end
	return "not restored (" .. tostring(result) .. ")"
end

function addon:RestoreNow(reason)
	local result = self:Restore(reason, true)
	Line("%s: %s", self.baseTitle, Describe(result))
	if self:Failed() then
		Line("  type %s and send the lines it prints", SLASH)
	end
	return result
end

local function OnSlash(text)
	local command = (text or ""):match("^%s*(.-)%s*$"):lower()

	if command == "" or command == "status" then
		Status()
	elseif command == "resync" or command == "restore" then
		addon:RestoreNow("slash resync")
	elseif command == "on" then
		addon.account.enabled = true
		Log("slash on: restoring the saved brightness at login turned on")
		Line("restoring the saved brightness at login is on")
	elseif command == "off" then
		addon.account.enabled = false
		Log("slash off: restoring the saved brightness at login turned off")
		Line("restoring the saved brightness at login is off -- the game keeps whatever it loads")
	elseif tonumber(command) then
		Line("a brightness cannot be set from an add-on on console -- the game ignores the write. Set it in Calibrate Brightness; %s resync restores that one after a login", SLASH)
	else
		Usage()
	end
end

-- ---------------------------------------------------------------------------------------
-- Bootstrap
-- ---------------------------------------------------------------------------------------

local function OnPlayerActivated()
	-- Only the first activation of a session is a login. Every later one is a zone change, and
	-- the player may well have used the calibration screen by then.
	if addon.activated then
		return
	end
	addon.activated = true

	-- Nothing to look at again when the player has turned it off.
	if addon:RestoreAtLogin("player activated") == "off" then
		return
	end

	for index, delayMs in ipairs(RECHECK_DELAYS_MS) do
		local isLast = index == #RECHECK_DELAYS_MS
		After(delayMs, function()
			addon:RestoreAtLogin(string.format("recheck +%ds", math.floor(delayMs / 1000)))
			-- Said once, at the end, so a failure that clears itself on a later try is not
			-- announced.
			if isLast and addon:Failed() then
				addon:ReportFailure()
			end
		end)
	end
end

local function OnAddOnLoaded(_, loadedName)
	if loadedName ~= addon.name then
		return
	end
	EVENT_MANAGER:UnregisterForEvent(addon.name, EVENT_ADD_ON_LOADED)

	addon.account = ZO_SavedVars:NewAccountWide("PBsGammaAdjuster_Data", 1, nil, addon.accountDefaults)
	-- Versions before 1.1.0 stored a brightness the player chose in the settings panel. It was
	-- never applied -- the console drops the write -- and nothing reads it now.
	addon.account.gamma = nil

	SLASH_COMMANDS[SLASH] = OnSlash

	-- Not before the player is activated: that is the state the restore was measured in, and
	-- the world is up. Only reading happens here, so there is nothing to wait for.
	Log("addon loaded: live %s, saved %s", RawLive(), RawSaved())

	EVENT_MANAGER:RegisterForEvent(addon.name, EVENT_PLAYER_ACTIVATED, OnPlayerActivated)

	if addon.InitSettings then
		addon:InitSettings()
	end
end

PBS_GAMMA_ADJUSTER = addon
EVENT_MANAGER:RegisterForEvent(addon.name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
