-- PB's Translate -- English sentence structure, read as a tree
--
-- Grammar.lua reads a sentence in one pass and writes Japanese as it goes. That is fast and
-- handles the short calls of PvP chat, but it has no memory of structure: it cannot say where
-- a noun phrase ends, which verb an adverb belongs to, or that "what I'm doing" is one unit
-- inside "I have no idea what I'm doing". This file reads a whole segment into a tree first
-- (Syntax.lua), and SyntaxGen.lua writes the Japanese from the tree.
--
-- It only answers when it understood every word: one complete analysis of the whole segment
-- that leaves nothing over. Anything else -- a call with no verb, a word it cannot place, a
-- construction it does not know -- returns nil and the old engine translates the segment as
-- before. So a gap here costs nothing; a wrong tree costs a worse line than before, which is
-- why the tests compare the two engines on every sentence in the test files.
--
-- The parser is a packrat recursive descent: each rule is asked "what can start here?" and
-- answers with every position it could end at, best analysis for each, remembered. English
-- word order is ambiguous in exactly the places a single pass guesses at (is "start" a noun in
-- "does the trial start tonight"?), and a parser that keeps both and lets the rest of the
-- sentence decide gets those right without a special case for each.
--
-- Lua 5.1: no goto, no integer division, at most 60 upvalues in a function -- so the shared
-- word lists live in one table (L) and the rules are methods.

PBsTranslate = PBsTranslate or {}
local T = PBsTranslate

local S = { enabled = true }
T.Syntax = S

local L = {}
S.L = L

-- ---------------------------------------------------------------------------------------
-- Word lists. Grammar words are recognised by spelling, the way Grammar.lua does it.
-- ---------------------------------------------------------------------------------------

L.BE = {
	am = { person = 1 }, is = { person = 3 }, are = {}, was = { past = true }, were = { past = true },
	be = { base = true }, been = { participle = true }, being = { gerund = true },
}
L.DO = { ["do"] = {}, does = {}, did = { past = true } }
L.HAVE = { have = {}, has = {}, had = { past = true } }
L.MODAL = {
	will = "will", would = "would", shall = "shall", can = "can", could = "could",
	should = "should", must = "must", may = "may", might = "might",
}
L.NEG = { ["not"] = true, never = true }
L.ART = { a = "indef", an = "indef", the = "def" }

-- A word that can only be the subject of its clause, and whom it stands for.
L.SUBJECT_PRON = { i = true, you = true, we = true, they = true, he = true, she = true, it = true }
L.OBJECT_PRON = { me = true, us = true, him = true, them = true, her = true, it = true, you = true }

-- Coordinating conjunctions join two clauses of equal rank.
L.CO = { ["and"] = "and", but = "but", ["or"] = "or", so = "so", ["then"] = "then" }

-- Subordinating conjunctions put one clause under another. kind picks the Japanese ending.
L.SUB = {
	["if"] = "if", unless = "unless", when = "when", ["while"] = "while", ["until"] = "until",
	because = "because", since = "since", although = "although", though = "although",
	after = "after", before = "before", once = "when", whenever = "whenever",
}
-- Subordinators that are also prepositions: a clause only follows them if a subject does.
L.SUB_PREP = { after = true, before = true, since = true, ["until"] = true, ["while"] = false }

-- Verbs that take a clause as their object: "I think we should wait".
L.REPORT = {
	think = true, guess = true, believe = true, hope = true, know = true, say = true, feel = true,
	suppose = true, bet = true, hear = true, remember = true, forget = true, wonder = true,
	understand = true, mean = true, tell = true, realize = true, realise = true, notice = true,
	wish = true, admit = true, claim = true, explain = true, mention = true, discover = true,
	doubt = true, expect = true, imagine = true, assume = true, learn = true, find = true,
	agree = true, insist = true, suggest = true, warn = true, promise = true, show = true,
	see = true, ask = true, check = true, decide = true, worry = true, bet2 = true, ["make sure"] = true,
}
-- ... and those that take "to + verb": "I want to go".
L.TO_VERB = {
	want = "want", need = "need", try = "try", like = "like", love = "like", hate = "hate", plan = "plan",
	hope = "hope", wish = "want", decide = "decide", forget = "forget", remember = "remember",
	start = "start", begin = "start", continue = "continue", prefer = "like", manage = "manage",
	afford = "afford", refuse = "refuse", offer = "offer", agree = "agree", promise = "promise",
	expect = "expect", intend = "plan", learn = "learn", choose = "decide", seem = "seem",
	appear = "seem", happen = "happen", used = "usedto",
	ask = "ask", tell = "tell", order = "tell", allow = "allow", invite = "tell", remind = "tell",
	help = "help", ["get"] = "get", ["come"] = "come", ["go"] = "goto",
}
-- Verbs followed by a gerund: "I enjoy playing", "stop attacking".
L.GERUND = {
	enjoy = "enjoy", stop = "stop", keep = "keep", finish = "finish", start = "start", begin = "start",
	continue = "continue", avoid = "avoid", mind = "mind", practice = "practice", quit = "stop",
	love = "like", like = "like", hate = "hate", try = "try", remember = "remember", forget = "forget",
	["go"] = "go", suggest = "suggest", consider = "consider", risk = "risk", miss = "miss", imagine = "imagine",
	recommend = "recommend",
}
-- Linking verbs: followed by an adjective or a noun, not an object.
L.LINK = {
	be = true, become = true, seem = true, look = true, feel = true, sound = true, stay = true,
	remain = true, turn = true, get = true, grow = true, smell = true, taste = true, keep = true,
	appear = true, go = true,
}
-- Two objects: "give me the key".
L.DITRANS = {
	give = true, show = true, tell = true, send = true, teach = true, offer = true, bring = true,
	buy = true, sell = true, pay = true, owe = true, lend = true, hand = true, pass = true,
	make = true, get = true, find = true, cook = true, ask = true, grant = true, throw = true,
}
-- A verb, an object, then a bare verb: "let me know", "help me find".
L.CAUSE_BARE = { let = true, make = true, help = true, have = true, see = true, hear = true, watch = true }

-- Adverbs that go in front of the whole clause.
L.TIME_ADV = {
	now = true, today = true, tomorrow = true, yesterday = true, tonight = true, later = true, soon = true,
	earlier = true, recently = true, lately = true, ["right now"] = true, ["this week"] = true,
	["last night"] = true, ["next week"] = true, ["this weekend"] = true, ["last week"] = true,
	["at the moment"] = true, ["these days"] = true, ["every day"] = true, ["every week"] = true,
	["every weekend"] = true, ["right away"] = true, ["tonite"] = true, ["this morning"] = true,
	["this evening"] = true, ["next time"] = true, ["last time"] = true, ["every time"] = true,
}
-- Adverbs that stay beside the verb.
L.ASPECT_ADV = {
	already = true, still = true, yet = true, always = true, never = true, usually = true, often = true,
	sometimes = true, just = true, ever = true, finally = true, almost = true, again = true, also = true,
	too = true, only = true, even = true, soon = true, probably = true, maybe = true, really = true,
	actually = true, definitely = true, totally = true, completely = true, simply = true, certainly = true,
	obviously = true, basically = true, seriously = true, honestly = true, apparently = true,
	eventually = true, immediately = true, quickly = true, slowly = true, easily = true, all = true, both = true,
}
-- Degree words: they modify an adjective or an adverb, not a verb.
L.DEGREE = {
	very = true, so = true, too = true, quite = true, pretty = true, really = true, extremely = true,
	totally = true, super = true, fairly = true, rather = true, how = false, enough = false,
	incredibly = true, absolutely = true, completely = true, much = true,
}
-- Sentence adverbs: the speaker's comment on the whole clause.
-- Adverbs that stand before the verb, not after it.
L.PRE_ONLY = {
	just = true, already = true, still = true, always = true, never = true, usually = true, often = true,
	sometimes = true, even = true, only = true, really = true, actually = true, definitely = true,
	probably = true, maybe = true, simply = true, basically = true, finally = true, almost = true,
	ever = true, totally = true, completely = true, certainly = true, obviously = true,
}
L.SENTENCE_ADV = {
	maybe = true, perhaps = true, probably = true, actually = true, unfortunately = true,
	luckily = true, honestly = true, obviously = true, apparently = true, basically = true,
	anyway = true, however = true, anyways = true, hopefully = true, seriously = true, sadly = true,
}

-- Nouns that may take an infinitive after them: "time to go", "something to eat".
L.INF_NOUN = {
	time = true, chance = true, way = true, place = true, thing = true, reason = true, need = true,
	plan = true, goal = true, option = true, ability = true, right = true, opportunity = true, spot = true,
	room = true, one = true, person = true, people = true, guide = true, tank = true, healer = true,
	dps = true, player = true, players = true, member = true, members = true, something = true,
	anything = true, nothing = true, someone = true, anyone = true, everything = true, food = true,
	money = true, help = true, idea = true, tip = true, tips = true, trick = true, step = true,
	steps = true, day = true, week = true, hour = true, minute = true, effort = true, courage = true,
	energy = true, patience = true, key = true, item = true, items = true, quest = true, friends = true,
	friend = true, book = true, stuff = true, job = true, work = true, task = true, goal2 = true,
}

-- Prepositions, and what each says when no verb tells it more.
L.PLACE_PREP = { ["in"] = true, at = true, on = true, inside = true, outside = true, near = true,
	behind = true, under = true, over = true, above = true, below = true, between = true, around = true,
	across = true, along = true, beside = true, ["in front of"] = true, ["next to"] = true,
	["on top of"] = true, ["far from"] = true, ["close to"] = true, among = true, beyond = true }

L.MOTION = {
	go = true, come = true, move = true, run = true, walk = true, head = true, ["return"] = true,
	travel = true, port = true, teleport = true, arrive = true, fly = true, hurry = true, ride = true,
	drive = true, swim = true, jump = true, ["get to"] = true, ["come back"] = true, ["go back"] = true,
	["head to"] = true, leave = true, enter = true, visit = true,
}

-- ---------------------------------------------------------------------------------------
-- Small helpers
-- ---------------------------------------------------------------------------------------

local function Lower(text) return T.Lower and T.Lower(text) or text:lower() end

