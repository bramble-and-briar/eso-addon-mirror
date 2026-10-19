-- PB's Translate -- the dictionary
--
-- An add-on cannot reach a server, so every word it can translate ships inside it. The word
-- lists live in dict/*.lua as plain "english=japanese" lines, one block per part of speech,
-- because that is the form that is easy to read, extend and diff. They are turned into
-- entries once, while the files load.
--
--   D("n", [[
--   sword=剣
--   world boss=ワールドボス          -- several words are fine; the longest match wins
--   ]])
--
--   D("v", [[
--   go=行く/5/に                     -- japanese / verb class / object particle
--   ]])
--
-- Parts of speech the grammar understands:
--
--   n    noun                  pn   pronoun             v    verb
--   a    adjective (/i, /na)   adv  adverb              x    fixed expression
--   prep preposition (/particle placement, see Grammar.lua)
--   det  determiner            conj conjunction         wh   question word
--
-- An x entry is translated as a whole and stands on its own: "thank you", "lfg", "gg".
--
-- A word not in the lists is looked up again with its inflection taken off -- plural -s,
-- past -ed, -ing, comparative -er -- and the inflection is handed to the grammar. Irregular
-- forms (went, children, better) come from the table in dict/Irregular.lua.

PBsTranslate = PBsTranslate or {}
local T = PBsTranslate

-- Normal translations advance the collector in bounded slices without changing
-- global GC tuning. A dictionary rebuild can request a completed collection to
-- release its obsolete index (important with generational collectors). Hosts
-- may restrict this API; failure disables explicit steps without breaking translation.
local canStepGC = type(collectgarbage) == "function"
function T.ReclaimTemporaryMemory(dictionaryRebuilt)
	if canStepGC then
		local ok = pcall(collectgarbage, dictionaryRebuilt and "collect" or "step", 128)
		if not ok then canStepGC = false end
	end
end

-- ---------------------------------------------------------------------------------------
-- Byte-safe text helpers
-- Lua's character classes (%a %w %s %u) and string.lower/upper ask the C library, and the C
-- library answers by the process's locale. On a desk that is the "C" locale and only ASCII
-- counts as a letter or a space. A game client need not run in "C": in a Latin-1 locale,
-- 0xE3 is a letter (a-tilde), 0xA0 and 0x85 are spaces, and lower() rewrites 0xC0-0xDE.
--
-- Those are UTF-8 bytes of Japanese text. こ is E3 81 93, だ is E3 81 A0. A pattern that thinks
-- E3 is a letter or A0 a space cuts a character in half, and lower() can change one of its
-- bytes -- either way the result is no longer UTF-8, and invalid UTF-8 handed to the chat
-- window or the entry box is the likely way /en crashed the PS5 client on untranslatable
-- Japanese (0.4.16): translatable input is consumed whole by dictionary matches and never
-- reaches a character class; untranslatable input always does.
--
-- So the add-on names its classes explicitly (ASCII only) and checks UTF-8 before any text it
-- built reaches the client. /en probe reports what the console's locale actually does.
--
-- They live in this file rather than one of their own: 0.4.17 shipped them as Text.lua, and
-- on PS5 this file then found T.Lower missing at load. Every build has always had Lexicon.lua.
-- ---------------------------------------------------------------------------------------

T.SPACE = "[ \t\r\n]"

function T.Trim(text)
	return (tostring(text or ""):gsub("^[ \t\r\n]+", ""):gsub("[ \t\r\n]+$", ""))
end

-- ASCII-only lower case; every other byte is left exactly as it was.
function T.Lower(text)
	return (tostring(text or ""):gsub("[A-Z]", function(c)
		return string.char(c:byte() + 32)
	end))
end

-- Is the whole string well-formed UTF-8?
function T.IsValidUTF8(text)
	if type(text) ~= "string" then
		return false
	end
	local i, length = 1, #text
	while i <= length do
		local byte = text:byte(i)
		local size
		if byte < 0x80 then
			size = 1
		elseif byte >= 0xC2 and byte <= 0xDF then
			size = 2
		elseif byte >= 0xE0 and byte <= 0xEF then
			size = 3
		elseif byte >= 0xF0 and byte <= 0xF4 then
			size = 4
		else
			return false
		end
		if i + size - 1 > length then
			return false
		end
		for k = i + 1, i + size - 1 do
			local continuation = text:byte(k)
			if continuation < 0x80 or continuation > 0xBF then
				return false
			end
		end
		i = i + size
	end
	return true
end

-- Drop every byte that is not part of a well-formed character. Returns the text and whether
-- anything was dropped.
function T.SanitizeUTF8(text)
	if T.IsValidUTF8(text) then
		return text, false
	end
	local out, i, length = {}, 1, #tostring(text or "")
	text = tostring(text or "")
	while i <= length do
		local byte = text:byte(i)
		local size = (byte < 0x80 and 1) or (byte >= 0xC2 and byte <= 0xDF and 2)
			or (byte >= 0xE0 and byte <= 0xEF and 3) or (byte >= 0xF0 and byte <= 0xF4 and 4) or 0
		local ok = size > 0 and i + size - 1 <= length
		if ok then
			for k = i + 1, i + size - 1 do
				local continuation = text:byte(k)
				if continuation < 0x80 or continuation > 0xBF then
					ok = false
					break
				end
			end
		end
		if ok then
			out[#out + 1] = text:sub(i, i + size - 1)
			i = i + size
		else
			i = i + 1
		end
	end
	return table.concat(out), true
end

-- What this Lua's locale does to UTF-8 bytes. Everything returned is ASCII.
function T.ProbeLocale()
	local function Matches(byte, class)
		return string.char(byte):find(class) ~= nil
	end
	local lowered = string.lower(string.char(0xC3))
	return {
		alphaE3 = Matches(0xE3, "%a"),
		alnumE3 = Matches(0xE3, "%w"),
		spaceA0 = Matches(0xA0, "%s"),
		space85 = Matches(0x85, "%s"),
		upperC3 = Matches(0xC3, "%u"),
		lowerChangesC3 = lowered ~= string.char(0xC3),
	}
end

T.lexicon = T.lexicon or {}
T.cyrodiilLexicon = T.cyrodiilLexicon or {}
T.cyrodiilPriority = T.cyrodiilPriority or false
T.irregular = T.irregular or {}
T.irregularPast = T.irregularPast or {}
T.irregularParticiple = T.irregularParticiple or {}
T.maxPhraseWords = T.maxPhraseWords or 1
T.entryCount = T.entryCount or 0

local lexicon = T.lexicon

local function Trim(text)
	return (text:gsub("^[ \t\r\n]+", ""):gsub("[ \t\r\n]+$", ""))
end

-- One "english=japanese/field/field" line into an entry. Returns key, entry or nil.
local function ParseLine(pos, line)
	line = Trim((line:gsub("%-%-.*$", "")))
	if line == "" then
		return nil
	end
	local english, rest = line:match("^(.-)[ \t]*=[ \t]*(.+)$")
	if not english or english == "" then
		return nil
	end
	local fields = {}
	for field in (rest .. "/"):gmatch("(.-)/") do
		fields[#fields + 1] = Trim(field)
	end
	local entry = { pos = pos, ja = fields[1] }
	if pos == "v" then
		entry.class = fields[2] ~= "" and fields[2] or "5"
		entry.particle = fields[3] ~= "" and fields[3] or nil
	elseif pos == "a" then
		entry.class = fields[2] == "na" and "na" or "i"
		-- A "na" entry that is really a verb form or a noun with の (乾いた, できる, 魔法の)
		-- neither takes な in front of a noun nor です after it; see T.Copula.
		local last = entry.ja:sub(-3)
		if entry.class == "na" and (last == "た" or last == "だ" or last == "る" or last == "の" or last == "な") then
			entry.class = "rel"
		end
	elseif pos == "prep" then
		entry.place = fields[2] ~= "" and fields[2] or "after"
	elseif (pos == "n" or pos == "adv") and fields[2] == "place" then
		entry.place = true
	elseif pos == "n" and fields[2] == "time" then
		entry.time = true
	elseif pos == "n" and fields[2] == "unit" then
		-- a unit stays after its number: 80パーセント, not パーセント×80
		entry.unit = true
	end
	-- join=の: the particle put between this noun and a noun right before it
	-- ("drake fd" -> ドレイクロー砦の正門, "bleaks ua" -> 侵入者の基地に奇襲)
	if pos == "n" then
		for index = 2, #fields do
			local join = fields[index]:match("^join=(.+)$")
			if join then
				entry.join = join
			elseif fields[index]:match("^then=") then
				-- the particle put after this noun when another noun follows ("ad zerg" -> ドミニオンの大集団)
				entry["then"] = fields[index]:match("^then=(.+)$")
			elseif fields[index] == "end" then
				-- ends its noun phrase: "ball group inc bd" -- bd is where, not whose
				entry.ends = true
			end
		end
	end
	return (T.Lower(english):gsub("[ \t\r\n]+", " ")), entry
end

-- A word defined under two parts of speech keeps both: the later one is the default and the
-- earlier ones hang off it in alts, for the grammar to pick when the context says so ("I need
-- help" is the noun, "help me" is the verb).
local function Add(key, entry, dictionary)
	local existing = dictionary[key] or lexicon[key]
	if not lexicon[key] and not T.cyrodiilLexicon[key] then
		T.entryCount = T.entryCount + 1
	end
	if existing then
		-- Never mutate a shared entry: normal meanings must survive PvP overrides.
		local alts = {}
		for pos, alternative in pairs(existing.alts or {}) do
			if pos ~= entry.pos then alts[pos] = alternative end
		end
		if existing.pos ~= entry.pos then
			local alternative = {}
			for k, v in pairs(existing) do
				if k ~= "alts" then alternative[k] = v end
			end
			alts[existing.pos] = alternative
		end
		if next(alts) then entry.alts = alts end
	end
	-- Definition order. The core vocabulary is defined first and chat slang last, so when
	-- several English words share one Japanese, JaToEn.lua reads it back as the earliest.
	T.defineSeq = (T.defineSeq or 0) + 1
	entry.seq = T.defineSeq
	dictionary[key] = entry
	local words = 1
	for _ in key:gmatch(" ") do
		words = words + 1
	end
	if words > T.maxPhraseWords then
		T.maxPhraseWords = words
	end
end

-- Later definitions of the same word replace earlier ones, so a file loaded later in the
-- manifest (the ESO terms) can override a general meaning ("tank" is not a water tank).
local function DefineInto(dictionary, pos, block)
	for line in (block .. "\n"):gmatch("(.-)\r?\n") do
		local key, entry = ParseLine(pos, line)
		if key and entry.ja and entry.ja ~= "" then
			Add(key, entry, dictionary)
		end
	end
end

function T.Define(pos, block)
	DefineInto(lexicon, pos, block)
end

function T.DefineCyrodiil(pos, block)
	DefineInto(T.cyrodiilLexicon, pos, block)
end

function T.SetCyrodiilPriority(enabled)
	T.cyrodiilPriority = enabled == true
end

-- english = "base inflection", e.g. went = "go past".
function T.DefineIrregular(block)
	for line in (block .. "\n"):gmatch("(.-)\r?\n") do
		line = Trim((line:gsub("%-%-.*$", "")))
		local form, base, inflection = line:match("^([^ \t=]+)[ \t]*=[ \t]*([^ \t]+)[ \t]+([^ \t]+)$")
		if form then
			form, base = T.Lower(form), T.Lower(base)
			T.irregular[form] = { base = base, inflection = inflection }
			-- The file lists the simple past before the participle (went, gone), which is how
			-- JaToEn.lua tells them apart.
			if inflection == "past" then
				T.irregularPast[base] = T.irregularPast[base] or form
				T.irregularParticiple[base] = form
			end
		end
	end
end

-- The player's own words, from saved variables. Kept apart from the shipped table so that
-- removing one gives the shipped meaning back.
T.userLexicon = T.userLexicon or {}

-- Bound compiled user data as well as temporary analysis. Saved data is never
-- deleted on failure; callers must reject an oversized edit/import atomically.
T.USER_WORD_LIMIT = 2000
T.USER_BYTE_LIMIT = 128 * 1024
function T.CheckUserWordBudget(entries, replaceKey, replaceValue)
	local count, bytes, cost = 0, 0, 0
	local function include(k, v)
		if type(k) ~= "string" or type(v) ~= "string" then return true end
		count = count + 1; bytes = bytes + #k + #v
		local pos = v:match("^([A-Za-z]+):")
		cost = cost + (pos == "v" and 12 or pos == "a" and 6 or 1)
		return #k <= 192 and #v <= 768 and count <= T.USER_WORD_LIMIT and cost <= T.USER_WORD_LIMIT and bytes <= T.USER_BYTE_LIMIT
	end
	for k, v in pairs(entries or {}) do
		if k ~= replaceKey and not include(k, v) then return false end
	end
	if replaceKey and not include(replaceKey, replaceValue) then return false end
	return true
end
local builtinPhraseWords
function T.SetUserEntries(entries)
	if not T.CheckUserWordBudget(entries) then return false, "budget" end
	builtinPhraseWords = builtinPhraseWords or T.maxPhraseWords
	T.maxPhraseWords = builtinPhraseWords
	T.userLexicon = {}
	local scanned = 0
	for english, value in pairs(entries or {}) do
		scanned = scanned + 1
		if scanned % 64 == 0 then T.ReclaimTemporaryMemory() end
		if type(english) == "string" and type(value) == "string" then
			local pos, rest = value:match("^([A-Za-z]+):(.+)$")
			if not pos then
				pos, rest = "x", value
			end
			local key, entry = ParseLine(pos, english .. "=" .. rest)
			if key then
				T.userLexicon[key] = entry
				local words = select(2, key:gsub(" ", " ")) + 1
				if words > T.maxPhraseWords then
					T.maxPhraseWords = words
				end
			end
		end
	end
	return true
end

local function Exact(key)
	if T.userLexicon[key] then return T.userLexicon[key] end
	if T.cyrodiilPriority then
		return T.cyrodiilLexicon[key] or lexicon[key]
	end
	return lexicon[key] or T.cyrodiilLexicon[key]
end

T.Exact = Exact

-- The entry as the given part of speech, or nil.
function T.As(entry, pos)
	if not entry then
		return nil
	end
	if entry.pos == pos then
		return entry
	end
	return entry.alts and entry.alts[pos] or nil
end

-- Which parts of speech each suffix may come off. "sings" is a verb, "swords" a noun; "ed"
-- never makes a noun.
local SUFFIX_RULES = {
	{ "ies", { "y" }, { n = "plural", v = "third" } },
	{ "ves", { "f", "fe" }, { n = "plural" } },
	{ "es", { "", "e" }, { n = "plural", v = "third" } },
	{ "s", { "" }, { n = "plural", v = "third", x = "plural" } },
	{ "ied", { "y" }, { v = "past" } },
	{ "ed", { "", "e", "double" }, { v = "past" } },
	{ "ying", { "ie" }, { v = "ing" } },
	{ "ing", { "", "e", "double" }, { v = "ing" } },
	{ "iest", { "y" }, { a = "superlative" } },
	{ "est", { "", "e", "double" }, { a = "superlative" } },
	{ "ier", { "y" }, { a = "comparative" } },
	{ "er", { "", "e", "double" }, { a = "comparative" } },
	{ "ily", { "y" }, { a = "adverb" } },
	{ "ly", { "", "le" }, { a = "adverb" } },
}

local function Candidates(word, suffix, endings)
	local stem = word:sub(1, #word - #suffix)
	if #stem < 2 then
		return {}
	end
	local out = {}
	for _, ending in ipairs(endings) do
		if ending == "double" then
			local last = stem:sub(-1)
			if #stem >= 3 and stem:sub(-2, -2) == last then
				out[#out + 1] = stem:sub(1, -2)
			end
		else
			out[#out + 1] = stem .. ending
		end
	end
	return out
end

-- Look a single lower-case word up. Returns entry, inflection (or nil), base word.
-- skipExact looks past an exact entry to the inflected reading ("understood" the expression
-- -> "understand" past).
function T.Lookup(word, skipExact, skipIrregular)
	local entry = not skipExact and Exact(word)
	if entry then
		return entry, nil, word
	end

	local irregular = not skipIrregular and T.irregular[word]
	if irregular then
		entry = Exact(irregular.base)
		if entry then
			return entry, irregular.inflection, irregular.base
		end
	end

	for _, rule in ipairs(SUFFIX_RULES) do
		local suffix, endings, allowed = rule[1], rule[2], rule[3]
		if #word > #suffix and word:sub(-#suffix) == suffix then
			for _, base in ipairs(Candidates(word, suffix, endings)) do
				local found = Exact(base)
				if found and allowed[found.pos] then
					return found, allowed[found.pos], base
				end
				if found and found.alts then
					for pos, inflection in pairs(allowed) do
						if found.alts[pos] then
							return found.alts[pos], inflection, base
						end
					end
				end
			end
		end
	end

	return nil
end
