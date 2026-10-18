-- PB's ScreenshotModeShortcut — PinkBanther
-- Hold L2, then press D-pad Left on the gamepad HUD.
-- L2 remains owned by the game. Read its analog value or the standard block
-- state; activation does not wait for a Left Up event.
--
-- Left is the D-pad only. The bind inherited from UI_SHORTCUT_INPUT_LEFT also arrives when
-- the left analog stick is pushed left, because the stick emulates the same directional
-- input, and there is no key code in the handler to tell the two apart. What can be read is
-- the stick itself: GetGamepadLeftStickX is public, a resting stick reads zero once its
-- deadzone is applied, and a D-pad press does not move it. So a Left that arrives while the
-- stick is deflected left is somebody walking, and is handed straight back to the game.

if PBS_SCREENSHOT_MODE_SHORTCUT then
	return
end

local addon = {
	name = "PBsScreenshotModeShortcut",
}

local em = EVENT_MANAGER

-- TYPOGRAPHIC apostrophe (U+2019): with an ASCII ' the settings library eats "PB's ". The
-- manifest keeps the ASCII form, because that is what the in-game add-on list wants.
local DISPLAY_NAME = "PB’s ScreenshotModeShortcut"
local AUTHOR = "PinkBanther"
local SLASH = "/pbshot"
local SHORT_SLASH = "/pbss"

local TRIGGER_LAYER = "PBsScreenshotModeShortcutTriggerLayer"
local SCREENSHOT_SCENE = "gamepadScreenshotMode"
local HUD_SCENE = "hud"

local LEFT_TRIGGER_THRESHOLD = 0.5
-- Below the point where the stick emulates a direction, and far above a worn stick's rest
-- position: the reading already has the deadzone taken out of it.
local LEFT_STICK_THRESHOLD = 0.35
local MAX_HOLD_S = 5
local WATCHDOG_MS = 100
local DEFERRED_FIRE = addon.name .. "DeferredFire"

local MODES = { "auto", "scene", "gui" }

local DEFAULTS = {
	enabled = true,
	mode = "auto",
	announce = true,
}

-- ---------------------------------------------------------------------------------------
-- Identity and output
-- ---------------------------------------------------------------------------------------

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
addon.shortSlash = SHORT_SLASH

local function Say(text)
	if CHAT_ROUTER and CHAT_ROUTER.AddSystemMessage then
		CHAT_ROUTER:AddSystemMessage(text)
	elseif CHAT_SYSTEM and CHAT_SYSTEM.AddMessage then
		CHAT_SYSTEM:AddMessage(text)
	else
		d(text)
	end
end

local function Text(stringId, ...)
	local value = GetString(stringId)
	if select("#", ...) > 0 then
		local ok, formatted = pcall(string.format, value, ...)
		if ok then
			return formatted
		end
	end
	return value
end

function addon:Line(stringId, ...)
	Say("|cFF69B4" .. DISPLAY_NAME .. "|r: " .. Text(stringId, ...))
end

function addon:Raw(text)
	Say("|cFF69B4" .. DISPLAY_NAME .. "|r: " .. tostring(text))
end

-- ---------------------------------------------------------------------------------------
-- Settings
-- ---------------------------------------------------------------------------------------

function addon:Enabled()
	return self.sv == nil or self.sv.enabled ~= false
end

function addon:Mode()
	local mode = self.sv and self.sv.mode
	for _, known in ipairs(MODES) do
		if mode == known then
			return mode
		end
	end
	return DEFAULTS.mode
end

-- ---------------------------------------------------------------------------------------
-- The HUD input layer
-- ---------------------------------------------------------------------------------------

function addon:EnsureFragments()
	if self.fragmentsBuilt then return true end
	if not (SCENE_MANAGER and ZO_ActionLayerFragment) then
		self.error = "no scene manager"
		return false
	end
	self.hudScene = SCENE_MANAGER:GetScene(HUD_SCENE)
	self.screenshotScene = SCENE_MANAGER:GetScene(SCREENSHOT_SCENE)
	if not self.hudScene then
		self.error = "no hud scene"
		return false
	end
	self.triggerFragment = ZO_ActionLayerFragment:New(TRIGGER_LAYER)
	self.triggerFragment:RegisterCallback("StateChange", function(_, state)
		if state == SCENE_FRAGMENT_HIDDEN then
			self:CancelPress()
		end
	end)
	self.fragmentsBuilt = true
	return true
