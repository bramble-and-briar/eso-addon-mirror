-- PB's ChatAssistant
-- Author: PinkBanther
--
-- On console the chat entry box can only be opened from the controller -- Options + touchpad on
-- PS5 -- and opening it is what makes the platform put its own text input screen up, the IME
-- included. With a USB keyboard plugged into the console that means letting go of the keyboard
-- and reaching for the pad before every single message.
--
-- Press Enter, the box opens, the console's input screen comes up. That is the whole add-on.

if PBS_CHAT_ASSISTANT then
	return
end

local addon = {
	name = "PBsChatAssistant",
}

-- Display name is a Lua constant; the version is VERSION below. Both are what the settings
-- panel shows. Typographic apostrophe (U+2019), matching the manifest title -- the identifier
-- stays plain ASCII so folder, manifest filename and addon.name can match byte for byte.
local DISPLAY_NAME = "PB’s ChatAssistant"
local AUTHOR = "PinkBanther"

local em = EVENT_MANAGER

-- ROUTES
--
-- Two ways exist for a key press to reach add-on Lua, and on console only one of them works:
--
--   binding  Bindings.xml declares PBSCHATASSISTANT_START_CHAT and the player binds a key to it.
--            This is the sanctioned route and the only one on PC. On console it is dead:
--            AreKeyboardBindingsSupportedInGamepadUI() returns false, meaning the client does
--            not route keyboard keys into the binding system at all. The action is still
--            declared, because it costs nothing and is the right route wherever it does work.
--
--   Neither is a gamepad route, and there is none. DIRECTIONAL_INPUT looked like one -- a plain
--   Lua object add-ons may register with -- but the D-pad reader is built out of the private
--   IsKeyDown and threw once per frame, and the stick reader was not pursued after that. Binding
--   is closed too: PS5 has no keybinding screen, and BindKeyToAction is refused as private.
--
--   catcher  A TopLevelControl with keyboardEnabled="true" and an OnKeyDown handler, kept shown
--            so it is handed key events. The game uses this pattern itself on a console-only
--            screen (ZO_ControllerDisconnect).
--
--            Measured on PS5: the default tier receives keyboard keys. Enter arrives as key 3
--            with IsKeyCodeKeyboardKey() true. The HIGH tier was not needed and is kept only as
--            the fallback to probe if a client update ever moves this.
--
-- captureMode: "auto", "off", "default" or "high".
--
-- It ships OFF, and that is not caution -- a shown catcher was observed to stop the controller
-- responding on PS5, from the moment the add-on loaded and before any key was pressed. Gamepad
-- buttons travel as KeyCodes through the same handler as keyboard keys, so the working theory is
-- that the catcher is swallowing them. Until that is settled the add-on loads doing nothing, and
-- /pbchat probe is how the swallowing gets measured: it reports gamepad and keyboard keys apart,
-- and clears itself after 15 seconds.
--
-- Auto, when chosen explicitly, picks the catcher exactly when the binding route is dead.
local DEFAULTS = {
	enabled = true,
	-- captureMode ships OFF, and it has to.
	--
	-- A shown catcher pauses the gamepad buttons, Options among them. Shipping "default" armed
	-- the catcher at load, so a fresh install began with the Options button dead -- and with the
	-- usual way out of that (open chat, let the input screen disarm the catcher) behind the very
	-- button that was not working. It only ever reached new installs: anyone who had used the
	-- add-on already had "off" written to their saved settings by autoSafe.
	--
	-- Off costs nothing that matters. The focus watcher is what raises the input screen, it is
	-- always on, and it serves a chat window opened from the controller exactly as well. Only the
	-- Enter key needs arming, and arming it is a deliberate act: /pbchat enter.
	--
	-- followInput false: the input-type event gated the catcher in an earlier build and was the
	-- wrong signal for it. It fires on a CHANGE only, so it cannot cover a run of key presses,
	-- and gating on it left nothing listening. /pbchat follow on still exists.
	captureMode = "off",
	-- 100 ms. Long enough on the hardware this was built against, and short enough that the box
	-- feels like it opens on the key press rather than after it.
	--
	-- This is the one setting that can make the add-on look broken if it is too low: too short a
	-- wait and the box still opens, but the console does not raise its input screen. The cure is
	-- to raise it, /pbchat delay 300 upward, not to look elsewhere.
	delayMs = 100,
	watch = true,
	autoSafe = true,
	channelKeys = true,
	entryChannelLayer = true, -- legacy setting
	hudChannelEnabled = true,
	-- One chat tab per guild, alongside the normal one. Tabs live in the client's own chat
	-- settings, so turning this off removes the ones this add-on made rather than orphaning them.
	guildTabsEnabled = true,
	-- Whether the normal tab still carries guild and officer chat, per guild rather than one
	-- switch for all of them: some guilds are worth seeing in the general flow and some are not.
	-- Keyed by guild id; a guild with no entry is shown, which is how chat read before any of
	-- this existed.
	guildMainTab = {},
	-- Guild Finder adverts contain a guild link. Off by default, matching ChatFilter; whispers
	-- remain exempt unless their separate switch is enabled.
	recruitFilterEnabled = false,
	recruitFilterWhispers = false,
	-- NPC speech reaches chat through four dedicated monster channels. Off by default.
	npcChatFilterEnabled = false,
	-- Whether the active-tab name is drawn. Tab selection and outgoing-channel synchronization
	-- continue when this is off.
	tabNameVisible = true,
	-- Position of the active-tab name: X from the screen centre, Y from the screen top.
	tabStripX = 0,
	tabStripY = 110,
	-- Size of the active-tab name drawn on the HUD.
	tabTextSize = 28,
	-- Draw layer for the active-tab name: background, controls, text or overlay.
	tabTextLayer = "text",
	-- Set once the offsets above have been moved to the meaning they have now. See
	-- MigrateStripPosition.
	tabStripPlaced = false,
	-- 0 means leave the channel wherever the game left it. Any other value is a channel id
	-- applied once when the player enters the world; see ApplyDefaultChannel.
	defaultChannel = 0,
	followInput = false,
	idleSeconds = 15,
	logResetDone = false,
	triggerOnKeyboard = false,
	log = false,
}

local MIN_DELAY_MS = 0
local MAX_DELAY_MS = 5000

-- Both Enters, because a keyboard has two and neither is more correct than the other.
local ENTER_KEYS = {
	[KEY_ENTER] = true,
	[KEY_NUMPAD_ENTER] = true,
}

-- Built rather than declared. A table constructor with a nil key raises "table index is nil" at
-- load, which would take the whole add-on down -- and KEY_ENTER is confirmed on PS5 while these
-- two are not yet. Cheap insurance against a constant that turns out not to exist.
local CHANNEL_KEYS = {}
if KEY_LEFTARROW then
	CHANNEL_KEYS[KEY_LEFTARROW] = -1
end
if KEY_RIGHTARROW then
	CHANNEL_KEYS[KEY_RIGHTARROW] = 1
end

local CATCHER_CONTROL_NAMES = {
	default = "PBsChatAssistantKeyCatcher",
	high = "PBsChatAssistantKeyCatcherHigh",
	low = "PBsChatAssistantKeyCatcherLow",
	medium = "PBsChatAssistantKeyCatcherMedium",
}

-- Bumped by hand with the manifest. The manifest version is not readable early enough to be
-- worth chasing here, and a wrong number in one place is easier to spot than a missing one.
--
-- Reported by /pbchat rather than announced at login. It was announced while the add-on was
-- being built, because a build behaving unlike its code was the hardest thing to diagnose from
-- inside the game. That is worth a command, not a line of chat on every login.
local VERSION = "1.30.0"

-- How long the catcher waits for the box to close before coming back anyway.
local RESUME_DEADLINE_SECONDS = 120

-- How long an armed catcher waits for a chat to happen before standing down by itself. The
-- buttons are paused the whole time it is armed, so an arming that goes unused has to expire.
local ARM_TIMEOUT_SECONDS = 60

