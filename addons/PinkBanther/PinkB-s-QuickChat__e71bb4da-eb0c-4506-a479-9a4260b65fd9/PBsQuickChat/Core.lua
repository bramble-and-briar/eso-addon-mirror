-- PB's Quick Chat
-- Author: PinkBanther
--
-- Keeps eight chat messages the player wrote in the settings panel and puts the chosen one into the chat
-- box, on the channel that was picked for it. They are chosen from an extra page of the utility wheel (the
-- wheel that opens when D-pad up is held on a console), the page that comes right after Emotes.
--
-- ---------------------------------------------------------------------------------------
-- WHAT THE ADD-ON CAN AND CANNOT DO WITH CHAT
-- ---------------------------------------------------------------------------------------
--
-- It cannot send a message. SendChatMessage is marked *private* in ESOUIDocumentation.txt, and so is every
-- way to it that an add-on could take (SubmitTextEntry, AutoSendChatInput end there). Add-on Lua is insecure
-- code: a private function is unreachable from it from any calling context (see PB's notes, "ESO add-on code is
-- insecure"). The same limit is why PB's Dice and PB's Translate end with "the last press has to be the
-- player's". So the wheel entry does everything up to that press: it opens the chat box with the message
-- already in it and the channel already set, and the console's own keyboard (which has the message on it)
-- sends it with its confirm button. That is Chat.lua.
--
-- ---------------------------------------------------------------------------------------
-- WHAT IS STORED
-- ---------------------------------------------------------------------------------------
--
-- One account-wide file: eight slots of { name, text, channel }. A message is the same whichever character
-- is playing, so the slots are not per character. `channel` is a key of A.CHANNELS ("current" keeps whatever
-- channel the chat box is on).

PBS_QUICK_CHAT = {
	name = "PBsQuickChat",
	baseTitle = "PB’s Quick Chat",
	chatName = "PB’s Quick Chat",
	author = "PinkBanther",
	version = "0.2.0",
	slash = "/pbquickchat",
	shortSlash = "/pbqc",
	NUM_SLOTS = 8, -- the size of one wheel page (ACTION_BAR_UTILITY_BAR_SIZE)
	MAX_NAME_CHARS = 12, -- what the wheel's centre label has room for
	MAX_TEXT_CHARS = 120, -- the settings text box's limit ...
	MAX_TEXT_BYTES = 350, -- ... and the chat box's (351), counted in bytes so either reading of "characters" holds
	MIN_DELAY_MS = 0,
	MAX_DELAY_MS = 3000,
	COMMAND_DELAY_MS = 2000, -- a command is typed into the very box the message is about to go in: wait longer
	-- the icon of every entry: the client's own chat glyph (the gamepad player menu's text chat entry)
	ICON = "EsoUI/Art/MenuBar/Gamepad/gp_playerMenu_icon_textChat.dds",
	defaults = {
		wheel = true, -- the extra page on the utility wheel
		wheelHead = false, -- the page is the first one of the wheel, not the one after Emotes (read at install time)
		wheelFirst = false, -- open the wheel on that page
		coop = true, -- ask PB's ChatAssistant (when it is there) to let go of the Enter key while the box opens
		delayMs = 600, -- wait after the wheel closes before the chat box opens (the console keyboard needs a fresh focus)
		slot = 1, -- the slot the settings panel is working on
	},
}
local A = PBS_QUICK_CHAT
local S = PBS_QUICK_CHAT_STRINGS

-- The version comes from the manifest, the same way PB's other add-ons read it.
do
	local manager = GetAddOnManager and GetAddOnManager()
	if manager then
		for index = 1, manager:GetNumAddOns() do
			local name, title = manager:GetAddOnInfo(index)
			if name == A.name and title then
				local plain = title:gsub("|c%x%x%x%x%x%x", ""):gsub("|r", "")
				A.version = plain:match("(%d+[%d%.]*)%s*$") or A.version
				break
			end
		end
	end
