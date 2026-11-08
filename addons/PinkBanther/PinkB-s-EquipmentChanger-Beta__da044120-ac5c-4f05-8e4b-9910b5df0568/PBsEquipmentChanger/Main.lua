local A, S = PBS_EQUIPMENT_CHANGER, PBS_EQUIPMENT_CHANGER_STRINGS
local em = EVENT_MANAGER

-- ---------------------------------------------------------------------------------------
-- Output
--
-- A message printed at EVENT_ADD_ON_LOADED is thrown away because chat is not up yet, so anything
-- user-facing is either a command response or fires on EVENT_PLAYER_ACTIVATED.
--
-- A console hides the chat window while a menu is open, and the settings panel is a menu: so every message
-- is also kept in a short log that the panel shows as a label.
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

function A:Print(text, ...)
	if select("#", ...) > 0 then
		local ok, formatted = pcall(string.format, text, ...)
		text = ok and formatted or text
	end
	local log = self.log
	log[#log + 1] = text
	while #log > LOG_LINES do
		table.remove(log, 1)
	end
	self:Say(PREFIX .. text)
	self:RefreshPanel()
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
-- /pbec status: what the add-on knows
-- ---------------------------------------------------------------------------------------

function A:StatusLines()
	local lines = {}
	local function add(text, ...)
		lines[#lines + 1] = select("#", ...) > 0 and string.format(text, ...) or text
	end
	add("%s", self.title)
	local record = self:Char()
	add("character: %s", record.name or "?")
	local any = false
	for i = 1, self.NUM_SLOTS do
		local set = self:GetSet(i)
		if set then
			any = true
			add("slot %d: %s (%s)", i, set.name, self:Describe(set))
		end
	end
	if not any then
		add("no saved sets")
	end
	for _, line in ipairs(self:WheelStatusLines()) do
		add("%s", line)
	end
	for _, group in ipairs({ "equip", "skills", "champion" }) do
		local usable, why = self:CheckGroup(group)
		local state = self.api[group]
		local kinds = {}
		for _, name in ipairs(self.GROUPS[group]) do
			kinds[#kinds + 1] = name .. "=" .. tostring(state.kinds[name] or "?")
		end
		add("%s calls: %s (%s) asked: %s", group, usable and "usable" or "not used", usable and (state.asked ~= "" and state.asked or "-") or tostring(why), table.concat(kinds, ", "))
	end
	local probe = self.sv.probe
	add("learned: equip=%s skills=%s champion=%s wheel=%s ask=%s", tostring(probe.equip), tostring(probe.skills), tostring(probe.champion), tostring(probe.wheel), tostring(probe.ask))
	local strikes = {}
	for group, count in pairs(self.sv.strikes) do
		strikes[#strikes + 1] = group .. "=" .. tostring(count)
	end
	table.sort(strikes)
	local startup = self.startup or {}
	add("strikes (off at %d): %s; left over at start-up: %s; old verdicts forgotten: %s; names repaired: %d", self.STRIKES_TO_DISABLE, #strikes > 0 and table.concat(strikes, ", ") or "-",
		tostring(startup.stale or "-"), tostring(startup.migrated == true), startup.healed or 0)
	local locale = self.ProbeLocale()
	if locale then
		add("locale: 81 is control=%s, 85 is space=%s, A0 is space=%s, E3 is letter=%s, lower() changes C3=%s (all false is what the add-on assumes)",
			tostring(locale.control81), tostring(locale.space85), tostring(locale.spaceA0), tostring(locale.letterE3), tostring(locale.lowerChangesC3))
	end
	add("options: wheel=%s first=%s save=%s/%s/%s apply=%s/%s/%s clearSkills=%s unequipEmpty=%s",
		tostring(self.sv.wheel), tostring(self.sv.wheelFirst), tostring(self.sv.saveGear), tostring(self.sv.saveSkills), tostring(self.sv.saveChampion),
		tostring(self.sv.applyGear), tostring(self.sv.applySkills), tostring(self.sv.applyChampion), tostring(self.sv.clearSkills), tostring(self.sv.unequipEmpty))
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
-- Japanese name (see Core.lua, "Text that the player typed").
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

function A:Command(input)
	local words = Words(input)
	local verb = A.LowerAscii(words[1])

	if verb == "" or verb == "help" then
		self:PrintHelp()
	elseif verb == "list" then
		local any = false
		for i = 1, self.NUM_SLOTS do
			local set = self:GetSet(i)
			if set then
				any = true
				self:Print("%d: %s (%s)", i, set.name, self:Describe(set))
			end
		end
		if not any then
			self:Print(S.noSets)
		end
	elseif verb == "save" then
		local slot = SlotArg(words, 2)
		local nameFrom = 3
		if not slot then
			slot, nameFrom = self:FirstFreeSlot(), 2
			if not slot then
				self:Print(S.allSlotsTaken)
				return
			end
		end
		self:ActionSave(slot, Rest(words, nameFrom))
	elseif verb == "load" then
		local slot = self:FindSlot(Rest(words, 2))
		if slot then
			self:Load(slot, "command")
		else
			self:Print(S.noSuchSlot)
		end
	elseif verb == "rename" then
		local slot = SlotArg(words, 2)
		if slot then
			self:ActionRename(slot, Rest(words, 3))
		else
			self:Print(S.noSuchSlot)
		end
	elseif verb == "delete" then
		local slot = SlotArg(words, 2)
		if slot then
			self:ActionDelete(slot)
		else
			self:Print(S.noSuchSlot)
		end
	elseif verb == "wheel" then
		local value = A.LowerAscii(words[2])
		if value == "on" or value == "off" then
			self:Set("wheel", value == "on")
			self:Print(value == "on" and S.wheelOn or S.wheelOff)
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

	A.sv = ZO_SavedVars:NewAccountWide("PBsEquipmentChanger_Data", 1, nil, A.defaults)
	A:Sanitize()
	A:ResolveConstants()
	A:InitSettings()

	local function command(input)
		A:Command(input)
	end
	SLASH_COMMANDS[A.slash] = command
	SLASH_COMMANDS[A.shortSlash] = command

	local bannerShown = false
	em:RegisterForEvent(A.name, EVENT_PLAYER_ACTIVATED, function()
		-- The client's wheel exists by now; try again at every activation until the page is installed.
		A:InstallWheel()
		A:ScheduleWheelRetry()
		if not bannerShown then
			bannerShown = true
			A:Print(S.bannerLine, A.title)
		end
	end)
	em:RegisterForEvent(A.name, EVENT_PLAYER_DEACTIVATED, function()
		A:EndJob(true)
	end)
end

em:RegisterForEvent(A.name, EVENT_ADD_ON_LOADED, OnLoaded)