-- Focus watcher cadence. Fast enough that the re-focus follows the box opening closely, slow
-- enough to be nothing on a frame budget: four reads of state and no allocation.
local WATCH_INTERVAL_MS = 200

-- Long enough for guild membership to be known. The default is applied once, so a few seconds
-- late costs nothing and being early costs the setting.
local DEFAULT_CHANNEL_DELAY_MS = 3000
local DEFAULT_CHANNEL_RETRY_MS = 1000
local DEFAULT_CHANNEL_MAX_ATTEMPTS = 15

local PROBE_SECONDS = 15
local TRIAL_SECONDS = 20

-- Watchdog cadence and how long the broken state is tolerated before it is undone. See
-- StartStuckWatchdog.
local WATCHDOG_INTERVAL_MS = 1000
local WATCHDOG_STRIKES = 3

local function Print(formatString, ...)
	d(string.format("|cFF69B4PB’s ChatAssistant|r: " .. formatString, ...))
end

-- ZO_GetChatSystem() returns the gamepad chat system on console and the keyboard one on PC.
-- Both inherit SharedChatSystem, so the shared methods are valid on either; the type checks are
-- there so a client that ever drops the chat system entirely degrades to doing nothing rather
-- than erroring on every key press.
local function GetChatSystem()
	if type(ZO_GetChatSystem) ~= "function" then
		return nil
	end
	return ZO_GetChatSystem()
end

local function IsTextEntryOpen()
	local chat = GetChatSystem()
	if not chat or type(chat.IsTextEntryOpen) ~= "function" then
		return false
	end
	return chat:IsTextEntryOpen()
end

local function IsChatAvailable()
	return type(IsChatSystemAvailableForCurrentPlatform) ~= "function"
		or IsChatSystemAvailableForCurrentPlatform()
end

-- False on console: the client does not route keyboard keys into the binding system there, so
-- Bindings.xml can never fire and a catcher is the only way in.
local function IsBindingRouteAvailable()
	return type(AreKeyboardBindingsSupportedInGamepadUI) ~= "function"
		or AreKeyboardBindingsSupportedInGamepadUI()
end

local function ResolveCaptureMode(mode)
	if mode ~= "auto" then
		return mode
	end
	return IsBindingRouteAvailable() and "off" or "default"
end

----------------------------------------------------------------------------------------------
-- Opening the box
----------------------------------------------------------------------------------------------

-- WHY StartChatInput() IS NOT USED
--
-- It is what the game's own Start Chat binding calls, and it is closed to add-ons on console.
-- It reaches ZO_GamepadChatSystem:StartTextEntry(), which calls the private SetSetting() to
-- persist the chat HUD setting, and a *private* function cannot be called by add-on code at all.
-- The hardware-event rule that lets a keybind reach a *protected* function does not extend to
-- private ones: calling it straight out of OnKeyDown fails exactly as calling it from a timer
-- did, with "Attempt to access a private function 'SetSetting' from insecure code".
--
-- The private call sits behind `if not dontShowHUDWindow`, so passing that flag is the only way
-- an add-on can open the box at all. The flag also skips the work that puts the window on
-- screen, which has to be done here instead -- and it matters that it is done, because a focused
-- entry box with no window activates an input eater (DIRECTIONAL_INPUT:ConsumeAll) and pushes
-- the GamepadChatSystem action layer, leaving nothing on screen to dismiss. StartStuckWatchdog
-- undoes that state if it ever happens anyway.
--
-- Everything below is plain Lua on the chat system. None of it is private or protected.
local function OpenChatEntry()
	local chat = GetChatSystem()
	if not chat or type(chat.StartTextEntry) ~= "function" then
		return
	end

	-- Turns the HUD chat on for this session. Making that persist is the private call itself, so
	-- it is dropped: the add-on shows the chat without quietly rewriting a saved setting.
	if type(chat.SetHUDEnabled) == "function" then
		chat:SetHUDEnabled(true)
	end

	chat:StartTextEntry(nil, nil, nil, true)

	-- StartTextEntry declines in a good number of states -- a dialog is up, the scene blocks
	-- chat, the player is not activated, the game does not have focus -- and says so only by not
	-- opening. Nothing below should run in that case.
	if not chat:IsTextEntryOpen() then
		return false
	end

	if chat.isMinimized and type(chat.Maximize) == "function" then
		chat:Maximize()
	elseif chat.primaryContainer then
		chat.primaryContainer:FadeIn()
	end

	-- Both branches of the skipped code set this to false: the minimized branch assigns
	-- STUB_SETTING_KEEP_MINIMIZED, which is itself false. So they need no telling apart.
	chat.shouldMinimizeAfterEntry = false

	-- What actually puts the console's own input screen up. There is no Lua call that summons
	-- it; IsVirtualKeyboardOnScreen() is read-only, and the screen is the platform's response to
	-- the chat edit control taking focus. TextEntry:Open() already took focus once, and this
	-- re-asserts it after the window moved, exactly as the game does.
	local textEntry = chat.textEntry
	local editControl = textEntry and type(textEntry.GetEditControl) == "function" and textEntry:GetEditControl()
	if editControl then
		editControl:TakeFocus()
	end

	return true
end

-- WHY THE WAIT IS BACK, AND WHY IT IS THE POINT
--
-- The console's input screen -- the IME -- is what makes any of this worth having, and it does
-- not come up when the box is opened in the same frame as the key press. Measured on PS5:
--
--   open immediately   entry open true, edit focus true, input screen FALSE
--   open 5s later      input screen appears
--
-- The input device is not what decides it. The second measurement was repeated without touching
-- the controller at all and the screen still came up, which rules out the platform gating this
-- on whether the player last used a gamepad.
--
-- What it is, is that the key press arrives while the previous focus state is still unwinding --
-- the chat box closing on the Enter that submitted the last message, say. Reopening in that same
-- frame gives the platform no lost-and-regained focus to react to. Let the frame finish and the
-- focus is genuinely fresh, so the screen is raised.
--
-- Which makes the wait the mechanism rather than a safety margin, exactly as first specified.
-- Deferring is free now, too: nothing left on the open path is private, so there is no hardware
-- event trace to preserve.
local openPending = false

local function OpenPending()
	openPending = false
	local opened = OpenChatEntry()
	addon:Log("opened: %s", tostring(opened or false))
	addon:ResumeCatcherWhenChatCloses()
	addon:StartStuckWatchdog()
	return opened
end

function addon:StartChat()
	if not self.sv.enabled then
		self:Log("start: off")
		return
	end

	-- A held key repeats. One box is enough.
	if openPending or IsTextEntryOpen() or not IsChatAvailable() then
		self:Log("start: declined (pending %s, entry %s, chat %s)", tostring(openPending),
			tostring(IsTextEntryOpen()), tostring(IsChatAvailable()))
		return
	end

	self:Log("start: opening in %d ms", self.sv.delayMs)

	-- The catcher comes down HERE, at the start of the wait, and stays down across the open.
	--
	-- A shown catcher stops the input screen appearing. That is the finding that took longest to
	-- see, because it looks like an unrelated failure: with a catcher up, /pbchat open -- the
	-- command that had worked minutes earlier with nothing shown -- stopped producing the screen
	-- as well. The catcher evidently holds the engine's keyboard focus, so the chat edit control
	-- taking focus is not what the platform sees, and it raises nothing.
	--
	-- So the catcher's whole job is to hear one key press and then get out of the way. It hears
	-- Enter, stands down, and the wait covers both that and the focus cycle before the box opens.
	-- It comes back when the box closes, in ResumeCatcherWhenChatCloses.
	self:SuspendCatcher()

	if self.sv.delayMs <= 0 then
		return OpenPending()
	end

	openPending = true
	zo_callLater(OpenPending, self.sv.delayMs)
	return true
end

----------------------------------------------------------------------------------------------
-- Channel cycling
----------------------------------------------------------------------------------------------