-- A result set: best analysis per end position.
local function NewResults() return { by = {} } end
local function Add(results, stop, node, score)
	local current = results.by[stop]
	if current == nil then
		local entry = { stop = stop, node = node, score = score }
		results.by[stop] = entry
		results[#results + 1] = entry
	elseif score > current.score then
		current.node, current.score = node, score
	end
end

S.NewResults, S.Add = NewResults, Add

-- ---------------------------------------------------------------------------------------
-- Readings: what each word could be
--
-- cat is one of
--   BE DO HAVE MODAL NEG ART TO CONJ THAT LET LETS THERE POSS
--   N PRON DET ADJ ADV PREP WH V X NUM RAW UNK
-- pref biases the parser toward the reading Disambiguate already chose.
-- ---------------------------------------------------------------------------------------

local function Reading(cat, item, extra)
	local r = { cat = cat, w = item.w, item = item, pref = 0 }
	if extra then
		for k, v in pairs(extra) do r[k] = v end
	end
	return r
end

-- The adverb an adjective makes: 強い -> 強く, 静か -> 静かに.
local function AdverbOf(entry)
	if entry.class == "na" then return entry.ja .. "に" end
	if entry.class == "rel" then return entry.ja end
	local word = entry.ja == "いい" and "よ" or entry.ja:sub(1, -4)
	return word .. "く"
end
S.AdverbOf = AdverbOf

-- The English base of a verb reading, checked against the dictionary: "lives" is also the plural
-- of "life", but the verb it reads as is "live".
local function VerbBase(item, entry, infl)
	local w = item.w
	local function IsIt(candidate)
		local found = T.As(T.Exact(candidate), "v")
		return found ~= nil and found.ja == entry.ja
	end
	if item.base and IsIt(item.base) then return item.base end
	local candidates = {}
	local irregular = T.irregular and T.irregular[w]
	if irregular then candidates[#candidates + 1] = irregular.base end
	if infl == "third" then
		candidates[#candidates + 1] = w:sub(1, -2)
		candidates[#candidates + 1] = w:sub(1, -3)
		if w:sub(-3) == "ies" then candidates[#candidates + 1] = w:sub(1, -4) .. "y" end
	elseif infl == "past" then
		candidates[#candidates + 1] = w:sub(1, -3)
		candidates[#candidates + 1] = w:sub(1, -2)
		if w:sub(-3) == "ied" then candidates[#candidates + 1] = w:sub(1, -4) .. "y" end
		candidates[#candidates + 1] = w:sub(1, -4)
	elseif infl == "ing" then
		candidates[#candidates + 1] = w:sub(1, -4)
		candidates[#candidates + 1] = w:sub(1, -4) .. "e"
		candidates[#candidates + 1] = w:sub(1, -5)
	else
		candidates[#candidates + 1] = w
	end
	for _, candidate in ipairs(candidates) do
		if candidate ~= "" and IsIt(candidate) then return candidate end
	end
	return item.base
end

function S.Readings(item)
	local out = {}
	if item.kind == "raw" then
		out[1] = Reading("RAW", item, { ja = item.v })
		return out
	elseif item.kind == "num" then
		out[1] = Reading("NUM", item, { v = item.v })
		return out
	elseif item.kind ~= "word" then
		return out
	end
	local w = item.w
	local entry = item.entry

	-- grammar words
	if L.BE[w] then out[#out + 1] = Reading("BE", item, { be = L.BE[w], pref = 3 }) end
	if L.DO[w] then out[#out + 1] = Reading("DO", item, { dobe = L.DO[w], pref = 3 }) end
	if L.HAVE[w] then out[#out + 1] = Reading("HAVE", item, { have = L.HAVE[w], pref = 3 }) end
	if L.MODAL[w] then out[#out + 1] = Reading("MODAL", item, { modal = L.MODAL[w], pref = 3 }) end
	if L.NEG[w] then out[#out + 1] = Reading("NEG", item, { neg = w, pref = 3 }) end
	if L.ART[w] then out[#out + 1] = Reading("ART", item, { art = L.ART[w], pref = 3 }) end
	if w == "to" then out[#out + 1] = Reading("TO", item, { pref = 2 }) end
	if w == "that" then out[#out + 1] = Reading("THAT", item, { pref = 2 }) end
	if w == "let's" then out[#out + 1] = Reading("LETS", item, { pref = 3 }) end
	if w == "let" then
		out[#out + 1] = Reading("LET", item, { pref = 1 })
		out[#out + 1] = Reading("V", item, { entry = { pos = "v", ja = "させる", class = "1" }, base = "let", pref = 2 })
	end
	if w == "there" then out[#out + 1] = Reading("THERE", item, { pref = 1 }) end
	if w == "'s" then out[#out + 1] = Reading("POSS", item, { pref = 3 }) end
	if w == "before" then out[#out + 1] = Reading("ADV", item, { entry = { pos = "adv", ja = "以前", time = true }, pref = 0 }) end
	if w == "better" then out[#out + 1] = Reading("ADV", item, { entry = { pos = "adv", ja = "もっとうまく" }, pref = 0 }) end
	if w == "all" then out[#out + 1] = Reading("ADV", item, { entry = { pos = "adv", ja = "みんな" }, pref = 0 }) end
	if w == "both" then out[#out + 1] = Reading("ADV", item, { entry = { pos = "adv", ja = "二人とも" }, pref = 0 }) end
	if w == "of" then out[#out + 1] = Reading("OF", item, { pref = 3 }) end
	if w == "as" then out[#out + 1] = Reading("AS", item, { pref = 3 }) end
	if w == "than" then out[#out + 1] = Reading("THAN", item, { pref = 3 }) end
	if L.CO[w] and not item.phrase then out[#out + 1] = Reading("CONJ", item, { conj = L.CO[w], kind = "co", pref = 2 }) end
	if L.SUB[w] and not item.phrase then out[#out + 1] = Reading("CONJ", item, { conj = L.SUB[w], kind = "sub", pref = 2 }) end

	-- dictionary readings
	local function FromEntry(e, primary)
		local pref = primary and 2 or 0
		local pos, infl = e.pos, item.infl
		if not primary and item.altInflection and pos == "v" then infl = item.altInflection end
		if pos == "n" then
			local plural = infl == "plural" or infl == "third" or nil
			out[#out + 1] = Reading("N", item, { entry = e, plural = plural, pref = pref, base = item.base })
		elseif pos == "pn" then
			out[#out + 1] = Reading("PRON", item, { entry = e, pref = pref })
		elseif pos == "det" then
			out[#out + 1] = Reading("DET", item, { entry = e, pref = pref })
		elseif pos == "a" then
			out[#out + 1] = Reading("ADJ", item, { entry = e, infl = infl, pref = pref })
			if infl == "adverb" then
				out[#out + 1] = Reading("ADV", item, { entry = { pos = "adv", ja = AdverbOf(e) }, adjective = e, pref = pref + 1 })
			end
		elseif pos == "adv" then
			out[#out + 1] = Reading("ADV", item, { entry = e, pref = pref })
		elseif pos == "prep" then
			out[#out + 1] = Reading("PREP", item, { entry = e, pref = pref })
		elseif pos == "wh" then
			out[#out + 1] = Reading("WH", item, { entry = e, pref = pref })
		elseif pos == "v" and (infl == "comparative" or infl == "superlative") and (e.class == "i" or e.class == "na") then
			out[#out + 1] = Reading("ADJ", item, { entry = e, infl = infl, pref = pref })
		elseif pos == "v" then
			local verbInfl = infl
			if verbInfl == "plural" then verbInfl = "third" end
			local inflectedPhrase
			if verbInfl == nil and item.phrase then
				-- "made of", "known as": the phrase starts with an inflected form, so it is no bare verb
				local first = w:match("^(%S+)")
				local irregular = first and T.irregular and T.irregular[first]
				inflectedPhrase = (irregular and irregular.base ~= first)
					or (first and #first > 4 and first:sub(-2) == "ed" and first:sub(-3) ~= "eed") or nil
			end
			local base = (not primary and item.altBase) or VerbBase(item, e, verbInfl)
			out[#out + 1] = Reading("V", item, { entry = e, infl = verbInfl, base = base, pref = pref, inflectedPhrase = inflectedPhrase })
		elseif pos == "x" then
			out[#out + 1] = Reading("X", item, { entry = e, pref = pref })
		end
	end
	if entry then
		FromEntry(entry, true)
		-- "finished", "closed": stored as a state ("is finished"), but "I finished it" is the past of the verb
		if item.infl == nil and not item.phrase and entry.pos == "v" and #w > 4 and w:sub(-2) == "ed" then
			local ja = entry.ja or ""
			if ja:sub(-9) == "ている" or ja:sub(-9) == "でいる" then
				local candidates = { w:sub(1, -3), w:sub(1, -2) }
				if w:sub(-3) == "ied" then candidates[#candidates + 1] = w:sub(1, -4) .. "y" end
				if w:sub(-3, -3) == w:sub(-4, -4) then candidates[#candidates + 1] = w:sub(1, -4) end
				for _, candidate in ipairs(candidates) do
					local stem = T.As(T.Exact(candidate), "v")
					if stem and stem ~= entry and stem.ja ~= entry.ja then
						out[#out + 1] = Reading("V", item, { entry = stem, infl = "past", base = candidate, pref = 1, extraPast = true })
						break
					end
				end
			end
		end
		-- "looking for": a dictionary phrase of its own, and also the -ing form of "look for"
		if item.phrase and item.infl == nil and entry.pos ~= "n" then
			local first, rest = w:match("^(%S+)(.*)$")
			local _, firstInfl, firstBase = T.Lookup(first)
			if firstInfl and firstBase and firstBase ~= first and rest ~= "" then
				local candidate = T.As(T.Exact(firstBase .. rest), "v")
				if candidate and candidate ~= entry then
					out[#out + 1] = Reading("V", item, { entry = candidate, infl = firstInfl == "plural" and "third" or firstInfl,
						base = firstBase .. rest, pref = 2 })
				end
			end
		end
		-- "quests": Lookup may hand back the verb alone; the noun is still a reading
		local base = item.base
		if base and base ~= w then
			local full = T.Exact(base)
			if full then
				local have = {}
				for _, r in ipairs(out) do have[r.cat] = true end
				local infl = item.infl
				local function Extra(e)
					if e == entry then return end
					if e.pos == "n" and not have.N and (infl == nil or infl == "plural" or infl == "third") then FromEntry(e, false); have.N = true
					elseif e.pos == "v" and not have.V and (infl == nil or infl == "third" or infl == "past" or infl == "ing") then FromEntry(e, false); have.V = true
					elseif e.pos == "a" and not have.ADJ and (infl == nil or infl == "comparative" or infl == "superlative") then FromEntry(e, false); have.ADJ = true end
				end
				Extra(full)
				for _, alt in pairs(full.alts or {}) do Extra(alt) end
			end
		end
		if entry.alts then
			-- stable order, so two runs read a word the same way
			local order = {}
			for pos in pairs(entry.alts) do order[#order + 1] = pos end
			table.sort(order)
			for _, pos in ipairs(order) do FromEntry(entry.alts[pos], false) end
		end
	end

	-- an unknown word: a name if it is capitalised, otherwise a guess the caller may refuse
	if not entry and #out == 0 then
		local orig = item.orig or w
		local capital = orig:match("^[A-Z]") ~= nil
		out[#out + 1] = Reading("UNK", item, { ja = orig, name = capital and not item.sentenceStart, pref = capital and 1 or -2 })
	end
	return out
end

-- ---------------------------------------------------------------------------------------
-- The parser
-- ---------------------------------------------------------------------------------------

local P = {}
P.__index = P
S.P = P

function S.NewParser(items)
	local parser = setmetatable({ items = items, n = #items, R = {}, memo = {} }, P)
	for i, item in ipairs(items) do
		parser.R[i] = S.Readings(item)
	end
	return parser
end

-- Memoise a rule at a position. A rule called again at the same position while it is still
-- being worked out (left recursion) sees nothing, which is what stops the loop.
function P:Memo(name, i, rule)
	local table_ = self.memo[name]
	if not table_ then
		table_ = {}
		self.memo[name] = table_
	end
	local cached = table_[i]
	if cached ~= nil then return cached end
	table_[i] = NewResults()
	local results = rule(self, i) or NewResults()
	table_[i] = results
	return results
end

-- The readings of word i with a given category.
function P:Has(i, cat)
	for _, r in ipairs(self.R[i] or {}) do
		if r.cat == cat then return r end
	end
	return nil
end

-- Is word i an adjective -- or a verb the dictionary stores as one (busy = 忙しい, tired = 疲れている)?
function P:AdjLike(i)
	if self:Has(i, "ADJ") then return true end
	local v = self:Has(i, "V")
	if v and v.infl == nil and v.entry then
		local e = v.entry
		return e.class == "i" or e.class == "na" or (e.ja or ""):sub(-9) == "ている" or (e.ja or ""):sub(-9) == "でいる"
			or ((e.ja or ""):sub(-9) == "がある" and e.particle ~= nil)
	end
	return false
end

function P:W(i)
	local item = self.items[i]
	return item and item.kind == "word" and item.w or nil
end

-- ---------------------------------------------------------------------------------------
-- Noun phrases
--
-- A node is { cat = "NP", ja = "...", ... }. ja is the Japanese for the phrase without any
-- particle. The fields the generator needs besides it:
--   pron      the English pronoun ("i", "you", "someone", ...)   head   the head noun's entry
--   def       definite (the, this, my, a name, a pronoun)         indef  a/an/some/any/a number
--   plural    animate   neg (no X, nobody)   wh (who, what)   count (a quantity)
--   time place unit   -- the head noun's flags
-- ---------------------------------------------------------------------------------------

-- Nouns that name a stretch of time even when the dictionary does not say so.
L.TIME_NOUN = { day = true, week = true, weekend = true, night = true, morning = true, afternoon = true, evening = true,
	month = true, year = true, monday = true, tuesday = true, wednesday = true, thursday = true, friday = true,
	saturday = true, sunday = true, hour = true, minute = true, second = true, today = true, tonight = true }
L.EVERY = { day = "毎日", week = "毎週", weekend = "毎週末", night = "毎晩", morning = "毎朝", afternoon = "毎日午後", evening = "毎晩",
	month = "毎月", year = "毎年", monday = "毎週月曜日", tuesday = "毎週火曜日", wednesday = "毎週水曜日", thursday = "毎週木曜日",
	friday = "毎週金曜日", saturday = "毎週土曜日", sunday = "毎週日曜日" }
L.DURATION = { ["秒"] = true, ["分"] = true, ["時間"] = true, ["日"] = true, ["週"] = true, ["月"] = true, ["年"] = true,
	["世紀"] = true, ["瞬間"] = true }
L.NUMWORD = {
	one = 1, two = 2, three = 3, four = 4, five = 5, six = 6, seven = 7, eight = 8, nine = 9, ten = 10,
	eleven = 11, twelve = 12, thirteen = 13, fourteen = 14, fifteen = 15, sixteen = 16, seventeen = 17,
	eighteen = 18, nineteen = 19, twenty = 20, thirty = 30, forty = 40, fifty = 50, sixty = 60,
	seventy = 70, eighty = 80, ninety = 90, hundred = 100, thousand = 1000, dozen = 12,
}
L.FREQ_UNIT = { day = "1日", week = "週", month = "月", year = "年", hour = "1時間", night = "夜", weekend = "週末", minute = "1分" }
L.QUANT_OF = { all = true, most = true, many = true, both = true, several = true }
L.APPROX = { about = true, around = true, roughly = true, approximately = true }
L.POSSESSIVE = { my = true, your = true, our = true, their = true, his = true, its = true }
L.DEMONSTRATIVE = { this = "この", that = "その", these = "これらの", those = "それらの" }
-- Determiners with no Japanese of their own in an ordinary sentence.
L.DROP_DET = { any = true, some = true, a = true, an = true, the = true }
L.INDEF_PRON = {
	someone = true, somebody = true, anyone = true, anybody = true, nobody = true, ["no one"] = true,
	something = true, anything = true, nothing = true, everyone = true, everybody = true, everything = true,
	none = true,
}
L.NEG_PRON = { nobody = true, ["no one"] = true, nothing = true, none = true }

-- The number a word stands for: "5" or "twenty".
function P:NumberAt(i)
	local item = self.items[i]
	if not item then return nil end
	if item.kind == "num" then return item.formatted or item.v end
	if item.kind == "word" and L.NUMWORD[item.w] and not T.userLexicon[item.w] then
		return tostring(L.NUMWORD[item.w])
	end
	return nil
end

local function AttributiveAdjective(entry, infl, degreePrefix)
	local word = entry.class == "na" and (entry.ja .. "な") or entry.ja
	if infl == "comparative" then word = "もっと" .. word
	elseif infl == "superlative" then word = "一番" .. word end
	return (degreePrefix or "") .. word
end
S.AttributiveAdjective = AttributiveAdjective

-- Read the modifiers in front of a head noun, starting at i. Returns the index of the first
-- word that is not one, and what was read.
function P:PreModifiers(i)
	local items, R = self.items, self.R
	local info = { adjs = {}, score = 0 }
	local k = i
	while R[k] do
		local item = items[k]
		local w = item.kind == "word" and item.w or nil
		local number = self:NumberAt(k)
		local art = self:Has(k, "ART")
		local det = self:Has(k, "DET")
		local nextIsNP = self:StartsNoun(k + 1)
		if #info.adjs > 0 and (art or (w and (L.POSSESSIVE[w] or L.DEMONSTRATIVE[w])) or w == "her") then
			-- "sorry my internet": the adjective is not part of this noun phrase
			break
		elseif art then
			info.art = art.art
			k = k + 1
		elseif w and L.APPROX[w] and not info.number and not info.approx and self:NumberAt(k + 1) and self:StartsNoun(k + 2) then
			-- "about ten minutes": 約10分
			info.approx = "約"
			info.score = info.score + 0.4
			k = k + 1
		elseif number and self:W(k + 1) == "more" and self:StartsNoun(k + 2) and not info.number then
			-- "one more person": あと1人
			info.number = number
			info.more = true
			k = k + 2
		elseif number and (self:StartsNoun(k + 1) or self:W(k + 1) == "more") and not info.number then
			info.number = number
			k = k + 1
		elseif w == "more" and self:Has(k + 1, "ADJ") and not info.number then
			info.degree = "comparative"
			k = k + 1
		elseif w == "most" and self:Has(k + 1, "ADJ") then
			info.degree = "superlative"
			k = k + 1
		elseif w and L.DEMONSTRATIVE[w] and nextIsNP and not info.dem then
			info.dem = L.DEMONSTRATIVE[w]
			k = k + 1
		elseif w == "her" and nextIsNP and not info.poss then
			info.poss = "彼女の"
			k = k + 1
		elseif det and w and L.POSSESSIVE[w] and not info.poss then
			info.poss = det.entry.ja
			k = k + 1
		elseif w == "no" and nextIsNP then
			info.neg = true
			k = k + 1
		elseif w == "neither" and nextIsNP then
			info.neg = true
			info.neither = true
			info.quant = "どちらの"
			info.quantWord = "neither"
			k = k + 1
		elseif det and w and L.QUANT_OF[w] and self:W(k + 1) == "of" and not info.quant and not info.art
			and (self:Has(k + 2, "ART") or L.POSSESSIVE[self:W(k + 2) or ""] or L.DEMONSTRATIVE[self:W(k + 2) or ""]) and self:StartsNoun(k + 3) then
			-- "all of the quests", "most of my friends"
			info.quant = det.entry.ja
			info.quantWord = w
			k = k + 2
		elseif w == "too" and (self:W(k + 1) == "many" or self:W(k + 1) == "much") and self:Has(k + 1, "DET") and self:StartsNoun(k + 2)
			and not info.quant then
			-- "too many players": a statement about how many, not a quantity
			info.quant = ""
			info.tooMany = true
			k = k + 2
		elseif det and w and not number and nextIsNP and not info.quant then
			-- some, any, every, many, a lot of, a few, ...
			info.quant = det.entry.ja
			info.quantWord = w
			k = k + 1
		else
			-- an adjective, with a degree adverb in front of it
			local degree
			local adverb = self:Has(k, "ADV")
			local m = k
			if adverb and w and L.DEGREE[w] and self:Has(k + 1, "ADJ") then
				degree = adverb.entry.ja
				m = k + 1
			end
			local adj = self:Has(m, "ADJ")
			if adj and self:StartsNoun(m + 1, true) and adj.infl ~= "adverb" then
				info.adjs[#info.adjs + 1] = { entry = adj.entry, infl = adj.infl or info.degree, degree = degree }
				info.degree = nil
				if adj.pref < 2 then info.score = info.score - 1 end
				k = m + 1
			else
				break
			end
		end
	end
	return k, info
end

-- Could a noun phrase's head begin at i, once the modifiers are skipped? (cheap look-ahead,
-- so a modifier is only taken when a noun follows it)
function P:StartsNoun(i, afterAdjective)
	local R = self.R[i]
	if not R then return false end
	local k = i
	-- skip modifiers
	while self.R[k] do
		local item = self.items[k]
		local w = item.kind == "word" and item.w or nil
		if self:Has(k, "N") or self:Has(k, "UNK") then return true end
		if item.kind == "raw" or item.kind == "num" then return true end
		if self:Has(k, "PRON") and not afterAdjective then return true end
		if w and L.QUANT_OF[w] and self:W(k + 1) == "of" and self:Has(k, "DET") and (self:Has(k + 2, "ART")
			or L.POSSESSIVE[self:W(k + 2) or ""] or L.DEMONSTRATIVE[self:W(k + 2) or ""]) then
			k = k + 2
		elseif self:Has(k, "ART") or self:Has(k, "DET") or self:Has(k, "ADJ") or self:Has(k, "ADV")
			or (w and L.DEMONSTRATIVE[w]) or w == "her" or w == "no" or w == "more" or w == "most" then
			k = k + 1
		elseif self:NumberAt(k) then
			k = k + 1
		else
			return false
		end
	end
	return false
end

-- Keep, outpost and town names end in these.
local function IsPlaceName(ja)
	for _, ending in ipairs({ "砦", "基地", "城", "街" }) do
		if (ja or ""):sub(-#ending) == ending then return true end
	end
	return false
end
S.IsPlaceName = IsPlaceName

L.DIRECTIONS = { north = true, south = true, east = true, west = true, northern = true, southern = true, eastern = true, western = true }
L.STRUCTURES = { wall = true, door = true, gate = true, tower = true }

-- Join a run of nouns into one Japanese word, with the joins some entries ask for:
-- "fd kings" is キングクレスト砦の正門, "roe south wall" ローベック砦の南の壁.
local function JoinNouns(entries)
	local ja = ""
	local previous
	local first = 1
	if #entries >= 2 and entries[1].join and IsPlaceName(entries[2].ja) and not entries[2].direction then
		ja = entries[2].ja .. entries[1].join .. entries[1].ja
		previous = entries[1]
		first = 3
	end
	for index = first, #entries do
		local e = entries[index]
		if e.direction then
			ja = ja .. "の" .. (e.ja or "")
		elseif previous and previous.direction then
			ja = ja .. (previous.ja:sub(-3) == "の" and "" or "の") .. (e.ja or "")
		elseif previous and previous["then"] and not e.ends then
			ja = ja .. previous["then"] .. (e.ja or "")
		elseif previous and e.join then
			ja = ja .. e.join .. (e.ja or "")
		else
			ja = ja .. (e.ja or "")
		end
		previous = e
	end
	return ja
end

-- The head of a noun phrase and every length it could have: "trial start" is one noun or a
-- noun and the start of something else. Returns { stop = index after the run, ... }.
function P:Heads(i)
	local heads = {}
	local k = i
	local entries, flags = {}, {}
	local unknown = 0
	local penalty = 0
	local lastWasVerbNoun = false
	while self.R[k] do
		local item = self.items[k]
		local reading = self:Has(k, "N")
		local unk = not reading and self:Has(k, "UNK")
		if item.kind == "raw" then
			-- a link ends the run: it is a noun phrase of its own
			if k == i then
				heads[#heads + 1] = { stop = k + 1, ja = item.v, raw = true, entries = {} }
			end
			break
		elseif reading and lastWasVerbNoun then
			break
		elseif reading then
			entries[#entries + 1] = reading.entry
			-- a noun that is really a verb (heal, run, push) can end a compound ("dungeon run") but
			-- not sit in the middle of one ("fd heal allies")
			if reading.pref < 2 then
				lastWasVerbNoun = true
				if #entries > 1 then penalty = penalty + 0.8 end
			end
			flags.plural = reading.plural
			flags.base = reading.base or item.w
			heads[#heads + 1] = {
				stop = k + 1, entries = {},
				ja = JoinNouns(entries), plural = reading.plural, last = reading.entry, w = item.w,
				score = reading.pref * 0.3 - penalty, count = #entries,
			}
			-- a place name, a direction, a structure: "roe south wall"
			local nextItem = self.items[k + 1]
			local after = self.items[k + 2]
			if IsPlaceName(reading.entry.ja) and nextItem and nextItem.kind == "word" and L.DIRECTIONS[nextItem.w]
				and (self:Has(k + 1, "ADJ") or self:Has(k + 1, "N")) and after and after.kind == "word" and L.STRUCTURES[after.base or after.w]
				and self:Has(k + 2, "N") and not T.userLexicon[nextItem.w] then
				local dir = self:Has(k + 1, "ADJ") or self:Has(k + 1, "N")
				entries[#entries + 1] = { ja = dir.entry.ja, direction = true }
				k = k + 1
			end
			-- a run of nouns is a compound only if the next word could not start something else
			k = k + 1
		elseif unk then
			if unk.name or #entries == 0 then
				unknown = unknown + 1
				local ja = unk.ja
				heads[#heads + 1] = {
					stop = k + 1, entries = {}, ja = ((#entries > 0) and JoinNouns(entries) or "") .. ja,
					unknown = true, name = unk.name, last = nil, w = item.w, score = unk.pref, count = #entries + 1,
				}
				-- a name can be followed by another capitalised word: "Vivec City" is in the dictionary,
				-- "Fungal Grotto" is not
				entries[#entries + 1] = { ja = ja }
				k = k + 1
			else
				break
			end
		else
			break
		end
	end
	return heads
end

-- Person and number of the English pronouns.
L.PRON_INFO = {
	i = { person = 1 }, me = { person = 1 }, myself = { person = 1 }, mine = { person = 1, possessive = true },
	we = { person = 1, plural = true }, us = { person = 1, plural = true }, ours = { person = 1, plural = true, possessive = true },
	you = { person = 2 }, yourself = { person = 2 }, yours = { person = 2, possessive = true },
	he = { person = 3 }, him = { person = 3 }, she = { person = 3 }, her = { person = 3 },
	it = { person = 3, thing = true }, they = { person = 3, plural = true }, them = { person = 3, plural = true },
	theirs = { person = 3, plural = true, possessive = true },
	this = { person = 3, thing = true }, that = { person = 3, thing = true },
	these = { person = 3, thing = true, plural = true }, those = { person = 3, thing = true, plural = true },
	everyone = { person = 3, plural = true }, everybody = { person = 3, plural = true }, guys = { person = 2, plural = true },
	["y'all"] = { person = 2, plural = true }, yall = { person = 2, plural = true },
}

-- Build the node for a noun phrase from what was read in front of the head and the head itself.
function P:BuildNP(info, head)
	local parts = {}
	if info.poss then parts[#parts + 1] = info.poss end
	if info.dem then parts[#parts + 1] = info.dem end
	local quantWord = info.quantWord
	if info.quant then
		if quantWord == "only" then
			-- said after the noun, below
		elseif quantWord == "any" or quantWord == "some" then
			-- "any help", "some food": nothing in Japanese; "some potions" is いくつかの
			if quantWord == "some" and head.plural then parts[#parts + 1] = "いくつかの" end
		else
			parts[#parts + 1] = info.quant
		end
	end
	for _, adj in ipairs(info.adjs) do
		parts[#parts + 1] = AttributiveAdjective(adj.entry, adj.infl, adj.degree)
	end
	local last = head.last
	local suffix = ""
	local moreLead = ""
	local ja = head.ja
	if (head.w == "month" or head.w == "months") and ja == "月" then ja = "か月" end
	if quantWord == "every" and L.EVERY[head.w or ""] and #info.adjs == 0 then
		return { cat = "NP", ja = L.EVERY[head.w], head = last, headJa = head.ja, def = true, w = head.w, time = true }
	end
	if quantWord and L.ORDINAL[quantWord] and head.w == "time" and #info.adjs == 0 then
		-- "the third time": 3回目
		return {
			cat = "NP", ja = tostring(L.ORDINAL[quantWord]) .. "回目", head = last, headJa = head.ja, def = true, w = head.w, time = true,
		}
	end
	local animate = last and T.IsAnimateEntry and T.IsAnimateEntry(last) or false
	if info.number then
		if info.more then
			-- "two more healers": あと2人のヒーラー
			moreLead = "あと" .. info.number .. (animate and "人" or "つ") .. "の"
		elseif last and (last.time or last.unit or L.TIME_NOUN[head.w or ""]) then
			ja = (info.approx or "") .. info.number .. ja
		elseif animate then
			suffix = info.number .. "人"
		else
			suffix = "×" .. info.number
		end
	elseif info.art == "indef" and last and head.w ~= "time" and #info.adjs == 0 and (last.time or L.DURATION[last.ja or ""]) and (L.DURATION[last.ja or ""] or L.TIME_NOUN[head.w or ""]) then
		-- "a minute": 1分
		ja = "1" .. ja
		info.number = "1"
	end
	parts[#parts + 1] = ja .. suffix
	local text = moreLead
	for _, p in ipairs(parts) do text = text .. p end
	if info.neither then text = text .. "も" end
	-- "only the guards": the guards, only
	if quantWord == "only" then text = text .. "だけ" end
	return {
		cat = "NP", ja = text, neither = info.neither, onlyNP = quantWord == "only" or nil, head = last, headJa = head.ja, plural = head.plural or (info.number and tonumber(info.number) ~= 1) or nil,
		def = (info.art == "def") or info.poss ~= nil or info.dem ~= nil or head.name or nil,
		indef = (info.art == "indef") or info.number ~= nil or info.quant ~= nil or nil,
		bare = (not info.art and not info.poss and not info.dem and not info.quant and not info.number) or nil,
		neg = info.neg, count = info.number and tonumber(info.number) or nil, animate = animate,
		time = last and (last.time or L.DURATION[last.ja or ""] or L.TIME_NOUN[head.w or ""]) or nil, place = last and last.place or nil, unit = last and last.unit or nil,
		enough = quantWord == "enough" or nil, tooMany = info.tooMany,
		name = head.name, unknown = head.unknown, raw = head.raw, w = head.w, possJa = info.poss,
		adjective = (#info.adjs > 0) and info.adjs or nil, superlative = info.adjs[1] and info.adjs[1].infl == "superlative" or nil,
	}
end

function P:NPCore(i) return self:Memo("NPCore", i, P.NPCoreRule) end
function P.NPCoreRule(self, i)
	local res = NewResults()
	local item = self.items[i]
	if not item then return res end
	local w = item.kind == "word" and item.w or nil

	-- how often: "three times a week", "twice a day", "once a month"
	do
		local n, k
		if w == "once" then n, k = "1", i + 1
		elseif w == "twice" then n, k = "2", i + 1
		elseif self:NumberAt(i) and self:W(i + 1) == "times" then n, k = self:NumberAt(i), i + 2 end
		local unit = n and L.FREQ_UNIT[self:W(k + 1) or ""]
		local article = n and self:W(k)
		if unit and (article == "a" or article == "per" or article == "each" or article == "every") then
			Add(res, k + 2, { cat = "NP", ja = unit .. "に" .. n .. "回", time = true, def = true, w = "times", freq = true }, 1.5)
		elseif n and self:W(i + 1) == "times" and w ~= "once" and w ~= "twice" then
			-- "three times": 3回
			Add(res, i + 2, { cat = "NP", ja = n .. "回", time = true, def = true, w = "times", freq = true, repeatCount = true }, 1.2)
		end
		if w == "twice" then
			Add(res, i + 1, { cat = "NP", ja = "2回", time = true, def = true, w = "times", freq = true, repeatCount = true }, 0.6)
		end
		if self:W(i + 1) == "times" and (w == "many" or w == "several") then
			Add(res, i + 2, { cat = "NP", ja = w == "many" and "何度も" or "数回", time = true, def = true, w = "times", freq = true, repeatCount = true }, 1.6)
		elseif w == "a" and self:W(i + 1) == "few" and self:W(i + 2) == "times" then
			Add(res, i + 3, { cat = "NP", ja = "数回", time = true, def = true, w = "times", freq = true, repeatCount = true }, 2.2)
		end
	end

	-- pronouns, and the pronoun reading of this/that
	local pron = self:Has(i, "PRON")
	if pron and w then
		local info = L.PRON_INFO[w] or { person = 3 }
		local possessiveHer = w == "her" and self:StartsNoun(i + 1)
		local determiner = L.DEMONSTRATIVE[w] and self:StartsNoun(i + 1)
		if not possessiveHer and not determiner then
			local indefinite = L.INDEF_PRON[w] ~= nil
			Add(res, i + 1, {
				cat = "NP", ja = pron.entry.ja, pron = w, person = info.person, plural = info.plural,
				def = not indefinite or nil, indef = indefinite or nil, neg = L.NEG_PRON[w] or nil,
				animate = info.person ~= 3 or w == "someone" or w == "somebody" or w == "anyone" or w == "anybody"
					or w == "everyone" or w == "everybody" or w == "nobody" or w == "no one" or w == "guys" or nil,
				thing = info.thing, possessivePron = info.possessive,
			}, 0.3 + pron.pref * 0.1)
		end
	end

	-- wh-words standing for a noun: who, what (which/what + noun is handled below)
	local wh = self:Has(i, "WH")
	if wh and w and (w == "who" or w == "what" or w == "whom" or w == "which") then
		Add(res, i + 1, { cat = "NP", ja = wh.entry.ja, wh = w, pron = w, def = false, person = 3 }, -0.3)
	end

	-- "that one", "these ones"
	if w and L.DEMONSTRATIVE[w] and (self:W(i + 1) == "one" or self:W(i + 1) == "ones") then
		local ja = ({ this = "これ", that = "それ", these = "これら", those = "それら" })[w]
		Add(res, i + 2, { cat = "NP", ja = ja, pron = w, person = 3, thing = true, def = true, plural = (w == "these" or w == "those") or nil }, 0.6)
	end
	-- how many people, how much money
	if wh and (w == "how many" or w == "how much") and self:StartsNoun(i + 1) then
		local k2, info2 = self:PreModifiers(i + 1)
		for _, head in ipairs(self:Heads(k2)) do
			local node = self:BuildNP(info2, head)
			local animate = node.animate
			node.ja = (w == "how many" and (animate and "何人の" or "いくつの") or "どれくらいの") .. node.ja
			node.whDet = w
			node.indef = nil
			Add(res, head.stop, node, info2.score + (head.score or 0) * 0.1 - 0.3 * (head.count - 1))
		end
	end
	-- "any of the markers", "one of the keeps", "all of them"
	if w and L.PARTITIVE[w] and self:Has(i + 1, "OF") then
		for _, a in ipairs(self:NP(i + 2)) do
			local inner = a.node
			if (inner.plural or inner.pron or inner.def) and not inner.wh then
				local node = {}
				for k, v in pairs(inner) do node[k] = v end
				local rule = L.PARTITIVE[w]
				local text = inner.ja or ""
				if rule == "one" then text = text .. (inner.pron and "のうちの1人" or "の1つ")
				elseif rule == "none" or rule == "neither" then
					node.neg = true
					text = text .. ((inner.pron and inner.person ~= 3 or inner.animate) and "の誰も" or "のどれも")
				elseif rule == "" then text = text
				elseif inner.pron then
					text = text .. ((w == "all" or w == "both") and "全員" or "の一部")
				else
					text = rule .. text
				end
				node.ja = text
				node.rel = nil
				node.partitive = w
				node.plural = (rule ~= "one") or nil
				Add(res, a.stop, node, 0.2 + a.score)
			end
		end
	end

	-- a link or other markup is a noun phrase as it stands
	if item.kind == "raw" then
		Add(res, i + 1, { cat = "NP", ja = item.v, raw = true, def = true, w = "raw" }, 0.4)
		return res
	end

	-- modifiers, then a head noun
	local k, info = self:PreModifiers(i)
	-- which class / what kind of: the question word is the modifier
	if wh and w and (w == "which" or w == "what") and self:StartsNoun(i + 1) then
		local k2, info2 = self:PreModifiers(i + 1)
		for _, head in ipairs(self:Heads(k2)) do
			info2.quant = w == "which" and "どの" or "どんな"
			local node = self:BuildNP(info2, head)
			node.whDet = w
			node.indef = nil
			Add(res, head.stop, node, info2.score + (head.score or 0) * 0.1 - 0.3 * (head.count - 1))
		end
	end
	for _, head in ipairs(self:Heads(k)) do
		local node = self:BuildNP(info, head)
		local score = info.score + (head.score or 0) - 0.3 * (head.count - 1)
		if head.unknown and not head.name then score = score - 3 end
		if info.degree then score = score - 1 end
		-- "a lot of", "lots of" and friends already read as determiners
		Add(res, head.stop, node, score)
	end

	-- a gerund as a noun: "playing healer"
	if self.Gerund then
		local gerunds = self:Gerund(i)
		for _, g in ipairs(gerunds) do
			Add(res, g.stop, { cat = "NP", gerund = g.node, ja = nil, def = true, w = "gerund" }, -0.2 + g.score)
		end
	end
	return res
end

-- A possessive: the boss's HP. A noun phrase, 's, then another noun phrase.
function P:NPPoss(i) return self:Memo("NPPoss", i, P.NPPossRule) end
function P.NPPossRule(self, i)
	local res = NewResults()
	for _, a in ipairs(self:NPCore(i)) do
		Add(res, a.stop, a.node, a.score)
		if self:Has(a.stop, "POSS") and not a.node.pron then
			for _, b in ipairs(self:NPCore(a.stop + 1)) do
				local node = {}
				for key, value in pairs(b.node) do node[key] = value end
				node.ja = (a.node.ja or "") .. "の" .. (b.node.ja or "")
				node.def = a.node.def or b.node.def
				node.possessor = a.node
				Add(res, b.stop, node, b.score + a.score)
			end
		end
	end
	return res
end

-- Noun phrase with what can follow it: of-phrases, "and"/"or" lists.
function P:NP(i) return self:Memo("NP", i, P.NPRule) end
function P.NPRule(self, i)
	local res = NewResults()
	for _, a in ipairs(self:NPPoss(i)) do
		Add(res, a.stop, a.node, a.score)
		-- "the end of the dungeon"
		if self:Has(a.stop, "OF") and not a.node.pron and not a.node.wh then
			for _, b in ipairs(self:NPPoss(a.stop + 1)) do
				local node = {}
				for key, value in pairs(a.node) do node[key] = value end
				node.ja = (b.node.ja or "") .. "の" .. (a.node.ja or "")
				node.ofOwner = b.node
				Add(res, b.stop, node, a.score + b.score + 0.2)
			end
		end
	end
	-- two years ago
	local snapshot = {}
	for _, a in ipairs(res) do snapshot[#snapshot + 1] = a end
	for _, a in ipairs(snapshot) do
		if a.node.time and a.node.count and self:W(a.stop) == "ago" then
			local node = {}
			for key, value in pairs(a.node) do node[key] = value end
			node.ja = a.node.ja .. "前"
			node.ago = true
			node.count = nil
			Add(res, a.stop + 1, node, a.score + 0.5)
		end
		self:RelVariants(a, res)
	end
	-- lists: "food and potions", "a tank or a healer"
	local more = {}
	for _, a in ipairs(res) do more[#more + 1] = a end
	for _, a in ipairs(more) do
		local conj = self.items[a.stop]
		local joiner = conj and conj.kind == "word" and (conj.w == "and" and "と" or (conj.w == "or" and "か")) or nil
		if joiner and not a.node.pron and not a.node.wh and not a.node.gerund then
			for _, b in ipairs(self:NP(a.stop + 1)) do
				if not b.node.pron and not b.node.wh and not b.node.gerund then
					local node = {}
					for key, value in pairs(a.node) do node[key] = value end
					node.ja = (a.node.ja or "") .. joiner .. (b.node.ja or "")
					node.plural = true
					node.list = true
					node.rel = nil
					node.first = a.node
					node.second = b.node
					node.joiner = joiner
					node.neg = a.node.neg or b.node.neg
					Add(res, b.stop, node, a.score + b.score - 0.5)
				end
			end
		end
	end
	return res
end

-- Nouns whose "to / from / for X" belongs to the noun: ダンジョンへの入口, 友達からのメッセージ.
L.TO_NOUN = { entrance = true, way = true, road = true, path = true, access = true, key = true, answer = true, solution = true,
	guide = true, invitation = true, reply = true, response = true, trip = true, journey = true, visit = true, door = true, gate = true,
	bridge = true, portal = true, route = true, passage = true, link = true, introduction = true, ticket = true, reaction = true }
L.FROM_NOUN = { message = true, gift = true, letter = true, mail = true, email = true, call = true, reply = true, answer = true,
	news = true, support = true, protection = true, distance = true, invitation = true, whisper = true }
L.FOR_NOUN = { key = true, reason = true, ticket = true, recipe = true, set = true, build = true, gear = true, spot = true, room = true,
	request = true, plan = true, reward = true, offer = true, guide = true, tips = true, tip = true, need = true, place = true }
-- Nouns with a place after them: the players in my guild, the quest in Auridon.
L.IN_NOUN = { player = true, players = true, member = true, members = true, people = true, everyone = true, someone = true,
	anyone = true, quest = true, quests = true, item = true, items = true, boss = true, enemy = true, enemies = true, monster = true,
	house = true, shop = true, store = true, guild = true, group = true, keep = true, dungeon = true, zone = true, thing = true,
	things = true, stuff = true, bug = true, event = true, trader = true, one = true, ones = true, all = true }

-- Nouns that take "with X" or "about X": "help with this", "information about the dungeon".
L.PP_NOUN = { help = true, advice = true, tips = true, tip = true, info = true, information = true, question = true,
	questions = true, guide = true, guides = true, problem = true, problems = true, issue = true, issues = true,
	idea = true, ideas = true, details = true, news = true, updates = true, update = true }

-- Words that stand for someone or something an infinitive can describe: "something to eat".
L.INF_PRON = { something = "もの", anything = "もの", someone = "人", anyone = "人", somebody = "人", anybody = "人" }

-- Post-modifiers of a noun: a relative clause (the guy who sold me this), a contact clause
-- (the item you need), a participle (a man playing guitar), an infinitive (time to go).
-- Each is added as another way to read the noun phrase, with the clause kept in node.rel.
function P:RelVariants(a, res)
	local node = a.node
	if node.wh or node.raw or node.gerund then return end
	local nounHead = node.head or node.name or node.unknown or node.ofOwner or node.possessor
	local infPron = node.pron and L.INF_PRON[node.pron]
	if not nounHead and not infPron then return end
	local k = a.stop
	local w = self:W(k)
	if not w then return end
	local function With(rel, stop, score)
		local copy = {}
		for key, value in pairs(node) do copy[key] = value end
		copy.rel = rel
		Add(res, stop, copy, a.score + score)
	end

	if not infPron and L.PP_NOUN[node.w or ""] and (w == "with" or w == "about" or w == "on" or w == "regarding") then
		for _, pp in ipairs(self:PP(k)) do
			With({ kind = "pp", pp = pp.node }, pp.stop, pp.score + 0.8)
		end
	end
	if not infPron and nounHead and (w == "to" or w == "from" or w == "for" or w == "in" or w == "at" or w == "on") then
		local nw = node.w or ""
		local bonus = -0.8
		if w == "to" and L.TO_NOUN[nw] then bonus = 0.8
		elseif w == "from" and L.FROM_NOUN[nw] then bonus = 0.8
		elseif w == "for" and L.FOR_NOUN[nw] then bonus = 0.5
		elseif (w == "in" or w == "at" or w == "on") and L.IN_NOUN[nw] then bonus = 0.2 end
		if not (w == "to" and self:Has(k, "TO") and #self:Inf(k) > 0 and not L.TO_NOUN[nw]) then
			for _, pp in ipairs(self:PP(k)) do
				if not pp.node.np.wh then With({ kind = "pp", pp = pp.node, general = true }, pp.stop, pp.score + bonus) end
			end
		end
	end

	if not infPron then
		local relpron = (w == "that" and self:Has(k, "THAT")) or w == "who" or w == "which" or w == "whom"
		if relpron then
			-- the pronoun is the subject: "the guy who sold me this"
			for _, vg in ipairs(self:VG(k + 1)) do
				local v = vg.node
				if v.verb or v.be then
					for _, c in ipairs(self:Comps(v.stop, v)) do
						local ok = not (v.be and not v.verb and not S.HasComplement(c.node.comps))
						if ok then With({ kind = "subj", vg = v, comps = c.node.comps }, c.stop, vg.score + c.score + 0.4) end
					end
				end
			end
			-- the pronoun is the object: "the item that you need"
			if w ~= "who" then
				for _, s in ipairs(self:NP(k + 1)) do
					if not s.node.wh then
						for _, vg in ipairs(self:VG(s.stop)) do
							local v = vg.node
							if v.verb then
								for _, c in ipairs(self:Comps(v.stop, v)) do
									local hasObject = false
									for _, comp in ipairs(c.node.comps) do
										if comp.kind == "np" and not comp.node.time and not comp.node.place then hasObject = true end
									end
									if not hasObject then
										With({ kind = "obj", subj = s.node, vg = v, comps = c.node.comps }, c.stop, s.score + vg.score + c.score + 0.2)
									end
								end
							end
						end
					end
				end
			end
		end
		-- where / when: "the place where we met"
		if w == "where" or (w == "when" and (L.GAP_NOUN[node.w or ""] or L.TIME_NOUN[node.w or ""])) then
			for _, cl in ipairs(self:Clause(k + 1)) do
				if cl.node.kind == "decl" then With({ kind = "adv", clause = cl.node, wh = w }, cl.stop, cl.score + 0.2) end
			end
		end
		-- no pronoun: "the item you need", "the best run we ever had"
		if (node.def or node.superlative) and (L.SUBJECT_FORMS[w] or w == "you") and not self:Has(k, "WH") then
			for _, s in ipairs(self:NP(k)) do
				if s.node.pron and not s.node.wh then
					for _, vg in ipairs(self:VG(s.stop)) do
						local v = vg.node
						if v.verb then
							for _, c in ipairs(self:Comps(v.stop, v)) do
								local hasObject = false
								for _, comp in ipairs(c.node.comps) do
									if comp.kind == "np" and not comp.node.time and not comp.node.place then hasObject = true end
								end
								if not hasObject then
									With({ kind = "obj", subj = s.node, vg = v, comps = c.node.comps, contact = true }, c.stop, s.score + vg.score + c.score - 0.2)
								elseif L.GAP_NOUN[node.w or ""] then
									local clause = { cat = "CL", kind = "decl", subj = s.node, vg = v, comps = c.node.comps }
									With({ kind = "adv", clause = clause, contact = true }, c.stop, s.score + vg.score + c.score + 0.3)
								end
							end
						end
					end
				end
			end
		end
		-- a participle: "a man playing guitar"
		local ing = self:VerbAt(k, "ing")
		if ing and not (L.GERUND[ing.base or ""] and false) then
			local vg = { cat = "VG", verb = ing, prog = true, advs = {}, stop = k + 1 }
			for _, c in ipairs(self:Comps(k + 1, vg)) do
				With({ kind = "subj", vg = vg, comps = c.node.comps }, c.stop, c.score + 0.1)
			end
		end
	end
	-- an infinitive: "time to go", "something to eat", "a group to do Cloudrest"
	if self:Has(k, "TO") and (infPron or L.INF_NOUN[node.w or ""]) then
		for _, inf in ipairs(self:Inf(k)) do
			With({ kind = "inf", inf = inf.node }, inf.stop, inf.score + 0.6)
		end
	end
end

-- ---------------------------------------------------------------------------------------
-- Adjective phrases
-- ---------------------------------------------------------------------------------------

-- [degree adverb] adjective: "very strong", "so laggy", "more expensive", "the best"
function P:AdjP(i) return self:Memo("AdjP", i, P.AdjPRule) end
function P.AdjPRule(self, i)
	local res = NewResults()
	local k = i
	local degreeJa, tooFlag, more
	local w = self:W(k)
	if w == "more" or w == "most" then
		more = w == "more" and "comparative" or "superlative"
		k = k + 1
		w = self:W(k)
	end
	-- "way too hard", "much too easy"
	if (w == "way" or w == "much" or w == "far") and self:W(k + 1) == "too" and self:AdjLike(k + 2) then
		k = k + 1
		w = self:W(k)
	end
	local adverb = self:Has(k, "ADV")
	if adverb and w and (L.DEGREE[w] or L.ASPECT_ADV[w]) and self:AdjLike(k + 1) then
		if w == "too" then tooFlag = true else degreeJa = adverb.entry.ja end
		k = k + 1
	end
	local adj = self:Has(k, "ADJ")
	if adj then
		Add(res, k + 1, {
			cat = "ADJP", entry = adj.entry, infl = adj.infl or more, degree = degreeJa, too = tooFlag,
			ja = adj.entry.ja, w = self:W(k),
		}, adj.pref * 0.2 - (adj.infl == "adverb" and 3 or 0))
	end
	-- a verb that is stored as a state: tired, ready, done
	local verb = self:Has(k, "V")
	if verb and verb.entry and (verb.entry.class == "i" or verb.entry.class == "na" or (verb.entry.ja or ""):sub(-9) == "ている"
		or (verb.entry.ja or ""):sub(-9) == "でいる" or ((verb.entry.ja or ""):sub(-9) == "がある" and verb.entry.particle ~= nil)) and (verb.infl == nil) then
		local entry = verb.entry
		local state = (entry.ja:sub(-9) == "ている" or entry.ja:sub(-9) == "でいる" or entry.ja:sub(-9) == "がある")
		Add(res, k + 1, {
			cat = "ADJP", entry = state and { ja = entry.ja:sub(1, -10), class = "state", stateVerb = entry, particle = entry.particle } or entry,
			infl = more, degree = degreeJa, too = tooFlag, ja = entry.ja, w = self:W(k), fromVerb = true,
		}, -0.6 + verb.pref * 0.1)
	end
	-- "friendly and active", "strong but slow"
	local base = {}
	for _, a in ipairs(res) do base[#base + 1] = a end
	for _, a in ipairs(base) do
		local conj = self:W(a.stop)
		if conj == "and" or conj == "but" or conj == "or" then
			for _, b in ipairs(self:AdjP(a.stop + 1)) do
				local node = { cat = "ADJP", list = true, first = a.node, second = b.node, conj = conj, entry = a.node.entry, ja = a.node.ja, w = a.node.w }
				Add(res, b.stop, node, a.score + b.score + 0.2)
			end
		end
	end
	return res
end

-- how long, how big: a question word with an adjective.
function P:WhAdj(i)
	if self:W(i) == "how" and self:Has(i, "WH") then
		for _, a in ipairs(self:AdjP(i + 1)) do
			if not a.node.list then return a end
		end
	end
	return nil
end

-- ---------------------------------------------------------------------------------------
-- Prepositional phrases
-- ---------------------------------------------------------------------------------------

function P:PP(i) return self:Memo("PP", i, P.PPRule) end
function P.PPRule(self, i)
	local res = NewResults()
	local w = self:W(i)
	if not w then return res end
	local prep = self:Has(i, "PREP")
	local isTo = self:Has(i, "TO")
	-- "in the middle of a fight": 戦いの最中
	if w == "in the middle" and self:Has(i + 1, "OF") then
		for _, a in ipairs(self:NP(i + 2)) do
			Add(res, a.stop, { cat = "PP", prep = "in the middle of", entry = { ja = "の最中に" }, np = a.node, w = "in the middle of" }, a.score + 1.0)
		end
	end
	if prep or isTo then
		local entry = prep and prep.entry or { ja = "に" }
		for _, a in ipairs(self:NP(i + 1)) do
			if not a.node.wh or true then
				Add(res, a.stop, { cat = "PP", prep = w, entry = entry, np = a.node, w = w }, a.score + (prep and prep.pref * 0.1 or 0))
			end
		end
		-- "from here", "in there": an adverb of place after the preposition
		local adverb = self:Has(i + 1, "ADV")
		if adverb and adverb.entry and adverb.entry.place then
			Add(res, i + 2, { cat = "PP", prep = w, entry = entry, np = { cat = "NP", ja = adverb.entry.ja, place = true, def = true, w = self:W(i + 1) }, w = w }, 1.5)
		end
	end
	return res
end

-- ---------------------------------------------------------------------------------------
-- Verb groups
--
-- modal, do-support, perfect, progressive, passive and "going to" are read into one node:
--   { modal, doSupport, perfect, prog, passive, neg, past, haveto, goingto, usedto, ableto,
--     advs = { {ja=, w=} }, verb = <reading or nil for a copular be>, be = true, stop }
-- The verb's own inflection says the tense of a plain verb; an auxiliary says it otherwise.
-- ---------------------------------------------------------------------------------------

local function CopyState(st)
	local c = {}
	for k, v in pairs(st) do c[k] = v end
	local advs = {}
	for k, v in ipairs(st.advs or {}) do advs[k] = v end
	c.advs = advs
	return c
end
S.CopyState = CopyState

-- Can a verb group continue at k (an auxiliary or a verb), so that an adverb before it is part
-- of the group rather than something else?
function P:CanContinueVG(k, st)
	for _, r in ipairs(self.R[k] or {}) do
		local cat = r.cat
		if cat == "V" or cat == "BE" or cat == "MODAL" or cat == "DO" or cat == "HAVE" or cat == "NEG" then
			return true
		end
		if cat == "ADV" and r.entry and (L.ASPECT_ADV[r.w] or L.DEGREE[r.w]) and k < self.n then
			return self:CanContinueVG(k + 1, st)
		end
	end
	return false
end

local function Emit(res, st, verb, stop, bonus)
	local node = CopyState(st)
	node.cat = "VG"
	node.verb = verb
	node.stop = stop
	local score = (bonus or 0) + (st.bonus or 0) + (verb and verb.pref * 0.3 or 0)
	Add(res, stop, node, score)
end

-- Is word k a V reading with this inflection ("" = base form)?
function P:VerbAt(k, infl)
	-- a phrase such as "looking for" can be read as a verb form of two entries
	for _, r in ipairs(self.R[k] or {}) do
		if r.cat == "V" then
			if infl == "base" then
				if r.infl == nil then return r end
			elseif r.infl == infl then
				return r
			end
		end
	end
	return nil
end

-- The verb group starting at i. st0, when given, is what an auxiliary already read in front
-- of the subject contributed ("can" in "can you help").
function P:VG(i, st0)
	local res = NewResults()
	self:VGStep(i, st0 and CopyState(st0) or { advs = {} }, res)
	return res
end

function P:VGStep(k, st, res)
	-- negation and adverbs between the parts of the group
	while true do
		local neg = self:Has(k, "NEG")
		if neg then
			st = CopyState(st)
			st.neg = true
			if neg.neg == "never" then st.never = true end
			k = k + 1
		else
			local adv = self:Has(k, "ADV")
			local aw = self:W(k)
			if adv and aw and (L.ASPECT_ADV[aw] or L.DEGREE[aw]) and adv.entry and self:CanContinueVG(k + 1, st)
				and not (L.DEGREE[aw] and self:AdjLike(k + 1)) then
				st = CopyState(st)
				st.advs[#st.advs + 1] = { ja = adv.entry.ja, w = aw }
				k = k + 1
			else
				break
			end
		end
	end
	local w = self:W(k)
	if not w then return end
	local hasMain = st.verbSeen
	local bareNeeded = st.modal or st.doSupport or st.haveto or st.goingto or st.usedto or st.ableto or st.inf

	-- modal
	local modal = self:Has(k, "MODAL")
	if modal and not st.modal and not st.perfect and not st.prog and not st.doSupport and not st.be then
		local s = CopyState(st)
		s.modal = modal.modal
		self:VGStep(k + 1, s, res)
	end

	-- do / does / did
	local d = self:Has(k, "DO")
	if d and not st.modal and not st.doSupport and not st.perfect and not st.prog and not st.be then
		local s = CopyState(st)
		s.doSupport = true
		s.doWord = w
		if d.dobe.past then s.past = true end
		self:VGStep(k + 1, s, res)
	end

	-- have / has / had
	local h = self:Has(k, "HAVE")
	if h and not st.perfect and not st.prog and not st.be and not st.haveto then
		-- have to: obligation
		local m = k + 1
		if self:Has(m, "TO") and (self:VerbAt(m + 1, "base") or self:Has(m + 1, "BE")) then
			local s = CopyState(st)
			s.haveto = true
			s.bonus = (s.bonus or 0) + 2.0
			if h.have.past then s.past = true end
			self:VGStep(m + 1, s, res)
		end
		-- perfect: have + been / past participle
		local nextVerbPast, nextBeen = false, false
		local m2 = k + 1
		while self:Has(m2, "NEG") or (self:Has(m2, "ADV") and (L.ASPECT_ADV[self:W(m2) or ""])) do m2 = m2 + 1 end
		if self:VerbAt(m2, "past") or (self:Has(m2, "BE") and self:W(m2) == "been") then
			local s = CopyState(st)
			s.perfect = true
			s.bonus = (s.bonus or 0) + 2.2
			s.haveWord = w
			if h.have.past then s.past = true end
			if st.modal then s.past = true end
			self:VGStep(k + 1, s, res)
		end
	end

	-- be
	local b = self:Has(k, "BE")
	if b and not st.be then
		local s = CopyState(st)
		local form = b.be
		-- be (base) only after to / a modal / do; been only after have; a command takes "be", not "is"
		if form.base and not (st.inf or st.modal or st.goingto or st.doSupport or st.haveto) then return end
		if st.inf and not form.base then return end
		if form.participle and not st.perfect then return end
		if form.past then s.past = true end
		s.be = true
		s.beWord = w
		if form.participle then s.beenForm = true end
		self:AfterBe(k + 1, s, res, form)
	end

	-- used to + verb
	if w == "used" and self:Has(k + 1, "TO") and self:VerbAt(k + 2, "base") and not bareNeeded and not st.be then
		local s = CopyState(st)
		s.usedto = true
		s.past = true
		self:VGStep(k + 2, s, res)
	end

	-- the main verb
	local verbReadings = {}
	for _, r in ipairs(self.R[k] or {}) do
		if r.cat == "V" then verbReadings[#verbReadings + 1] = r end
	end
	for _, v in ipairs(verbReadings) do
	if L.DO[w] and (self:Has(k + 1, "NEG") or not st.doSupport and false) and not st.doSupport then v = nil end
	if v and not st.be then
		local infl = v.infl
		local ok = false
		if bareNeeded then
			ok = infl == nil
		elseif st.perfect then
			ok = infl == "past"
		else
			ok = infl == nil or infl == "third" or infl == "past"
		end
		if ok then
			local s = CopyState(st)
			s.verbSeen = true
			if not bareNeeded and not st.perfect and infl == "past" then s.past = true end
			-- get/got + participle: a passive
			if v.base == "get" and not bareNeeded and self:VerbAt(k + 1, "past") then
				local g = CopyState(s)
				g.passive = true
				g.getPassive = true
				Emit(res, g, self:Has(k + 1, "V"), k + 2, 0.3)
			end
			-- "finished": the verb form wins over the state it is also stored as
			local penalty = 0
			if infl == nil and not bareNeeded and not st.perfect then
				local sibling = self:VerbAt(k, "past")
				if sibling and sibling.extraPast then penalty = -1.0 end
			end
			Emit(res, s, v, k + 1, penalty)
		end
	end
	end
end

-- What can follow a form of "be" that has been read (or, in a question, whose subject has):
-- an -ing form, a participle, "going to", "able to", or nothing at all -- a copula.
function P:AfterBe(m, s, res, form)
	local j = m
	while self:Has(j, "NEG") or (self:Has(j, "ADV") and L.ASPECT_ADV[self:W(j) or ""] and self:CanContinueVG(j + 1, s)
		and not (L.DEGREE[self:W(j) or ""] and self:AdjLike(j + 1))) do
		local nr = self:Has(j, "NEG")
		s = CopyState(s)
		if nr then
			s.neg = true
			if nr.neg == "never" then s.never = true end
		else
			s.advs[#s.advs + 1] = { ja = self:Has(j, "ADV").entry.ja, w = self:W(j) }
		end
		j = j + 1
	end
	local ing = self:VerbAt(j, "ing")
	local pp = self:VerbAt(j, "past")
	-- "is finished" is a state, not the passive of "finish"
	if pp and pp.extraPast then pp = nil end
	if ing then
		-- "going to" + verb
		if self:W(j) == "going" and self:Has(j + 1, "TO") and self:VerbAt(j + 2, "base") then
			local g = CopyState(s)
			g.be = nil
			g.goingto = true
			g.bonus = (g.bonus or 0) + 2.5
			self:VGStep(j + 2, g, res)
		end
		if not (self:W(j) == "going" and self:Has(j + 1, "TO") and self:VerbAt(j + 2, "base")) then
			local p = CopyState(s)
			p.be = nil
			p.prog = true
			Emit(res, p, ing, j + 1, 1.0)
		end
	end
	if pp and not s.prog then
		local p = CopyState(s)
		p.be = nil
		p.passive = true
		Emit(res, p, pp, j + 1, 1.2)
		if form and form.gerund then
			local q = CopyState(p)
			q.prog = true
			Emit(res, q, pp, j + 1, 0.2)
		end
	end
	-- "able to" + verb
	if self:W(j) == "able" and self:Has(j + 1, "TO") and self:VerbAt(j + 2, "base") then
		local a = CopyState(s)
		a.be = nil
		a.ableto = true
		a.bonus = (a.bonus or 0) + 2.5
		self:VGStep(j + 2, a, res)
	end
	-- a plain copula: the complement follows; the clause reads it
	Emit(res, s, nil, j, -0.1)
end

-- ---------------------------------------------------------------------------------------
-- What follows a verb
--
-- A list of complements, read left to right by a small dynamic program: the best way to reach
-- each position, extending by one complement at a time.
--   { kind = "np", node }   { kind = "pp", node }   { kind = "adv", node }
--   { kind = "adj", node }  { kind = "than", node } { kind = "inf", node }
--   { kind = "ger", node }  { kind = "that", node } { kind = "wh", node }
-- Which kinds a verb takes comes from its English base and the tables above.
-- ---------------------------------------------------------------------------------------

L.SUBJECT_FORMS = { i = true, we = true, they = true, he = true, she = true }
-- Verbs after which an adjective describes the object: "make it easy", "keep it clean".
L.OBJ_ADJ = { make = true, keep = true, find = true, get = true, leave = true, drive = true, consider = true, want = true, like = true }
-- Verbs with an object and then "to + verb": "I want you to wait".
L.OBJ_INF = {
	want = true, need = true, ask = true, tell = true, expect = true, allow = true, invite = true, order = true,
	remind = true, wish = true, help = true, get = true, ["would like"] = true, like = true, force = true,
	require = true, teach = true, advise = true, warn = true, encourage = true, trust = true,
	let = true, make = true, have = true, see = true, hear = true, watch = true,
}
L.STATIVE_START = {
	need = true, want = true, have = true, like = true, love = true, hate = true, know = true, think = true,
	hope = true, wish = true, miss = true, got = true, ["look for"] = true, ["looking for"] = true,
}

function P:Comps(i, vg)
	local verb = vg.verb
	local base = verb and (verb.base or verb.w) or nil
	local copula = vg.be and not verb
	local ctx = { base = base, copula = copula, link = copula or (base and L.LINK[base]) or false, vg = vg }
	local states = { [i] = { score = 0, comps = {}, nnp = 0 } }
	local final = NewResults()
	for idx = i, self.n + 1 do
		local st = states[idx]
		if st then
			Add(final, idx, { comps = st.comps, adj = st.adj, clause = st.clause }, st.score)
			if idx <= self.n then self:ExtendComps(idx, st, states, ctx) end
		end
	end
	return final
end

-- Every complement costs a little, so that one long constituent beats the same words cut into
-- several ("the best way to level up quickly without spending money" is one noun phrase).
S.COMP_COST = 0.3

local function Push(states, j, st, comp, kind, inc, flags)
	local comps = {}
	for k, v in ipairs(st.comps) do comps[k] = v end
	comps[#comps + 1] = { kind = kind, node = comp }
	local new = { score = st.score + inc - S.COMP_COST, comps = comps, nnp = st.nnp, adj = st.adj, clause = st.clause }
	if flags then for k, v in pairs(flags) do new[k] = v end end
	local old = states[j]
	if not old or new.score > old.score then states[j] = new end
end

function P:ExtendComps(idx, st, states, ctx)
	local base = ctx.base
	local R = self.R[idx]
	local noClause = not st.clause
	-- an NP (object, or the complement of a copula)
	if noClause and (not st.adj or (st.adj.entry and st.adj.entry.particle and st.nnp == 0)) then
		for _, a in ipairs(self:NP(idx)) do
			local np = a.node
			local inc = 0.45 + a.score
			local ok = true
			if np.pron and L.SUBJECT_FORMS[np.pron] then inc = inc - 2.5 end
			if np.wh then inc = inc - 1.5 end
			if np.gerund then inc = inc - 0.3 end
			if np.rel and (np.rel.kind == "inf" or (np.rel.kind == "pp" and not np.rel.general)) then inc = inc + 0.9 end
			if np.ago then inc = inc + 1.0 end
			-- "realized that the situation was ...": that opens a clause, it is not the object
			if np.pron == "that" and base and L.REPORT[base] and #self:Clause(a.stop) > 0 then inc = inc - 2.5 end
			-- "stop healing", "is healing": the -ing word is a verb, not the noun it also names
			if np.w and not np.gerund and self:Has(a.stop - 1, "V") then
				local vr = self:Has(a.stop - 1, "V")
				if vr.infl == "ing" and np.w:sub(-3) == "ing" and (L.GERUND[base or ""] or ctx.copula) then inc = inc - 1.8 end
				if vr.infl == "past" and ctx.copula and vr.pref >= 2 then inc = inc - 1.8 end
			end
			if st.nnp >= 1 then
				-- a second noun phrase: two objects, or a time or place said as a noun
				if np.time or np.place then
					inc = inc - 0.2
				elseif (L.DITRANS[base or ""] or L.OBJ_INF[base or ""]) and st.nnp == 1 and not L.CAUSE_BARE[base or ""] or (base == "make" or base == "get") and st.nnp == 1 then
					local first
					for k = #st.comps, 1, -1 do
						if st.comps[k].kind == "np" then first = st.comps[k].node break end
					end
					if first and (first.pron or first.animate or first.name) then inc = inc + 0.2 else ok = false end
				else
					ok = false
				end
			end
			if ctx.copula and st.nnp >= 1 and not (np.time or np.place) then ok = false end
			if np.pron and ctx.copula and not ({ me = true, you = true, him = true, her = true, us = true, them = true, it = true, mine = true,
				yours = true, ours = true, theirs = true, this = true, that = true, these = true, those = true, who = true, what = true,
				someone = true, anyone = true, nobody = true, everyone = true, something = true, nothing = true, anything = true,
				everything = true, guys = true, everybody = true, somebody = true, anybody = true })[np.pron] then
				ok = false
			end
			if ok then Push(states, a.stop, st, np, "np", inc, { nnp = st.nnp + 1 }) end
		end
	end
	-- a preposition with nothing after it, at the end of a question: "which server are you on"
	if self.allowStranded and idx == self.n and self:Has(idx, "PREP") then
		local prep = self:Has(idx, "PREP")
		Push(states, idx + 1, st, { cat = "PP", prep = self:W(idx), entry = prep.entry, stranded = true, w = self:W(idx) }, "pp", 0.3)
	end
	-- a prepositional phrase
	local infHere = self:Has(idx, "TO") and #self:Inf(idx) > 0
	for _, a in ipairs(self:PP(idx)) do
		local inc = 0.1 + a.score
		if infHere and a.node.prep == "to" then inc = inc - 1.5 end
		-- a gerund after a preposition is read in the NP; keep the phrase attached to the verb
		Push(states, a.stop, st, a.node, "pp", inc)
	end
	-- an adverb
	local adv = self:Has(idx, "ADV")
	if adv and adv.entry then
		local aw = self:W(idx)
		local inc = 0.0
		if L.DEGREE[aw] and self:AdjLike(idx + 1) then inc = inc - 1.2 end
		if L.PRE_ONLY[aw or ""] then inc = inc - 0.9 end
		Push(states, idx + 1, st, { cat = "ADV", ja = adv.entry.ja, w = aw, entry = adv.entry }, "adv", inc)
	end
	-- an adjective: after a link verb, or after an object that it describes
	if ctx.link and noClause and not st.adj and st.nnp == 0 or (L.OBJ_ADJ[base or ""] and st.nnp == 1 and not st.adj) then
		for _, a in ipairs(self:AdjP(idx)) do
			local inc = 0.6 + a.score
			Push(states, a.stop, st, a.node, "adj", inc, { adj = a.node })
		end
	end
	-- "than X" after an adjective
	if st.adj and self:Has(idx, "THAN") then
		for _, a in ipairs(self:NP(idx + 1)) do
			Push(states, a.stop, st, a.node, "than", 0.3 + a.score, nil)
		end
	end
	-- "to" + verb
	if self:Has(idx, "TO") and not st.thatClause then
		for _, a in ipairs(self:Inf(idx)) do
			local inc
			if L.TO_VERB[base or ""] or L.OBJ_INF[base or ""] and st.nnp >= 1 then
				inc = 0.7 + a.score
			elseif st.adj then
				inc = 0.5 + a.score
			elseif ctx.copula then
				inc = -0.2 + a.score
			else
				inc = 0.0 + a.score
			end
			Push(states, a.stop, st, a.node, "inf", inc, { clause = true })
		end
	end
	-- a bare verb after its object: "let you know", "help me find", "make him wait"
	if noClause and base and L.CAUSE_BARE[base] and st.nnp == 1 and st.comps[#st.comps] and st.comps[#st.comps].kind == "np" then
		local group = NewResults()
		self:VGStep(idx, { advs = {}, inf = true }, group)
		for _, vg in ipairs(group) do
			local v = vg.node
			if v.verb and not v.be and not v.verb.inflectedPhrase then
				for _, c in ipairs(self:Comps(v.stop, v)) do
					Push(states, c.stop, st, { cat = "INF", vg = v, comps = c.node.comps }, "bare", 0.5 + vg.score + c.score, { clause = true })
				end
			end
		end
	end
	-- a verb with -ing
	if noClause and (L.GERUND[base or ""] or base == "go" or ctx.copula and false) then
		for _, a in ipairs(self:Gerund(idx)) do
			Push(states, a.stop, st, a.node, "ger", 1.3 + a.score, { clause = true })
		end
	end
	-- "have no idea what I'm doing"
	if noClause and base == "have" and st.nnp == 1 and st.comps[1] and st.comps[1].kind == "np" and st.comps[1].node.w == "idea"
		and st.comps[1].node.neg then
		for _, a in ipairs(self:EmbeddedWh(idx)) do
			Push(states, a.stop, st, a.node, "wh", 1.0 + a.score, { clause = true })
		end
	end
	-- a clause as the object: "think we should wait", "know where it is"
	if noClause and base and L.REPORT[base] then
		local k = idx
		if self:Has(k, "THAT") and self:W(k) == "that" then k = k + 1 end
		for _, a in ipairs(self:Clause(k)) do
			if (a.node.kind == "decl" and a.node.subj) or a.node.kind == "there" then
				Push(states, a.stop, st, a.node, "that", 0.55 + a.score, { clause = true, thatClause = true })
			end
		end
		for _, a in ipairs(self:EmbeddedWh(idx)) do
			-- "know the player who won" is a noun with a relative clause; only tell/show/ask take a person and a question
			if st.nnp == 0 or base == "tell" or base == "show" or base == "ask" or base == "teach" then
				Push(states, a.stop, st, a.node, "wh", 0.55 + a.score, { clause = true, thatClause = true })
			end
		end
	end
end

-- "to + verb ...": an infinitive clause with no subject of its own.
function P:Inf(i) return self:Memo("Inf", i, P.InfRule) end
function P.InfRule(self, i)
	local res = NewResults()
	if not self:Has(i, "TO") then return res end
	local st = { advs = {}, inf = true }
	local group = NewResults()
	self:VGStep(i + 1, st, group)
	for _, vg in ipairs(group) do
		for _, c in ipairs(self:Comps(vg.stop, vg.node)) do
			Add(res, c.stop, { cat = "INF", vg = vg.node, comps = c.node.comps }, vg.score + c.score)
		end
	end
	return res
end

-- A verb with -ing and what it takes: "playing a tank", "waiting for 20 minutes".
function P:Gerund(i) return self:Memo("Gerund", i, P.GerundRule) end
function P.GerundRule(self, i)
	local res = NewResults()
	local neg = false
	local k = i
	if self:Has(k, "NEG") and self:W(k) == "not" then neg = true k = k + 1 end
	local ing = self:VerbAt(k, "ing")
	if not ing then return res end
	local vg = { cat = "VG", verb = ing, gerund = true, neg = neg or nil, advs = {}, stop = k + 1 }
	for _, c in ipairs(self:Comps(k + 1, vg)) do
		Add(res, c.stop, { cat = "GER", vg = vg, comps = c.node.comps }, c.score)
	end
	return res
end

-- An embedded question: "where it is", "what I'm doing", "how to get there", "if you can".
function P:EmbeddedWh(i) return self:Memo("EmbeddedWh", i, P.EmbeddedWhRule) end
function P.EmbeddedWhRule(self, i)
	local res = NewResults()
	local w = self:W(i)
	if not w then return res end
	local wh = self:Has(i, "WH")
	local isIf = w == "if" or w == "whether"
	if not wh and not isIf then return res end
	if wh then
		-- "how long this queue is"
		local howAdj = self:WhAdj(i)
		if howAdj then
			for _, s in ipairs(self:NP(howAdj.stop)) do
				if not s.node.wh then
					for _, vg in ipairs(self:VG(s.stop)) do
						local v = vg.node
						if v.be and not v.verb then
							local clause = { cat = "CL", kind = "decl", subj = s.node, vg = v, comps = {}, gapBe = true, wh = { word = "how", adj = howAdj.node } }
							Add(res, vg.stop, { cat = "WHCL", wh = "how", whEntry = wh.entry, clause = clause, howAdj = true }, s.score + vg.score + 0.5)
						end
					end
				end
			end
		end
		-- how to / what to / where to + verb
		if self:Has(i + 1, "TO") then
			for _, a in ipairs(self:Inf(i + 1)) do
				Add(res, a.stop, { cat = "WHCL", wh = w, whEntry = wh.entry, inf = a.node }, a.score + 0.5)
			end
		end
		-- how many / how much + noun, which + noun, what + noun
		local np = nil
		if w == "which" or w == "what" or w == "whose" then
			for _, a in ipairs(self:NP(i)) do
				if a.node.whDet or a.node.wh then np = a end
			end
		end
		local start = i + 1
		-- the question word is the subject: "who killed the boss", "what happened"
		for _, vg in ipairs(self:VG(start)) do
			for _, c in ipairs(self:Comps(vg.stop, vg.node)) do
				local clause = { cat = "CL", kind = "decl", subj = { cat = "NP", wh = w, ja = wh.entry.ja, pron = w }, vg = vg.node, comps = c.node.comps, subjGap = true }
				Add(res, c.stop, { cat = "WHCL", wh = w, whEntry = wh.entry, clause = clause, subjectWh = true }, vg.score + c.score)
			end
		end
		-- "where the group is", "what that is": a subject and a be with nothing after it
		for _, s in ipairs(self:NP(start)) do
			if not s.node.wh then
				for _, vg in ipairs(self:VG(s.stop)) do
					local v = vg.node
					if v.be and not v.verb then
						local clause = { cat = "CL", kind = "decl", subj = s.node, vg = v, comps = {}, gapBe = true }
						Add(res, vg.stop, { cat = "WHCL", wh = w, whEntry = wh.entry, clause = clause }, s.score + vg.score - 0.1)
					end
				end
			end
		end
		-- the question word is not the subject: a complete clause (an object or adverb gap)
		for _, a in ipairs(self:Clause(start)) do
			if a.node.kind == "decl" then
				Add(res, a.stop, { cat = "WHCL", wh = w, whEntry = wh.entry, clause = a.node }, a.score + 0.2)
			end
		end
		if np then
			for _, a in ipairs(self:Clause(np.stop)) do
				if a.node.kind == "decl" then
					Add(res, a.stop, { cat = "WHCL", wh = w, whEntry = wh.entry, whNP = np.node, clause = a.node }, a.score + 0.2)
				end
			end
		end
	else
		for _, a in ipairs(self:Clause(i + 1)) do
			if a.node.kind == "decl" then
				Add(res, a.stop, { cat = "WHCL", wh = "if", clause = a.node, yesno = true }, a.score + 0.2)
			end
		end
	end
	return res
end

-- ---------------------------------------------------------------------------------------
-- Clauses
--
--   { cat = "CL", kind = "decl" | "ynq" | "whq" | "imp" | "lets" | "there",
--     subj = NP | nil, vg = verb group, comps = { ... },
--     wh = { word, entry, np }   -- the question word, when it is not the subject
--     implied = "i"              -- a fragment with no subject ("looking for a group")
--     frontAdv, frontPP, let = true, ... }
-- ---------------------------------------------------------------------------------------

-- A penalty for a verb that does not agree with its subject: "I starts", "the boss start".
function P:Agreement(subj, vg)
	if not subj or not vg then return 0 end
	local singular3 = (subj.pron == nil or subj.pron == "he" or subj.pron == "she" or subj.pron == "it"
		or subj.pron == "that" or subj.pron == "this" or L.INDEF_PRON[subj.pron or ""] ~= nil) and not subj.plural
	local score = 0
	local verb = vg.verb
	local function Bad() score = score - 2 end
	if vg.beWord and not vg.inverted then
		local bw = vg.beWord
		if bw == "am" and subj.pron ~= "i" then Bad() end
		if bw == "is" and not singular3 then Bad() end
		if bw == "are" and (singular3 and subj.pron ~= "you") then Bad() end
		if bw == "was" and not (singular3 or subj.pron == "i") then Bad() end
		if bw == "were" and (singular3 or subj.pron == "i") then score = score - 0.5 end
	elseif vg.doWord then
		if vg.doWord == "does" and not singular3 then Bad() end
		if vg.doWord == "do" and singular3 and subj.pron ~= "you" then Bad() end
	elseif vg.haveWord then
		if vg.haveWord == "has" and singular3 then score = score + 0.4 end
		if vg.haveWord == "has" and not singular3 then Bad() end
		if vg.haveWord == "have" and singular3 and subj.pron ~= "you" then Bad() end
	elseif verb and not (vg.modal or vg.perfect or vg.prog or vg.passive or vg.goingto or vg.haveto or vg.ableto or vg.usedto) then
		if verb.infl == "third" then
			if not singular3 then Bad() else score = score + 0.4 end
		elseif verb.infl == nil then
			-- a bare verb in the present: not for a singular third-person subject
			if singular3 and subj.pron ~= "you" then Bad() end
		end
	end
	return score
end

-- Does a copular group have something after it to be?
local function HasComplement(comps)
	for _, c in ipairs(comps) do
		if c.kind == "np" or c.kind == "adj" or c.kind == "pp" or c.kind == "adv" or c.kind == "inf" or c.kind == "ger" then
			return true
		end
	end
	return false
end
S.HasComplement = HasComplement

function P:Clause(i) return self:Memo("Clause", i, P.ClauseRule) end
function P.ClauseRule(self, i)
	local res = NewResults()
	if i > self.n then return res end
	self:ClauseDecl(i, res)
	self:ClauseYesNo(i, res)
	self:ClauseWh(i, res)
	self:ClauseImperative(i, res)
	self:ClauseThere(i, res)
	self:ClauseFragment(i, res)
	self:ClauseFront(i, res)
	return res
end

-- Subject, verb group, complements.
function P:ClauseDecl(i, res)
	for _, s in ipairs(self:NP(i)) do
		local subj = s.node
		if not subj.wh and not subj.whDet then
			local group = self:VG(s.stop)
			for _, vg in ipairs(group) do
				local v = vg.node
				for _, c in ipairs(self:Comps(v.stop, v)) do
					local comps = c.node.comps
					if not (v.be and not v.verb and not HasComplement(comps)) then
						local node = { cat = "CL", kind = "decl", subj = subj, vg = v, comps = comps }
						local wrongCase = subj.pron and ({ me = true, him = true, them = true, us = true })[subj.pron] and -3 or 0
						Add(res, c.stop, node, 1 + s.score + vg.score + c.score + self:Agreement(subj, v) + wrongCase)
						-- "everyone stack on me", "guys wait": a command with the group named in front
						if subj.pron and L.VOCATIVE[subj.pron] and v.verb and v.verb.infl == nil
							and not (v.modal or v.perfect or v.prog or v.passive or v.doSupport or v.be or v.haveto or v.goingto) then
							local imp = { cat = "CL", kind = "imp", vocative = subj, vg = v, comps = comps }
							Add(res, c.stop, imp, 1 + s.score + vg.score + c.score + 0.8)
						end
					end
				end
			end
		end
	end
end

-- An auxiliary first: "can you help", "is it ok", "has the boss spawned", "do you know".
function P:AuxStates(i)
	local states = {}
	local w = self:W(i)
	for _, r in ipairs(self.R[i] or {}) do
		if r.cat == "BE" and not r.be.base and not r.be.participle and not r.be.gerund then
			states[#states + 1] = { st = { advs = {}, be = true, beWord = w, inverted = true, past = r.be.past or nil }, form = r.be, kind = "be" }
		elseif r.cat == "DO" then
			states[#states + 1] = { st = { advs = {}, doSupport = true, doWord = w, inverted = true, past = r.dobe.past or nil }, kind = "do" }
		elseif r.cat == "HAVE" then
			states[#states + 1] = { st = { advs = {}, perfect = true, haveWord = w, inverted = true, past = r.have.past or nil }, kind = "have" }
		elseif r.cat == "MODAL" then
			states[#states + 1] = { st = { advs = {}, modal = r.modal, inverted = true }, kind = "modal" }
		end
	end
	return states
end

-- After an inverted auxiliary: subject, then the rest of the verb group, then complements.
-- Calls back with (subject, vg, comps, stop, score).
function P:Inverted(i, callback, allowWhGap)
	for _, aux in ipairs(self:AuxStates(i)) do
		local k = i + 1
		local st = aux.st
		if self:Has(k, "NEG") then
			st = CopyState(st)
			st.neg = true
			k = k + 1
		end
		for _, s in ipairs(self:NP(k)) do
			local subj = s.node
			if not subj.wh and not subj.whDet then
				local group = NewResults()
				if aux.kind == "be" then
					self:AfterBe(s.stop, CopyState(st), group, aux.form)
				else
					self:VGStep(s.stop, CopyState(st), group)
				end
				for _, vg in ipairs(group) do
					local v = vg.node
					for _, c in ipairs(self:Comps(v.stop, v)) do
						callback(subj, v, c.node.comps, c.stop, s.score + vg.score + c.score + self:Agreement(subj, v))
					end
				end
			end
		end
	end
end

function P:ClauseYesNo(i, res)
	self:Inverted(i, function(subj, v, comps, stop, score)
		if v.be and not v.verb and not HasComplement(comps) then return end
		Add(res, stop, { cat = "CL", kind = "ynq", subj = subj, vg = v, comps = comps }, score + 0.8)
	end)
end

L.WH_NP = { who = true, whom = true, what = true, which = true, whose = true }
L.VOCATIVE = { everyone = true, everybody = true, guys = true }
-- "any of the markers", "one of the keeps", "all of them"
L.PARTITIVE = {
	any = "", some = "いくつかの", all = "すべての", most = "ほとんどの", many = "多くの", each = "それぞれの", both = "両方の",
	one = "one", none = "none", neither = "neither", few = "少数の", several = "いくつかの", half = "半分の",
}
-- Nouns an adverbial relative clause can describe: "the third time I failed this trial".
L.GAP_NOUN = { time = true, day = true, week = true, year = true, moment = true, reason = true, place = true, way = true, night = true }
L.ORDINAL = { first = 1, second = 2, third = 3, fourth = 4, fifth = 5, sixth = 6, seventh = 7, eighth = 8, ninth = 9, tenth = 10 }

function P:ClauseWh(i, res)
	local w = self:W(i)
	if not w then return end
	-- the question word is a noun phrase: who / what / which X
	for _, a in ipairs(self:NP(i)) do
		local np = a.node
		if np.wh or np.whDet then
			-- as the subject: "who killed the boss", "what happened", "which class is better"
			for _, vg in ipairs(self:VG(a.stop)) do
				local v = vg.node
				for _, c in ipairs(self:Comps(v.stop, v)) do
					Add(res, c.stop, { cat = "CL", kind = "whq", subj = np, vg = v, comps = c.node.comps, whSubject = true },
						1 + a.score + vg.score + c.score)
				end
			end
			-- as an object or complement: "what are you doing", "who did you see", "what is that"
			self.allowStranded = true
			self:Inverted(a.stop, function(subj, v, comps, stop, score)
				Add(res, stop, { cat = "CL", kind = "whq", subj = subj, vg = v, comps = comps,
					wh = { word = np.wh or np.whDet, np = np } }, 1 + a.score + score)
			end)
			self.allowStranded = false
		end
	end
	-- how long is the queue
	local howAdj = self:WhAdj(i)
	if howAdj then
		self:Inverted(howAdj.stop, function(subj, v, comps, stop, score)
			if v.be and not v.verb and not S.HasComplement(comps) then
				Add(res, stop, { cat = "CL", kind = "whq", subj = subj, vg = v, comps = comps, wh = { word = "how", adj = howAdj.node } }, 1.5 + howAdj.score + score)
			end
		end)
	end
	-- an adverbial question word: where, when, why, how, what time, how much
	local wh = self:Has(i, "WH")
	if wh and not L.WH_NP[w] then
		self:Inverted(i + 1, function(subj, v, comps, stop, score)
			Add(res, stop, { cat = "CL", kind = "whq", subj = subj, vg = v, comps = comps,
				wh = { word = w, entry = wh.entry } }, 1 + score)
		end)
		-- "when is the raid": a noun after "is"
		-- the adverbial word as the start of a plain clause: "how you doing"
	end
end

-- Commands: "heal me", "do not push", "please wait", "be careful", "let's go", "let me know".
function P:ClauseImperative(i, res)
	local k = i
	local st = { advs = {}, inf = true, imperative = true }
	-- let's / let us + verb
	if self:Has(k, "LETS") then
		local group = NewResults()
		self:VGStep(k + 1, st, group)
		for _, vg in ipairs(group) do
			for _, c in ipairs(self:Comps(vg.stop, vg.node)) do
				Add(res, c.stop, { cat = "CL", kind = "lets", vg = vg.node, comps = c.node.comps }, 0.5 + vg.score + c.score)
			end
		end
	end
	-- let me / let us / let him + verb: the verb "let" with a bare verb after its object
	if self:Has(k, "LET") and false then return end
	-- do not / never
	if self:Has(k, "DO") and self:Has(k + 1, "NEG") then
		st.neg = true
		k = k + 2
	elseif self:Has(k, "NEG") then
		st.neg = true
		k = k + 1
	end
	local group = NewResults()
	self:VGStep(k, st, group)
	for _, vg in ipairs(group) do
		local v = vg.node
		if v.verb or v.be then
			for _, c in ipairs(self:Comps(v.stop, v)) do
				local comps = c.node.comps
				if not (v.be and not v.verb and not HasComplement(comps)) then
					local base = v.verb and (v.verb.base or v.verb.w) or "be"
					local penalty = L.STATIVE_START[base] and -1.5 or 0
					-- a verb stored as an adjective (売りたい, 好き) is a statement about the speaker, not a command
					local ve = v.verb and v.verb.entry
					if ve and (ve.class == "i" or ve.class == "na" or (ve.ja or ""):sub(-9) == "ている" or (ve.ja or ""):sub(-9) == "でいる") then
						penalty = penalty - 4
					end
					Add(res, c.stop, { cat = "CL", kind = "imp", vg = v, comps = comps }, 0.3 + vg.score + c.score + penalty)
				end
			end
		end
	end
end

-- there is / are: "there is a guild in the city"
function P:ClauseThere(i, res)
	if self:Has(i, "THERE") then
		for _, vg in ipairs(self:VG(i + 1)) do
			local v = vg.node
			if v.be and not v.verb then
				for _, c in ipairs(self:Comps(v.stop, v)) do
					if c.node.comps[1] and c.node.comps[1].kind == "np" then
						Add(res, c.stop, { cat = "CL", kind = "there", vg = v, comps = c.node.comps }, 1.5 + vg.score + c.score)
					end
				end
			end
		end
	end
	-- "is there a healer here", "are there any tanks"
	for _, aux in ipairs(self:AuxStates(i)) do
		if aux.kind == "be" and self:Has(i + 1, "THERE") then
			local group = NewResults()
			self:AfterBe(i + 2, CopyState(aux.st), group, aux.form)
			for _, vg in ipairs(group) do
				local v = vg.node
				if v.be and not v.verb then
					for _, c in ipairs(self:Comps(v.stop, v)) do
						if c.node.comps[1] and c.node.comps[1].kind == "np" then
							Add(res, c.stop, { cat = "CL", kind = "there", ynq = true, vg = v, comps = c.node.comps }, 1.6 + vg.score + c.score)
						end
					end
				end
			end
		end
	end
end

-- No subject: "looking for a group" (we are), "need two healers" (we need).
function P:ClauseFragment(i, res)
	local ing = self:VerbAt(i, "ing")
	if ing then
		local vg = { cat = "VG", verb = ing, prog = true, advs = {}, stop = i + 1 }
		for _, c in ipairs(self:Comps(i + 1, vg)) do
			Add(res, c.stop, { cat = "CL", kind = "decl", vg = vg, comps = c.node.comps, implied = "i" }, 0.6 + c.score)
		end
	end
	local v = self:Has(i, "V")
	if v and v.infl == nil and (L.STATIVE_START[v.base or v.w or ""] or (v.entry and (v.entry.class == "i" or v.entry.class == "na"
		or (v.entry.ja or ""):sub(-9) == "ている" or (v.entry.ja or ""):sub(-9) == "でいる") and not L.BE[v.w or ""])) then
		local group = NewResults()
		self:VGStep(i, { advs = {} }, group)
		for _, vg in ipairs(group) do
			for _, c in ipairs(self:Comps(vg.node.stop, vg.node)) do
				Add(res, c.stop, { cat = "CL", kind = "decl", vg = vg.node, comps = c.node.comps, implied = "i" }, 0.5 + vg.score + c.score)
			end
		end
	end
end

-- A time word or a comment on the whole clause, in front of it: "now we need healers".
function P:ClauseFront(i, res)
	local adv = self:Has(i, "ADV")
	local w = self:W(i)
	if adv and adv.entry and w and (L.TIME_ADV[w] or L.SENTENCE_ADV[w] or adv.entry.time) then
		for _, a in ipairs(self:Clause(i + 1)) do
			local node = {}
			for k, v in pairs(a.node) do node[k] = v end
			local front = { { ja = adv.entry.ja, w = w, sentence = L.SENTENCE_ADV[w] } }
			for _, f in ipairs(a.node.frontAdv or {}) do front[#front + 1] = f end
			node.frontAdv = front
			Add(res, a.stop, node, a.score + 0.1)
		end
	end
	-- "just let me know": an adverb in front of a command
	if adv and adv.entry and w and L.ASPECT_ADV[w] and not L.TIME_ADV[w] and not L.SENTENCE_ADV[w] then
		for _, a in ipairs(self:Clause(i + 1)) do
			if a.node.kind == "imp" then
				local node = {}
				for k, v in pairs(a.node) do node[k] = v end
				local front = { { ja = adv.entry.ja, w = w, aspect = true } }
				for _, f in ipairs(a.node.frontAdv or {}) do front[#front + 1] = f end
				node.frontAdv = front
				Add(res, a.stop, node, a.score + 0.1)
			end
		end
	end
	-- a time or place phrase in front: "in Cyrodiil we need healers"
	for _, p in ipairs(self:PP(i)) do
		for _, a in ipairs(self:Clause(p.stop)) do
			if a.node.kind == "decl" or a.node.kind == "ynq" or a.node.kind == "whq" or a.node.kind == "imp" then
				local node = {}
				for k, v in pairs(a.node) do node[k] = v end
				local front = { p.node }
				for _, f in ipairs(a.node.frontPP or {}) do front[#front + 1] = f end
				node.frontPP = front
				Add(res, a.stop, node, a.score + 0.05)
			end
		end
	end
end

-- ---------------------------------------------------------------------------------------
-- A whole segment: clauses joined by conjunctions
--   { parts = { { conj = "and"|nil, kind = "main"|"sub", clause = CL, elliptical = bool } } }
-- ---------------------------------------------------------------------------------------

function P:Utterance(i)
	local need = { [i] = { score = 0, parts = {}, conj = nil } }
	local done = {}
	local best
	for idx = i, self.n + 1 do
		-- a main clause may follow a subordinate one directly: "if you need help let me know"
		local finished = done[idx]
		if finished and idx <= self.n and finished.parts[#finished.parts].kind == "sub" and not need[idx] then
			need[idx] = { score = finished.score, parts = finished.parts, conj = nil, subKind = nil, afterSub = true }
		end
		local n = need[idx]
		if n then
			-- a clause here
			for _, a in ipairs(self:Clause(idx)) do
				local parts = {}
				for k, v in ipairs(n.parts) do parts[k] = v end
				parts[#parts + 1] = { conj = n.conj, kind = (n.subKind == "sub") and "sub" or "main", clause = a.node, leadConj = n.conj }
				local cand = { score = n.score + a.score, parts = parts }
				if not done[a.stop] or cand.score > done[a.stop].score then done[a.stop] = cand end
			end
			-- a subordinate clause: "if you need help"
			local sub = self:Has(idx, "CONJ")
			if sub and sub.kind == "sub" then
				for _, a in ipairs(self:Clause(idx + 1)) do
					if a.node.kind == "decl" or a.node.kind == "ynq" or a.node.kind == "there" or a.node.kind == "imp" then
						local parts = {}
						for k, v in ipairs(n.parts) do parts[k] = v end
						parts[#parts + 1] = { conj = sub.conj, kind = "sub", clause = a.node, word = sub.w, leadConj = n.conj }
						local cand = { score = n.score + a.score + 0.2, parts = parts }
						if not done[a.stop] or cand.score > done[a.stop].score then done[a.stop] = cand end
					end
				end
			end
			-- a plain verb phrase sharing the subject: "went home and slept"
			if #n.parts > 0 and n.conj then
				local last
				for k = #n.parts, 1, -1 do if n.parts[k].kind == "main" then last = n.parts[k] break end end
				if last and last.clause.subj then
					local group = NewResults()
					self:VGStep(idx, { advs = {} }, group)
					for _, vg in ipairs(group) do
						local v = vg.node
						if v.verb or v.be then
							for _, c in ipairs(self:Comps(v.stop, v)) do
								local comps = c.node.comps
								if not (v.be and not v.verb and not HasComplement(comps)) then
									local parts = {}
									for k2, v2 in ipairs(n.parts) do parts[k2] = v2 end
									local clause = { cat = "CL", kind = "decl", vg = v, comps = comps, sharedSubject = last.clause.subj }
									parts[#parts + 1] = { conj = n.conj, kind = "main", clause = clause, elliptical = true }
									local cand = { score = n.score + vg.score + c.score - 0.2, parts = parts }
									if not done[c.stop] or cand.score > done[c.stop].score then done[c.stop] = cand end
								end
							end
						end
					end
				end
			end
		end
		-- after a clause, a conjunction asks for another
		local d = done[idx]
		if d then
			if idx == self.n + 1 then
				if not best or d.score > best.score then best = d end
			end
			local conj = self:Has(idx, "CONJ")
			if conj and idx < self.n then
				local cand = { score = d.score, parts = d.parts, conj = conj.conj, subKind = conj.kind }
				if not need[idx + 1] or cand.score > need[idx + 1].score then need[idx + 1] = cand end
			end
		end
	end
	return best
end

-- ---------------------------------------------------------------------------------------
-- Entry points
-- ---------------------------------------------------------------------------------------

S.MAX_ITEMS = 40

-- Parse the words of one segment. Returns the best whole-segment analysis, or nil.
function S.Parse(items)
	if #items == 0 or #items > S.MAX_ITEMS then return nil end
	local parser = S.NewParser(items)
	local best = parser:Utterance(1)
	if best then best.parser = parser end
	return best
end

-- A readable dump of a tree, for the tests and for looking at what was understood.
function S.Dump(node, indent)
	indent = indent or ""
	if type(node) ~= "table" then return tostring(node) end
	local keys = {}
	for k in pairs(node) do
		if k ~= "parser" and k ~= "entry" and k ~= "item" and k ~= "head" and k ~= "whEntry" and k ~= "last" then keys[#keys + 1] = k end
	end
	table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
	local out = {}
	for _, k in ipairs(keys) do
		local v = node[k]
		if type(v) == "table" then
			out[#out + 1] = indent .. tostring(k) .. ":\n" .. S.Dump(v, indent .. "  ")
		else
			out[#out + 1] = indent .. tostring(k) .. " = " .. tostring(v)
		end
	end
	return table.concat(out, "\n")
end
