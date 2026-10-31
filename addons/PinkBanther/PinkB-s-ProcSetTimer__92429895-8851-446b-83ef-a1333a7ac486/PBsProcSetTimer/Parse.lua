-- PB's Proc Set Timer -- reading a set's timings out of its own bonus text.
--
-- Nothing about a set's effect is kept in this add-on. The game already writes it down, in the
-- player's language, for the item tooltip:
--
--     GetItemSetInfo(setId)              -> hasSet, setName, numBonuses, ...
--     GetItemSetBonusInfo(setId, index)  -> numRequired, bonusDescription, ...
--
-- The description of the proc bonus carries every number we need ("for 5 seconds", "once every
-- 8 seconds"), so a balance patch changes the timers without touching this add-on.
--
-- ---------------------------------------------------------------------------------------
-- HOW A NUMBER OF SECONDS IS TOLD APART
-- ---------------------------------------------------------------------------------------
--
-- Every "<number> <seconds word>" is found first. Then each one is classified by the words
-- right around it, using cue lists for every language the game ships (they are all tried on
-- every text; a cue of one language never occurs in another):
--
--     cooldown  "once every 8 seconds"   "8秒に1回"      "alle 8 Sekunden"
--     delay     "after 1.3 seconds"      "1.3秒後"       "nach 1,3 Sekunden"
--     duration  "for 5 seconds"          "5秒間"         "für 5 Sekunden"
--
-- When no cue matches (a language whose wording is not covered, or a patch that rewords the
-- sentence) the position decides: the description ends with the cooldown sentence, so a time
-- that is still unclassified and comes after every other time is the cooldown. A text with a
-- single unclassified time keeps it as a duration.
--
-- A bonus line can hold more than one effect (two sentences that each last a while, or two
-- cooldown sentences); it is cut into them and every piece is read on its own, so the effects can
-- run independently.
--
-- /procset text prints the raw lines and what was read from them.

if not PBS_PROCSETTIMER then
	return
end

local addon = PBS_PROCSETTIMER

-- "second(s)" in every language of the client. CJK has the one character 秒 and no spaces.
local CJK_SECOND = "秒"
local SECOND_WORDS = {
	second = true,
	seconds = true,
	sekunde = true,
	sekunden = true,
	seconde = true,
	secondes = true,
	segundo = true,
	segundos = true,
	["секунда"] = true,
	["секунды"] = true,
	["секунду"] = true,
	["секунд"] = true,
}

-- Lua patterns. "before" cues are anchored to the END of the text before the number, "after"
-- cues to the START of the text after the unit; both sides are lower-cased first. No
-- multi-byte character may sit inside [...] -- a set matches single bytes, not characters.
local CUES = {
	cooldown = {
		before = {
			"once every%s*$",
			"once per%s*$",
			"every%s*$",
			"cooldown of%s*$",
			"alle%s*$",
			"abklingzeit von%s*$",
			"toutes les%s*$",
			"tous les%s*$",
			"cada%s*$",
			"раз в%s*$",
			"каждые%s*$",
			"每%s*$",
		},
		after = {
			"^%s*cooldown",
			"^%s*internal cooldown",
			"^%s*abklingzeit",
			"^%s*de recharge",
			"^%s*de reutilizaci",
			"^%s*перезарядк",
			"^に1回",
			"^に一回",
			"^に1度",
			"^に一度",
			"^ごと",
			"^毎",
			"^おき",
			"^間隔",
			"^の間隔",
			"^のクールダウン",
			"^クールダウン",
			"^冷却",
			"^的冷却",
		},
	},
	delay = {
		before = { "after%s*$", "nach%s*$", "après%s*$", "apres%s*$", "después de%s*$", "despues de%s*$", "через%s*$" },
		after = { "^後", "^后" },
	},
	duration = {
		before = { "for%s*$", "lasting%s*$", "für%s*$", "pendant%s*$", "durante%s*$" },
		after = { "^間", "^の間", "^持続", "^内" },
	},
}
local CLASS_ORDER = { "cooldown", "delay", "duration" }

-- How much text on either side of a number is looked at for a cue.
local CONTEXT_BYTES = 32

-- Colour codes, texture tags and full-width digits would hide a number from the scan.
local function Normalize(text)
	text = text or ""
	text = text:gsub("|c%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|t[^|]*|t", "")
	-- U+FF10..U+FF19 are EF BC 90..99, U+FF0E is EF BC 8E
	text = text:gsub("\239\188([\144-\153])", function(c)
		return string.char(c:byte() - 96)
	end)
	text = text:gsub("\239\188\142", ".")
	return text
end

local function Cued(list, str)
	for _, pattern in ipairs(list) do
		if str:find(pattern) then
			return true
		end
	end
	return false
end

local function Classify(before, after)
	for _, class in ipairs(CLASS_ORDER) do
		local cues = CUES[class]
		if Cued(cues.before, before) or Cued(cues.after, after) then
			return class
		end
	end
	return "unknown"
end

-- All "<number> <seconds>" in a text, in reading order.
local function ScanTimes(text)
	local hits = {}
	local pos = 1
	while true do
		local s, e, num = text:find("(%d+[%.,]?%d*)", pos)
		if not s then
			break
		end
		pos = e + 1

		local _, spaceEnd = text:find("^%s*", e + 1)
		local unitStart = spaceEnd + 1
		local unitEnd
		if text:sub(unitStart, unitStart + #CJK_SECOND - 1) == CJK_SECOND then
			unitEnd = unitStart + #CJK_SECOND - 1
		else
			local ws, we, word = text:find("^([%a\128-\255]+)", unitStart)
			if ws and SECOND_WORDS[word:lower()] then
				unitEnd = we
			end
		end

		if unitEnd then
			local seconds = tonumber((num:gsub(",", ".")))
			if seconds then
				local before = text:sub(zo_max(1, s - CONTEXT_BYTES), s - 1):lower()
				local after = text:sub(unitEnd + 1, unitEnd + CONTEXT_BYTES):lower()
				hits[#hits + 1] = { seconds = seconds, class = Classify(before, after), first = s, last = unitEnd }
			end
			pos = unitEnd + 1
		end
	end
	return hits
end

-- text -> { cooldown = seconds|nil, duration = seconds|nil, delay = seconds|nil, hits = {...} }
function addon.ParseBonusText(text)
	local hits = ScanTimes(Normalize(text))

	local cooldown
	for _, hit in ipairs(hits) do
		if hit.class == "cooldown" then
			cooldown = hit
			break
		end
	end
	-- No cooldown phrase recognised: the closing time of a text with several is the cooldown.
	if not cooldown and #hits >= 2 and hits[#hits].class == "unknown" then
		cooldown = hits[#hits]
		cooldown.class = "cooldown"
		cooldown.inferred = true
	end

	local duration, delay
	for _, hit in ipairs(hits) do
		if hit ~= cooldown then
			if hit.class == "duration" and not duration then
				duration = hit
			elseif hit.class == "delay" and not delay then
				delay = hit
			end
		end
	end
	if not duration then
		for _, hit in ipairs(hits) do
			if hit ~= cooldown and hit.class == "unknown" then
				duration = hit
				duration.inferred = true
				break
			end
		end
	end

	return {
		cooldown = cooldown and cooldown.seconds or nil,
		duration = duration and duration.seconds or nil,
		delay = delay and delay.seconds or nil,
		inferred = (cooldown and cooldown.inferred) or (duration and duration.inferred) or false,
		hits = hits,
	}
end

addon.NormalizeText = Normalize

-- The last byte of the sentence that holds position `from`: its full stop (ASCII, CJK or
-- full-width), or the end of the text. A stop inside a number ("1.3") is not one.
local function SentenceEnd(text, from)
	local best = #text
	local function consider(position)
		if position and position < best then
			best = position
		end
	end
	consider(text:find("%.%s", from))
	consider(text:find("[!?]", from))
	for _, stop in ipairs({ "。", "！", "？" }) do
		local at = text:find(stop, from, true)
		consider(at and at + #stop - 1)
	end
	return best
end

-- A bonus line can hold more than one effect. It is read sentence by sentence and cut into
-- groups of sentences, one group per effect:
--
--     * a sentence with a cooldown closes the group it is in ("This effect can occur once every 8
--       seconds."), and whatever comes next starts a new one;
--     * a sentence with a duration ("for 15 seconds") starts a new group when the group it would
--       join already has one -- two effects that each last a while are two effects.
--
-- A line that yields fewer than two groups with a time in them stays whole, which is what every
-- line did before. (A time whose wording is not recognised never starts a group: the wording
-- may be a cooldown the cues missed, and splitting on it would cut one effect in two.)
function addon.SplitEffects(text)
	text = Normalize(text)
	local hits = ScanTimes(text)

	local groups = {}
	local current
	local from = 1
	while from <= #text and not text:sub(from):match("^%s*$") do
		local stop = SentenceEnd(text, from)
		local hasCooldown, hasDuration = false, false
		for _, hit in ipairs(hits) do
			if hit.first >= from and hit.first <= stop then
				if hit.class == "cooldown" then
					hasCooldown = true
				elseif hit.class == "duration" then
					hasDuration = true
				end
			end
		end
		if not current or current.closed or (hasDuration and current.hasDuration) then
			current = { first = from, hasDuration = false, closed = false }
			groups[#groups + 1] = current
		end
		current.last = stop
		current.hasDuration = current.hasDuration or hasDuration
		current.closed = current.closed or hasCooldown
		from = stop + 1
	end

	local pieces = {}
	for _, group in ipairs(groups) do
		local piece = text:sub(group.first, group.last):match("^%s*(.-)%s*$")
		local read = addon.ParseBonusText(piece)
		if read.cooldown ~= nil or read.duration ~= nil then
			pieces[#pieces + 1] = piece
		end
	end
	if #pieces < 2 then
		return { text }
	end
	return pieces
end

-- setId -> every bonus line of the set, each read for its timings; nil if the game has no such set.
--   bonuses[i] = {
--     index, required   the line's position and the pieces it needs
--     perfected         a Perfected-set bonus: counted against Perfected pieces only
--     text              the description, cleaned (the proc's own words, used to match events)
--     cooldown / duration / delay   seconds, or nil when the text does not say
--     inferred          a time was placed by its position, not by its wording
--     timed             the line has a cooldown or a duration, so it is worth a row
--     effects           the timed effects of the line (see SplitEffects), usually one; each
--                       carries the line's index/required/perfected plus its own text and times,
--                       and key (unique in the set), k (its number in the line), n (how many)
--   }
-- Also: effects (every timed effect of the set, in the order of the text) and effectCount.
-- Which effects get a row is decided by the caller: all those whose line the worn pieces switch on.
function addon.ReadSetEffect(setId)
	local hasSet, setName, numBonuses = GetItemSetInfo(setId)
	if not hasSet or not numBonuses or numBonuses < 1 then
		return nil
	end

	local bonuses = {}
	local effects = {}
	for index = 1, numBonuses do
		local required, description, perfected = GetItemSetBonusInfo(setId, index)
		local parsed = addon.ParseBonusText(description)
		local timed = parsed.cooldown ~= nil or parsed.duration ~= nil
		local line = {
			index = index,
			required = required or 5,
			perfected = perfected and true or false,
			text = Normalize(description),
			parsed = parsed,
			cooldown = parsed.cooldown,
			duration = parsed.duration,
			delay = parsed.delay,
			inferred = parsed.inferred,
			timed = timed,
			effects = {},
		}
		bonuses[index] = line

		if timed then
			local pieces = addon.SplitEffects(description)
			for _, piece in ipairs(pieces) do
				-- a whole line was read above; only a cut-up line needs reading piece by piece
				local read = (#pieces == 1) and parsed or addon.ParseBonusText(piece)
				if read.cooldown ~= nil or read.duration ~= nil then
					local k = #line.effects + 1
					line.effects[k] = {
						index = index,
						key = index * 100 + k,
						k = k,
						required = line.required,
						perfected = line.perfected,
						text = piece,
						parsed = read,
						cooldown = read.cooldown,
						duration = read.duration,
						delay = read.delay,
						inferred = read.inferred,
						timed = true,
					}
				end
			end
			for _, effect in ipairs(line.effects) do
				effect.n = #line.effects
				effects[#effects + 1] = effect
			end
		end
	end
	return { setName = setName, bonuses = bonuses, timed = #effects > 0, effects = effects, effectCount = #effects }
end
