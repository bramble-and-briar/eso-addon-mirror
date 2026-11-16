local A, S = PBS_OSA, PBS_OSA_STRINGS
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
-- /pbosa status: what the add-on knows
-- ---------------------------------------------------------------------------------------

local function YesNo(value)
	return value and "yes" or "no"
end

function A:StatusLines()
	local lines = {}
	local function add(text, ...)
		lines[#lines + 1] = select("#", ...) > 0 and string.format(text, ...) or text
	end
	local alert, diag, sv = self.alert, self.diag, self.sv
	add("%s", self.title)
	add("alerts: %s; listening to the game: %s; options: online=%s offline=%s guild name=%s character=%s sound=%s", YesNo(sv.enabled),
		YesNo(self.listening), YesNo(sv.notifyOnline), YesNo(sv.notifyOffline), YesNo(sv.showGuildName), YesNo(sv.showCharacter), YesNo(sv.sound))
	add("banner: %d s, size %d, %d from the right, %d from the top", sv.duration, sv.size, sv.posX, sv.posY)

	local now = A.Now()
	local left = self.quietUntil - now
	add("quiet time after login: %d s (%s); first activation seen: %s", sv.quiet, left > 0 and string.format("running, %.1f s left", left / 1000) or "not running",
		self.loginAt and string.format("%.0f s ago", (now - self.loginAt) / 1000) or "no")

	for i = 1, self.MAX_GUILDS do
		local id = self:GuildIdAt(i)
		if id then
			local ok, total, online = pcall(GetGuildInfo, id)
			add("guild %d: \"%s\" (id %d) %s, %s of %s online", i, self:GuildName(id, i), id, self:IsWatched(id) and "WATCHED" or "not watched",
				ok and tostring(online) or "?", ok and tostring(total) or "?")
		end
	end

	add("game screen showing: %s; banner phase: %s; waiting: %d; shown %d, merged %d, expired %d, dropped %d", YesNo(alert.hud), alert.phase, #alert.queue,
		alert.shown, alert.merged, alert.expired, alert.dropped)
	add("status events seen: %d; of watched guilds in the first minute after login: %d; other guilds: %d; same state: %d; own: %d; switched off: %d; quiet time: %d; alerts: %d; guild data loaded: %d",
		diag.seen, diag.burst, diag.unwatched, diag.sameState, diag.self, diag.kindOff, diag.quiet, diag.alerts, diag.dataLoaded)
	if #diag.raw > 0 then
		add("last events of watched guilds:")
		for _, line in ipairs(diag.raw) do
			add("  %s", line)
		end
	else
		add("no event of a watched guild has arrived yet")
	end
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

-- ---------------------------------------------------------------------------------------
-- Commands
-- ---------------------------------------------------------------------------------------

function A:PrintHelp()
	self:Print("%s", S.help)
end

function A:PrintGuilds()
	local any = false
	for i = 1, self.MAX_GUILDS do
		local id = self:GuildIdAt(i)
		if id then
			any = true
			local ok, total, online = pcall(GetGuildInfo, id)
			self:Print(S.guildLine, i, self:GuildName(id, i), self:IsWatched(id) and S.guildWatched or S.guildIgnored, ok and online or 0, ok and total or 0)
		end
	end
	if not any then
		self:Print(S.guildsNone)
	end
end

-- Switches a guild's watch on or off by its slot (1-5).
function A:WatchSlot(slotText, watched)
	local slot = tonumber(slotText)
	local id = slot and slot == math.floor(slot) and self:GuildIdAt(slot) or nil
	if not id then
		self:Print(S.noSuchGuild, slot or 0)
		return
	end
	self:SetWatched(id, watched)
	self:RefreshPreview()
	self:Print(watched and S.watchOn or S.watchOff, slot, self:GuildName(id, slot))
end

function A:Command(input)
	local words = A.SplitWords(input)
	local verb = A.LowerAscii(words[1])

	if verb == "" or verb == "help" then
		self:PrintHelp()
	elseif verb == "status" then
		self:PrintStatus()
	elseif verb == "guilds" then
		self:PrintGuilds()
	elseif verb == "watch" then
		self:WatchSlot(words[2], true)
	elseif verb == "unwatch" then
		self:WatchSlot(words[2], false)
	elseif verb == "on" or verb == "off" then
		self:Set("enabled", verb == "on")
		self:ApplyListening()
		self:Print(verb == "on" and S.on or S.off)
	elseif verb == "test" then
		self:QueueTest()
		self:Print(S.testQueued)
	elseif verb == "quiet" then
		local seconds = tonumber(words[2])
		if seconds then
			self:Set("quiet", seconds)
			self:Print(S.quietSet, self.sv.quiet)
		else
			self:PrintHelp()
		end
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

A.boot = PBS_OSA_BOOT or { files = {}, like = {}, announced = 0, activated = 0 }
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
	Step("banner", self.InitAlert, self)
	Step("settings panel", self.InitSettings, self)
	Step("listening", self.ApplyListening, self)
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
		SLASH_COMMANDS[self.longSlash] = command
	end)
end

function A:OnActivated()
	if not self.sv then
		return
	end
	-- Only the first activation is the login (this event fires after every loading screen).
	if self.loginAt then
		return
	end
	self.loginAt = A.Now()
	self:StartQuiet()
	self:Print(S.bannerLine, self.title)
	if boot.init ~= "EVENT_ADD_ON_LOADED" then
		self:Print("started late, by " .. tostring(boot.init) .. ": the game did not announce this add-on as \"" .. self.name .. "\"")
	end
	local names = self:WatchedNames()
	if self.sv.enabled then
		if #names > 0 then
			self:Print(S.bannerWatching, table.concat(names, ", "))
		else
			self:Print(S.bannerNoGuild)
		end
	else
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

PBS_OSA_MARK("Main")
