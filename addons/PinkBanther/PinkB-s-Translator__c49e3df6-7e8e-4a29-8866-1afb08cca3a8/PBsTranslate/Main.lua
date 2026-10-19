-- PB's Translate
-- Author: PinkBanther
--
-- English chat, with a Japanese line under it.
--
-- An add-on cannot reach an external translation service. Translation runs entirely
-- happens in this folder: a dictionary of a couple of thousand English words, chat shorthand
-- and ESO terms (dict/), and a small rule-based grammar that turns English word order into
-- Japanese word order (Tokenizer.lua, Grammar.lua, Conjugate.lua). The result is a rough,
-- literal rendering -- enough to follow what a group is saying, not a polished translation.
--
-- ---------------------------------------------------------------------------------------
-- HOW A MESSAGE IS PICKED UP
-- ---------------------------------------------------------------------------------------
--
-- CHAT_ROUTER (esoui/ingame/chatsystem/chathandlers.lua) formats every chat event and then
-- fires one callback that both chat UIs -- keyboard and gamepad -- listen on:
--
--     self:FireCallbacks("FormattedChatMessage", formattedEventText, eventCategory,
--         targetChannel, fromDisplayName, rawMessageText, formattedNarrationText, overrideColorDef)
--
-- The callback listener adds a second line in normal mode. Translation-only mode registers
-- a channel formatter around the existing formatter, replacing only its message body before
-- either chat UI receives it. Sender/channel markup and original raw text are preserved.
-- A formatter that hides a message is respected; failed translations keep the original.
--
-- ---------------------------------------------------------------------------------------
-- WHEN A LINE IS LEFT ALONE
-- ---------------------------------------------------------------------------------------
--
-- By default, show partial translations and leave unknown words as typed. Players can
-- raise the known-word threshold to filter them. Lines with no known words or no non-ASCII
-- output are still skipped.
-- ---------------------------------------------------------------------------------------

if PBS_TRANSLATE then
	return
end

local T = PBsTranslate
if not T or not T.Translate then
	return
end

local addon = {
	name = "PBsTranslate",
	engine = T,
}

local em = EVENT_MANAGER

local DISPLAY_NAME = "PB’s Translate"
local AUTHOR = "PinkBanther"
local SLASH = "/pbtr"
local TRANSLATE_SLASH = "/jp"

local function ReadManifestVersion()
	local manager = GetAddOnManager and GetAddOnManager()
	if not manager then
		return ""
	end
	for index = 1, manager:GetNumAddOns() do
		local name, title = manager:GetAddOnInfo(index)
		if name == addon.name and title then
			local plain = title:gsub("|c%x%x%x%x%x%x", ""):gsub("|r", "")
			return plain:match("([%d]+[%d%.]*%-[%w%.%-]+)%s*$") or plain:match("([%d]+[%d%.]*)%s*$") or ""
		end
	end
	return ""
end

addon.author = AUTHOR
addon.version = ReadManifestVersion()
addon.title = addon.version ~= "" and (DISPLAY_NAME .. " " .. addon.version) or DISPLAY_NAME
addon.slash = SLASH

-- ---------------------------------------------------------------------------------------
-- Output
-- ---------------------------------------------------------------------------------------

local function Say(text)
	if CHAT_ROUTER and CHAT_ROUTER.AddSystemMessage then
		CHAT_ROUTER:AddSystemMessage(text)
	elseif d then
		d(text)
	end
end

local PREFIX = "|cFF69B4" .. DISPLAY_NAME .. "|r: "

local function Print(text, ...)
	if select("#", ...) > 0 then
		local ok, formatted = pcall(string.format, text, ...)
		text = ok and formatted or text
	end
	Say(PREFIX .. text)
end

addon.Say = Say
addon.Print = Print

-- ---------------------------------------------------------------------------------------
-- Settings
--
-- enabled          master switch
-- translateOwn     your own messages (the echo of what you sent, and whispers you send)
-- translateOthers  everyone else's
-- translateZone    zone chat, which on a busy megaserver is most of the traffic
-- minKnownPercent  how much of a line has to be dictionary words before it is translated
-- userWords        [english] = "japanese" or "pos:japanese", added with /pbtr add
-- direction        "en2ja": English chat gets a Japanese line; "ja2en": Japanese chat gets
--                  an English line (the smaller, callout-sized JaToEn dictionary)
-- ---------------------------------------------------------------------------------------

local DEFAULTS = {
	enabled = true,
	translateOwn = true,
	translateOthers = true,
	translateZone = true,
	translationOnly = false,
	minKnownPercent = 0,
	color = "9FD8FF",
	userWords = {},
	direction = "en2ja",
}

addon.DEFAULTS = DEFAULTS

-- Session counters, for /pbtr: they answer "is it doing anything?" from inside the game.
addon.stats = { seen = 0, translated = 0, skipped = 0, errors = 0 }