end

function addon:SetInputLayer(wanted)
	wanted = wanted and true or false
	if self.triggerLayerAdded == wanted or not self.triggerFragment then return end
	self.triggerLayerAdded = wanted
	local ok, err = pcall(function()
		if wanted then
			self.hudScene:AddFragment(self.triggerFragment)
			-- Shared with screenshot mode so a late Left Up remains consumed.
			if self.screenshotScene then self.screenshotScene:AddFragment(self.triggerFragment) end
		else
			self.hudScene:RemoveFragment(self.triggerFragment)
			if self.screenshotScene then self.screenshotScene:RemoveFragment(self.triggerFragment) end
		end
	end)
	if not ok then
		self.error = "input layer: " .. tostring(err)
		if wanted then
			self.triggerLayerAdded = false
			pcall(function() self.hudScene:RemoveFragment(self.triggerFragment) end)
			if self.screenshotScene then
				pcall(function() self.screenshotScene:RemoveFragment(self.triggerFragment) end)
			end
		end
	end
end

-- ---------------------------------------------------------------------------------------
-- The chord
-- ---------------------------------------------------------------------------------------

function addon:OnHud()
	return SCENE_MANAGER ~= nil
		and SCENE_MANAGER:IsShowing(HUD_SCENE)
		and SCENE_MANAGER:GetHUDSceneName() == HUD_SCENE
end

-- Whether a press should be listened to at all. Deliberately re-asked on every event rather
-- than latched: a queued Down that arrives after a menu opened must do nothing.
function addon:InCombat()
	return IsUnitInCombat and IsUnitInCombat("player") or false
end

function addon:Ready()
	if not self:Enabled() or self.error or self:InCombat() then
		return false
	end
	if IsInGamepadPreferredMode and not IsInGamepadPreferredMode() then
		return false
	end
	return self:OnHud()
end

function addon:CancelPress()
	self.leftDown = false
	self.consumedTrigger = false
	self.pressDownAtS = nil
	self.pressExpired = false
	self.pendingFire = false
	em:UnregisterForUpdate(DEFERRED_FIRE)
end

function addon:StartWatchdog()
	if self.watching then return end
	self.watching = true
	em:RegisterForUpdate(addon.name, WATCHDOG_MS, function() self:OnWatchTick() end)
end

function addon:StopWatchdog()
	if not self.watching then return end
	self.watching = false
	em:UnregisterForUpdate(addon.name)
end

function addon:OnWatchTick()
	if not self:OnHud() and not self:InScreenshotMode() then
		self:CancelPress()
	end
	local timeS = GetGameTimeSeconds()
	if self.pressDownAtS and timeS - self.pressDownAtS > MAX_HOLD_S then
		self:CancelPress()
	end
	if self.guiHidden and not self:OnHud() then self:RestoreGui() end
	if not self.pressDownAtS and not self.guiHidden then self:StopWatchdog() end
end

function addon:IsL2Held()
	local analogHeld = false
	if GetGamepadLeftTriggerMagnitude then
		local ok, magnitude = pcall(GetGamepadLeftTriggerMagnitude)
		self.lastAnalog = ok and tostring(magnitude) or ("error: " .. tostring(magnitude))
		analogHeld = ok and type(magnitude) == "number" and magnitude >= LEFT_TRIGGER_THRESHOLD
	else
		self.lastAnalog = "unavailable"
	end
	-- Standard gamepad controls map L2 to block. This read-only fallback does
	-- not intercept, start or stop block, even when the analog API is unavailable.
	local blocking = false
	if IsBlockActive then
		local ok, value = pcall(IsBlockActive)
		blocking = ok and value == true
	end
	self.lastBlocking = blocking
	self.lastModifierSource = analogHeld and "analog" or (blocking and "block" or "none")
	return analogHeld or blocking
end

-- True when the left analog stick is pushed left far enough to be what produced this Left.
-- Read-only, and never fatal: an unreadable stick is treated as centred, which leaves the
-- chord working exactly as it did before this check existed.
function addon:IsLeftStickLeft()
	if not GetGamepadLeftStickX then
		self.lastStickX = "unavailable"
		return false
	end
	local includeDeadzone = GAMEPAD_INCLUDE_DEADZONE
	if includeDeadzone == nil then
		includeDeadzone = true
	end
	local ok, x = pcall(GetGamepadLeftStickX, includeDeadzone)
	if not ok or type(x) ~= "number" or x ~= x then
		self.lastStickX = "error: " .. tostring(x)
		return false
	end
	self.lastStickX = string.format("%.2f", x)
	return x <= -LEFT_STICK_THRESHOLD