end
A.title = A.baseTitle .. " " .. A.version

-- The channels a message can be sent to, in the order of the settings drop-down. `const` is the client's
-- constant; one that does not exist (an older or newer API) drops that channel from the list.
A.CHANNELS = {
	{ key = "current" },
	{ key = "say", const = "CHAT_CHANNEL_SAY" },
	{ key = "yell", const = "CHAT_CHANNEL_YELL" },
	{ key = "zone", const = "CHAT_CHANNEL_ZONE" },
	{ key = "party", const = "CHAT_CHANNEL_PARTY" },
	{ key = "guild1", const = "CHAT_CHANNEL_GUILD_1", guild = true },
	{ key = "guild2", const = "CHAT_CHANNEL_GUILD_2", guild = true },
	{ key = "guild3", const = "CHAT_CHANNEL_GUILD_3", guild = true },
	{ key = "guild4", const = "CHAT_CHANNEL_GUILD_4", guild = true },
	{ key = "guild5", const = "CHAT_CHANNEL_GUILD_5", guild = true },
	{ key = "officer1", const = "CHAT_CHANNEL_OFFICER_1", guild = true },
	{ key = "officer2", const = "CHAT_CHANNEL_OFFICER_2", guild = true },
	{ key = "officer3", const = "CHAT_CHANNEL_OFFICER_3", guild = true },
	{ key = "officer4", const = "CHAT_CHANNEL_OFFICER_4", guild = true },
	{ key = "officer5", const = "CHAT_CHANNEL_OFFICER_5", guild = true },
}
A.CHANNEL_BY_KEY = {}
for _, def in ipairs(A.CHANNELS) do
	A.CHANNEL_BY_KEY[def.key] = def
end

-- ---------------------------------------------------------------------------------------
-- Text that the player typed
--
-- Lua's character classes (%s %c %a ...) and string.lower/upper ask the C library, which answers by the
-- process's locale. On a desk that is "C" and only ASCII counts. A game client need not run in "C": in a
-- Latin-1 locale 0x80-0x9F are control characters and 0xA0 and 0x85 are spaces -- and those are exactly the
-- bytes inside Japanese UTF-8 (こ is E3 81 93, だ is E3 81 A0). A message run through "%c" or "%s" can come out
-- cut in the middle of a character, and invalid UTF-8 handed to the client's text controls is the likely way
-- PB's Translate crashed a PS5 (0.4.16). This add-on is nothing but typed Japanese text on its way to the chat
-- box, so none of it uses a class or lower/upper: characters are read by byte value, a message is made of
-- whole, well-formed characters, and `/pbqc status` reports what this console's locale does.
-- ---------------------------------------------------------------------------------------

-- The length in bytes of the well-formed UTF-8 character that starts at index i, or nil when none does.
-- (Overlong forms, surrogates and anything above U+10FFFF are refused.)
local function CharSize(text, i)
	local b = text:byte(i)
	if not b then
		return nil
	end
	if b < 0x80 then
		return 1
	end
	local size, low, high
	if b >= 0xC2 and b <= 0xDF then
		size, low, high = 2, 0x80, 0xBF
	elseif b == 0xE0 then
		size, low, high = 3, 0xA0, 0xBF
	elseif b == 0xED then
		size, low, high = 3, 0x80, 0x9F
	elseif b >= 0xE1 and b <= 0xEF then
		size, low, high = 3, 0x80, 0xBF
	elseif b == 0xF0 then
		size, low, high = 4, 0x90, 0xBF
	elseif b >= 0xF1 and b <= 0xF3 then
		size, low, high = 4, 0x80, 0xBF
	elseif b == 0xF4 then
		size, low, high = 4, 0x80, 0x8F
	else
		return nil
	end
	local second = text:byte(i + 1)
	if not second or second < low or second > high then
		return nil
	end
	for k = i + 2, i + size - 1 do
		local c = text:byte(k)
		if not c or c < 0x80 or c > 0xBF then
			return nil
		end
	end
	return size