-- Diagnostics, for /pbtr probe. A console test round is expensive, so one run of the command
-- has to say where a message stopped: never reached the add-on, reached it without text,
-- was judged not worth translating, or was translated and failed to reach the window.
addon.diag = {
	callbacks = 0,      -- every FormattedChatMessage the listener saw
	withText = 0,       -- ... of which carried player text
	outputOk = 0,       -- translations handed to the chat window with their own category
	outputFallback = 0, -- ... that had to fall back to a system message
	lastOutputError = nil,
	recent = {},        -- the last few decisions, newest last
}
addon.loadSteps = {}

-- ---------------------------------------------------------------------------------------
-- Channels
-- ---------------------------------------------------------------------------------------

local ZONE_CATEGORIES = {}
local SKIPPED_CATEGORIES = {}
local OWN_CATEGORIES = {}

local function Declare(set, constant)
	if type(constant) == "number" then
		set[constant] = true
	end
end

Declare(ZONE_CATEGORIES, CHAT_CATEGORY_ZONE)
Declare(ZONE_CATEGORIES, CHAT_CATEGORY_ZONE_ENGLISH)
Declare(ZONE_CATEGORIES, CHAT_CATEGORY_ZONE_FRENCH)
Declare(ZONE_CATEGORIES, CHAT_CATEGORY_ZONE_GERMAN)
Declare(ZONE_CATEGORIES, CHAT_CATEGORY_ZONE_JAPANESE)
Declare(ZONE_CATEGORIES, CHAT_CATEGORY_ZONE_RUSSIAN)
Declare(ZONE_CATEGORIES, CHAT_CATEGORY_ZONE_SPANISH)
Declare(ZONE_CATEGORIES, CHAT_CATEGORY_ZONE_CHINESE_S)

-- NPC speech is English only on an English client, and it is not chat.
Declare(SKIPPED_CATEGORIES, CHAT_CATEGORY_MONSTER_SAY)
Declare(SKIPPED_CATEGORIES, CHAT_CATEGORY_MONSTER_YELL)
Declare(SKIPPED_CATEGORIES, CHAT_CATEGORY_MONSTER_WHISPER)
Declare(SKIPPED_CATEGORIES, CHAT_CATEGORY_MONSTER_EMOTE)
Declare(SKIPPED_CATEGORIES, CHAT_CATEGORY_SYSTEM)

-- A whisper you send arrives with the RECIPIENT as fromDisplayName.
Declare(OWN_CATEGORIES, CHAT_CATEGORY_WHISPER_OUTGOING)

local function SameAccount(a, b)
	if type(a) ~= "string" or type(b) ~= "string" or a == "" or b == "" then
		return false
	end
	return (a:gsub("^@", "")) == (b:gsub("^@", ""))
end

function addon:IsOwn(category, fromDisplayName)
	if category and OWN_CATEGORIES[category] then
		return true
	end
	local mine = type(GetDisplayName) == "function" and GetDisplayName() or nil
	return SameAccount(fromDisplayName, mine)
end

-- ---------------------------------------------------------------------------------------
-- The decision and the translation
-- ---------------------------------------------------------------------------------------

local function ContainsNonASCII(text)
	if type(text) ~= "string" then
		return false
	end
	-- Inspect UTF-8 bytes directly, without a non-ASCII character-class pattern.
	for i = 1, #text do
		if string.byte(text, i) >= 128 then
			return true
		end
	end
	return false
end

-- Inspect code points without depending on utf8 (unavailable in Lua 5.1) or locale.
-- Han also occurs in Chinese; mixed Han/English chat is intentionally excluded.
local function ContainsJapanese(text)
	local i = 1
	while i <= #text do
		local a, b, c, d = text:byte(i, i + 3)
		local size = a >= 0xE0 and a <= 0xEF and 3
			or a >= 0xF0 and a <= 0xF4 and 4 or 1
		local cp
		if size >= 3 and b and c and b >= 0x80 and b <= 0xBF and c >= 0x80 and c <= 0xBF then
			if size == 3 then
				cp = (a - 0xE0) * 4096 + (b - 0x80) * 64 + c - 0x80
			elseif d and d >= 0x80 and d <= 0xBF then
				cp = (a - 0xF0) * 262144 + (b - 0x80) * 4096 + (c - 0x80) * 64 + d - 0x80
			end
		end
		if cp and ((cp >= 0x3040 and cp <= 0x30FF) -- hiragana / katakana
			or (cp >= 0x31F0 and cp <= 0x31FF)
			or (cp >= 0xFF66 and cp <= 0xFF9F) -- half-width kana
			or (cp >= 0x3400 and cp <= 0x4DBF) or (cp >= 0x4E00 and cp <= 0x9FFF)
			or (cp >= 0xF900 and cp <= 0xFAFF)
			or (cp >= 0x20000 and cp <= 0x2FA1F) or (cp >= 0x30000 and cp <= 0x323AF)
			or (cp >= 0x1B000 and cp <= 0x1B16F)
			or cp == 0x3005 or cp == 0x3006 or cp == 0x3007) then
			return true
		end
		i = i + (cp and size or 1)
	end
	return false