end

function addon:OnTriggerDown()
	if self:InCombat() then self:Stop(); return false end
	self.triggerDowns = (self.triggerDowns or 0) + 1
	if self.leftDown then return self.consumedTrigger end
	if not self:Ready() then self.lastInput = "left: not ready"; return false end
	-- The stick's own left, not the D-pad's. Not consumed: it is the game's input.
	if self:IsLeftStickLeft() then
		self.stickRejections = (self.stickRejections or 0) + 1
		self.lastInput = "left: analog stick, ignored"
		return false
	end
	self.leftDown = true
	self.consumedTrigger = self:IsL2Held()
	self.lastInput = self.consumedTrigger and "chord queued" or "left: L2 not detected"
	self.pressDownAtS = GetGameTimeSeconds()
	self:StartWatchdog()
	if self.consumedTrigger then
		self.pendingFire = true
		-- Consume Down before changing scenes; do not depend on an Up callback.
		em:RegisterForUpdate(DEFERRED_FIRE, 1, function()
			em:UnregisterForUpdate(DEFERRED_FIRE)
			local pending = self.pendingFire
			self.pendingFire = false
			if pending and self:Ready() then
				self.fireAttempts = (self.fireAttempts or 0) + 1
				local ok, why = self:Fire(true)
				self.lastInput = (ok and "fire: " or "failed: ") .. tostring(why)
			else
				self.lastInput = "fire cancelled: not ready"
			end
		end)
	end
	return self.consumedTrigger
end

function addon:OnTriggerUp()
	if self:InCombat() then self:Stop(); return false end
	self.triggerUps = (self.triggerUps or 0) + 1
	local consumed = self.consumedTrigger == true
	-- Up can arrive before or after the deferred transition; neither cancels it.
	self.leftDown = false
	self.consumedTrigger = false
	self.pressDownAtS = nil
	return consumed
end

-- ---------------------------------------------------------------------------------------
-- Getting in
-- ---------------------------------------------------------------------------------------

function addon:InScreenshotMode()
	return SCENE_MANAGER ~= nil and SCENE_MANAGER.GetHUDSceneName ~= nil
		and SCENE_MANAGER:GetHUDSceneName() == SCREENSHOT_SCENE
end

-- Called by the native sheathe binding (D-pad Left hold on standard gamepad
-- controls) inside ScreenshotMode. Only sheathe; never draw an already stowed weapon.
function addon:OnScreenshotSheathe()
	if not self:Enabled() or self:InCombat() or not self:InScreenshotMode()
		or not SCENE_MANAGER:IsShowing(SCREENSHOT_SCENE)
		or (IsInGamepadPreferredMode and not IsInGamepadPreferredMode()) then
		return false
	end
	-- The sheathe bind is D-pad Left held, and the stick emulates it the same way the
	-- shortcut's Left is emulated. Walking left in screenshot mode must not stow a weapon.
	if self:IsLeftStickLeft() then
		self.lastInput = "sheathe: analog stick, ignored"
		return false
	end
	self.sheatheAttempts = (self.sheatheAttempts or 0) + 1
	if not (ArePlayerWeaponsSheathed and TogglePlayerWield) then
		self.lastInput = "sheathe: API unavailable"
		return true
	end
	local ok, sheathed = pcall(ArePlayerWeaponsSheathed)
	if not ok or type(sheathed) ~= "boolean" then
		self.lastInput = "sheathe: cannot read weapon state"
		return true
	end
	if sheathed then
		self.lastInput = "sheathe: already sheathed"
		return true
	end
	if IsBlockActive then
		local blockOk, blocking = pcall(IsBlockActive)
		if blockOk and blocking then
			self.lastInput = "sheathe: release L2 first"
			return true
		end
	end
	local toggleOk, err = pcall(TogglePlayerWield)
	self.lastInput = toggleOk and "sheathe: requested" or ("sheathe failed: " .. tostring(err))
	return true
end

