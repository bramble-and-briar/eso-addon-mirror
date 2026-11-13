local A, S = PBS_QUICK_CHAT, PBS_QUICK_CHAT_STRINGS
local em = EVENT_MANAGER

-- ---------------------------------------------------------------------------------------
-- Output
--
-- A message printed at EVENT_ADD_ON_LOADED is thrown away because chat is not up yet, so anything
-- user-facing is either a command response or fires on EVENT_PLAYER_ACTIVATED.
--
-- A console hides the chat window while a menu is open, and the settings panel is a menu: so every message
-- is also kept in a short log that the panel shows as a label. Note() writes only to that log (the chat box
-- is about to open; a line in the chat above it would be noise), Print() also goes to the chat, Fail() also
-- puts a line on the screen -- for the moments when nobody is looking at the chat (the wheel).
-- ---------------------------------------------------------------------------------------

local PREFIX = "|cFF69B4" .. A.chatName .. "|r: "
local LOG_LINES = 6

A.log = {}

function A:Say(text)
	if CHAT_ROUTER and CHAT_ROUTER.AddSystemMessage then
		CHAT_ROUTER:AddSystemMessage(text)
	elseif CHAT_SYSTEM and CHAT_SYSTEM.AddMessage then
		CHAT_SYSTEM:AddMessage(text)
	else
		d(text)
	end
end

