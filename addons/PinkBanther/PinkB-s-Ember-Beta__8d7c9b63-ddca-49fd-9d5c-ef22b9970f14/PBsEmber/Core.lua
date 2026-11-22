-- PB's Ember
-- Author: PinkBanther
--
-- A two-head-tall mascot, Ember, who appears on the game screen during a fight and tells the player, in a
-- speech bubble and with a little animation, when one of these happens:
--   * Major Resolve or Minor Resolve is about to run out,
--   * the player's health falls below a set share (and again, more urgently, below a lower one).
--
-- ---------------------------------------------------------------------------------------
-- WHERE THE INFORMATION COMES FROM
-- ---------------------------------------------------------------------------------------
--
-- Buffs: EVENT_EFFECT_CHANGED for the player (the event the game's own buff bar is fed by) says when an effect is
-- gained, refreshed (a new end time) and faded; a scan of GetUnitBuffInfo("player", i) picks up what is already
-- there when a fight starts or the screen loads. Times are in GetFrameTimeSeconds() seconds, the same clock the
-- game's buff bar counts down against. Which effect is "Major Resolve" (or Minor Resolve, or Major Brutality) is decided by NAME (see A.BuffKind):
-- the API documents buff types (BUFF_TYPE_MAJOR_RESOLVE ...) but the effect events carry only a deprecated
-- type string, and no ability id of the Resolve effects is hard-coded here because none has been verified.
-- /pbember buffs lists the player's buffs and how each was recognised, so a language that is not matched yet
-- can be added from one real list.
--
-- Health: EVENT_POWER_UPDATE (player, health) and GetUnitPower("player", COMBAT_MECHANIC_FLAGS_HEALTH).
--
-- ---------------------------------------------------------------------------------------
-- WHAT IS NOT KNOWN YET (nothing here has been run on a console)
-- ---------------------------------------------------------------------------------------
--
-- * The Japanese names of the effects on the console ("強固(強)" / "強固(弱)" / "残忍(強)", with half- or full-width
--   brackets): both widths are accepted, and /pbember buffs says what was seen.
-- * Whether SetTextureRotation turns counter-clockwise on a console (the client's own radial menu code and the
--   map's player pin say so). If Ember's head and face come apart, /pbember flip turns the direction round.
-- * Whether a refresh of a buff arrives as EFFECT_RESULT_UPDATED with the new end time (assumed).
--
-- ---------------------------------------------------------------------------------------
-- TEXT
--
-- Names reach the screen untouched. Nothing here runs a Lua character class (%s %c %a ...) or lower()/upper()
-- over them: those ask the C library, which answers by the process's locale, and in a non-"C" locale the bytes
-- inside Japanese UTF-8 can be taken for control characters or blanks. Matching is byte-wise (plain find) and
-- commands are lowered one ASCII letter at a time.
-- ---------------------------------------------------------------------------------------

PBS_EMBER = {
	name = "PBsEmber",
	baseTitle = "PB’s Ember",
	chatName = "PB’s Ember",
	author = "PinkBanther",
	version = "0.1.1",
	slash = "/pbember",
	shortSlash = "/pbe",
	savedVar = "PBsEmber_Data",
	LIMITS = {
		resolveSeconds = { 1, 10 },
		hpWarn = { 30, 90 },
		hpDanger = { 0, 60 },
		size = { 50, 200 },
		posX = { 0, 1600 },
		posY = { 0, 900 },
		hold = { 2, 15 },
	},
	defaults = {
		enabled = true,
		major = true, -- Major Resolve about to run out
		brutal = true, -- Major Brutality about to run out
		minor = true, -- Minor Resolve about to run out
		hp = true,
		resolveSeconds = 3,
		hpWarn = 70, -- percent
		hpDanger = 35, -- percent; 0 = no second, more urgent alert
		combatOnly = true,
		side = 1, -- 1 = Ember stands at the left of the screen, 2 = at the right
		size = 100, -- percent
		posX = 40, -- from the screen edge
		posY = 400, -- height above the bottom of the screen (clear of the chat window and the group frames)
		hold = 5, -- seconds she stays for one alert
		bubble = true,
		sound = false, -- not asked for, so off
		preview = true, -- she plays her alerts at the right of the screen while the settings panel is open
		rotFlip = false, -- only if SetTextureRotation turns the other way on the console
	},
}
local A = PBS_EMBER
local S = PBS_EMBER_STRINGS

-- The version comes from the manifest, the same way PB's other add-ons read it.
do
	local manager = GetAddOnManager and GetAddOnManager()
	if manager then
		for index = 1, manager:GetNumAddOns() do
			local name, title = manager:GetAddOnInfo(index)
			if name == A.name and title then
				local plain = title:gsub("|c%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("[ \t\r\n]+$", "")
				A.version = plain:match("(%d+[%d%.]*)$") or A.version
				break
			end
		end
	end
end
A.title = A.baseTitle .. " " .. A.version

-- Seconds on the clock the game's buff bar uses.
function A.Now()
	return GetFrameTimeSeconds and GetFrameTimeSeconds() or 0
end

A.errors = 0
A.lastError = nil

-- A handler that cannot raise: an error in an event handler would reach the game as an error screen.
function A.Guard(fn)
	return function(...)
		local ok, err = pcall(fn, ...)
		if not ok then
			A.errors = A.errors + 1
			A.lastError = tostring(err)
		end
	end
end

-- ---------------------------------------------------------------------------------------
-- Commands are the only text that is read
-- ---------------------------------------------------------------------------------------

function A.LowerAscii(text)
	return (tostring(text or ""):gsub("[A-Z]", function(c)
		return string.char(c:byte() + 32)
	end))
end

local function IsAsciiBlank(b)
	return b == 32 or (b >= 9 and b <= 13)
end

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

-- ---------------------------------------------------------------------------------------
-- Saved settings
-- ---------------------------------------------------------------------------------------

local function Clamp(value, limits, default)
	value = tonumber(value)
	if not value or value ~= value then
		return default
	end
	value = math.floor(value + 0.5)
	if value < limits[1] then
		return limits[1]
	elseif value > limits[2] then
		return limits[2]
	end
	return value
end

-- Whatever is in the saved file (an older version, a hand edit) is brought back into range.
function A:Sanitize()
	local sv, defaults = self.sv, self.defaults
	for _, key in ipairs({ "enabled", "major", "minor", "brutal", "hp", "combatOnly", "bubble", "sound", "preview", "rotFlip" }) do
		if type(sv[key]) ~= "boolean" then
			sv[key] = defaults[key]
		end
	end
	for key, limits in pairs(self.LIMITS) do
		sv[key] = Clamp(sv[key], limits, defaults[key])
	end
	if sv.side ~= 1 and sv.side ~= 2 then
		sv.side = defaults.side
	end
	-- the urgent level must lie below the first one
	if sv.hpDanger >= sv.hpWarn then
		sv.hpDanger = math.max(0, sv.hpWarn - 10)
	end
end

function A:Set(key, value)
	local limits = self.LIMITS[key]
	if limits then
		value = Clamp(value, limits, self.defaults[key])
	end
	self.sv[key] = value
	if key == "hpWarn" and self.sv.hpDanger >= value then
		self.sv.hpDanger = math.max(0, value - 10)
	elseif key == "hpDanger" and value > 0 and value >= self.sv.hpWarn then
		self.sv.hpDanger = math.max(0, self.sv.hpWarn - 10)
	end
end

-- ---------------------------------------------------------------------------------------
-- Which effect is Major / Minor Resolve
-- ---------------------------------------------------------------------------------------

-- By the effect's name, in the game's language. Japanese: the word (強固 = Resolve, 残忍 = Brutality) followed within a
-- few bytes by a 強 (major) or 弱 (minor), in half- or full-width brackets alike. English: "Major Resolve",
-- "Minor Resolve", "Major Brutality". Returns "major" / "minor" (Resolve), "brutal" (Major Brutality) or nil.
-- Minor Brutality is not followed. Byte-wise plain finds only (see TEXT above).
local KANJI_RESOLVE = "強固"
local KANJI_BRUTALITY = "残忍"
local KANJI_STRONG = "強"
local KANJI_WEAK = "弱"
local TAG_REACH = 12 -- bytes after the word within which the 強 / 弱 must come: "(強)", " （強）"

-- "strong", "weak" or nil: which tag stands right after the word.
local function JapaneseTag(rest)
	local head = rest:sub(1, TAG_REACH)
	local strong = head:find(KANJI_STRONG, 1, true)
	local weak = head:find(KANJI_WEAK, 1, true)
	if strong and (not weak or strong < weak) then
		return "strong"
	elseif weak then
		return "weak"
	end
	return nil
end

function A.BuffKind(name)
	if type(name) ~= "string" or name == "" then
		return nil
	end
	local _, last = name:find(KANJI_RESOLVE, 1, true)
	if last then
		local tag = JapaneseTag(name:sub(last + 1))
		if tag == "strong" then
			return "major"
		elseif tag == "weak" then
			return "minor"
		end
		return nil
	end
	_, last = name:find(KANJI_BRUTALITY, 1, true)
	if last then
		return JapaneseTag(name:sub(last + 1)) == "strong" and "brutal" or nil
	end
	local lower = A.LowerAscii(name)
	if lower:find("major resolve", 1, true) then
		return "major"
	elseif lower:find("minor resolve", 1, true) then
		return "minor"
	elseif lower:find("major brutality", 1, true) then
		return "brutal"
	end
	return nil
end

PBS_EMBER_MARK("Core")