-- The real thing. Returns false plus a reason rather than throwing, because every caller of
-- this has a second way to take the picture.
function addon:EnterClientScreenshotMode()
	local mode = SCREENSHOT_MODE_GAMEPAD
	if type(mode) ~= "table" then
		return false, "no SCREENSHOT_MODE_GAMEPAD"
	end
	if not (SCENE_MANAGER and SCENE_MANAGER.SetHUDScene and SCENE_MANAGER.GetScene) then
		return false, "no SetHUDScene"
	end
	if not self:OnHud() then
		return false, "not on the hud"
	end
	local scene = SCENE_MANAGER:GetScene(SCREENSHOT_SCENE)
	if not scene then
		return false, "no " .. SCREENSHOT_SCENE .. " scene"
	end

	-- Let the standard scene own its countdown and nameplate save/restore.
	-- Never remove callbacks or write the client's private state.
	local ok, err = pcall(function() SCENE_MANAGER:SetHUDScene(SCREENSHOT_SCENE) end)

	if not ok then
		-- SetHUDScene writes the new name before it shows anything, so a throw halfway leaves
		-- the manager pointing at a scene that is not up. Put it back by hand.
		pcall(function()
			if SCENE_MANAGER:GetHUDSceneName() == SCREENSHOT_SCENE then
				SCENE_MANAGER:RestoreHUDScene()
			end
		end)
		return false, tostring(err)
	end
	if not self:InScreenshotMode() or not SCENE_MANAGER:IsShowing(SCREENSHOT_SCENE) then
		return false, "the scene did not take"
	end
	return true
end

-- The fallback: no scene, no client code, one public call.
function addon:HideGui()
	if not SetGuiHidden then
		return false, "no SetGuiHidden"
	end
	local ok, err = pcall(SetGuiHidden, "ingame", true)
	if not ok then
		return false, tostring(err)
	end
	self.guiHidden = true
	self:StartWatchdog()
	return true
end

function addon:RestoreGui()
	if not self.guiHidden then
		return
	end
	self.guiHidden = false
	if SetGuiHidden then
		pcall(SetGuiHidden, "ingame", false)
	end
end

-- What the chord does. Also what /pbshot now does, so the whole path can be exercised without
-- a controller in the way.
function addon:Fire(preservePress)
	if not preservePress then self:CancelPress() end

	if self.guiHidden then
		self:RestoreGui()
		return true, "gui-off"
	end
	if self:InScreenshotMode() then
		return true, "already in"
	end

	if not self:Ready() then
		return false, "not on an enabled gamepad HUD"
	end
	self.lastError = nil
	local mode = self:Mode()
	if mode ~= "gui" then
		local ok, err = self:EnterClientScreenshotMode()
		if ok then
			self.entries = (self.entries or 0) + 1
			return true, "scene"
		end
		self.lastError = err
		if mode == "scene" then
			self:Line(SI_PBSSMS_SCENE_FAILED, tostring(err))
			return false, err
		end
	end

	if not self:OnHud() then
		return false, self.lastError or "HUD transition incomplete"
	end
	local ok, err = self:HideGui()
	if not ok then
		self.lastError = err
		self:Line(SI_PBSSMS_BOTH_FAILED, tostring(err))
		return false, err
	end
	self.entries = (self.entries or 0) + 1
	if mode == "auto" and self.lastError and self.sv and self.sv.announce and not self.announcedFallback then
		self.announcedFallback = true
		self:Line(SI_PBSSMS_FELL_BACK, tostring(self.lastError))
	end
	return true, "gui"
end

-- ---------------------------------------------------------------------------------------
-- Running
-- ---------------------------------------------------------------------------------------

function addon:Start()
	if self:InCombat() then self:Stop(); return end
	if not self:Enabled() then
		return
	end
	if not self:EnsureFragments() then
		return
	end
	self.error = nil
	self:SetInputLayer(not IsInGamepadPreferredMode or IsInGamepadPreferredMode())
end

function addon:Stop()
	self:CancelPress()
	self:SetInputLayer(false)
	self:RestoreGui()
	self:StopWatchdog()
end

function addon:Restart()
	self:Stop()
	self:Start()
end

-- ---------------------------------------------------------------------------------------
-- Diagnostics
--
-- Everything in here exists so that a question about this add-on costs one look at the chat
-- window rather than one PS5 session.
-- ---------------------------------------------------------------------------------------

