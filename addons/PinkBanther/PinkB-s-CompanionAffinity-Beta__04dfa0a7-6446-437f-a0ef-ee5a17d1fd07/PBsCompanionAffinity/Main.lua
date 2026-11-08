local A, S = PBS_CABS, PBS_CABS_STRINGS
local em = EVENT_MANAGER

-- ---------------------------------------------------------------------------------------
-- Output
--
-- A message printed at EVENT_ADD_ON_LOADED is thrown away because chat is not up yet, so anything
-- user-facing is either a command response or fires on EVENT_PLAYER_ACTIVATED.
-- ---------------------------------------------------------------------------------------

function A:Say(text)
	if CHAT_ROUTER and CHAT_ROUTER.AddSystemMessage then
		CHAT_ROUTER:AddSystemMessage(text)
	elseif CHAT_SYSTEM and CHAT_SYSTEM.AddMessage then
		CHAT_SYSTEM:AddMessage(text)
	else
		d(text)
	end
end

local PREFIX = "|cFF69B4" .. A.chatName .. "|r: "

function A:Print(text, ...)
	if select("#", ...) > 0 then
		local ok, formatted = pcall(string.format, text, ...)
		self:Say(PREFIX .. (ok and formatted or text))
	else
		self:Say(PREFIX .. text)
	end
end

function A:Clear()
	self.led.rows = {}
	self.led.log = {}
	self:Render()
	self:Print(S.cleared)
end

-- ---------------------------------------------------------------------------------------
-- /pbcabs
-- ---------------------------------------------------------------------------------------

local NUMBERS = {
	min = "minAmount", rows = "maxRows", expire = "expireHours", opacity = "opacity", x = "x", y = "y",
	width = "width", size = "textSize", hsize = "headerSize", columns = "columns",
}
local SWITCHES = { neg = "showNegative", est = "useEstimates", alone = "showWithoutCompanion", all = "showCatalog" }
-- 0.1.0 had three sizes by name; they still work, as the steps nearest to the old fonts.
local OLD_SIZES = { small = 1, medium = 3, large = 5 }

-- /pbcabs cd <row> <minutes | daily | auto>: the number is the one /pbcabs list prints.
function A:SetCooldown(index, what)
	local id = self:ActiveCompanionId()
	local entry = id and self:ListRows(id)[index]
	if not entry then
		self:Print(S.cdBad, index)
		return false
	end
	local value, word
	if what == "auto" then
		value, word = nil, S.cdAuto
	elseif what == "daily" then
		value, word = "daily", S.cdDaily
	else
		local minutes = tonumber(what)
		if not minutes or minutes <= 0 or minutes > 100000 then
			self:Say(S.help)
			return false
		end
		minutes = math.floor(minutes)
		value, word = minutes * 60, string.format(S.cdMinutes, minutes)
	end
	entry.row.user = value
	self:Print(S.cdSet, index, word)
	self:Render()
	return true
end

-- /pbcabs used <action number from /pbcabs cat>: the action was done just now.
function A:UsedCommand(number)
	local id = self:ActiveCompanionId()
	local actions = id and A.EntriesOf(id)
	local action = actions and number and actions[number]
	if not action then
		self:Print(S.catBad, number or 0)
		return
	end
	self:MarkUsed(action)
	self:Print(S.usedSet, A.EntryName(action))
	self:Render()
end

-- /pbcabs link <row from /pbcabs list> <action number from /pbcabs cat>: that row is that action (0 = none).
function A:LinkCommand(rowNumber, number)
	local id = self:ActiveCompanionId()
	local entry = id and self:ListRows(id)[rowNumber]
	if not entry then
		self:Print(S.cdBad, rowNumber)
		return
	end
	if number == 0 then
		entry.row.entry = nil
		self:Print(S.linkCleared, rowNumber)
	else
		local actions = A.EntriesOf(id)
		local action = actions and actions[number]
		if not action then
			self:Print(S.catBad, number)
			return
		end
		entry.row.entry = action.id
		self:Print(S.linkSet, rowNumber, A.EntryName(action))
	end
	self:Render()
end