end

-- Is the whole string well-formed UTF-8?
function A.IsValidUTF8(text)
	if type(text) ~= "string" then
		return false
	end
	local i, length = 1, #text
	while i <= length do
		local size = CharSize(text, i)
		if not size then
			return false
		end
		i = i + size
	end
	return true
end

-- The well-formed characters of a string, in order; every byte that belongs to none is left out.
local function Characters(text)
	local list, i, length = {}, 1, #text
	while i <= length do
		local size = CharSize(text, i)
		if size then
			list[#list + 1] = text:sub(i, i + size - 1)
			i = i + size
		else
			i = i + 1
		end
	end
	return list
end

-- The string with its broken bytes dropped, and whether anything was dropped.
function A.SanitizeUTF8(text)
	text = tostring(text or "")
	if A.IsValidUTF8(text) then
		return text, false
	end
	return table.concat(Characters(text)), true
end

local IDEOGRAPHIC_SPACE, NO_BREAK_SPACE = "\227\128\128", "\194\160"
local LINE_SEPARATOR, PARAGRAPH_SEPARATOR = "\226\128\168", "\226\128\169"
local ELLIPSIS = "\226\128\166" -- U+2026

local function IsBlank(ch)
	return ch == " " or ch == IDEOGRAPHIC_SPACE or ch == NO_BREAK_SPACE
end

-- Text for display and saving: whole characters only, control characters (C0, DEL, C1, line and paragraph
-- separators) become spaces, the ends are trimmed of spaces (ASCII, ideographic, no-break). `maxChars` and
-- `maxBytes` cut on a character boundary.
function A.CleanText(text, maxChars, maxBytes)
	-- only text and numbers are text: a table or a boolean from a damaged file is nothing, never "table: 0x..."
	if type(text) == "number" then
		text = tostring(text)
	elseif type(text) ~= "string" then
		text = ""
	end
	local chars = Characters(text)
	for i, ch in ipairs(chars) do
		local b = ch:byte(1)
		if b < 32 or b == 127 or (b == 0xC2 and ch:byte(2) < 0xA0) or ch == LINE_SEPARATOR or ch == PARAGRAPH_SEPARATOR then
			chars[i] = " "
		end
	end
	local first, last = 1, #chars
	while first <= last and IsBlank(chars[first]) do
		first = first + 1
	end
	if maxChars and last - first + 1 > maxChars then
		last = first + maxChars - 1
	end
	if maxBytes then
		local bytes = 0
		for i = first, last do
			bytes = bytes + #chars[i]
			if bytes > maxBytes then
				last = i - 1
				break
			end
		end
	end
	while last >= first and IsBlank(chars[last]) do
		last = last - 1
	end
	return table.concat(chars, "", first, last)
end

-- A slot's name as typed in the panel or after /pbqc name.
function A.CleanName(text)
	return A.CleanText(text, A.MAX_NAME_CHARS)
end

-- A slot's message: what the chat box will hold.
function A.CleanMessage(text)
	return A.CleanText(text, A.MAX_TEXT_CHARS, A.MAX_TEXT_BYTES)
end

-- The first `count` characters of a text, with an ellipsis when something was cut.
function A.ShortText(text, count)
	local chars = Characters(tostring(text or ""))
	if #chars <= count then
		return table.concat(chars)
	end
	return table.concat(chars, "", 1, count) .. ELLIPSIS
end

-- ASCII-only lower case; every other byte is left exactly as it was.
function A.LowerAscii(text)
	return (tostring(text or ""):gsub("[A-Z]", function(c)
		return string.char(c:byte() + 32)
	end))
end

local function IsAsciiBlank(b)
	return b == 32 or b == 9 or b == 10 or b == 13
end

-- The words of a command line, split at ASCII blanks only.
function A.SplitWords(input)
	input = tostring(input or "")
	local words, from = {}, nil
	for i = 1, #input + 1 do
		local b = input:byte(i)
		if b == nil or IsAsciiBlank(b) then
			if from then
				words[#words + 1] = input:sub(from, i - 1)
				from = nil
			end
		elseif not from then
			from = i
		end
	end
	return words
end

-- What this Lua's locale does to UTF-8 bytes (one byte at a time, never on the player's text). The answers
-- are all `false` in the "C" locale; `true` anywhere means a class would have cut a Japanese character.
function A.ProbeLocale()
	local function matches(byte, class)
		return string.char(byte):find(class) ~= nil
	end
	local ok, result = pcall(function()
		return {
			control81 = matches(0x81, "%c"),
			space85 = matches(0x85, "%s"),
			spaceA0 = matches(0xA0, "%s"),
			letterE3 = matches(0xE3, "%a"),
			lowerChangesC3 = string.lower(string.char(0xC3)) ~= string.char(0xC3),
		}
	end)
	return ok and result or nil
end

-- ---------------------------------------------------------------------------------------
-- Channels
-- ---------------------------------------------------------------------------------------

-- Resolve the constants once: a missing one drops that channel instead of failing.
function A:ResolveConstants()
	local list = {}
	for _, def in ipairs(self.CHANNELS) do
		def.id = def.const and type(_G[def.const]) == "number" and _G[def.const] or nil
		if def.key == "current" or def.id ~= nil then
			list[#list + 1] = def
		end
	end
	self.channelList = list
end

function A.IsChannelKey(key)
	return type(key) == "string" and A.CHANNEL_BY_KEY[key] ~= nil
end

-- The channel's name as the player reads it: the game's own word (GetChannelName) when it has one, ours
-- otherwise. A guild channel also names the guild when the game says it.
function A:ChannelName(key)
	local def = self.CHANNEL_BY_KEY[key]
	if not def or def.key == "current" then
		return S.channelCurrent
	end
	local ours = S["channel_" .. key] or key
	local theirs
	if def.id and type(GetChannelName) == "function" then
		local ok, value = pcall(GetChannelName, def.id)
		if ok and type(value) == "string" then
			theirs = A.CleanText(value, 24)
		end
	end
	if not theirs or theirs == "" then
		return ours
	end
	if def.guild then
		return string.format(S.channelNamed, ours, theirs)
	end
	return theirs
end

-- ---------------------------------------------------------------------------------------
-- Saved variables
--
-- `pending` is written before a guarded game call (and while the wheel page is up) and cleared when it
-- returns. If the game shows the UI error screen and the player reloads, the file still says "pending".
-- That is a hint, not proof: the file is also written on a normal logout, and a hard crash writes nothing at
-- all. So a leftover marker is only a *strike* against its group (`strikes`); the group is switched off
-- (`probe[group] = "bad"`) after STRIKES_TO_DISABLE strikes in a row, and any clean use clears the count. A
-- console has no comfortable way to type /pbqc retry, so the settings panel has a button for it.
-- ---------------------------------------------------------------------------------------

local SCHEMA = 1
local STRIKES_TO_DISABLE = 2
A.STRIKES_TO_DISABLE = STRIKES_TO_DISABLE

local function Clamp(value, low, high)
	value = tonumber(value) or low
	return math.max(low, math.min(high, math.floor(value)))
end

function A:Sanitize()
	local sv = self.sv
	for key, default in pairs(self.defaults) do
		if type(sv[key]) ~= type(default) then
			sv[key] = default
		end
	end
	sv.slot = Clamp(sv.slot, 1, self.NUM_SLOTS)
	sv.delayMs = Clamp(sv.delayMs, self.MIN_DELAY_MS, self.MAX_DELAY_MS)
	if type(sv.probe) ~= "table" then
		sv.probe = {}
	end
	if type(sv.strikes) ~= "table" then
		sv.strikes = {}
	end

	-- what this start-up found, for /pbqc status
	local startup = { stale = nil, healed = 0 }
	self.startup = startup

	if sv.schema ~= SCHEMA then
		sv.probe, sv.strikes, sv.pending = {}, {}, nil
		sv.schema = SCHEMA
	end

	local pending = sv.pending
	sv.pending = nil
	if type(pending) == "string" then
		local group = pending == "wheelUse" and "wheel" or pending
		local count = (tonumber(sv.strikes[group]) or 0) + 1
		sv.strikes[group] = count
		startup.stale = pending
		if count >= STRIKES_TO_DISABLE then
			sv.probe[group] = "bad"
		end
	end

	-- A message that was saved by another version, or edited by hand in the file, may hold bytes that are not
	-- UTF-8 (see "Text that the player typed"); one of those on the wheel, in the panel or in the chat box is a
	-- crash waiting to happen. Make every slot well-formed again.
	if type(sv.slots) ~= "table" then
		sv.slots = {}
	end
	for i = 1, self.NUM_SLOTS do
		local slot = sv.slots[i]
		if type(slot) ~= "table" then
			slot = {}
			sv.slots[i] = slot
		end
		local name, text = A.CleanName(slot.name), A.CleanMessage(slot.text)
		local channel = A.IsChannelKey(slot.channel) and slot.channel or "current"
		if (slot.name ~= nil and slot.name ~= name) or (slot.text ~= nil and slot.text ~= text) or (slot.channel ~= nil and slot.channel ~= channel) then
			startup.healed = startup.healed + 1
		end
		slot.name, slot.text, slot.channel = name, text, channel
	end
end

-- Forget what was learned about the calls (the panel's retry button, /pbqc retry).
function A:Retry()
	self.sv.probe, self.sv.strikes, self.sv.pending = {}, {}, nil
end

-- May this group of calls be used? ("wheel" or "chat")
function A:CheckGroup(group)
	if self.sv.probe[group] == "bad" then
		return false, S.whyEarlier
	end
	return true
end

function A:Set(key, value)
	local default = self.defaults[key]
	if default == nil or type(value) ~= type(default) then
		return
	end
	if key == "delayMs" then
		value = Clamp(value, self.MIN_DELAY_MS, self.MAX_DELAY_MS)
	elseif key == "slot" then
		value = Clamp(value, 1, self.NUM_SLOTS)
	end
	self.sv[key] = value
end

-- ---------------------------------------------------------------------------------------
-- The slots
-- ---------------------------------------------------------------------------------------

function A:GetSlot(index)
	return self.sv and self.sv.slots and self.sv.slots[index]
end

function A:HasText(index)
	local slot = self:GetSlot(index)
	return slot ~= nil and slot.text ~= nil and slot.text ~= ""
end

function A:SetSlotText(index, text)
	local slot = self:GetSlot(index)
	if slot then
		slot.text = A.CleanMessage(text)
	end
end

function A:SetSlotName(index, name)
	local slot = self:GetSlot(index)
	if slot then
		slot.name = A.CleanName(name)
	end
end

function A:SetSlotChannel(index, key)
	local slot = self:GetSlot(index)
	if slot and A.IsChannelKey(key) then
		slot.channel = key
	end
end

function A:ClearSlot(index)
	local slot = self:GetSlot(index)
	if slot then
		slot.name, slot.text, slot.channel = "", "", "current"
	end
end

-- What the wheel shows for a slot: its name, or the start of its message.
function A:WheelName(index)
	local slot = self:GetSlot(index)
	if not slot or slot.text == "" then
		return ""
	end
	if slot.name ~= "" then
		return slot.name
	end
	return A.ShortText(slot.text, A.MAX_NAME_CHARS)
end

-- One line for the settings drop-down and the overview.
function A:SlotLabel(index)
	if not self:HasText(index) then
		return string.format(S.slotLabel, index, S.slotEmpty)
	end
	return string.format(S.slotLabel, index, self:WheelName(index))
end