local KEY_NAMES = {
	"KEY_GAMEPAD_DPAD_LEFT", "KEY_GAMEPAD_DPAD_RIGHT", "KEY_GAMEPAD_DPAD_UP", "KEY_GAMEPAD_DPAD_DOWN",
	"KEY_GAMEPAD_BUTTON_1", "KEY_GAMEPAD_BUTTON_2", "KEY_GAMEPAD_BUTTON_3", "KEY_GAMEPAD_BUTTON_4",
	"KEY_GAMEPAD_LEFT_SHOULDER", "KEY_GAMEPAD_RIGHT_SHOULDER",
	"KEY_GAMEPAD_LEFT_TRIGGER", "KEY_GAMEPAD_RIGHT_TRIGGER",
	"KEY_GAMEPAD_LEFT_STICK", "KEY_GAMEPAD_RIGHT_STICK",
	"KEY_GAMEPAD_START", "KEY_GAMEPAD_BACK", "KEY_GAMEPAD_TOUCHPAD_PRESSED",
}

-- Indexed one name at a time, never iterated: pairs() over _G raises a private-function error
-- on console.
local function KeyName(keyCode)
	if not keyCode or keyCode == 0 then
		return "unbound"
	end
	for _, name in ipairs(KEY_NAMES) do
		if _G[name] == keyCode then
			return name:gsub("^KEY_GAMEPAD_", "")
		end
	end
	return "key " .. tostring(keyCode)
end

local WATCHED_ACTIONS = {
	"PBSSCREENSHOTMODE_SHEATHE",
	"SHEATHE_WEAPON_TOGGLE",
	"PBSSCREENSHOTMODE_TRIGGER",
	"UI_SHORTCUT_INPUT_LEFT",
}