function A:Command(input)
	local command, arg = string.lower(input or ""):match("^%s*(%S*)%s*(.-)%s*$")
	local number = tonumber(arg)
	if command == "on" or command == "off" then
		self:Set("enabled", command == "on")
	elseif command == "reset" then
		self:Reset()
	elseif command == "status" then
		for _, line in ipairs(self:StatusLines()) do
			self:Say(line)
		end
	elseif command == "list" then
		local lines = self:ListLines()
		if #lines == 0 then
			self:Say(S.noRows)
		end
		for _, line in ipairs(lines) do
			self:Say(line)
		end
	elseif command == "log" then
		local lines = self:LogLines(math.max(1, math.min(A.LOG_MAX, number or 10)))
		if #lines == 0 then
			self:Say(S.noLog)
		end
		for _, line in ipairs(lines) do
			self:Say(line)
		end
	elseif command == "test" then
		self:StartDemo()
		self:Print(S.testOn)
	elseif command == "clear" then
		self:Clear()
	elseif command == "cat" then
		local lines = self:CatLines()
		if #lines == 0 then
			self:Say(string.format(S.noTable, tostring(self:ActiveCompanionId())))
		end
		for _, line in ipairs(lines) do
			self:Say(line)
		end
	elseif command == "used" then
		self:UsedCommand(tonumber(arg))
	elseif command == "link" then
		local row, action = arg:match("^(%d+)%s+(%d+)$")
		if row then
			self:LinkCommand(tonumber(row), tonumber(action))
		else
			self:Say(S.help)
		end
	elseif command == "boot" then
		if PBS_CABS_BOOT then
			PBS_CABS_BOOT.Print()
		end
	elseif command == "cd" then
		local index, what = arg:match("^(%d+)%s+(%S+)$")
		if not index then
			self:Say(S.help)
		else
			self:SetCooldown(tonumber(index), what)
		end
	elseif NUMBERS[command] and number then
		self:Set(NUMBERS[command], number)
	elseif SWITCHES[command] and (arg == "on" or arg == "off") then
		self:Set(SWITCHES[command], arg == "on")
	elseif command == "size" and OLD_SIZES[arg] then
		self:Set("textSize", OLD_SIZES[arg])
	else
		self:Say(S.help)
		return
	end
	if self.panel and self.panel.UpdateControls then
		self.panel:UpdateControls()
	end
end

-- ---------------------------------------------------------------------------------------
-- Start-up
-- ---------------------------------------------------------------------------------------

