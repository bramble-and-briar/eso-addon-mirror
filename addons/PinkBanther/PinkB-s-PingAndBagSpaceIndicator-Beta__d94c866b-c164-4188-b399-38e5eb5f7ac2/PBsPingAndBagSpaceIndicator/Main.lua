local A, S = PBS_PBSI, PBS_PBSI_STRINGS
local em = EVENT_MANAGER

-- ---------------------------------------------------------------------------------------
-- Output. A message printed at EVENT_ADD_ON_LOADED is thrown away because chat is not up yet, so anything
-- user-facing is either a command response or fires on EVENT_PLAYER_ACTIVATED.
-- ---------------------------------------------------------------------------------------

local PREFIX = "|cFF69B4" .. A.chatName .. "|r: "

function A:Say(text)
	if CHAT_ROUTER and CHAT_ROUTER.AddSystemMessage then
		CHAT_ROUTER:AddSystemMessage(text)
	elseif CHAT_SYSTEM and CHAT_SYSTEM.AddMessage then
		CHAT_SYSTEM:AddMessage(text)
	elseif d then
		d(text)
	end
end

function A:Print(text, ...)
	if select("#", ...) > 0 then
		local ok, formatted = pcall(string.format, text, ...)
		text = ok and formatted or text
	end
	self:Say(PREFIX .. text)
end

-- ---------------------------------------------------------------------------------------
-- /pbping status: the raw answer of every game function the readout uses
-- ---------------------------------------------------------------------------------------

local function Show(value)
	if value == nil then
		return "nil"
	end
	return tostring(value)
end

local function YesNo(value)
	return value and "yes" or "no"
end

function A:StatusLines()
	local lines = {}
	local function add(text, ...)
		lines[#lines + 1] = select("#", ...) > 0 and string.format(text, ...) or text
	end
	local sv, hud, N = self.sv, self.hud, self.Number
	add("%s", self.title)
	add("readout: %s; game screen showing: %s; preview: %s; reading: %s (%d reads, text changed %d times)", YesNo(sv.enabled), YesNo(hud.shown),
		YesNo(hud.preview), YesNo(hud.ticking), hud.ticks, hud.textSets)
	add("GetLatency() = %s; GetFramerate() = %s", Show(N(GetLatency)), Show(N(GetFramerate)))
	add("backpack: used %s, GetBagSize %s, GetBagUseableSize %s", Show(N(GetNumBagUsedSlots, BAG_BACKPACK)), Show(N(GetBagSize, BAG_BACKPACK)),
		Show(N(GetBagUseableSize, BAG_BACKPACK)))
	add("bank: used %s of %s; ESO Plus bank: used %s of %s; ESO Plus: %s", Show(N(GetNumBagUsedSlots, BAG_BANK)), Show(N(GetBagUseableSize, BAG_BANK)),
		Show(BAG_SUBSCRIBER_BANK and N(GetNumBagUsedSlots, BAG_SUBSCRIBER_BANK)), Show(BAG_SUBSCRIBER_BANK and N(GetBagUseableSize, BAG_SUBSCRIBER_BANK)),
		Show(type(IsESOPlusSubscriber) == "function" and IsESOPlusSubscriber()))
	add("gold: carried %s, banked %s", Show(CURRENCY_LOCATION_CHARACTER and N(GetCurrencyAmount, CURT_MONEY, CURRENCY_LOCATION_CHARACTER)),
		Show(CURRENCY_LOCATION_BANK and N(GetCurrencyAmount, CURT_MONEY, CURRENCY_LOCATION_BANK)))
	add("place: %s %+d %+d, size %d, layout %d, background %d %%", self.ANCHORS[sv.anchor] or "?", sv.posX, sv.posY, sv.size, sv.layout, sv.bgAlpha)
	add("errors: %d%s", self.errors, self.lastError and (" - last: " .. self.lastError) or "")
	return lines
end

function A:PrintStatus()
	for _, line in ipairs(self:StatusLines()) do
		self:Say(PREFIX .. line)
	end
end

-- ---------------------------------------------------------------------------------------
-- Commands
-- ---------------------------------------------------------------------------------------

function A:Command(input)
	local words = A.SplitWords(input)
	local verb = A.LowerAscii(words[1])

	if verb == "status" then
		self:PrintStatus()
	elseif verb == "on" or verb == "off" then
		self:Set("enabled", verb == "on")
		self:HudSettingsChanged()
		self:Print(verb == "on" and S.on or S.off)
	elseif verb == "reset" then
		self:ResetPlace()
		self:HudSettingsChanged()
		self:Print(S.resetDone)
	else
		self:Print("%s", S.help)
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

A.boot = PBS_PBSI_BOOT or { files = {}, like = {}, announced = 0, activated = 0 }
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
	Step("readout", self.InitHud, self)
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
		SLASH_COMMANDS[self.longSlash] = command
	end)
end

function A:OnActivated()
	if not self.sv or self.announcedReady then
		return
	end
	-- Only the first activation is the login (this event fires after every loading screen).
	self.announcedReady = true
	self:Print(S.bannerLine, self.title)
	if boot.init ~= "EVENT_ADD_ON_LOADED" then
		self:Print("started late, by " .. tostring(boot.init) .. ": the game did not announce this add-on as \"" .. self.name .. "\"")
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

PBS_PBSI_MARK("Main")