function A:Note(text, ...)
	if select("#", ...) > 0 then
		local ok, formatted = pcall(string.format, text, ...)
		text = ok and formatted or text
	end
	local log = self.log
	log[#log + 1] = text
	while #log > LOG_LINES do
		table.remove(log, 1)
	end
	self:RefreshPanel()
end

function A:Print(text, ...)
	if select("#", ...) > 0 then
		local ok, formatted = pcall(string.format, text, ...)
		text = ok and formatted or text
	end
	self:Note(text)
	self:Say(PREFIX .. text)
end

function A:LogText()
	if #self.log == 0 then
		return S.logEmpty
	end
	return table.concat(self.log, "\n")
end

-- A line on the screen, for the moments when nobody is looking at the chat (the wheel, a menu).
function A:Alert(text)
	if ZO_Alert and UI_ALERT_CATEGORY_ALERT then
		pcall(ZO_Alert, UI_ALERT_CATEGORY_ALERT, SOUNDS and SOUNDS.NONE or nil, text)
	end
end

function A:Fail(text)
	self:Print(text)
	self:Alert(text)
end

function A:RefreshPanel()
	local panel = self.panel
	if not (panel and panel.selected and panel.UpdateControls) then
		return
	end
	-- only while the library's settings screen is up: its rows are pooled and shared with other add-ons' panels
	local scene = LibHarvensAddonSettings and LibHarvensAddonSettings.scene
	if type(scene) == "table" and type(scene.IsShowing) == "function" and not scene:IsShowing() then
		return
	end
	pcall(panel.UpdateControls, panel)
end

-- ---------------------------------------------------------------------------------------
-- /pbqc status: what the add-on knows
-- ---------------------------------------------------------------------------------------

function A:StatusLines()
	local lines = {}
	local function add(text, ...)
		lines[#lines + 1] = select("#", ...) > 0 and string.format(text, ...) or text
	end
	add("%s", self.title)
	local any = false
	for i = 1, self.NUM_SLOTS do
		local slot = self:GetSlot(i)
		if slot and self:HasText(i) then
			any = true
			add("slot %d: \"%s\" -> %s: %s", i, self:WheelName(i), self:ChannelName(slot.channel), slot.text)
		end
	end
	if not any then
		add("no messages saved")
	end
	for _, line in ipairs(self:WheelStatusLines()) do
		add("%s", line)
	end
	for _, line in ipairs(self:ChatStatusLines()) do
		add("%s", line)
	end
	local strikes = {}
	for group, count in pairs(self.sv.strikes) do
		strikes[#strikes + 1] = group .. "=" .. tostring(count)
	end
	table.sort(strikes)
	local probe = self.sv.probe
	local startup = self.startup or {}
	add("learned: wheel=%s chat=%s; strikes (off at %d): %s; left over at start-up: %s; messages repaired: %d", tostring(probe.wheel), tostring(probe.chat), self.STRIKES_TO_DISABLE,
		#strikes > 0 and table.concat(strikes, ", ") or "-", tostring(startup.stale or "-"), startup.healed or 0)
	local locale = self.ProbeLocale()
	if locale then
		add("locale: 81 is control=%s, 85 is space=%s, A0 is space=%s, E3 is letter=%s, lower() changes C3=%s (all false is what the add-on assumes)",
			tostring(locale.control81), tostring(locale.space85), tostring(locale.spaceA0), tostring(locale.letterE3), tostring(locale.lowerChangesC3))
	end
	add("options: wheel=%s head=%s first=%s coop=%s delay=%d ms", tostring(self.sv.wheel), tostring(self.sv.wheelHead), tostring(self.sv.wheelFirst), tostring(self.sv.coop), self.sv.delayMs)
	return lines
end

function A:PrintStatus()
	for _, line in ipairs(self:StatusLines()) do
		self:Print("%s", line)
	end
end

-- ---------------------------------------------------------------------------------------
-- Commands
-- ---------------------------------------------------------------------------------------

-- Split at ASCII blanks only: a character class such as %S would ask the C library about the bytes of a
-- Japanese message (see Core.lua, "Text that the player typed").
local Words = A.SplitWords

local function Rest(words, from)
	local parts = {}
	for i = from, #words do
		parts[#parts + 1] = words[i]
	end
	return table.concat(parts, " ")
end

local function SlotArg(words, position)
	local number = tonumber(words[position])
	if number and number == math.floor(number) and number >= 1 and number <= A.NUM_SLOTS then
		return number
	end
	return nil
end

function A:PrintHelp()
	for line in S.help:gmatch("[^\n]+") do
		self:Print("%s", line)
	end
end

local function ChannelKeys()
	local keys = {}
	for _, def in ipairs(A.channelList or A.CHANNELS) do
		keys[#keys + 1] = def.key
	end
	return table.concat(keys, ", ")
end

function A:Command(input)
	local words = Words(input)
	local verb = A.LowerAscii(words[1])

	if verb == "" or verb == "help" then
		self:PrintHelp()
	elseif verb == "list" then
		local any = false
		for i = 1, self.NUM_SLOTS do
			local slot = self:GetSlot(i)
			if slot and self:HasText(i) then
				any = true
				self:Print(S.listLine, i, self:ChannelName(slot.channel), self:WheelName(i), slot.text)
			end
		end
		if not any then
			self:Print(S.noMessages)
		end
	elseif verb == "set" then
		local slot = SlotArg(words, 2)
		if not slot then
			self:Print(S.noSuchSlot)
			return
		end
		self:SetSlotText(slot, Rest(words, 3))
		self:Print(S.setDone, slot, self:GetSlot(slot).text)
	elseif verb == "name" then
		local slot = SlotArg(words, 2)
		if not slot then
			self:Print(S.noSuchSlot)
			return
		end
		self:SetSlotName(slot, Rest(words, 3))
		self:Print(S.nameDone, slot, self:GetSlot(slot).name)
	elseif verb == "channel" then
		local slot = SlotArg(words, 2)
		if not slot then
			self:Print(S.noSuchSlot)
			return
		end
		local key = A.LowerAscii(words[3])
		local def = A.CHANNEL_BY_KEY[key]
		if not def or (def.key ~= "current" and def.id == nil) then
			self:Print(S.noSuchChannel, ChannelKeys())
			return
		end
		self:SetSlotChannel(slot, key)
		self:Print(S.channelDone, slot, self:ChannelName(key))
	elseif verb == "clear" then
		local slot = SlotArg(words, 2)
		if not slot then
			self:Print(S.noSuchSlot)
			return
		end
		self:ClearSlot(slot)
		self:Print(S.cleared, slot)
	elseif verb == "send" then
		local slot = SlotArg(words, 2)
		if not slot then
			self:Print(S.noSuchSlot)
			return
		end
		self:Stage(slot, "command")
	elseif verb == "wheel" then
		local value = A.LowerAscii(words[2])
		if value == "on" or value == "off" then
			self:Set("wheel", value == "on")
			self:Print(value == "on" and S.wheelOn or S.wheelOff)
			if value == "on" then
				self:RetryWheel()
			end
		elseif value == "head" or value == "tail" then
			self:Set("wheelHead", value == "head")
			self:Print(value == "head" and S.wheelHeadOn or S.wheelHeadOff)
		else
			self:PrintHelp()
		end
	elseif verb == "delay" then
		local ms = tonumber(words[2])
		if ms then
			self:Set("delayMs", ms)
			self:Print(S.delaySet, self.sv.delayMs)
		else
			self:PrintHelp()
		end
	elseif verb == "status" then
		self:PrintStatus()
	elseif verb == "retry" then
		self:Retry()
		self:Print(S.retried)
		self:RetryWheel()
	else
		self:PrintHelp()
	end
end

-- ---------------------------------------------------------------------------------------
-- Start-up
-- ---------------------------------------------------------------------------------------

local function OnLoaded(_, addonName)
	if addonName ~= A.name then
		return
	end
	em:UnregisterForEvent(A.name, EVENT_ADD_ON_LOADED)

	A.sv = ZO_SavedVars:NewAccountWide("PBsQuickChat_Data", 1, nil, A.defaults)
	A:Sanitize()
	A:ResolveConstants()
	A:InitSettings()

	local function command(input)
		A:Command(input)
	end
	SLASH_COMMANDS[A.slash] = command
	SLASH_COMMANDS[A.shortSlash] = command
end

local bannerShown = false

local function OnActivated()
	if not A.sv then
		return
	end
	-- The client's wheel exists by now; try again at every activation until the page is installed.
	A:InstallWheel()
	A:ScheduleWheelRetry()
	if not bannerShown then
		bannerShown = true
		A:Print(S.bannerLine, A.title)
	end
end

em:RegisterForEvent(A.name, EVENT_ADD_ON_LOADED, OnLoaded)
-- Registered here, at file load, and not inside OnLoaded: the client runs every add-on's files before it fires
-- the first EVENT_ADD_ON_LOADED, and handlers of one event run in the order they were registered. So this
-- add-on's activation handler runs before the one of an add-on that registers its own in its OnLoaded (PB's
-- Equipment Changer), and this page is the one that comes right after Emotes (Wheel.lua, last section).
em:RegisterForEvent(A.name, EVENT_PLAYER_ACTIVATED, OnActivated)
