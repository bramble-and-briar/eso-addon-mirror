local A, S = PBS_COMBAT_ASSISTANT, PBS_COMBAT_ASSISTANT_STRINGS
local em = EVENT_MANAGER

-- ---------------------------------------------------------------------------------------
-- Output
--
-- A message printed at EVENT_ADD_ON_LOADED is thrown away because chat is not up yet, so anything user-facing is
-- either a command response or fires on EVENT_PLAYER_ACTIVATED.
--
-- A console hides the chat window while a menu is open, and the settings panel is a menu: so what the add-on did
-- is also kept in a short log that the panel shows as a label. Note() writes only to that log, Print() also goes
-- to the chat.
-- ---------------------------------------------------------------------------------------

local PREFIX = "|cFF69B4" .. A.chatName .. "|r: "
local LOG_LINES = 8

A.log = {}

function A:Say(text)
	if CHAT_ROUTER and CHAT_ROUTER.AddSystemMessage then
		CHAT_ROUTER:AddSystemMessage(text)
	elseif CHAT_SYSTEM and CHAT_SYSTEM.AddMessage then
		CHAT_SYSTEM:AddMessage(text)
	elseif d then
		d(text)
	end
end

local function Format(text, ...)
	if select("#", ...) > 0 then
		local ok, formatted = pcall(string.format, text, ...)
		return ok and formatted or text
	end
	return text
end