end

function addon:Direction()
	return self.sv and self.sv.direction == "ja2en" and "ja2en" or "en2ja"
end

local function HasASCIILetter(text)
	return type(text) == "string" and text:find("[A-Za-z]") ~= nil
end

-- Japanese chat, into English. The same gates as the other way round: something read, the
-- known-word threshold, valid UTF-8, and an English letter in the result.
function addon:TranslateJaLine(text)
	if not ContainsNonASCII(text) then
		return nil, "no Japanese"
	end
	local ok, english, unknown, known = pcall(T.TranslateJaToEn, text)
	if not ok then
		self.stats.errors = self.stats.errors + 1
		self.lastError = tostring(english)
		return nil, "error"
	end
	known = known or 0
	local total = known + #(unknown or {})
	if known == 0 or total == 0 then
		return nil, "no known words"
	end
	local percent = known * 100 / total
	if percent < (self.sv and self.sv.minKnownPercent or DEFAULTS.minKnownPercent) then
		return nil, string.format("%d%% known", math.floor(percent))
	end
	if not T.IsValidUTF8(english) then
		return nil, "invalid text"
	end
	if not HasASCIILetter(english) then
		return nil, "nothing to translate"
	end
	return english, nil, { known = known, unknown = #unknown }
end

-- Returns the translated line in the chosen direction, or nil and the reason it was not
-- produced.
function addon:TranslateLine(text)
	if type(text) ~= "string" or text == "" then
		return nil, "empty"
	end
	if self:Direction() == "ja2en" then
		return self:TranslateJaLine(text)
	end
	if ContainsJapanese(text) then
		return nil, "contains Japanese"
	end
	if not text:find("[A-Za-z]") then
		return nil, "no letters"
	end

	local ok, ja, stats = pcall(T.Translate, text)
	if not ok then
		self.stats.errors = self.stats.errors + 1
		self.lastError = tostring(ja)
		return nil, "error"
	end

	local total = stats.known + stats.unknown
	if stats.known == 0 or total == 0 then
		return nil, "no known words"
	end
	local percent = stats.known * 100 / total
	if percent < (self.sv and self.sv.minKnownPercent or DEFAULTS.minKnownPercent) then
		return nil, string.format("%d%% known", math.floor(percent))
	end
	-- Never hand the chat window broken UTF-8 (see Lexicon.lua, byte-safe text helpers).
	if not T.IsValidUTF8(ja) then
		return nil, "invalid text"
	end
	-- Nothing but ASCII means nothing got translated: "vMA", a name, a number.
	if not ContainsNonASCII(ja) then
		return nil, "nothing to translate"
	end
	return ja, nil, stats
end

function addon:ShouldTranslate(category, fromDisplayName)
	return self:SkipReason(category, fromDisplayName) == nil
end

local function NormalizeColor(value)
	if type(value) ~= "string" then return nil end
	value = value:gsub("^#", "")
	if #value == 6 and value:match("^%x+$") then return value:upper() end
end

function addon:GetTranslationColor()
	return NormalizeColor(self.sv and self.sv.color) or DEFAULTS.color
end

function addon:GetTranslationRGB(hex)
	hex = hex or self:GetTranslationColor()
	return tonumber(hex:sub(1, 2), 16) / 255,
		tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255, 1
end

function addon:SetTranslationRGB(r, g, b)
	local function Byte(value)
		return math.floor(math.max(0, math.min(1, value)) * 255 + 0.5)
	end
	self.sv.color = string.format("%02X%02X%02X", Byte(r), Byte(g), Byte(b))
end

-- The prefix says which way the line went. direction defaults to the chat setting; /jp,
-- which always goes into Japanese, passes "en2ja".
function addon:FormatTranslation(text, direction)
	local prefix = (direction or self:Direction()) == "ja2en" and SI_PBSTR_LINE_PREFIX_EN or SI_PBSTR_LINE_PREFIX
	return string.format("|c%s%s %s|r", self:GetTranslationColor(), GetString(prefix), text)
end

function addon:SetDirection(direction)
	self.sv.direction = direction == "ja2en" and "ja2en" or "en2ja"
end

function addon:DirectionLabel()
	return GetString(self:Direction() == "ja2en" and SI_PBSTR_DIRECTION_TO_EN or SI_PBSTR_DIRECTION_TO_JA)
end

local MAX_RECENT = 5

function addon:NoteDecision(category, fromDisplayName, text, reason)
	local recent = self.diag.recent
	recent[#recent + 1] = {
		category = category,
		own = self:IsOwn(category, fromDisplayName),
		text = type(text) == "string" and text:sub(1, 40) or "",
		reason = reason,
	}
	if #recent > MAX_RECENT then
		table.remove(recent, 1)
	end
	if self.sv and self.sv.debug then
		Say(string.format("|c888888[pbtr] cat=%s own=%s %s: %s|r", tostring(category),
			tostring(recent[#recent].own), reason, recent[#recent].text))
	end
end

-- Why a message would not be translated, or nil if it should be.
function addon:SkipReason(category, fromDisplayName)
	local sv = self.sv
	if not sv then
		return "no saved variables"
	end
	if not sv.enabled then
		return "switched off"
	end
	if category and SKIPPED_CATEGORIES[category] then
		return "system/NPC category"
	end
	if category and ZONE_CATEGORIES[category] and not sv.translateZone then
		return "zone chat off"
	end
	if self:IsOwn(category, fromDisplayName) then
		return not sv.translateOwn and "own messages off" or nil
	end
	return not sv.translateOthers and "others off" or nil
end

function addon:OutputTranslation(ja, category, fromDisplayName)
	local line = self:FormatTranslation(ja)
	-- Keep the original category so the same tab filters apply to both lines.
	-- No raw text prevents recursion; no target channel avoids adding reply targets again.
	local ok, err = pcall(CHAT_ROUTER.FireCallbacks, CHAT_ROUTER, "FormattedChatMessage", line,
		category, nil, fromDisplayName, nil)
	if ok then
		self.diag.outputOk = self.diag.outputOk + 1
		return
	end
	self.diag.lastOutputError = tostring(err)
	self.diag.outputFallback = self.diag.outputFallback + 1
	Say(line)
end

function addon:OnFormattedChatMessage(formattedText, category, _, fromDisplayName, rawMessageText)
	self.diag.callbacks = self.diag.callbacks + 1
	-- System messages, including this add-on's own lines, carry no raw text.
	if type(rawMessageText) ~= "string" then
		return
	end
	self.diag.withText = self.diag.withText + 1
	local handled = self.formattedDecision
	if handled and handled.formatted == formattedText and handled.raw == rawMessageText then
		self.formattedDecision = nil
		return
	end
	local skip = self:SkipReason(category, fromDisplayName)
	if skip then
		self:NoteDecision(category, fromDisplayName, rawMessageText, skip)
		return
	end
	self.stats.seen = self.stats.seen + 1
	local ja, reason = self:TranslateLine(rawMessageText)
	if not ja then
		self.stats.skipped = self.stats.skipped + 1
		self:NoteDecision(category, fromDisplayName, rawMessageText, reason or "skipped")
		return
	end
	self.stats.translated = self.stats.translated + 1
	self:NoteDecision(category, fromDisplayName, rawMessageText, "translated")
	self:OutputTranslation(ja, category, fromDisplayName)
end

function addon:InstallListener()
	if self.installed then
		return true
	end
	if type(CHAT_ROUTER) ~= "table" or type(CHAT_ROUTER.RegisterCallback) ~= "function" then
		return false
	end
	CHAT_ROUTER:RegisterCallback("FormattedChatMessage", function(...)
		-- A fault in the translator must never take a chat message down with it.
		local ok, message = pcall(self.OnFormattedChatMessage, self, ...)
		if not ok then
			self.stats.errors = self.stats.errors + 1
			self.lastError = tostring(message)
		end
	end)
	self.installed = true
	return true
end

-- Replace the last literal occurrence (the sender may happen to have the same name).
local function ReplaceBody(formatted, raw, replacement)
	if type(formatted) ~= "string" or raw == "" then return nil end
	local first, last, offset = nil, nil, 1
	while true do
		local a, b = formatted:find(raw, offset, true)
		if not a then break end
		first, last, offset = a, b, b + 1
	end
	if not first then return nil end
	return formatted:sub(1, first - 1) .. replacement .. formatted:sub(last + 1)
end

function addon:ReplaceFormattedMessage(formatted, raw, category, sender, narration)
	if not self.sv or not self.sv.translationOnly or not formatted or type(raw) ~= "string" then return end
	if self:SkipReason(category, sender) then return end
	-- Don't alter an unfamiliar formatter layout: the callback can still add a second line.
	if not ReplaceBody(formatted, raw, "") then return end
	local ja, reason = self:TranslateLine(raw)
	local result = ja and ReplaceBody(formatted, raw, self:FormatTranslation(ja)) or formatted
	local spoken = ja and (ReplaceBody(narration, raw, ja) or (narration and ja)) or narration
	self.stats.seen = self.stats.seen + 1
	if ja then
		self.stats.translated = self.stats.translated + 1
		self.diag.outputOk = self.diag.outputOk + 1
	else
		self.stats.skipped = self.stats.skipped + 1
	end
	self:NoteDecision(category, sender, raw, ja and "replaced" or reason or "skipped")
	-- Preserve raw text for other listeners, but don't translate it again in our own listener.
	self.formattedDecision = { formatted = result, raw = raw }
	return result, spoken
end

function addon:InstallReplacementFormatter()
	if not CHAT_ROUTER or type(CHAT_ROUTER.GetRegisteredMessageFormatters) ~= "function"
		or type(CHAT_ROUTER.RegisterMessageFormatter) ~= "function"
		or type(ZO_ChatSystem_GetEventCategoryMappings) ~= "function" then
		return false, "chat formatter API unavailable"
	end
	local formatters = CHAT_ROUTER:GetRegisteredMessageFormatters()
	local original = formatters and formatters[EVENT_CHAT_MESSAGE_CHANNEL]
	if type(original) ~= "function" then return false, "channel formatter not ready" end
	if original == self.replacementFormatter then return true end
	local mappings = ZO_ChatSystem_GetEventCategoryMappings()
	local categories = mappings and mappings[EVENT_CHAT_MESSAGE_CHANNEL]
	if not categories then return false, "channel category mappings not ready" end
	local wrapper
	wrapper = function(messageType, ...)
		-- Each wrapper captures its predecessor once. Older generations become pass-through
		-- even if another add-on kept them inside its own formatter chain.
		local formatted, target, sender, raw, narration, color = original(messageType, ...)
		if self.replacementFormatter ~= wrapper then
			return formatted, target, sender, raw, narration, color
		end
		local ok, replacement, spoken = pcall(self.ReplaceFormattedMessage, self,
			formatted, raw, categories[messageType], sender, narration)
		if ok and replacement then
			return replacement, target, sender, raw, spoken, color
		elseif not ok then
			self.stats.errors = self.stats.errors + 1
			self.lastError = tostring(replacement)
		end
		return formatted, target, sender, raw, narration, color
	end
	CHAT_ROUTER:RegisterMessageFormatter(EVENT_CHAT_MESSAGE_CHANNEL, wrapper)
	local registered = CHAT_ROUTER:GetRegisteredMessageFormatters()
	if not registered or registered[EVENT_CHAT_MESSAGE_CHANNEL] ~= wrapper then
		return false, "formatter registration was not retained"
	end
	self.replacementFormatter = wrapper
	return true
end

function addon:TryReplacementFormatter(quiet)
	local ok, installed, reason = pcall(self.InstallReplacementFormatter, self)
	if ok and installed then
		self.diag.replacementError = nil
		return true
	end
	self.diag.replacementError = ok and (reason or "registration failed") or tostring(installed)
	if not quiet then Print(GetString(SI_PBSTR_REPLACE_UNAVAILABLE)) end
	return false
end

function addon:ScheduleReplacementCheck()
	local name = self.name .. "ReplacementRetry"
	if type(em.RegisterForUpdate) ~= "function" or type(em.UnregisterForUpdate) ~= "function" then return end
	em:UnregisterForUpdate(name)
	if not self.sv.translationOnly then return end
	local attempts = 0
	-- Bounded checks after activation also catch formatters registered later in that event.
	em:RegisterForUpdate(name, 1000, function()
		attempts = attempts + 1
		if not self.sv.translationOnly then em:UnregisterForUpdate(name); return end
		self:TryReplacementFormatter(attempts < 5)
		if attempts >= 5 then em:UnregisterForUpdate(name) end
	end)
end

function addon:SetTranslationOnly(enabled, quiet)
	-- Keep the requested preference separate from temporary registration availability.
	self.sv.translationOnly = enabled
	local installed = not enabled or self:TryReplacementFormatter(quiet)
	self:ScheduleReplacementCheck()
	return installed
end

-- ---------------------------------------------------------------------------------------
-- The player's own dictionary
-- ---------------------------------------------------------------------------------------

function addon:ApplyUserWords()
	local ok = T.SetUserEntries(self.sv.userWords)
	if not ok then Print("%s", GetString(SI_PBSTR_ERROR_WORD_BUDGET)) end
	return ok
end

local USER_POS = { n = true, v = true, a = true, adv = true, x = true, pn = true }

local function WordKey(english)
	return (T.Trim(T.Lower(english or "")):gsub("[ \t\r\n]+", " "))
end

-- Shared by /pbtr add and the settings panel. value is what is saved: "レイドの夜", or with a
-- part of speech in front, "n:レイドの夜" / "v:走る/5". Returns the key, or nil and a message.
function addon:StoreUserWord(english, value)
	english = WordKey(english)
	value = T.Trim(value or "")
	if english == "" or value == "" or english:find("=", 1, true) then
		return nil, GetString(SI_PBSTR_ERROR_ADD_FORMAT)
	end
	local pos = value:match("^([A-Za-z]+):")
	if pos and not USER_POS[pos] then
		return nil, string.format(GetString(SI_PBSTR_ERROR_POS), pos)
	end
	if not T.IsValidUTF8(english) or not T.IsValidUTF8(value) then
		return nil, GetString(SI_PBSTR_ERROR_ADD_FORMAT)
	end
	if not T.CheckUserWordBudget(self.sv.userWords, english, value) then
		return nil, GetString(SI_PBSTR_ERROR_WORD_BUDGET)
	end
	self.sv.userWords[english] = value
	self:ApplyUserWords()
	return english
end

function addon:DeleteUserWord(english)
	english = WordKey(english)
	if self.sv.userWords[english] == nil then
		return nil, string.format(GetString(SI_PBSTR_ERROR_NOT_FOUND), english)
	end
	self.sv.userWords[english] = nil
	self:ApplyUserWords()
	return english
end

-- The added words, sorted, for /pbtr list and the panel's list.
function addon:SortedUserWords()
	local keys = {}
	for english in pairs(self.sv.userWords) do
		keys[#keys + 1] = english
	end
	table.sort(keys)
	return keys
end

-- "raid night = レイドの夜" or "raid night = n:レイドの夜"
function addon:AddUserWord(argument)
	-- No %s here: it is locale-dependent and could take the last byte of a Japanese word.
	local english, japanese = tostring(argument or ""):match("^([^=]*)=(.*)$")
	local key, err = self:StoreUserWord(english, japanese)
	if not key then
		Print("%s", err)
		return
	end
	self:RefreshPanel()
	Print(GetString(SI_PBSTR_REPLY_ADDED), key, self.sv.userWords[key])
end

function addon:RemoveUserWord(argument)
	local key, err = self:DeleteUserWord(argument)
	if not key then
		Print("%s", err)
		return
	end
	self:RefreshPanel()
	Print(GetString(SI_PBSTR_REPLY_REMOVED), key)
end

function addon:ListUserWords()
	local keys = self:SortedUserWords()
	if #keys == 0 then
		Print(GetString(SI_PBSTR_REPLY_NO_WORDS))
		return
	end
	for _, english in ipairs(keys) do
		Say(string.format("  %s = %s", english, self.sv.userWords[english]))
	end
end

-- ---------------------------------------------------------------------------------------
-- Commands
-- ---------------------------------------------------------------------------------------

local function OnOff(value)
	return value and GetString(SI_PBSTR_ON) or GetString(SI_PBSTR_OFF)
end

-- /pbtr probe: every reading needed to tell where a chat message stops. English only, and
-- plain values, so the output can be read back exactly as the console shows it.
function addon:PrintProbe()
	local diag = self.diag
	Print("probe %s", self.version ~= "" and self.version or "?")
	local formatters = CHAT_ROUTER and CHAT_ROUTER.GetRegisteredMessageFormatters and CHAT_ROUTER:GetRegisteredMessageFormatters()
	Say(string.format("  translationOnly=%s formatterActive=%s", tostring(self.sv and self.sv.translationOnly),
		tostring(self.replacementFormatter ~= nil and formatters ~= nil and formatters[EVENT_CHAT_MESSAGE_CHANNEL] == self.replacementFormatter)))
	if diag.replacementError then Say("  replacement error: " .. diag.replacementError) end
	for _, step in ipairs(self.loadSteps) do
		if not step.ok then
			Say(string.format("  load step FAILED: %s -- %s", step.name, tostring(step.err)))
		end
	end
	Say(string.format("  load steps ok: %d/%d, listener=%s, router=%s", self.okSteps or 0, #self.loadSteps,
		tostring(self.installed), type(CHAT_ROUTER)))
	local sv = self.sv or {}
	Say(string.format("  enabled=%s own=%s others=%s zone=%s known=%s cyrodiil=%s",
		tostring(sv.enabled), tostring(sv.translateOwn), tostring(sv.translateOthers),
		tostring(sv.translateZone), tostring(sv.minKnownPercent), tostring(T.cyrodiilPriority)))
	Say(string.format("  callbacks=%d withText=%d translated=%d skipped=%d errors=%d",
		diag.callbacks, diag.withText, self.stats.translated, self.stats.skipped, self.stats.errors))
	Say(string.format("  output ok=%d fallback=%d", diag.outputOk, diag.outputFallback))
	if diag.lastOutputError then
		Say("  output error: " .. diag.lastOutputError)
	end
	if self.lastError then
		Say("  last error: " .. self.lastError)
	end
	for _, entry in ipairs(diag.recent) do
		Say(string.format("  cat=%s own=%s %s: %s", tostring(entry.category), tostring(entry.own),
			entry.reason, entry.text))
	end
end

function addon:PrintStatus()
	local sv = self.sv
	Print("%s -- %s", self.version ~= "" and self.version or "?", OnOff(sv.enabled))
	if not self.installed then
		Print(GetString(SI_PBSTR_STATUS_NOT_INSTALLED))
	end
	Print(GetString(SI_PBSTR_STATUS_TARGETS), OnOff(sv.translateOwn), OnOff(sv.translateOthers),
		OnOff(sv.translateZone), sv.minKnownPercent)
	Print(GetString(SI_PBSTR_STATUS_DIRECTION), self:DirectionLabel())
	Print(GetString(SI_PBSTR_STATUS_ONLY), OnOff(sv.translationOnly))
	local userCount = 0
	for _ in pairs(sv.userWords) do
		userCount = userCount + 1
	end
	Print(GetString(SI_PBSTR_STATUS_DICTIONARY), T.entryCount or 0, userCount)
	Print(GetString(SI_PBSTR_STATUS_COUNTS), self.stats.seen, self.stats.translated, self.stats.skipped,
		self.stats.errors)
	if self.lastError then
		Print(GetString(SI_PBSTR_STATUS_LAST_ERROR), self.lastError)
	end
end

function addon:PrintHelp()
	Print("%s", self.title)
	for _, stringId in ipairs({
		SI_PBSTR_HELP_TRANSLATE,
		SI_PBSTR_HELP_STATUS,
		SI_PBSTR_HELP_MASTER,
		SI_PBSTR_HELP_DIRECTION,
		SI_PBSTR_HELP_OWN,
		SI_PBSTR_HELP_OTHERS,
		SI_PBSTR_HELP_ZONE,
		SI_PBSTR_HELP_KNOWN,
		SI_PBSTR_HELP_COLOR,
		SI_PBSTR_HELP_ONLY,
		SI_PBSTR_HELP_ADD,
		SI_PBSTR_HELP_REMOVE,
		SI_PBSTR_HELP_LIST,
	}) do
		Say(GetString(stringId))
	end
end

local ON_WORDS = { on = true, ["true"] = true, yes = true, ["1"] = true }
local OFF_WORDS = { off = true, ["false"] = true, no = true, ["0"] = true }

local function ParseSwitch(word)
	word = word and T.Lower(word)
	if ON_WORDS[word] then
		return true
	elseif OFF_WORDS[word] then
		return false
	end
	return nil
end

-- /jp <english> -- translate for yourself, without sending anything. Always shows a result,
-- even under the known-words threshold, so it doubles as a way to see what the add-on makes
-- of a sentence.
function addon:TranslateCommand(argumentString)
	local text = T.Trim(argumentString)
	if text == "" then
		Print(GetString(SI_PBSTR_HELP_TRANSLATE))
		return
	end
	local ok, ja, stats = pcall(T.Translate, text)
	if not ok then
		self.stats.errors = self.stats.errors + 1
		self.lastError = tostring(ja)
		Print(GetString(SI_PBSTR_STATUS_LAST_ERROR), self.lastError)
		return
	end
	Say(self:FormatTranslation(ja ~= "" and ja or "-", "en2ja"))
	Say(string.format(GetString(SI_PBSTR_REPLY_KNOWN), stats.known, stats.known + stats.unknown))
end

function addon:HandleCommand(argumentString)
	local argument = tostring(argumentString or "")
	local command, rest = argument:match("^[ \t\r\n]*([^ \t\r\n]+)[ \t\r\n]*(.-)[ \t\r\n]*$")
	command = command and T.Lower(command)

	if not command or command == "status" then
		self:PrintStatus()
		return
	end
	if command == "help" or command == "?" then
		self:PrintHelp()
		return
	end
	if command == "probe" then
		self:PrintProbe()
		return
	end
	if command == "debug" then
		local value = ParseSwitch(rest)
		if value == nil then
			Print(GetString(SI_PBSTR_ERROR_ON_OR_OFF))
			return
		end
		self.sv.debug = value
		Print("debug %s", OnOff(value))
		return
	end
	if command == "add" then
		self:AddUserWord(rest)
		return
	end
	if command == "remove" or command == "delete" then
		self:RemoveUserWord(rest)
		return
	end
	if command == "list" or command == "words" then
		self:ListUserWords()
		return
	end
	if command == "own" or command == "others" or command == "zone" then
		local value = ParseSwitch(rest)
		if value == nil then
			Print(GetString(SI_PBSTR_ERROR_ON_OR_OFF))
			return
		end
		local key = command == "own" and "translateOwn" or (command == "others" and "translateOthers" or "translateZone")
		self.sv[key] = value
		self:RefreshPanel()
		self:PrintStatus()
		return
	end
	if command == "mode" or command == "direction" then
		local value = T.Lower(rest)
		local direction = (value == "en2ja" or value == "ja") and "en2ja" or ((value == "ja2en" or value == "en") and "ja2en" or nil)
		if rest ~= "" and not direction then
			Print(GetString(SI_PBSTR_ERROR_DIRECTION))
			return
		end
		if direction then
			self:SetDirection(direction)
			self:RefreshPanel()
		end
		Print(GetString(SI_PBSTR_STATUS_DIRECTION), self:DirectionLabel())
		return
	end
	if command == "only" then
		local value = ParseSwitch(rest)
		if value == nil then Print(GetString(SI_PBSTR_ERROR_ON_OR_OFF)); return end
		self:SetTranslationOnly(value)
		self:RefreshPanel()
		Print(GetString(SI_PBSTR_STATUS_ONLY), OnOff(self.sv.translationOnly))
		return
	end
	if command == "color" then
		if rest ~= "" then
			local color = T.Lower(rest) == "default" and DEFAULTS.color or NormalizeColor(rest)
			if not color then
				Print(GetString(SI_PBSTR_ERROR_COLOR))
				return
			end
			self.sv.color = color
			self:RefreshPanel()
		end
		Print(GetString(SI_PBSTR_REPLY_COLOR), self:GetTranslationColor())
		Say(self:FormatTranslation(GetString(SI_PBSTR_COLOR_SAMPLE)))
		return
	end
	if command == "known" then
		local percent = tonumber(rest)
		if not percent or percent < 0 or percent > 100 then
			Print(GetString(SI_PBSTR_ERROR_PERCENT))
			return
		end
		self.sv.minKnownPercent = math.floor(percent)
		self:RefreshPanel()
		self:PrintStatus()
		return
	end
	local master = ParseSwitch(command)
	if master ~= nil and rest == "" then
		self.sv.enabled = master
		self:RefreshPanel()
		self:PrintStatus()
		return
	end

	Print(GetString(SI_PBSTR_ERROR_UNKNOWN), command)
	self:PrintHelp()
end

function addon:InitSlashCommands()
	SLASH_COMMANDS[SLASH] = function(argumentString)
		self:HandleCommand(argumentString)
	end
	SLASH_COMMANDS[TRANSLATE_SLASH] = function(argumentString)
		self:TranslateCommand(argumentString)
	end
end

function addon:RefreshPanel()
	if self.settingsControls and self.settingsControls.UpdateControls then
		self.settingsControls:UpdateControls()
	end
end

-- ---------------------------------------------------------------------------------------
-- Load
-- ---------------------------------------------------------------------------------------

function addon:UpdateDictionaryContext()
	-- The Imperial City is a zone of its own (IsInCyrodiil is false there), but its chat is the
	-- same alliance-war chat.
	local inCyrodiil = type(IsInCyrodiil) == "function" and IsInCyrodiil()
	local inImperialCity = type(IsInImperialCity) == "function" and IsInImperialCity()
	T.SetCyrodiilPriority(inCyrodiil or inImperialCity)
end

-- Each start-up step runs by itself: one that fails (a client function refused on console,
-- say) is recorded for /pbtr probe and does not stop the steps after it. The chat listener
-- and the commands go first, because without them nothing else can even be observed.
local function Step(name, fn)
	local ok, err = pcall(fn)
	addon.loadSteps[#addon.loadSteps + 1] = { name = name, ok = ok, err = err }
	if ok then
		addon.okSteps = (addon.okSteps or 0) + 1
	end
end

local function OnPlayerActivated()
	if addon.sv.translationOnly then addon:SetTranslationOnly(true, true) end
	Step("dictionary context", function()
		addon:UpdateDictionaryContext()
	end)
	-- Nothing is printed at login; /pbtr probe reports the build and any failed start-up step.
end

-- Upgrade the previous default once; preserve other explicitly chosen thresholds.
function addon:MigrateKnownThreshold()
	if not self.sv.partialTranslationDefaultApplied then
		if self.sv.minKnownPercent == 60 then
			self.sv.minKnownPercent = DEFAULTS.minKnownPercent
		end
		self.sv.partialTranslationDefaultApplied = true
	end
end

local function OnAddOnLoaded(_, name)
	if name ~= addon.name then
		return
	end
	em:UnregisterForEvent(addon.name, EVENT_ADD_ON_LOADED)

	Step("saved variables", function()
		addon.sv = ZO_SavedVars:NewAccountWide("PBsTranslate_Data", 1, nil, DEFAULTS)
	end)
	if not addon.sv then
		addon.sv = {}
		for key, value in pairs(DEFAULTS) do
			addon.sv[key] = value
		end
	end
	addon:MigrateKnownThreshold()
	Step("slash commands", function()
		addon:InitSlashCommands()
	end)
	Step("chat listener", function()
		if not addon:InstallListener() then
			error("CHAT_ROUTER unavailable")
		end
	end)
	Step("replacement formatter", function()
		if addon.sv.translationOnly then addon:SetTranslationOnly(true, true) end
	end)
	Step("user words", function()
		addon:ApplyUserWords()
	end)
	Step("settings panel", function()
		if addon.InitSettings then
			addon:InitSettings()
		end
	end)
	Step("dictionary sharing", function()
		if addon.InitSharing then addon:InitSharing() end
	end)
	em:RegisterForEvent(addon.name, EVENT_PLAYER_ACTIVATED, OnPlayerActivated)
end

em:RegisterForEvent(addon.name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)

PBS_TRANSLATE = addon