-- One step of start-up. A step that fails is kept (it is printed with the banner and by /pbcabs
-- status) and the steps after it still run: one broken part must not take the whole add-on down, which
-- from the outside looks exactly like an add-on that is not there.
local function Step(label, fn, ...)
	local ok, err = pcall(fn, ...)
	if not ok then
		local errors = A.diag.loadErrors
		errors[#errors + 1] = label .. ": " .. tostring(err)
	end
	return ok
end

-- A handler for the game to call: whatever it does wrong is kept, not thrown into the game's event loop.
local function Guarded(fn)
	return function(...)
		local ok, err = pcall(fn, ...)
		if not ok then
			A:NoteError(err)
		end
	end
end

-- Boot.lua's trace of how far start-up got (a stand-in if that file did not run).
local boot = PBS_CABS_BOOT or { files = {}, like = {}, announced = 0, activated = 0 }

-- Start-up proper, once. It happens at whichever comes first: the game announcing this add-on, or the
-- player becoming active. The second is a fallback for an announcement that never comes under the name
-- the add-on expects (a folder that was renamed on its way to the console): the files have run by then,
-- and so has everything the game loads for every add-on, saved variables included.
function A:Init(how)
	if self.initialised then
		return
	end
	self.initialised = true
	boot.init = how

	-- Settings are shared by the account; what was gained, and when, belongs to the character (rapport
	-- is per character, and so are the cooldowns).
	Step("saved variables", function()
		self.sv = ZO_SavedVars:NewAccountWide(self.savedVar, 1, nil, self.defaults)
		self.led = ZO_SavedVars:NewCharacterIdSettings(self.savedVar, 1, "Ledger", { rows = {}, log = {} })
	end)
	-- Without them the add-on still runs, on defaults it cannot save.
	if not self.sv then
		self.sv = {}
		for key, value in pairs(self.defaults) do
			self.sv[key] = value
		end
	end
	if not self.led then
		self.led = { rows = {}, log = {} }
	end
	Step("checking the saved data", self.Sanitize, self, GetTimeStamp())
	Step("window", self.CreateUI, self)
	Step("layout", self.ApplyLayout, self)
	Step("settings panel", self.InitSettings, self)
	Step("watchers", self.RegisterContext, self)

	-- From here the add-on answers /pbcabs itself; until now Boot.lua did.
	Step("commands", function()
		local function command(input)
			local ok, err = pcall(self.Command, self, input)
			if not ok then
				self:NoteError(err)
				self:Print("error: " .. tostring(err))
			end
		end
		SLASH_COMMANDS[self.slash] = command
		SLASH_COMMANDS[self.shortSlash] = command
	end)

	local refresh = Guarded(function()
		self:RefreshVisibility()
	end)
	Step("scenes", function()
		HUD_SCENE:RegisterCallback("StateChange", refresh)
		HUD_UI_SCENE:RegisterCallback("StateChange", refresh)
	end)
	Step("rapport event", function()
		em:RegisterForEvent(self.name .. "Rapport", EVENT_COMPANION_RAPPORT_UPDATE, Guarded(function(...)
			self:OnRapportEvent(...)
		end))
	end)
	-- A companion arriving or leaving shows or hides the list.
	Step("companion events", function()
		em:RegisterForEvent(self.name .. "CompanionState", EVENT_ACTIVE_COMPANION_STATE_CHANGED, refresh)
		em:RegisterForEvent(self.name .. "CompanionOn", EVENT_COMPANION_ACTIVATED, refresh)
		em:RegisterForEvent(self.name .. "CompanionOff", EVENT_COMPANION_DEACTIVATED, refresh)
	end)
	Step("screen events", function()
		em:RegisterForEvent(self.name, EVENT_PLAYER_DEACTIVATED, Guarded(function()
			self.active = false
			self:SetPanelOpen(false)
			self:RefreshVisibility()
		end))
		em:RegisterForEvent(self.name, EVENT_SCREEN_RESIZED, Guarded(function()
			self:ApplyLayout()
		end))
	end)
end

-- The player is in the world (this fires on every loading screen): show the list, and once, say hello.
function A:OnActivated()
	self.active = true
	Guarded(function()
		self:ApplyLayout()
		self:RefreshVisibility()
	end)()
	if not self.bannerShown then
		self.bannerShown = true
		self:Print(S.bannerLine, self.title)
		if boot.init ~= "EVENT_ADD_ON_LOADED" then
			self:Print("started late, by " .. tostring(boot.init) .. ": the game did not announce this add-on as \"" .. self.name
				.. "\" (/pbcabs boot says what it did announce)")
		end
		-- Anything that went wrong on the way up is said here, where chat is up to show it.
		for _, text in ipairs(self.diag.loadErrors) do
			self:Print("load error - " .. text)
		end
		if self.diag.lastError then
			self:Print("error - " .. self.diag.lastError)
		end
	end
end

-- These two are set up when the file runs, not when start-up happens, so that start-up can be started
-- (and traced) from either.
em:RegisterForEvent(A.name, EVENT_ADD_ON_LOADED, Guarded(function(_, name)
	boot.announced = boot.announced + 1
	if name == A.name then
		boot.ours = true
		A:Init("EVENT_ADD_ON_LOADED")
	elseif boot.Looks and boot.Looks(name) and #boot.like < 8 then
		boot.like[#boot.like + 1] = tostring(name)
	end
end))
em:RegisterForEvent(A.name, EVENT_PLAYER_ACTIVATED, Guarded(function()
	boot.activated = boot.activated + 1
	if not A.initialised then
		A:Init("EVENT_PLAYER_ACTIVATED (fallback)")
	end
	A:OnActivated()
end))

if PBS_CABS_MARK then
	PBS_CABS_MARK("Main")
end