-- Left and right walk the channel the next message will go to.
--
-- Only while the chat box is CLOSED. Inside an open box the arrow keys move the text cursor, and
-- taking them would be a poor trade for a channel switch. So the gesture is: pick the channel on
-- the HUD, then press Enter and type. The choice survives the open -- StartTextEntry only resets
-- the channel when there is not one already set.
--
-- This costs the gamepad nothing it was not already costing. The arrows are read by the same
-- catcher that reads Enter, which is up only when Enter is armed, so a build with the channel
-- keys behaves exactly like one without until /pbchat enter is used.
local function IsUsableChannelName(name)
	return type(name) == "string" and name ~= "" and name ~= "nil"
end

-- Officer channels answer to the same guild name as the guild channel they belong to, so without
-- this the two are indistinguishable in the label and in the switch message: two entries reading
-- the same guild name, one of which is not the one you meant.
--
-- Built rather than declared, because a table constructor with a nil key raises at load and would
-- take the add-on down with it if any of these constants ever went missing.
local OFFICER_CHANNELS = {}
for _, channelId in ipairs({
	CHAT_CHANNEL_OFFICER_1, CHAT_CHANNEL_OFFICER_2, CHAT_CHANNEL_OFFICER_3,
	CHAT_CHANNEL_OFFICER_4, CHAT_CHANNEL_OFFICER_5,
}) do
	OFFICER_CHANNELS[channelId] = true
end

local function OfficerSuffix(channelId)
	if not OFFICER_CHANNELS[channelId] then
		return ""
	end
	return GetString(SI_PBSCHATASSISTANT_OFFICER_SUFFIX) or ""
end

function addon:GetChannelDisplayName(channelId)
	if channelId == nil then return "--" end
	local info = type(ZO_ChatSystem_GetChannelInfo) == "function" and ZO_ChatSystem_GetChannelInfo()
	local data = info and info[channelId]
	-- Guild and officer channels have dynamicName=true and no fixed name.
	local suffix = OfficerSuffix(channelId)
	if data and data.dynamicName and type(GetDynamicChatChannelName) == "function" then
		local ok, name = pcall(GetDynamicChatChannelName, channelId)
		if ok and IsUsableChannelName(name) then return name .. suffix end
	end
	if type(GetChannelName) == "function" then
		local ok, name = pcall(GetChannelName, channelId)
		if ok and IsUsableChannelName(name) then return name .. suffix end
	end
	if data and IsUsableChannelName(data.name) then return data.name .. suffix end
	-- Membership information may not yet be available immediately after a load.
	local switches = type(ZO_ChatSystem_GetChannelSwitchLookupTable) == "function"
		and ZO_ChatSystem_GetChannelSwitchLookupTable()
	local switch = switches and switches[channelId]
	return IsUsableChannelName(switch) and (switch .. suffix) or tostring(channelId)
end