function A:Note(text, ...)
	local log = self.log
	log[#log + 1] = Format(text, ...)
	while #log > LOG_LINES do
		table.remove(log, 1)
	end
	self:RefreshPanel()
end

function A:Print(text, ...)
	text = Format(text, ...)
	self:Note(text)
	self:Say(PREFIX .. text)
end

function A:LogText()
	if #self.log == 0 then
		return S.logEmpty
	end
	return table.concat(self.log, "\n")
end

-- Re-reads the panel's labels, only while the library's settings screen is up: its rows are pooled and shared
-- with other add-ons' panels.
function A:RefreshPanel()
	local panel = self.panel
	if not (panel and panel.selected and panel.UpdateControls) then
		return
	end
	local scene = LibHarvensAddonSettings and LibHarvensAddonSettings.scene
	if type(scene) == "table" and type(scene.IsShowing) == "function" and not scene:IsShowing() then
		return
	end
	pcall(panel.UpdateControls, panel)
end

-- ---------------------------------------------------------------------------------------
-- /pbca status: what the add-on knows
-- ---------------------------------------------------------------------------------------

local function YesNo(value)
	return value and "yes" or "no"
end

function A:StatusLines()
	local lines = {}
	local function add(text, ...)
		lines[#lines + 1] = select("#", ...) > 0 and string.format(text, ...) or text
	end
	local sv, ember, watch = self.sv, self.ember, self.watch
	add("%s", self.title)
	add("on: %s; buffs (on, seconds left): Major Resolve=%s %d s, Minor Resolve=%s %d s, Major Brutality=%s %d s; health: %s below %d%%, urgent below %d%%; only in combat: %s",
		YesNo(sv.enabled), YesNo(sv.major), sv.majorSeconds, YesNo(sv.minor), sv.minorSeconds, YesNo(sv.brutal), sv.brutalSeconds, YesNo(sv.hp), sv.hpWarn, sv.hpDanger, YesNo(sv.combatOnly))
	local tiles = self.tiles
	add("design: %s; tiles: yellow under %d s, size %d%%, x %d, y %d from the bottom, shown %s, preview %s, test running %s, %d frames, %d times running out",
		sv.style == 2 and "Meru-Sawa Style" or "Ember Style", sv.tileWarn, sv.tileSize, sv.tileX, sv.tileY, YesNo(tiles and tiles.shown),
		YesNo(tiles and tiles.preview), YesNo(tiles and tiles.demoStart ~= nil), tiles and tiles.frames or 0, tiles and tiles.pops or 0)
	local watchCc = 0
	for _ in pairs(self.watch.ccKey) do
		watchCc = watchCc + 1
	end
	add("crowd control: on %s, sound %d, tile sound %s; results followed %d; seen %d (last %s), alerts %d, stunned now %s",
		YesNo(sv.cc), sv.ccSound, YesNo(sv.tileSound), watchCc, self.watch.ccSeen, tostring(self.watch.ccLast), self.watch.fired.cc, YesNo(self.watch.stunned))
	add("she: size %d%%, side %d, %d from the edge, %d from the bottom, stays %d s, bubble %s, sound %s, rotation %s",
		sv.size, sv.side, sv.posX, sv.posY, sv.hold, YesNo(sv.bubble), YesNo(sv.sound), sv.rotFlip and "REVERSED" or "normal")

	add("game: in combat %s, dead %s, health %s; the check runs: %s", YesNo(watch.inCombat), YesNo(watch.dead),
		watch.hp and string.format("%.0f%%", watch.hp) or "unknown", YesNo(watch.checking))
	local now = A.Now()
	local any = false
	for abilityId, buff in pairs(watch.buffs) do
		any = true
		local finish = (buff.finish and buff.begin and buff.finish > buff.begin) and string.format("%.1f s left", buff.finish - now) or "no end"
		add("tracked: %s \"%s\" (id %s) %s", buff.kind, tostring(buff.name), tostring(abilityId), finish)
	end
	if not any then
		add("no Resolve or Brutality effect is tracked right now")
	end
	add("effects seen on the player: %d (names remembered %d, emptied %d times), recognised as one of the three: %d; armed: major=%s minor=%s brutal=%s hp=%s urgent=%s; alerts so far: major %d, minor %d, brutal %d, health %d, urgent %d",
		watch.effects, watch.cacheSize, watch.cacheResets, watch.recognised, YesNo(watch.armed.major), YesNo(watch.armed.minor), YesNo(watch.armed.brutal), YesNo(watch.armed.hp), YesNo(watch.armed.danger),
		watch.fired.major, watch.fired.minor, watch.fired.brutal, watch.fired.hp, watch.fired.danger)

	local reasons = {}
	for kind, r in pairs(ember.reasons) do
		reasons[#reasons + 1] = kind .. ":" .. r.state
	end
	table.sort(reasons)
	add("game screen showing: %s; preview: %s; phase: %s, mood: %s; reasons: %s; appeared %d times, %d alerts raised, %d frames",
		YesNo(ember.hud), YesNo(ember.preview), ember.phase, tostring(ember.mood), #reasons > 0 and table.concat(reasons, ", ") or "none",
		ember.shown, ember.raised, ember.frames)
	add("errors: %d%s", self.errors, self.lastError and (" - last: " .. self.lastError) or "")
	return lines
end

-- Straight to the chat, not through the log: a dozen status lines would push the alerts out of the panel's
-- short log.
function A:PrintStatus()
	for _, line in ipairs(self:StatusLines()) do
		self:Say(PREFIX .. line)
	end
end

function A:PrintBuffs()
	for _, line in ipairs(self:BuffLines()) do
		self:Say(PREFIX .. line)
	end
end

-- ---------------------------------------------------------------------------------------
-- Commands
-- ---------------------------------------------------------------------------------------

function A:PrintHelp()
	self:Print("%s", S.help)
end

function A:Command(input)
	local words = A.SplitWords(input)
	local verb = A.LowerAscii(words[1])

	if verb == "" or verb == "help" then
		self:PrintHelp()
	elseif verb == "status" then
		self:PrintStatus()
	elseif verb == "buffs" then
		self:PrintBuffs()
	elseif verb == "on" or verb == "off" then
		self:Set("enabled", verb == "on")
		self:ApplyEnabled()
		self:WatchUpdateState()
		self:Print(verb == "on" and S.on or S.off)
	elseif verb == "test" then
		self:StartTest()
		self:Print(S.testStarted)
	elseif verb == "size" then
		local size = tonumber(words[2])
		if size then
			self:Set("size", size)
			self:ApplyLayout()
			self:Print(S.sizeSet, self.sv.size)
		else
			self:PrintHelp()
		end
	elseif verb == "style" then
		local which = A.LowerAscii(words[2])
		local style = (which == "ember" or which == "1") and 1 or (which == "meru" or which == "merusawa" or which == "2") and 2 or nil
		if style then
			self:Set("style", style)
			self:ApplyStyle()
			self:Print(S.styleSet, style == 2 and S.styleMeru or S.styleEmber)
		else
			self:PrintHelp()
		end
	elseif verb == "flip" then
		self:Set("rotFlip", not self.sv.rotFlip)
		self:ApplyLayout()
		self:Print(S.flipSet, self.sv.rotFlip and S.flipReversed or S.flipNormal)
	else
		self:PrintHelp()
	end
end

-- ---------------------------------------------------------------------------------------
-- Start-up
--
-- Start-up proper happens once, at whichever comes first: the game announcing this add-on, or the player
-- becoming active. The second is a fallback for an announcement that never comes under the name the add-on
-- expects (a folder that was renamed on its way to the console); Boot.lua's trace says which it was. Every step
-- is guarded on its own, so one that fails is reported and does not stop the ones after it.
-- ---------------------------------------------------------------------------------------

A.boot = PBS_COMBAT_ASSISTANT_BOOT or { files = {}, like = {}, announced = 0, activated = 0 }
local boot = A.boot

local function Step(name, fn, ...)
	local ok, err = pcall(fn, ...)
	if not ok then
		A.errors = A.errors + 1
		A.lastError = name .. ": " .. tostring(err)
	end
	return ok
end

local function CopyDefaults(defaults)
	local copy = {}
	for key, value in pairs(defaults) do
		copy[key] = type(value) == "table" and CopyDefaults(value) or value
	end
	return copy
end

function A:Init(how)
	if self.initialised then
		return
	end
	self.initialised = true
	boot.init = how

	Step("saved variables", function()
		self.sv = ZO_SavedVars:NewAccountWide(self.savedVar, 1, nil, self.defaults)
	end)
	-- Without them the add-on still runs, on defaults it cannot save.
	if not self.sv then
		self.sv = CopyDefaults(self.defaults)
	end
	Step("checking the saved data", self.Sanitize, self)
	Step("window", self.InitEmber, self)
	Step("tiles", self.InitTiles, self)
	Step("watching the game", self.InitWatch, self)
	Step("settings panel", self.InitSettings, self)
	Step("commands", function()
		local function command(input)
			local ok, err = pcall(self.Command, self, input)
			if not ok then
				self.errors = self.errors + 1
				self.lastError = tostring(err)
				self:Print("error: " .. tostring(err))
			end
		end
		SLASH_COMMANDS[self.slash] = command
		SLASH_COMMANDS[self.aliasSlash] = command
	end)
end

function A:OnActivated()
	if not self.sv then
		return
	end
	-- every loading screen: read the game's state again
	if self.initialised and self.WatchSync then
		Step("syncing", self.WatchSync, self)
	end
	-- Only the first activation is the login (this event fires after every loading screen).
	if self.loginAt then
		return
	end
	self.loginAt = A.Now()
	self:Print(S.bannerLine, self.title)
	if boot.init ~= "EVENT_ADD_ON_LOADED" then
		self:Print(S.bannerLate, tostring(boot.init), self.name)
	end
	if not self.sv.enabled then
		self:Print(S.off)
	end
	if self.lastError then
		self:Print("error - " .. self.lastError)
	end
end

-- Registered here, at file load, so that start-up can be started (and traced) from either.
em:RegisterForEvent(A.name, EVENT_ADD_ON_LOADED, A.Guard(function(_, name)
	boot.announced = boot.announced + 1
	if name == A.name then
		boot.ours = true
		A:Init("EVENT_ADD_ON_LOADED")
	elseif boot.Looks and boot.Looks(name) and #boot.like < 8 then
		boot.like[#boot.like + 1] = tostring(name)
	end
end))
em:RegisterForEvent(A.name, EVENT_PLAYER_ACTIVATED, A.Guard(function()
	boot.activated = boot.activated + 1
	if not A.initialised then
		A:Init("EVENT_PLAYER_ACTIVATED (fallback)")
	end
	A:OnActivated()
end))

PBS_COMBAT_ASSISTANT_MARK("Main")