function addon:PrintBinds()
	if not (GetActionIndicesFromName and GetActionBindingInfo) then
		self:Raw("no binding API")
		return
	end
	for _, action in ipairs(WATCHED_ACTIONS) do
		local layerIndex, categoryIndex, actionIndex = GetActionIndicesFromName(action)
		if not layerIndex then
			self:Raw(action .. ": not registered")
		else
			local keys = {}
			for bindingIndex = 1, 2 do
				local keyCode = GetActionBindingInfo(layerIndex, categoryIndex, actionIndex, bindingIndex)
				if keyCode and keyCode ~= 0 then
					keys[#keys + 1] = KeyName(keyCode)
				end
			end
			self:Raw(string.format("%s: %d/%d/%d %s", action, layerIndex, categoryIndex, actionIndex,
				#keys > 0 and table.concat(keys, " + ") or "unbound"))
		end
	end
end

function addon:PrintStatus()
	local activeTrigger = IsActionLayerActiveByName and IsActionLayerActiveByName(TRIGGER_LAYER)
	self:Raw(string.format("%s | on=%s mode=%s hud=%s L2=%s",
		addon.version ~= "" and ("v" .. addon.version) or "v?",
		tostring(self:Enabled()), self:Mode(), tostring(self:OnHud()), tostring(self:IsL2Held())))
	self:Raw(string.format("left layer: attached=%s active=%s | presses D/U=%d/%d entries=%d",
		tostring(self.triggerLayerAdded == true), tostring(activeTrigger),
		self.triggerDowns or 0, self.triggerUps or 0, self.entries or 0))
	self:IsLeftStickLeft()
	self:Raw(string.format("analog=%s block=%s modifier=%s stickX=%s stick ignored=%d",
		tostring(self.lastAnalog), tostring(self.lastBlocking), tostring(self.lastModifierSource),
		tostring(self.lastStickX), self.stickRejections or 0))
	self:Raw(string.format("attempts=%d input=%s",
		self.fireAttempts or 0, tostring(self.lastInput or "none")))
	self:Raw(string.format("state: hudScene=%s guiHidden=%s error=%s last=%s",
		tostring(SCENE_MANAGER and SCENE_MANAGER:GetHUDSceneName()), tostring(self.guiHidden == true),
		tostring(self.error or "none"), tostring(self.lastError or "none")))
end

-- ---------------------------------------------------------------------------------------
-- Slash command
-- ---------------------------------------------------------------------------------------

local function OnOrOff(argument)
	if argument == "on" then return true end
	if argument == "off" then return false end
	return nil
end

function addon:Command(argumentString)
	local words = {}
	for word in tostring(argumentString or ""):gmatch("%S+") do
		words[#words + 1] = word:lower()
	end
	local command, argument = words[1], words[2]

	if command == nil or command == "status" then
		self:PrintStatus()
		return
	end

	if command == "on" or command == "off" then
		self.sv.enabled = command == "on"
		self:Restart()
		self:Line(self.sv.enabled and SI_PBSSMS_TURNED_ON or SI_PBSSMS_TURNED_OFF)
		return
	end

	if command == "mode" then
		for _, known in ipairs(MODES) do
			if argument == known then
				self.sv.mode = known
				self.announcedFallback = false
				self:Line(SI_PBSSMS_MODE_SET, known)
				return
			end
		end
		self:Line(SI_PBSSMS_ERROR_MODE)
		return
	end

	if command == "now" or command == "test" then
		local ok, why = self:Fire()
		self:Raw((ok and "entered: " or "failed: ") .. tostring(why))
		return
	end

	if command == "binds" then
		self:PrintBinds()
		return
	end

	if command == "reset" then
		for key, value in pairs(DEFAULTS) do
			self.sv[key] = value
		end
		self.announcedFallback = false
		self:Restart()
		self:Line(SI_PBSSMS_RESET)
		return
	end

	if command == "help" then
		self:Line(SI_PBSSMS_HELP_HEADER)
		self:Raw(Text(SI_PBSSMS_HELP_STATUS))
		self:Raw(Text(SI_PBSSMS_HELP_NOW))
		self:Raw(Text(SI_PBSSMS_HELP_MODE))
		self:Raw(Text(SI_PBSSMS_HELP_BINDS))
		self:Raw(Text(SI_PBSSMS_HELP_MASTER))
		self:Raw(Text(SI_PBSSMS_HELP_RESET))
		return
	end

	self:Line(SI_PBSSMS_ERROR_UNKNOWN, tostring(command))
end

function addon:InitSlashCommand()
	local function handler(argumentString)
		self:Command(argumentString)
	end
	SLASH_COMMANDS[SLASH] = handler
	SLASH_COMMANDS[SHORT_SLASH] = handler
end

-- ---------------------------------------------------------------------------------------
-- Load
-- ---------------------------------------------------------------------------------------

local function OnPlayerActivated()
	-- Not at EVENT_ADD_ON_LOADED: the scenes and the keybind machinery are not up yet, and a
	-- line put in chat there is thrown away.
	addon:Start()
end

local function OnPlayerDeactivated()
	-- A loading screen with the interface hidden is how somebody ends up rebooting a PS5.
	addon:Stop()
end

local function OnAddOnLoaded(_, name)
	if name ~= addon.name then
		return
	end
	em:UnregisterForEvent(addon.name, EVENT_ADD_ON_LOADED)

	addon.sv = ZO_SavedVars:NewAccountWide("PBsScreenshotModeShortcut_Data", 1, nil, DEFAULTS)
	addon:InitSlashCommand()

	em:RegisterForEvent(addon.name, EVENT_PLAYER_COMBAT_STATE, function(_, inCombat)
		if inCombat then addon:Stop() else addon:Start() end
	end)
	em:RegisterForEvent(addon.name, EVENT_PLAYER_ACTIVATED, OnPlayerActivated)
	em:RegisterForEvent(addon.name, EVENT_PLAYER_DEACTIVATED, OnPlayerDeactivated)
	if EVENT_GAMEPAD_PREFERRED_MODE_CHANGED then
		em:RegisterForEvent(addon.name, EVENT_GAMEPAD_PREFERRED_MODE_CHANGED, function() addon:Restart() end)
	end
	if EVENT_CONTROLLER_DISCONNECTED then
		em:RegisterForEvent(addon.name, EVENT_CONTROLLER_DISCONNECTED, function() addon:Stop() end)
	end
	if EVENT_CONTROLLER_CONNECTED then
		em:RegisterForEvent(addon.name, EVENT_CONTROLLER_CONNECTED, function() addon:Start() end)
	end
end

em:RegisterForEvent(addon.name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)

addon.MODES = MODES
addon.DEFAULTS = DEFAULTS
addon.TRIGGER_LAYER = TRIGGER_LAYER
addon.SCREENSHOT_SCENE = SCREENSHOT_SCENE
addon.MAX_HOLD_S = MAX_HOLD_S

PBS_SCREENSHOT_MODE_SHORTCUT = addon