local function GetCyclableChannels()
	if type(ZO_ChatSystem_GetChannelInfo) ~= "function"
		or type(ZO_ChatSystem_GetChannelSwitchLookupTable) ~= "function" then
		return {}
	end

	local channelInfo = ZO_ChatSystem_GetChannelInfo()
	local switchLookup = ZO_ChatSystem_GetChannelSwitchLookupTable()
	local channels = {}

	for channelId, data in pairs(channelInfo) do
		local switch = switchLookup[channelId]
		-- The same requirement test the chat system applies when it decides whether a channel
		-- can be selected: not in a group, no guild, no such channel to walk into.
		local available = not data.requires or data.requires(channelId)
		-- A whisper needs someone to whisper to, so there is nothing to cycle into.
		local needsTarget = data.saveTarget ~= nil

		if switch and available and not needsTarget then
			channels[#channels + 1] = { id = channelId, switch = switch, name = addon:GetChannelDisplayName(channelId) }
		end
	end

	-- By switch, which is how the game's own channel dropdown is ordered, so the sequence the
	-- arrows walk is the sequence the player has already seen there.
	table.sort(channels, function(a, b)
		return a.switch < b.switch
	end)

	return channels
end

-- Reached two ways: the arrow keys, which need the catcher up and so need Enter armed, and the
-- bindable actions in Bindings.xml, which do not. Keyboard keys never reach the binding system
-- on console, but gamepad buttons do, so a controller button bound to one of those walks the
-- channel with nothing shown and no buttons paused.
--
-- No guard on the chat box being closed here. That guard belongs to the arrow keys alone, where
-- it stops an open box losing its text cursor; a bound button has nothing to take.
-- The same list the arrows and L2+D-pad Right walk, for the settings panel to offer.
function addon:GetSelectableChannels()
	return GetCyclableChannels()
end

-- Applied once, at login, and never on opening the chat box or after a zone change.
--
-- Per-open would fight the feature it sits beside: L2+D-pad Right chooses the channel on the HUD, before
-- the box opens, so re-imposing a default at that moment would throw the choice away every time.
-- Once per session is what "default" means here -- where messages start, not where they are
-- forced back to.
--
-- Deferred, because guild membership is not known the instant the world appears, and a guild
-- channel is exactly the kind of default worth setting.
function addon:ApplyDefaultChannel()
	local wanted = self.sv and self.sv.defaultChannel or 0
	if wanted == 0 then
		return true
	end

	local chat = GetChatSystem()
	if not chat or type(chat.SetChannel) ~= "function" then
		return false
	end

	for _, channel in ipairs(GetCyclableChannels()) do
		if channel.id == wanted then
			chat:SetChannel(wanted)
			if self.chatTabs and self.sv.guildTabsEnabled then
				if not self.chatTabs:SelectTabForChannel(wanted) then
					return false
				end
			end
			self:Log("default channel -> %s", tostring(self:GetChannelDisplayName(wanted)))
			return true
		end
	end

	-- Not available: no guild any more, or not grouped. Left alone rather than reset, since the
	-- setting may become valid again later in the session.
	self:Log("default channel %s not available", tostring(wanted))
	return false
end

-- What L2 + D-pad Right does now: move to the next chat tab.
--
-- Falls back to walking the outgoing channel when the guild tabs are switched off, so the chord
-- still does something useful rather than nothing at all.
function addon:CycleChatTab(step)
	if self.chatTabs and self.sv and self.sv.guildTabsEnabled then
		if self.chatTabs:Cycle(step) then
			return
		end
	end
	self:CycleChannel(step, true)
end

function addon:CycleChannel(step, suppressAlert)
	if not self.sv or not self.sv.enabled then
		return
	end

	local chat = GetChatSystem()
	if not chat or type(chat.SetChannel) ~= "function" then
		return
	end

	local channels = GetCyclableChannels()
	if #channels == 0 then
		return
	end

	local index = 1
	for i, channel in ipairs(channels) do
		if channel.id == chat.currentChannel then
			index = i
			break
		end
	end

	local target = channels[((index - 1 + step) % #channels) + 1]
	chat:SetChannel(target.id)

	-- Printed whatever the log setting says, because this one is not diagnostics: it is the
	-- answer to "where is my next message going", and it is wanted in the chat log where it can
	-- be scrolled back to. Resolved through GetChannelDisplayName so guild channels get their
	-- guild name and officer channels are marked as such.
	local displayName = self:GetChannelDisplayName(target.id)
	Print(GetString(SI_PBSCHATASSISTANT_CHANNEL_LABEL), displayName)

	-- The alert is the on-screen version, for when nothing else is showing the channel. The HUD
	-- path suppresses it because its own label is already saying the same thing.
	if not suppressAlert and type(ZO_Alert) == "function" then
		ZO_Alert(UI_ALERT_CATEGORY_ALERT, nil, displayName)
	end
end

----------------------------------------------------------------------------------------------
-- Catching the key
----------------------------------------------------------------------------------------------

-- Reported only. It is not fit to decide anything on console: measured on PS5, it answers
-- "gamepad" immediately after a whole slash command has been typed on the keyboard, so the
-- console UI evidently pins it rather than tracking the device in use. A release was built on
-- it and did nothing at all, because the catcher it gated was never once shown.
--
-- EVENT_INPUT_TYPE_CHANGED does fire, which is the part worth having. See the event handler.
local function IsGamepadInput()
	return type(WasLastInputGamepad) ~= "function" or WasLastInputGamepad()
end

-- Whether the player is currently at the keyboard, as told by EVENT_INPUT_TYPE_CHANGED.
--
-- Driven by the event and nothing else. An earlier build asked WasLastInputGamepad() instead and
-- did nothing at all, because on console that answers "gamepad" even while a slash command is
-- being typed. The event is the only signal here that reflects reality.
--
-- Starts false, meaning the controller: on console that is where a session begins, and it is the
-- safe end to be wrong at, since it leaves the catcher down and the buttons working.
local keyboardActive = false
local idleHandle = 0

local probeActive = false
local probeSeen = nil
local probeControl = nil
local catcherSuspended = false

local function GetCatcherControl(mode)
	local controlName = CATCHER_CONTROL_NAMES[mode]
	return controlName and _G[controlName] or nil
end

local function HideAllCatchers()
	for _, controlName in pairs(CATCHER_CONTROL_NAMES) do
		local control = _G[controlName]
		if control then
			control:SetHidden(true)
		end
	end
end

-- The single place that decides what is shown. Everything else sets state and calls this, so
-- probe and capture cannot end up fighting over the same two controls.
local function IsCatcherShown()
	for _, controlName in pairs(CATCHER_CONTROL_NAMES) do
		local control = _G[controlName]
		if control and not control:IsHidden() then
			return true
		end
	end
	return false
end

-- Off by default and stays off across an upgrade -- see the one-time reset in OnAddOnLoaded --
-- but reachable. Every hard problem in this add-on was settled by turning this on and reading
-- what actually happened: whether the event fired, whether the key arrived, whether the open was
-- declined and why. Removing the switch would mean starting the next one blind.
function addon:Log(formatString, ...)
	if self.sv and self.sv.log then
		Print(formatString, ...)
	end
end

function addon:ApplyCatcher()
	HideAllCatchers()

	if probeActive then
		if probeControl then
			probeControl:SetHidden(false)
		end
		return
	end

	if catcherSuspended then
		return
	end

	-- Every tier tested on PS5 kills the gamepad buttons while shown, so the catcher cannot
	-- simply be left up. It does not have to be: EVENT_INPUT_TYPE_CHANGED says which device the
	-- player is on, and the catcher is only wanted on the keyboard side of that. The moment a
	-- controller button is pressed the event fires and this puts the catcher away again.
	-- The catcher is what takes the gamepad buttons, so it is only up while the player is
	-- actually at the keyboard -- where buttons do not matter, because they are not holding the
	-- controller. Touching the controller fires the event and puts it away again.
	if self.sv.followInput and not keyboardActive then
		return
	end

	local control = GetCatcherControl(ResolveCaptureMode(self.sv.captureMode))
	if control then
		control:SetHidden(false)
	end
end

-- A safety net for the case where no gamepad event ever arrives -- the player simply stops
-- typing and walks away. Without it the catcher would stay up, and so would the dead buttons.
function addon:TouchKeyboardActivity()
	keyboardActive = true

	-- With followInput off the catcher is up unconditionally, so there is nothing for the idle
	-- countdown to take away. Running it anyway printed "catcher down" over a catcher that was
	-- plainly still up, which is worse than not logging at all.
	if not self.sv.followInput then
		self:ApplyCatcher()
		return
	end

	idleHandle = idleHandle + 1
	local handle = idleHandle

	self:ApplyCatcher()

	zo_callLater(function()
		if handle ~= idleHandle or not keyboardActive then
			return
		end
		keyboardActive = false
		self:Log("keyboard idle -- catcher down")
		self:ApplyCatcher()
	end, self.sv.idleSeconds * 1000)
end

function addon:SuspendCatcher()
	catcherSuspended = true
	self:ApplyCatcher()
end

-- There is no event for the entry box closing, so this polls. It only runs while the box is
-- open, and only when a catcher is actually in use.
-- There is no event for the entry box closing, so this polls.
--
-- The deadline matters as much as the poll. An earlier build waited for IsTextEntryOpen() to go
-- false and nothing else, and the box does not always close -- it can sit holding focus after a
-- message is sent. The catcher then never came back and the add-on worked exactly once per
-- session. Waiting has a limit now, after which the catcher returns regardless.
function addon:ResumeCatcherWhenChatCloses(deadline)
	if not catcherSuspended then
		return
	end

	deadline = deadline or (GetFrameTimeSeconds() + RESUME_DEADLINE_SECONDS)

	if IsTextEntryOpen() and GetFrameTimeSeconds() < deadline then
		zo_callLater(function()
			self:ResumeCatcherWhenChatCloses(deadline)
		end, 250)
		return
	end

	catcherSuspended = false
	self:Log("catcher back up")
	self:ApplyCatcher()
end

function addon:OnCatcherKey(control, key)
	if probeActive then
		-- Key repeat would flood the chat, so each code is reported once per probe.
		if not probeSeen[key] then
			local isGamepad = type(IsKeyCodeGamepadKey) == "function" and IsKeyCodeGamepadKey(key)
			probeSeen[key] = isGamepad and "gamepad" or "keyboard"
			Print("key %d (%s) %s%s", key, tostring(GetKeyName(key)),
				isGamepad and "GAMEPAD" or "keyboard", ENTER_KEYS[key] and " <- ENTER" or "")
		end
		return
	end

	self:Log("key %d (%s), entry %s, input %s", key, tostring(GetKeyName(key)),
		tostring(IsTextEntryOpen()), IsGamepadInput() and "gamepad" or "keyboard")

	-- Any key means the player is still at the keyboard, so the catcher stays up and the idle
	-- countdown restarts. Only Enter opens the box.
	self:TouchKeyboardActivity()

	if ENTER_KEYS[key] then
		self:StartChat()
		return
	end

	-- Only while the box is closed, where the arrow keys have nothing else to do. Inside an open
	-- box they move the text cursor; while the input screen is up they never arrive at all.
	local step = CHANNEL_KEYS[key]
	if step and self.sv.channelKeys and not IsTextEntryOpen() then
		self:CycleChannel(step)
	end
end

----------------------------------------------------------------------------------------------
-- The focus watcher
----------------------------------------------------------------------------------------------

-- Whatever opens the chat box, this raises the console's input screen for it.
--
-- Nothing in Lua summons that screen. IsVirtualKeyboardOnScreen() and
-- DoesCurrentLanguageRequireIME() only report, and SetVirtualKeyboardType() picks a layout for a
-- control the platform has already decided to serve. The screen is the platform's own response
-- to the chat edit control LOSING focus and taking it again a frame or more later -- which is
-- the whole reason this add-on waits before opening rather than opening on the key press.
--
-- So the watcher does not show anything. It watches for the state that means the screen is owed
-- and has not come -- box open, edit control focused, no input screen -- and performs the focus
-- cycle that earns it: close, wait, open.
--
-- The point of doing it this way is that it does not care what opened the box. The controller
-- combo, a caught Enter, another add-on: all of them land in the same state, and all of them get
-- the input screen. The first Enter of a session stops being a special case, because there is no
-- longer a case.
local watchArmed = false
local armHandle = 0

local function GetEditControl()
	local chat = GetChatSystem()
	local textEntry = chat and chat.textEntry
	if not textEntry or type(textEntry.GetEditControl) ~= "function" then
		return nil
	end
	return textEntry:GetEditControl()
end

local function HasEditFocus()
	local editControl = GetEditControl()
	return editControl ~= nil and type(editControl.HasFocus) == "function" and editControl:HasFocus()
end

local function IsInputScreenUp()
	return type(IsVirtualKeyboardOnScreen) == "function" and IsVirtualKeyboardOnScreen()
end

local function GetEntryText()
	local chat = GetChatSystem()
	local textEntry = chat and chat.textEntry
	if not textEntry or type(textEntry.GetText) ~= "function" then
		return ""
	end
	return textEntry:GetText() or ""
end

function addon:RefocusForInputScreen()
	local chat = GetChatSystem()
	if not chat or type(chat.CloseTextEntry) ~= "function" then
		return
	end

	-- keepText is not passed, so the box is cleared. It is empty at this point by the check in
	-- the watcher; clearing is only belt and braces.
	chat:CloseTextEntry()

	-- Not logged. The watcher runs this on every chat open, which is the most common thing the
	-- add-on does, so the pair of lines it used to print were in the chat window constantly.
	zo_callLater(function()
		OpenChatEntry()
	end, self.sv.delayMs)
end

function addon:OnWatchTick()
	if not self.sv.enabled or not self.sv.watch then
		return
	end

	-- The catcher's entire job is the one key press that starts a chat. Once the input screen is
	-- up that press has been had, and everything the catcher still costs -- the gamepad buttons,
	-- for as long as it is shown -- is being paid for nothing. So it comes down here, and the
	-- controller works again while the message is being typed and after it is sent.
	--
	-- captureMode is a saved setting, so this persists: a session starts with the buttons
	-- working, and /pbchat enter is how Enter is armed for the next stretch of typing.
	-- The catcher's entire job is the one key press that starts a chat. Once the input screen is
	-- up that press has been had, and everything the catcher still costs -- the gamepad buttons,
	-- for as long as it is shown -- is being paid for nothing.
	--
	-- Holding it up across the input screen was tried, so the arrow keys could change channel at
	-- the one moment the cost is not real: the player is typing into a system overlay with the
	-- game behind it, so paused buttons are no loss. It cannot work. The overlay keeps the
	-- keyboard to itself and no key reaches the game at all -- measured on PS5, with the hold
	-- confirmed in the log and not one arrow arriving.
	if self.sv.autoSafe and self.sv.captureMode ~= "off" and IsInputScreenUp() then
		self.sv.captureMode = "off"
		self:ApplyCatcher()
		self:Log("input screen up -- catcher down, gamepad back")
	end

	-- Our own open is mid-flight; it will produce the screen by itself.
	if openPending then
		return
	end

	if not IsTextEntryOpen() then
		-- Box closed: ready to act on the next one.
		watchArmed = false
		return
	end

	if watchArmed then
		return
	end

	if IsInputScreenUp() then
		-- Already served. Nothing owed.
		watchArmed = true
		return
	end

	if not HasEditFocus() then
		return
	end

	-- Never destroy something the player has typed. A box with text in it was not opened a
	-- moment ago, and re-cycling its focus would throw the message away.
	if GetEntryText() ~= "" then
		watchArmed = true
		return
	end

	watchArmed = true
	self:RefocusForInputScreen()
end

function addon:ApplyWatch()
	local updateName = self.name .. "Watch"
	em:UnregisterForUpdate(updateName)

	if self.sv.enabled and self.sv.watch then
		em:RegisterForUpdate(updateName, WATCH_INTERVAL_MS, function()
			self:OnWatchTick()
		end)
		return
	end

end

----------------------------------------------------------------------------------------------
-- Getting unstuck
----------------------------------------------------------------------------------------------

-- An entry box that is open while the chat window is hidden is the unrecoverable state: the
-- input eater and the action layer are both live, and there is nothing on screen to dismiss.
-- Nothing here should produce it any more, but it costs almost nothing to notice and undo, and
-- the alternative for the player is closing the game.
--
-- Strikes rather than a single check, because the window is legitimately hidden for a moment
-- while it fades in.
local watchdogRunning = false

function addon:ForceCloseTextEntry()
	local chat = GetChatSystem()
	if chat and type(chat.CloseTextEntry) == "function" then
		-- Undoes the whole thing: loses focus, removes the GamepadChatSystem action layer and
		-- deactivates the directional input eater.
		chat:CloseTextEntry()
		return true
	end
	return false
end

function addon:StartStuckWatchdog()
	if watchdogRunning then
		return
	end
	watchdogRunning = true

	local strikes = 0

	local function Tick()
		if not IsTextEntryOpen() then
			watchdogRunning = false
			return
		end

		local chat = GetChatSystem()
		local hidden = chat and type(chat.IsHidden) == "function" and chat:IsHidden()

		if hidden then
			strikes = strikes + 1
			if strikes >= WATCHDOG_STRIKES then
				watchdogRunning = false
				if self:ForceCloseTextEntry() then
					Print("chat entry was open with nothing on screen -- closed it to give the controller back")
				end
				return
			end
		else
			strikes = 0
		end

		zo_callLater(Tick, WATCHDOG_INTERVAL_MS)
	end

	zo_callLater(Tick, WATCHDOG_INTERVAL_MS)
end

----------------------------------------------------------------------------------------------
-- Probe
----------------------------------------------------------------------------------------------

function addon:StopProbe()
	if not probeActive then
		return
	end

	probeActive = false
	probeControl = nil
	self:ApplyCatcher()

	local keyboardCount, gamepadCount = 0, 0
	for _, kind in pairs(probeSeen) do
		if kind == "gamepad" then
			gamepadCount = gamepadCount + 1
		else
			keyboardCount = keyboardCount + 1
		end
	end

	if keyboardCount == 0 and gamepadCount == 0 then
		Print("probe over: nothing arrived. This tier does not receive keys here.")
	else
		Print("probe over: %d keyboard, %d gamepad", keyboardCount, gamepadCount)
		if gamepadCount > 0 then
			-- Reaching the handler and being swallowed before the game sees it are not the same
			-- thing, but a controller that went dead during the probe settles it.
			Print("gamepad keys reach this tier -- likely why the controller stops responding")
		end
	end
	probeSeen = nil
end

function addon:StartProbe(mode)
	local control = GetCatcherControl(mode)
	if not control then
		Print("no such tier: %s (default, high, medium, low)", tostring(mode))
		return
	end

	probeActive = true
	probeSeen = {}
	probeControl = control
	self:ApplyCatcher()

	Print("probe on (%s tier) for %d s -- press Enter, then try the controller", mode, PROBE_SECONDS)
	-- Self-clearing, so a tier that turns out to swallow input cannot strand the session.
	zo_callLater(function()
		self:StopProbe()
	end, PROBE_SECONDS * 1000)
end

----------------------------------------------------------------------------------------------
-- Commands
----------------------------------------------------------------------------------------------

function addon:DescribeCaptureMode()
	local mode = self.sv.captureMode
	local resolved = ResolveCaptureMode(mode)
	if resolved == mode then
		return mode
	end
	return string.format("%s -> %s", mode, resolved)
end

-- The console's input screen is the platform's response to the chat edit control holding focus.
-- Nothing in Lua summons it and nothing reports why it did not come, so the two readable facts
-- either side of it are taken instead: whether the edit control actually has focus, and whether
-- the screen is up. Sampled twice, because the platform does not necessarily put it up in the
-- same frame as the focus.
function addon:ReportEntryState(label)
	local chat = GetChatSystem()
	local editControl = chat and chat.editControl
	local hasFocus = editControl and type(editControl.HasFocus) == "function" and editControl:HasFocus()
	local keyboardUp = type(IsVirtualKeyboardOnScreen) == "function" and IsVirtualKeyboardOnScreen()
	-- The suspected deciding factor: the platform may only put its input screen up when the
	-- player was last using the gamepad, on the reasoning that someone typing on a keyboard has
	-- no use for an on-screen one. Reported so the theory can be checked rather than argued.
	local lastInputGamepad = type(WasLastInputGamepad) == "function" and WasLastInputGamepad()

	Print("%s: entry open %s, edit focus %s, input screen %s, last input %s",
		label, tostring(IsTextEntryOpen()), tostring(hasFocus or false), tostring(keyboardUp or false),
		lastInputGamepad and "gamepad" or "keyboard")
end

-- The active action layers, outermost first.
--
-- Precedence is the first thing to suspect when a layer is up, its push reports working, and its
-- action still never fires: the chat system pushes GamepadChatSystem when the entry takes focus,
-- and a layer pushed after ours sits above it. Read-only throughout.
function addon:PrintLayers()
	if type(GetNumActiveActionLayers) ~= "function" then
		Print("no action layer API on this client")
		return
	end

	local count = GetNumActiveActionLayers()
	Print("%d active layer(s):", count)
	for i = 1, count do
		local layerIndex = GetActiveActionLayerIndex(i)
		local name = layerIndex and GetActionLayerNameByIndex(layerIndex)
		Print("  %d: %s", i, tostring(name))
	end
end

function addon:PrintStatus()
	Print("%s -- %s, capture %s, delay %d ms", VERSION, self.sv.enabled and "on" or "off",
		self:DescribeCaptureMode(), self.sv.delayMs)
	Print("chat available: %s", tostring(IsChatAvailable()))
	Print("gamepad UI: %s", tostring(IsInGamepadPreferredMode()))
	Print("binding route: %s", tostring(IsBindingRouteAvailable()))
	Print("text entry open: %s", tostring(IsTextEntryOpen()))
	Print("input type: %s, follow %s, trigger %s", IsGamepadInput() and "gamepad" or "keyboard",
		tostring(self.sv.followInput), tostring(self.sv.triggerOnKeyboard))
	Print("catcher shown: %s, keyboard active: %s", tostring(IsCatcherShown()), tostring(keyboardActive))
	if PBS_CHAT_ASSISTANT_HUD_CHANNEL then PBS_CHAT_ASSISTANT_HUD_CHANNEL:PrintStatus() end
	Print("watch %s, auto safe %s, edit focus %s, input screen %s", tostring(self.sv.watch),
		tostring(self.sv.autoSafe), tostring(HasEditFocus()), tostring(IsInputScreenUp()))
	Print("guild recruitment filter %s, whispers %s, hidden this session %d",
		self.sv.recruitFilterEnabled and "on" or "off",
		self.sv.recruitFilterWhispers and "on" or "off", self.hiddenRecruitment or 0)
	Print("NPC chat filter %s, hidden this session %d",
		self.sv.npcChatFilterEnabled and "on" or "off", self.hiddenNpcChat or 0)
end

-- Reports what the game thinks of the add-on's bindable actions.
--
-- Read-only, and that is not a limitation of this function but of add-ons. BindKeyToAction cannot
-- be called from here or from anywhere else in an add-on: the client refuses it as a PRIVATE
-- function, whatever ESOUIDocumentation.txt says, and the refusal names the add-on's own frames
-- as the untrusted part. Measured from a slash command whose traceback bottoms out in
-- ZO_GamepadTextChatTextEntryEditBox_Enter -- a real key press -- so the hardware event was
-- there and made no difference. Add-on Lua is insecure code by its nature; one frame of it taints
-- the callstack, and no calling context escapes that.
--
-- Three things can be wrong when a bound button does nothing, and they need telling apart before
-- anything is changed: the action was never registered (Bindings.xml did not take), it was
-- registered but nothing is bound to it (CreateDefaultActionBind did not take, and it is an
-- unproven call), or something is bound and the chord is not reaching it.
--
-- All read-only calls, so this is safe to run any time.
function addon:PrintBinds()
	if type(GetActionIndicesFromName) ~= "function" then
		Print("no binding API on this client")
		return
	end

	-- The chord action and the stock action it inherits from, side by side. Between them they say
	-- which of the three remaining possibilities is true: the action never registered, so
	-- Bindings.xml did not take; it registered with no bind, so the inheritance did not attach;
	-- or the source itself is unbound on this platform, in which case inheriting it was always
	-- going to inherit nothing.
	local actions = {
		"PBSCHATASSISTANT_HUD_CHANNEL_RIGHT",
		"UI_SHORTCUT_INPUT_RIGHT",
		"ASSIST_NEXT_TRACKED_QUEST",
		"PBSCHATASSISTANT_CHANNEL_NEXT",
		"PBSCHATASSISTANT_START_CHAT",
	}

	for _, actionName in ipairs(actions) do
		local shortName = actionName:gsub("^PBSCHATASSISTANT_", ""):gsub("^UI_SHORTCUT_", "UI:")
		local layerIndex, categoryIndex, actionIndex = GetActionIndicesFromName(actionName)

		if not layerIndex then
			-- Bindings.xml never registered it. Nothing else below can be true.
			Print("%s: NOT REGISTERED", shortName)
		else
			local bound = {}
			local maxBindings = type(GetMaxBindingsPerAction) == "function" and GetMaxBindingsPerAction() or 2
			for bindingIndex = 1, maxBindings do
				local key = GetActionBindingInfo(layerIndex, categoryIndex, actionIndex, bindingIndex)
				if key and key ~= 0 then
					bound[#bound + 1] = string.format("%d (%s)", key, tostring(GetKeyName(key)))
				end
			end

			if #bound == 0 then
				Print("%s: registered at %d/%d/%d, nothing bound", shortName, layerIndex, categoryIndex, actionIndex)
			else
				Print("%s: registered, bound to %s", shortName, table.concat(bound, ", "))
			end
		end
	end

	if KEY_GAMEPAD_BOTH_SHOULDERS then
		Print("L1+R1 is key %d (%s)", KEY_GAMEPAD_BOTH_SHOULDERS, tostring(GetKeyName(KEY_GAMEPAD_BOTH_SHOULDERS)))
	else
		Print("KEY_GAMEPAD_BOTH_SHOULDERS does not exist on this client")
	end
end

function addon:InitSlashCommand()
	SLASH_COMMANDS["/pbchat"] = function(args)
		args = zo_strtrim(args or "")
		local command, argument = args:match("^(%S+)%s*(.*)$")
		command = command and command:lower() or ""
		argument = argument and zo_strtrim(argument):lower() or ""

		if command == "on" or command == "off" then
			self.sv.enabled = (command == "on")
			-- The master switch has to reach everything that is running, the channel layer
			-- included; ApplyWatch takes that down when it stops the tick.
			self:ApplyCatcher()
			self:ApplyWatch()
			Print("%s", self.sv.enabled and "on" or "off")
		elseif command == "probe" then
			self:StartProbe(argument ~= "" and argument or "default")
		elseif command == "log" then
			self.sv.log = (argument ~= "off")
			Print("log %s", self.sv.log and "on" or "off")
		elseif command == "follow" then
			self.sv.followInput = (argument ~= "off")
			self:ApplyCatcher()
			Print("follow input %s", self.sv.followInput and "on" or "off")
		elseif command == "trigger" then
			self.sv.triggerOnKeyboard = (argument ~= "off")
			Print("trigger on keyboard switch %s", self.sv.triggerOnKeyboard and "on" or "off")
		elseif command == "delay" and tonumber(argument) then
			self.sv.delayMs = zo_clamp(zo_round(tonumber(argument)), MIN_DELAY_MS, MAX_DELAY_MS)
			Print("delay %d ms", self.sv.delayMs)
		elseif command == "trial" then
			-- The controller died at load with a catcher on, and the probe says the catcher is
			-- not receiving gamepad keys, so the cause is still unaccounted for. This turns a
			-- catcher on for real and takes it away again on its own, which is the only way to
			-- test that safely.
			local mode = argument ~= "" and argument or "default"
			if not CATCHER_CONTROL_NAMES[mode] then
				Print("trial default | high | medium | low")
			else
				local restore = self.sv.captureMode
				self.sv.captureMode = mode
				self:ApplyCatcher()
				Print("catcher on (%s) for %d s -- try the controller now", mode, TRIAL_SECONDS)
				zo_callLater(function()
					self.sv.captureMode = restore
					self:ApplyCatcher()
					Print("catcher off again (back to %s)", restore)
				end, TRIAL_SECONDS * 1000)
			end
		elseif command == "capture" then
			if argument == "auto" or argument == "off" or CATCHER_CONTROL_NAMES[argument] then
				self.sv.captureMode = argument
				self:ApplyCatcher()
				Print("capture %s", self:DescribeCaptureMode())
			else
				Print("capture auto | off | default | high | medium | low")
			end
		elseif command == "unstick" then
			if self:ForceCloseTextEntry() then
				Print("chat entry closed")
			else
				Print("no chat system to close")
			end
		elseif command == "enter" then
			-- One command instead of three, because setting this up by hand across several
			-- settings is how a test ends up measuring the wrong thing.
			--
			-- Catcher permanently up, no input-event gating. This is the configuration that
			-- catches every Enter, and the one that costs the gamepad buttons for as long as it
			-- is on. /pbchat safe puts it back.
			self.sv.captureMode = "default"
			self.sv.followInput = false
			self:ApplyCatcher()
			Print("Enter capture ON -- gamepad buttons pause until you chat, or %d s",
				ARM_TIMEOUT_SECONDS)

			armHandle = armHandle + 1
			local handle = armHandle
			zo_callLater(function()
				if handle ~= armHandle or self.sv.captureMode == "off" then
					return
				end
				self.sv.captureMode = "off"
				self:ApplyCatcher()
				Print("Enter capture expired -- gamepad buttons back")
			end, ARM_TIMEOUT_SECONDS * 1000)
		elseif command == "safe" then
			armHandle = armHandle + 1
			self.sv.captureMode = "off"
			self:ApplyCatcher()
			Print("Enter capture OFF (catcher %s) -- gamepad buttons back", tostring(IsCatcherShown()))
		elseif command == "forcelayer" then
			Print("force layer is disabled; hold L2 on the HUD to enable the D-pad Right channel shortcut")
		elseif command == "hudstatus" then
			if PBS_CHAT_ASSISTANT_HUD_CHANNEL then PBS_CHAT_ASSISTANT_HUD_CHANNEL:PrintStatus() end
		elseif command == "tabs" then
			if not self.chatTabs then
				Print("chat tabs not loaded")
			elseif argument == "off" or argument == "on" then
				self.sv.guildTabsEnabled = (argument == "on")
				if self.sv.guildTabsEnabled then
					self.chatTabs:Reconcile()
				else
					self.chatTabs:RemoveAll()
				end
				Print("guild tabs %s", self.sv.guildTabsEnabled and "on" or "off")
			elseif argument == "rebuild" then
				self.chatTabs:Reconcile()
				self.chatTabs:PrintStatus()
			elseif argument:match("^x%s") then
				self.sv.tabStripX = tonumber(argument:match("^x%s+(-?%d+)")) or self.sv.tabStripX
				self.chatTabs:PositionStrip()
				Print("tab strip x %d", self.sv.tabStripX)
			elseif argument:match("^y%s") then
				self.sv.tabStripY = tonumber(argument:match("^y%s+(-?%d+)")) or self.sv.tabStripY
				self.chatTabs:PositionStrip()
				Print("tab strip y %d", self.sv.tabStripY)
			elseif argument:match("^size%s") then
				local size = tonumber(argument:match("^size%s+(%d+)"))
				if size then
					self.sv.tabTextSize = zo_clamp(size, 14, 72)
					self.chatTabs:PositionStrip()
				end
				Print("tab text size %d", self.sv.tabTextSize)
			elseif tonumber(argument) then
				self.chatTabs:SelectTab(tonumber(argument), false)
			else
				self.chatTabs:PrintStatus()
			end
		elseif command == "drawtest" then
			if self.chatTabs then
				self.chatTabs:DrawTest(argument ~= "off")
			end
		elseif command == "recruit" then
			local whisperState = argument:match("^whisper%s+(on)$")
				or argument:match("^whisper%s+(off)$")
			if whisperState then
				self.sv.recruitFilterWhispers = whisperState == "on"
			elseif argument == "on" or argument == "off" then
				self.sv.recruitFilterEnabled = argument == "on"
			end
			Print("guild recruitment filter %s, whispers %s, hidden this session %d",
				self.sv.recruitFilterEnabled and "on" or "off",
				self.sv.recruitFilterWhispers and "on" or "off", self.hiddenRecruitment or 0)
		elseif command == "npc" then
			if argument == "on" or argument == "off" then
				self.sv.npcChatFilterEnabled = argument == "on"
			end
			Print("NPC chat filter %s, hidden this session %d",
				self.sv.npcChatFilterEnabled and "on" or "off", self.hiddenNpcChat or 0)
		elseif command == "guildinmain" then
			local slot, state = argument:match("^(%S*)%s*(%S*)$")
			local slotIndex = tonumber(slot)
			if not self.chatTabs then
				Print("chat tabs not loaded")
			elseif not slotIndex then
				Print("guildinmain <guild 1-5> on|off")
				for _, entry in ipairs(self.chatTabs:GuildSlots()) do
					Print("  %d %s: %s", entry.index, tostring(entry.name),
						self.chatTabs:IsGuildInMainTab(entry.guildId) and "on" or "off")
				end
			else
				local guildId = GetGuildId and GetGuildId(slotIndex)
				if not guildId then
					Print("no guild in slot %d", slotIndex)
				else
					self.chatTabs:SetGuildInMainTab(guildId, state ~= "off")
					Print("%s in the normal tab: %s", tostring(GetGuildName(guildId)),
						state ~= "off" and "on" or "off")
				end
			end
		elseif command == "layers" then
			self:PrintLayers()
		elseif command == "binds" then
			self:PrintBinds()
		elseif command == "hudchannel" or command == "entrychannel" then
			self.sv.hudChannelEnabled = (argument ~= "off")
			if PBS_CHAT_ASSISTANT_HUD_CHANNEL then PBS_CHAT_ASSISTANT_HUD_CHANNEL:Update() end
			Print("HUD L2+D-pad Right tab switching %s", self.sv.hudChannelEnabled and "on" or "off")
		elseif command == "channel" then
			self.sv.channelKeys = (argument ~= "off")
			Print("channel keys %s", self.sv.channelKeys and "on" or "off")
		elseif command == "autosafe" then
			self.sv.autoSafe = (argument ~= "off")
			Print("auto safe %s", self.sv.autoSafe and "on" or "off")
		elseif command == "watch" then
			self.sv.watch = (argument ~= "off")
			self:ApplyWatch()
			Print("focus watcher %s", self.sv.watch and "on" or "off")
		elseif command == "open" then
			-- The one route confirmed to work end to end, kept as a plain command: wait, then
			-- open. No key catching, no input events, nothing that has to fire first.
			--
			-- The wait is the mechanism. Opening the box in the same frame as the Enter that
			-- submitted this command gives the platform no lost-and-regained focus to react to,
			-- and the input screen stays down. Five seconds is simply comfortable; delayMs alone
			-- has also been enough.
			local seconds = zo_clamp(zo_round(tonumber(argument) or 5), 1, 30)
			Print("opening in %d s", seconds)
			zo_callLater(function()
				local opened = self:StartChat()
				self:Log("open command: %s", tostring(opened or false))
			end, seconds * 1000)
		elseif command == "test" and tonumber(argument) then
			-- Deferred open, so the gamepad can be made the last input device before it runs.
			-- If the input screen appears this way and not from an immediate test, the platform
			-- is gating it on the input device and a keyboard key can never be the trigger.
			--
			-- Deferring is safe now in a way it never was before: nothing on the open path is
			-- private any more, so losing the hardware-event trace costs nothing.
			local seconds = zo_clamp(zo_round(tonumber(argument)), 1, 30)
			Print("opening in %d s", seconds)
			zo_callLater(function()
				-- Sampled before the open, because that is the moment the platform makes its
				-- decision, and because once the input screen is up it covers the chat log.
				self:ReportEntryState("before")
				Print("opened: %s", tostring(self:StartChat() or false))
				self:ReportEntryState("now")
				zo_callLater(function()
					self:ReportEntryState("after 1s")
				end, 1000)
			end, seconds * 1000)
		elseif command == "test" then
			-- Tests the open on its own, with no key catching involved. Nothing on this path is
			-- private or protected, so where it runs from no longer matters -- which is what
			-- makes the two unknowns separable: this one answers "does the box open and does the
			-- console put its input screen up", and probe answers "can a key reach us safely".
			Print("opened: %s", tostring(self:StartChat() or false))
			self:ReportEntryState("now")
			-- Second sample, in case the platform is a beat behind the focus.
			zo_callLater(function()
				self:ReportEntryState("after 1s")
			end, 1000)
		else
			self:PrintStatus()
		end
	end
end

local function OnAddOnLoaded(_, name)
	if name ~= addon.name then
		return
	end
	em:UnregisterForEvent(addon.name, EVENT_ADD_ON_LOADED)

	-- The saved-variables version is not the release version. It counts settings changes, and it
	-- climbed through pre-release testing as settings were added and dropped.
	--
	-- Moved to 12 for 1.0.1 on purpose, discarding stored settings. 1.0.0 shipped captureMode
	-- "default", which left the Options button dead on a fresh install, and a stored "default"
	-- would have survived the fix and kept doing it. Losing a tuned delay is the cheaper mistake.
	addon.sv = ZO_SavedVars:NewAccountWide("PBsChatAssistant_Data", 12, nil, DEFAULTS)
	-- Log off, once.
	--
	-- It shipped ON for a stretch while the add-on was being built, when the only way to tell
	-- "the event did not fire" from "it fired and the open declined" was to print everything.
	-- That value is still sitting in the saved settings of anyone who ran those builds, spraying
	-- refocus lines into chat on every Enter.
	--
	-- Cleared here rather than by moving the saved-variables version, which would have taken the
	-- tuned wait and everything else with it. The marker makes it a one-time correction: turn the
	-- log back on afterwards and it stays on.
	if not addon.sv.logResetDone then
		addon.sv.logResetDone = true
		addon.sv.log = false
	end

	if addon.InstallRecruitmentFilter then
		addon:InstallRecruitmentFilter()
	end
	addon:InitSlashCommand()
	addon:ApplyCatcher()
	addon:ApplyWatch()

	-- The version rides in the title, because that is what the settings panel lists add-ons by:
	-- settings.version below only fills a field inside the panel, which is no help when the
	-- question is which build is installed and the menu is all that is on screen.
	addon.title = string.format("%s %s", DISPLAY_NAME, VERSION)
	addon.author = AUTHOR
	addon.version = VERSION

	-- LibHarvens setting labels are fixed when their rows are created. Wait until the player is
	-- active so the guild list and real guild names are available, as ChatFilter does.
	local SETTINGS_EVENT = addon.name .. "Settings"
	em:RegisterForEvent(SETTINGS_EVENT, EVENT_PLAYER_ACTIVATED, function()
		em:UnregisterForEvent(SETTINGS_EVENT, EVENT_PLAYER_ACTIVATED)
		if not addon.settingsPanelBuilt then
			addon.settingsPanelBuilt = true
			if addon.InitSettings then
				addon:InitSettings()
			end
		end
	end)

	-- Auto reads the binding route, which on PC depends on which UI is in front. Console never
	-- fires this.
	em:RegisterForEvent(addon.name, EVENT_GAMEPAD_PREFERRED_MODE_CHANGED, function()
		addon:ApplyCatcher()
	end)

	-- THE ROUTE.
	--
	-- Not the key catcher. A catcher does receive the keyboard's Enter, but every tier tried on
	-- PS5 kills the gamepad buttons for as long as one is shown. It stays in the add-on behind
	-- /pbchat capture, for probing and for any platform where it is harmless, and ships off.
	--
	-- Two routes, each covering what the other cannot.
	--
	-- The event fires on PS5 -- confirmed, with nothing shown at all, a keyboard key after
	-- controller use opened the box and brought the input screen up. Its limit is in the name: it
	-- reports a CHANGE, so the second key press in a row fires nothing, which is exactly why an
	-- event-only build worked once and then went quiet.
	--
	-- The catcher has the opposite shape. It sees every key press, and it takes the gamepad
	-- buttons for as long as it is shown.
	--
	-- So the event decides when the catcher is up. Touch the keyboard: the switch opens the box
	-- and raises the catcher, which then handles every key after it. Touch the controller: the
	-- switch puts the catcher away and the buttons come back. Stop typing for idleSeconds and it
	-- comes down on its own, in case no controller event ever arrives.
	--
	-- The cost is that the buttons are dead while the player is at the keyboard, and that the
	-- first key of a session opens the box whatever key it was. /pbchat follow off and
	-- /pbchat trigger off turn those two off separately.
	-- The login channel, applied exactly once.
	--
	-- EVENT_PLAYER_ACTIVATED fires after every loading screen. The handler unregisters itself on
	-- the first event after this add-on loads, so zone changes cannot reapply the default. Do not
	-- gate on the event's initial flag: /reloadui and add-on reloads can report false even though
	-- this is the first activation this loaded copy sees, and the requested startup tab must still
	-- be selected then.
	--
	-- Its own namespace, so unregistering it cannot take any other PLAYER_ACTIVATED handler with it.
	local DEFAULT_CHANNEL_EVENT = addon.name .. "DefaultChannel"
	em:RegisterForEvent(DEFAULT_CHANNEL_EVENT, EVENT_PLAYER_ACTIVATED, function(_, initial)
		em:UnregisterForEvent(DEFAULT_CHANNEL_EVENT, EVENT_PLAYER_ACTIVATED)
		addon:Log("player activated, initial %s", tostring(initial))
		local attempts = 0
		local function ApplyInitialDefault()
			attempts = attempts + 1
			if addon:ApplyDefaultChannel() or attempts >= DEFAULT_CHANNEL_MAX_ATTEMPTS then
				return
			end
			zo_callLater(ApplyInitialDefault, DEFAULT_CHANNEL_RETRY_MS)
		end
		zo_callLater(ApplyInitialDefault, DEFAULT_CHANNEL_DELAY_MS)
	end)

	-- Guild membership decides the tabs, and it is not known the instant the world appears.
	-- All three of these schedule the same debounced pass.
	local function ScheduleTabs()
		if addon.chatTabs then
			addon.chatTabs:ScheduleReconcile()
			-- Also drawn straight away: a reconcile can decline to do anything, and the strip
			-- should still be on screen when it does.
			addon.chatTabs:RefreshStrip()
		end
	end
	em:RegisterForEvent(addon.name .. "Tabs", EVENT_PLAYER_ACTIVATED, ScheduleTabs)
	if EVENT_GUILD_DATA_LOADED then
		em:RegisterForEvent(addon.name .. "Tabs", EVENT_GUILD_DATA_LOADED, ScheduleTabs)
	end
	if EVENT_GUILD_SELF_JOINED_GUILD then
		em:RegisterForEvent(addon.name .. "TabsJoin", EVENT_GUILD_SELF_JOINED_GUILD, ScheduleTabs)
	end
	if EVENT_GUILD_SELF_LEFT_GUILD then
		em:RegisterForEvent(addon.name .. "TabsLeave", EVENT_GUILD_SELF_LEFT_GUILD, ScheduleTabs)
	end

	em:RegisterForEvent(addon.name, EVENT_INPUT_TYPE_CHANGED, function(_, isGamepad)
		-- Deliberately not logged. This fires on every switch between the keyboard and the
		-- controller, which is constantly, and with followInput and triggerOnKeyboard both off by
		-- default the handler has nothing else to say. It was noise in the chat window and it
		-- drowned the lines that were worth reading.

		if isGamepad then
			keyboardActive = false
			idleHandle = idleHandle + 1
			addon:ApplyCatcher()
			return
		end

		-- The key that caused this switch is already spent; there was no catcher up to see it.
		-- So the switch itself opens the box, and the catcher goes up to take every key after it
		-- directly -- which is what the event alone could never do, firing only on a change.
		addon:TouchKeyboardActivity()

		if addon.sv.triggerOnKeyboard then
			addon:StartChat()
		end
	end)

	-- No default binds, and no way to make any. CreateDefaultActionBind does nothing from an
	-- add-on, tried from here and from file scope straight after Bindings.xml. BindKeyToAction is
	-- refused outright: the client calls it PRIVATE, whatever the documentation's "protected"
	-- says, and names the add-on's own frames as what made the callstack untrusted -- measured
	-- from a slash command whose traceback bottoms out in a real key press, so the hardware event
	-- was there and changed nothing.
	--
	-- The actions register fine, 1/7/1..3 on PS5, and on this platform there is no keybinding
	-- screen to reach them from either. They are kept for PC, and for a console update that adds
	-- one.
end

em:RegisterForEvent(addon.name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)

PBS_CHAT_ASSISTANT = addon
