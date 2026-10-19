-- PB's Translate -- from English word order to Japanese word order
--
-- This is not machine translation and does not pretend to be. It is a small rule-based
-- rewriter that knows the shapes chat sentences actually come in:
--
--   [interjection,] [wh-word] [aux] [subject] [aux...] [verb] [object] [prep phrases]
--
-- and turns each clause into
--
--   [subject]は [adverbs] [prep phrases] [object]を [verb + tense/negation/mode](か)
--
-- Clauses are joined back with the Japanese connective for the English conjunction, and a
-- subordinate clause ("if", "because", "when") is moved in front of the clause it belongs to,
-- which is where Japanese puts it.
--
-- What it gets wrong is predictable: idioms it has no entry for, relative clauses ("the guy
-- who sold me this"), and any word with two meanings it cannot tell apart. The dictionary is
-- the lever for all three -- a multi-word entry beats every rule here, because the longest
-- match is taken before the grammar runs.

PBsTranslate = PBsTranslate or {}
local T = PBsTranslate

-- ---------------------------------------------------------------------------------------
-- Closed-class words. These are grammar, not vocabulary, so they are recognised by spelling
-- and never looked up.
-- ---------------------------------------------------------------------------------------

local BE = {
	am = {}, is = {}, are = {}, be = {}, been = {}, being = {},
	was = { past = true }, were = { past = true },
}
local DO = { ["do"] = {}, does = {}, did = { past = true } }
local HAVE = { have = {}, has = {}, had = { past = true } }
local MODALS = {
	will = "future", shall = "future", would = "future", can = "can", could = "can",
	should = "should", must = "must", may = "maybe", might = "maybe",
}
local NEGATORS = { ["not"] = true, never = true }
local ARTICLES = { a = true, an = true, the = true }
local DEMONSTRATIVE_DET = { this = "この", that = "その", these = "これらの", those = "それらの" }
local INDEFINITE_PRONOUNS = {
	someone = true, somebody = true, anyone = true, anybody = true, nobody = true, ["no one"] = true,
	something = true, anything = true, nothing = true, who = true,
}
local SUBJECT_PRONOUNS = { i = true, you = true, we = true, they = true, he = true, she = true, it = true }

local GRAMMAR_WORDS = { to = true, ["let's"] = true, let = true, ["'s"] = true, please = true, of = true, as = true }

local function IsGrammarWord(w)
	return BE[w] or DO[w] or HAVE[w] or MODALS[w] or NEGATORS[w] or ARTICLES[w] or GRAMMAR_WORDS[w]
end

-- Verbs that take a whole clause: "I think it is broken" -> それが壊れていると思います
local REPORT_VERBS = {
	think = true, guess = true, believe = true, hope = true, know = true, say = true, feel = true,
	suppose = true, bet = true, hear = true, remember = true, forget = true, wonder = true,
	understand = true, mean = true, heard = true, tell = true,
	realize = true, realise = true, notice = true, wish = true, admit = true, claim = true, explain = true,
	mention = true, prove = true, discover = true, doubt = true, expect = true, imagine = true,
	assume = true, recognize = true, predict = true, report = true, learn = true, find = true,
	agree = true, insist = true, suggest = true, warn = true, promise = true,
}

-- Nouns for people and creatures take いる, everything else ある. Judged on the Japanese, so
-- a player's own dictionary words are covered by the same suffixes.
local ANIMATE_WORDS = {
	["ボス"] = true, ["ワールドボス"] = true, ["最終ボス"] = true, ["タンク"] = true, ["ヒーラー"] = true,
	["DPS"] = true, ["DD"] = true, ["敵"] = true, ["大集団"] = true, ["クラウン"] = true, ["皇帝"] = true,
	["友達"] = true, ["仲間"] = true, ["みんな"] = true, ["リーダー"] = true, ["グループ"] = true,
	["パーティー"] = true, ["ドラゴン"] = true, ["モンスター"] = true, ["トレーダー"] = true,
	["ギルドトレーダー"] = true, ["メンバー"] = true, ["プレイヤー"] = true, ["雑魚"] = true, ["NPC"] = true,
	["ガンカー"] = true, ["ボマー"] = true, ["ボールグループ"] = true, ["馬"] = true, ["ペット"] = true,
	["ドミニオン"] = true, ["カバナント"] = true, ["パクト"] = true, ["陣営"] = true, ["トレイン"] = true,
	["人々"] = true, ["人間"] = true, ["男性"] = true, ["女性"] = true, ["子供"] = true, ["先生"] = true,
}
local ANIMATE_SUFFIXES = { "人", "者", "師", "員", "士", "手", "商", "勢" }

-- 左手 ends in 手 like 運転手 does, and is not a person.
local NOT_PEOPLE = { "左手", "右手", "両手", "握手", "拍手", "素手", "相手", "上手", "下手", "上手", "入手", "着手", "先手", "後手" }

local function IsAnimate(entry)
	if not entry or not entry.ja then
		return false
	end
	for _, word in ipairs(NOT_PEOPLE) do
		if entry.ja:sub(-#word) == word then
			return false
		end
	end
	if entry.ja == "手" then
		return false
	end
	for word in pairs(ANIMATE_WORDS) do
		if entry.ja:sub(-#word) == word then
			return true
		end
	end
	for _, suffix in ipairs(ANIMATE_SUFFIXES) do
		if entry.ja:sub(-#suffix) == suffix then
			return true
		end
	end
	return false
end

local NUMBER_WORDS = {
	one = "1", two = "2", three = "3", four = "4", five = "5", six = "6", seven = "7", eight = "8",
	nine = "9", ten = "10", a = "1", several = "数", few = "数", many = "何",
}

-- Verbs whose "to + verb" is a purpose even with nothing else in between: "came to help"
-- Nouns that measure a span of time: "in 5 minutes" is 5分後に, "in April" is 4月に
local DURATION_WORDS = { ["秒"] = true, ["分"] = true, ["時間"] = true, ["日"] = true, ["週"] = true,
	["月"] = true, ["年"] = true, ["瞬間"] = true, ["10年間"] = true, ["世紀"] = true }

local MOTION_VERBS = {
	come = true, go = true, ["return"] = true, run = true, hurry = true, stop = true, visit = true,
	stay = true, travel = true, walk = true, drive = true, fly = true, move = true, work = true,
	study = true, save = true, arrive = true, leave = true, gather = true, meet = true, wait = true,
}

-- Subjects that can open a relative clause with no "that": "the item you need"
-- A verb entry that already names a state: 持っている, 死んでいる
local function IsStateVerb(entry)
	local ja = entry and entry.ja or ""
	return ja:sub(-9) == "ている" or ja:sub(-9) == "でいる"
end

local CONTACT_SUBJECTS = { i = true, you = true, we = true, they = true, he = true, she = true }

-- Participle phrases that modify the noun before them: "a sword made of iron"
local PARTICIPLE_PHRASES = {
	["made of"] = true, ["made from"] = true, ["made in"] = true, ["known as"] = true, ["written by"] = true,
	["filled with"] = true, ["covered with"] = true, ["called"] = true, ["named"] = true,
	["located in"] = true, ["based on"] = true, ["used for"] = true,
}

local PLACING_VERBS = { put = true, drop = true, place = true, set = true, stack = true, go = true, port = true, ["drop siege"] = true, ["set up siege"] = true }

local PERSON_PRONOUNS = { i = true, you = true, we = true, they = true, he = true, she = true }

-- Transitive verbs and the intransitive partner used when there is no object and a thing is
-- the subject.
local INTRANSITIVE = {
	["始める"] = { ja = "始まる", class = "5" },
	["終わらせる"] = { ja = "終わる", class = "5" },
	["開ける"] = { ja = "開く", class = "5" },
	["閉める"] = { ja = "閉まる", class = "5" },
	["止める"] = { ja = "止まる", class = "5" },
	["変える"] = { ja = "変わる", class = "5" },
	["続ける"] = { ja = "続く", class = "5" },
	["壊す"] = { ja = "壊れる", class = "1" },
	["直す"] = { ja = "直る", class = "5" },
	["落とす"] = { ja = "落ちる", class = "1" },
	["消す"] = { ja = "消える", class = "1" },
	["見つける"] = { ja = "見つかる", class = "5" },
	["増やす"] = { ja = "増える", class = "1" },
	["減らす"] = { ja = "減る", class = "5" },
	["上げる"] = { ja = "上がる", class = "5" },
	["下げる"] = { ja = "下がる", class = "5" },
	["広げる"] = { ja = "広がる", class = "5" },
	["集める"] = { ja = "集まる", class = "5" },
	["伝える"] = { ja = "伝わる", class = "5" },
	["終える"] = { ja = "終わる", class = "5" },
	["動かす"] = { ja = "動く", class = "5" },
	["育てる"] = { ja = "育つ", class = "5" },
	["起こす"] = { ja = "起きる", class = "1" },
	["治す"] = { ja = "治る", class = "5" },
	["並べる"] = { ja = "並ぶ", class = "5" },
	["回す"] = { ja = "回る", class = "5" },
	["出す"] = { ja = "出る", class = "1" },
	["入れる"] = { ja = "入る", class = "5" },
	["溶かす"] = { ja = "溶ける", class = "1" },
	["燃やす"] = { ja = "燃える", class = "1" },
	["流す"] = { ja = "流れる", class = "1" },
	["冷やす"] = { ja = "冷える", class = "1" },
	["温める"] = { ja = "温まる", class = "5" },
	["乾かす"] = { ja = "乾く", class = "5" },
	["高める"] = { ja = "高まる", class = "5" },
	["強める"] = { ja = "強まる", class = "5" },
	["弱める"] = { ja = "弱まる", class = "5" },
	["改善する"] = { ja = "改善する", class = "s" },
	["延長する"] = { ja = "延びる", class = "1" },
	["拡大する"] = { ja = "拡大する", class = "s" },
}

T.INTRANSITIVE = INTRANSITIVE

local REQUEST_SUBJECTS = { you = true, someone = true, somebody = true, anyone = true, anybody = true }

-- Chaining verbs: "want to X", "need to X".
local CHAIN = {
	want = "want", need = "need", try = "try", like = "likes", love = "likes",
	plan = "intend", hope = "want", wish = "want",
}

-- Clause-level conjunctions and what they become. kind "sub" moves in front; kind "co" joins.
local CONJUNCTIONS = {
	but = { kind = "co", join = "が、" },
	["and"] = { kind = "co", join = "、" },
	["or"] = { kind = "co", join = "、それとも" },
	so = { kind = "co", join = "ので、" },
	["then"] = { kind = "co", join = "、それから" },
	because = { kind = "sub", form = {}, after = "から、" },
	since = { kind = "sub", form = {}, after = "から、" },
	although = { kind = "sub", form = {}, after = "が、" },
	though = { kind = "sub", form = {}, after = "が、" },
	["if"] = { kind = "sub", form = { conditional = true }, before = "もし", after = "、" },
	-- "unless you hurry" -> 急がなかったら
	unless = { kind = "sub", form = { conditional = true }, invertNegation = true, after = "、" },
	when = { kind = "sub", form = { plain = true }, after = "とき、" },
	["while"] = { kind = "sub", form = { plain = true }, after = "間に、" },
	["until"] = { kind = "sub", form = { plain = true }, after = "まで、" },
	after = { kind = "sub", form = { plain = true, past = true }, after = "後で、" },
	before = { kind = "sub", form = { plain = true }, after = "前に、" },
	whenever = { kind = "sub", form = { plain = true }, after = "ときはいつでも、" },
}

-- Only split on these when a new clause visibly starts after them; otherwise they join nouns
-- ("sword and shield") or are prepositions ("after the raid").
local SPLIT_ONLY_BEFORE_CLAUSE = { ["and"] = true, ["or"] = true, after = true, before = true, ["until"] = true, since = true, so = true, ["then"] = true }

-- ---------------------------------------------------------------------------------------
-- Tagging: tokens -> items, with the longest dictionary match taken first.
-- ---------------------------------------------------------------------------------------

-- Expressions that take an object through a preposition: { in the Japanese, preposition, particle }
local EXPRESSION_OBJECTS = {
	{ "ありがとう", "for", "を" },
	{ "ごめん", "for", "のことで" },
	{ "ようこそ", "to", "へ" },
	{ "おめでとう", "on", "" },
	{ "おめでとう", "for", "" },
	{ "頑張って", "with", "" },
	{ "頑張って", "on", "" },
	{ "頑張って", "in", "" },
	{ "どう思いますか", "about", "について" },
	{ "どう思いますか", "of", "について" },
	{ "向かっている途中", "to", "に" },
}

local function ExpressionTakesObject(ja, preposition)
	for _, rule in ipairs(EXPRESSION_OBJECTS) do
		if preposition == rule[2] and ja:find(rule[1], 1, true) then
			return true
		end
	end
	return false
end

-- Words after which a new sentence has visibly begun.
local CLAUSE_OPENERS = {
	i = true, you = true, we = true, they = true, he = true, she = true, it = true,
	what = true, where = true, when = true, who = true, why = true, how = true, which = true,
	can = true, could = true, will = true, would = true, ["do"] = true, does = true, did = true,
	is = true, are = true, am = true, please = true, pls = true, ["let's"] = true,
	lol = true, guys = true, everyone = true, all = true, ["and"] = true, but = true, so = true,
	["then"] = true,
}
-- Interjections that a noun phrase may follow: "sorry my internet is lagging".
local INTERJECTIONS = { sorry = true, thanks = true, hi = true, hello = true, hey = true, oops = true, thx = true, ty = true }
local DETERMINERS_AFTER_INTERJECTION = { my = true, our = true, their = true, his = true, your = true, the = true, this = true,
	these = true, those = true, its = true }

local function Tag(tokens)
	local items = {}
	local i, count = 1, #tokens
	while i <= count do
		local token = tokens[i]
		if token.kind ~= "word" then
			items[#items + 1] = token
			i = i + 1
		else
			local matched = false
			-- Multi-word entries: "world boss", "thank you", "pick up". The first word may carry
			-- an inflection ("picked up").
			local maxWords = math.min(T.maxPhraseWords or 1, count - i + 1)
			for length = maxWords, 2, -1 do
				if i + length - 1 <= count then
					local words, ok = {}, true
					for k = 0, length - 1 do
						local t = tokens[i + k]
						if t.kind ~= "word" then
							ok = false
							break
						end
						words[#words + 1] = t.w
					end
					if ok then
						local key = table.concat(words, " ")
						local entry = T.Exact(key)
						local inflection, base = nil, key
						if not entry then
							local _, firstInflection, firstBase = T.Lookup(words[1])
							if firstInflection and firstBase then
								words[1] = firstBase
								local candidate = T.As(T.Exact(table.concat(words, " ")), "v")
								if candidate then
									entry, inflection = candidate, firstInflection
									base = table.concat(words, " ")
								end
							end
						end
						-- "daily quests": a noun phrase of the dictionary with its last word in the plural
						if not entry then
							local _, lastInflection, lastBase = T.Lookup(words[length])
							if lastInflection == "plural" and lastBase then
								local singular = {}
								for index, word in ipairs(words) do singular[index] = word end
								singular[length] = lastBase
								local candidate = T.As(T.Exact(table.concat(singular, " ")), "n")
								if candidate then
									entry, inflection = candidate, "plural"
									base = table.concat(singular, " ")
								end
							end
						end
						-- A multi-word expression in the middle of a sentence is usually not that
						-- expression: "help me" is one, "help me with this" is a sentence.
						if entry and entry.pos == "x" then
							local following = tokens[i + length]
							local thanksFor = following and following.kind == "word" and ExpressionTakesObject(entry.ja, following.w)
							local afterInterjection = INTERJECTIONS[key] and following and following.kind == "word" and DETERMINERS_AFTER_INTERJECTION[following.w]
							if following and following.kind == "word" and not CLAUSE_OPENERS[following.w] and not thanksFor and not afterInterjection then
								-- not the expression; the same words may still be a verb or noun phrase
								entry = entry.alts and (entry.alts.v or entry.alts.n) or nil
							end
							local before = items[#items]
							if entry and before and before.kind == "word" and not (before.entry and before.entry.pos == "x")
								and not CONJUNCTIONS[before.w] and not CONJUNCTIONS[words[1]] and not BE[before.w] then
								-- Preserve the conjugatable reading in "do not hard stack".
								entry = entry.alts and (entry.alts.v or entry.alts.n) or nil
							end
						end
						if entry then
							items[#items + 1] = {
								kind = "word", w = key, base = base, orig = token.orig,
								entry = entry, infl = inflection, phrase = true,
							}
							i = i + length
							matched = true
							break
						end
					end
				end
			end

			if not matched then
				local item = { kind = "word", w = token.w, orig = token.orig, base = token.w }
				if not IsGrammarWord(token.w) or HAVE[token.w] or DO[token.w] then
					local entry, inflection, base = T.Lookup(token.w)
					item.entry, item.infl, item.base = entry, inflection, base or token.w
					-- "left" is a noun and leave's past; "saw" a noun and see's past.
					local irregular = T.irregular[token.w]
					if entry and not inflection and entry.pos ~= "v" and not (entry.alts and entry.alts.v) and irregular then
						local verb = T.As(T.Exact(irregular.base), "v")
						if verb then
							local both = {}
							for k, v in pairs(entry) do
								both[k] = v
							end
							both.alts = {}
							for k, v in pairs(entry.alts or {}) do
								both.alts[k] = v
							end
							both.alts.v = verb
							item.entry = both
							item.altInflection = irregular.inflection
							item.altBase = irregular.base
						end
					end
					-- An irregular plural can also be a verb: "lives" is life's plural and live's
					-- third person. Keep both readings and let the context choose.
					if entry and inflection == "plural" and entry.pos == "n" and not (entry.alts and entry.alts.v) then
						local word = token.w
						local verb = T.As(T.Exact(word:sub(1, -2)), "v")
							or (word:sub(-2) == "es" and T.As(T.Exact(word:sub(1, -3)), "v")) or nil
						if verb then
							local both = {}
							for k, v in pairs(entry) do
								both[k] = v
							end
							both.alts = { v = verb }
							item.entry = both
						end
					end
				end
				items[#items + 1] = item
				i = i + 1
			end
		end
	end
	return items
end

-- A word with more than one part of speech ("help", "fight", "love") is read by what stands
-- in front of it. After an article, a determiner, an adjective, a number, a preposition or a
-- verb it is a noun (the help, need help); after a pronoun, a modal, "to" or "not" it is a
-- verb. Anywhere else the dictionary's default -- the last definition loaded -- stands.
-- Words chat puts straight after a bare noun subject: "zerg inc", "rss down", "chal lit"
local SUBJECT_ONLY_VERBS = { inc = true, incoming = true, down = true, lit = true, gone = true, ua = true, open = true }

-- Words that close a status report; the next word starts a new one ("bb gone fare lit")
local STATUS_WORDS = { gone = true, down = true, lit = true, ua = true, open = true }

-- Japanese endings of keep, outpost and town names
local function IsPlaceName(ja)
	for _, ending in ipairs({ "砦", "基地", "城", "街" }) do
		if ja:sub(-#ending) == ending then
			return true
		end
	end
	return false
end

local DIRECTIONS = { north = true, south = true, east = true, west = true,
	northern = true, southern = true, eastern = true, western = true }
local STRUCTURES = { wall = true, door = true, gate = true, tower = true }
local COMBAT_ACTIONS = { repair = true, heal = true, defend = true, attack = true, push = true,
	retreat = true, stack = true, siege = true, rez = true, resurrect = true }
local OBJECT_PRONOUNS = { me = true, us = true, him = true, them = true }
local NOUN_CONTEXT_POS = { det = true, a = true, prep = true, v = true }
local VERB_CONTEXT_WORDS = { to = true, ["not"] = true, ["let's"] = true, never = true, please = true }

local function Disambiguate(items)
	for index, item in ipairs(items) do
		local entry = item.entry
		local following = items[index + 1]
		-- Negative determiners/pronouns are grammar, not stand-alone interjections.
		-- Keep a user's explicit replacement authoritative.
		if not T.userLexicon[item.w] then
			if item.w == "no" and following and following.kind == "word" then
				item.entry = { pos = "det", ja = "", negative = true }
			elseif item.w == "nobody" or item.w == "no one" or item.w == "nothing" or item.w == "none" then
				item.entry = { pos = "pn", ja = item.w == "none" and "どれも" or item.w ~= "nothing" and "誰も" or "何も", negative = true }
			elseif item.w == "neither" and following and T.As(following.entry, "n") then
				item.entry = {pos = "det", ja = "どちらの", negative = true, neither = true}
			elseif item.w == "enough" and following and T.As(following.entry, "n") then
				item.entry = { pos = "det", ja = "十分な" }
			elseif item.w == "more" and following and T.As(following.entry, "n") then
				item.entry = { pos = "det", ja = "もっと" }
			end
			entry = item.entry
		end
		-- "thanks" is an expression; "he thanks you" is a verb. For an expression with no
		-- alternative reading of its own, the inflected reading is the alternative.
		if entry and entry.pos == "x" and not entry.alts and not item.phrase and item.w then
			local previous, following = items[index - 1], items[index + 1]
			local joinedBefore = previous and previous.kind == "word"
				and not (previous.entry and previous.entry.pos == "x") and not CONJUNCTIONS[previous.w]
			local joinedAfter = following and following.kind == "word" and not CLAUSE_OPENERS[following.w]
				and not (INTERJECTIONS[item.w] and DETERMINERS_AFTER_INTERJECTION[following.w])
				and not (following.entry and following.entry.pos == "x")
				and not ExpressionTakesObject(entry.ja, following.w)
			if joinedBefore or joinedAfter then
				local inflected, inflection, base = T.Lookup(item.w, true)
				if inflected and inflected.pos ~= "x" then
					item.entry, item.infl, item.base = inflected, inflection, base
					entry = inflected
				end
			end
		end
		if entry and entry.alts then
			local previous, following = items[index - 1], items[index + 1]
			local wantPos
			-- Perfect auxiliaries can be separated from their participle by adverbs.
			local auxIndex = index - 1
			while items[auxIndex] and items[auxIndex].kind == "word" and
				(NEGATORS[items[auxIndex].w] or items[auxIndex].entry and items[auxIndex].entry.pos == "adv") do
				auxIndex = auxIndex - 1
			end
			local perfectAux = items[auxIndex] and HAVE[items[auxIndex].w]
			local atStart = not previous or previous.kind == "punct"
				or (previous.kind == "word" and CONJUNCTIONS[previous.w])
			if item.w == "still" and entry.alts.adv and following and following.entry
				and (following.entry.pos == "v" or following.entry.pos == "a") then
				wantPos = "adv"
			elseif item.altInflection == "past" and previous and previous.entry and previous.entry.pos == "n"
				and following and ARTICLES[following.w] then
				wantPos = "v"
			elseif perfectAux and (item.infl == "past" or item.altInflection == "past") and entry.alts.v then
				wantPos = "v"
			elseif item.infl == "ing" and previous and (previous.base == "keep" or previous.base == "stop") and T.As(entry, "v") then
				wantPos = "v"
			elseif following and following.kind == "word" and following.infl == "ing"
				and (item.base == "keep" or item.base == "stop") and T.As(entry, "v") then
				wantPos = "v"
			elseif previous and previous.kind == "word" and previous.entry and previous.entry.pos == "n"
				and following and following.kind == "word" and SUBJECT_ONLY_VERBS[following.w] and entry.alts.n then
				-- "yellow zerg inc": still the subject noun phrase
				wantPos = "n"
			elseif not following and atStart and entry.alts.x then
				-- a word on its own: "inc", "push", "def"
				wantPos = "x"
			elseif atStart and following and following.kind == "word" and (entry.alts.n or entry.pos == "n")
				and (BE[following.w] or MODALS[following.w] or following.w == "'s" or SUBJECT_ONLY_VERBS[following.w]
					or (following.entry and following.entry.pos == "v" and following.infl)) then
				-- "water is cold", "the fish's", "rain stopped": a noun doing the verb
				wantPos = "n"
			elseif atStart and entry.pos ~= "v" and entry.alts.v and following
				and (following.kind == "num" or following.kind == "word" and (ARTICLES[following.w] or DEMONSTRATIVE_DET[following.w]
					or (following.entry and (T.As(following.entry, "n") or following.entry.pos == "det")))) then
				-- "drop siege", "farm rss": a clause that opens on a verb with its object after it
				wantPos = "v"
			elseif item.infl == "plural" and entry.alts.v and previous and previous.kind == "word" and previous.entry
				and (previous.entry.pos == "n" or SUBJECT_PRONOUNS[previous.w]) then
				-- "my grandmother lives": a noun, then a plural that can be a verb
				wantPos = "v"
			elseif following and following.kind == "word" and OBJECT_PRONOUNS[following.w] and entry.alts.v then
				-- "add me", "port us"
				wantPos = "v"
			elseif previous and previous.kind == "num" then
				wantPos = "n"
			elseif previous and previous.kind == "word" then
				local w = previous.w
				if BE[w] and entry.alts.pn then
					-- "it is mine": after be, the pronoun reading of a word that is also a place
					wantPos = "pn"
				elseif BE[w] and (entry.pos == "x" or entry.pos == "v" and item.infl ~= "ing" and item.infl ~= "past"
					and not IsStateVerb(entry)) then
					-- "it's ok", "I am new": an expression or verb after "be" is its adjective.
					wantPos = "a"
				elseif ARTICLES[w] or w == "'s" or DEMONSTRATIVE_DET[w] then
					wantPos = "n"
				elseif (HAVE[w] or BE[w]) and (item.infl == "past" or item.infl == "ing") and (entry.pos == "v" or entry.alts.v) then
					-- "has changed", "is changing": the participle, not the noun
					wantPos = "v"
				elseif SUBJECT_PRONOUNS[w] or MODALS[w] or VERB_CONTEXT_WORDS[w] or DO[w]
					or previous.entry and previous.entry.pos == "pn" and previous.entry.negative then
					wantPos = "v"
				elseif previous.entry and NOUN_CONTEXT_POS[previous.entry.pos]
					and not (previous.entry.pos == "v" and entry.pos == "a") then
					wantPos = "n"
				end
			end

			-- A one-word expression with another reading ("nice", "help", "right") is only the
			-- expression when it stands alone: "nice!" is, "a nice sword" is not.
			if entry.pos == "x" and not item.phrase and entry.alts then
				local joinedBefore = previous and (previous.kind == "word" or previous.kind == "num")
					and not (previous.entry and previous.entry.pos == "x")
				local joinedAfter = following and (following.kind == "raw" and following.v:sub(1, 2) == "|H"
					or following.kind == "word" and not CLAUSE_OPENERS[following.w]
						and not (INTERJECTIONS[item.w] and DETERMINERS_AFTER_INTERJECTION[following.w]))
					and not (following.entry and following.entry.pos == "x")
					and not ExpressionTakesObject(entry.ja, following.w)
				if joinedBefore or joinedAfter then
					if not (wantPos and entry.alts[wantPos]) then
						for _, pos in ipairs({ "a", "v", "n", "adv", "pn" }) do
							if entry.alts[pos] then
								wantPos = pos
								break
							end
						end
					end
				else
					wantPos = nil
				end
			end

			if wantPos and entry.pos ~= wantPos then
				local alternative = T.As(entry, wantPos) or (wantPos == "n" and T.As(entry, "a"))
					or (wantPos == "a" and (T.As(entry, "n") or (entry.pos == "x" and T.As(entry, "v")))) or nil
				if alternative then
					item.entry = alternative
					if wantPos == "v" and item.altInflection then
						item.infl, item.base = item.altInflection, item.altBase
					end
					if wantPos == "n" and item.infl == "third" then
						item.infl = "plural"
					elseif wantPos == "v" and item.infl == "plural" then
						item.infl = "third"
					end
				end
			end
		end
		if not T.userLexicon[item.w] then
			local previous, following = items[index - 1], items[index + 1]
			if (item.base == "warden" or item.w == "warden") and not T.userLexicon.warden and T.lexicon.warden and (
				previous and (previous.w == "a" or previous.kind == "num" or NUMBER_WORDS[previous.w])
				or following and ({ healer = true, tank = true, dps = true, dd = true, build = true, class = true })[following.base or following.w]) then
				item.entry = T.lexicon.warden
			end
			-- A complete action call between a place and a new modal clause stays a call.
			local exact = T.Exact(item.w)
			if exact and exact.pos == "x" and T.As(exact, "v") and previous and T.As(previous.entry, "n")
				and following and MODALS[following.w] then item.entry = exact end
		end
	end
	return items
end

-- "its" is the possessive before a noun ("its paintings") and chat's "it is" anywhere else
-- ("its ok", "its broken", "its fine lol").
local function ExpandIts(tokens)
	local out = {}
	for index, token in ipairs(tokens) do
		local following = tokens[index + 1]
		if token.kind == "word" and token.w == "its" then
			local entry = following and following.kind == "word" and T.Lookup(following.w)
			local possessive = entry and (entry.pos == "n" or (entry.alts and entry.alts.n))
				and not (entry.pos == "a" or entry.pos == "x" or entry.pos == "adv")
			if possessive then
				out[#out + 1] = token
			else
				out[#out + 1] = { kind = "word", w = "it", orig = token.orig }
				out[#out + 1] = { kind = "word", w = "is", orig = "is" }
			end
		else
			out[#out + 1] = token
		end
	end
	return out
end

-- "you guys", "you all": one plural "you", read as みんな.
local PLURAL_YOU = { guys = true, all = true, lot = true, folks = true, gals = true, people = true }
local function MergePluralYou(items)
	local out = {}
	local index = 1
	while index <= #items do
		local item, following = items[index], items[index + 1]
		if item.kind == "word" and item.w == "you" and following and following.kind == "word" and PLURAL_YOU[following.w]
			and not T.userLexicon.you and not T.userLexicon[following.w] and not (items[index + 2] and items[index + 2].kind == "word"
			and items[index + 2].entry and items[index + 2].entry.pos == "n") then
			local merged = {}
			for k, v in pairs(item) do merged[k] = v end
			merged.entry = { pos = "pn", ja = "みんな" }
			merged.plural = true
			out[#out + 1] = merged
			index = index + 2
		else
			out[#out + 1] = item
			index = index + 1
		end
	end
	return out
end

T.Tag = function(tokens)
	return MergePluralYou(Disambiguate(Tag(ExpandIts(tokens))))
end

-- ---------------------------------------------------------------------------------------
-- Output helpers
-- ---------------------------------------------------------------------------------------

-- Concatenate Japanese and English fragments: no spaces, except between two pieces of
-- English that would otherwise run together.
local function Join(parts, separator)
	local out = ""
	for _, part in ipairs(parts) do
		if part ~= "" then
			if out ~= "" then
				if separator then
					out = out .. separator
				elseif out:sub(-1):match("[A-Za-z0-9%]]") and part:sub(1, 1):match("[A-Za-z0-9|%[]") then
					out = out .. " "
				end
			end
			out = out .. part
		end
	end
	return out
end

T.Join = Join

local function AttributiveAdjective(entry, inflection)
	local word = entry.class == "na" and (entry.ja .. "な") or entry.ja
	if inflection == "comparative" then
		return "もっと" .. word
	elseif inflection == "superlative" then
		return "一番" .. word
	end
	return word
end

-- 高い -> 高すぎ, 簡単 -> 簡単すぎ
local function TooStem(entry)
	if entry.class == "state" then
		return entry.ja .. "すぎ"
	end
	if entry.class == "na" or entry.class == "rel" then
		return entry.ja .. "すぎ"
	end
	local word = entry.ja == "いい" and "よい" or entry.ja
	return word:sub(1, -4) .. "すぎ"
end

local function AdverbFromAdjective(entry)
	if entry.class == "na" then
		return entry.ja .. "に"
	elseif entry.class == "rel" then
		return entry.ja
	end
	local word = entry.ja == "いい" and "よい" or entry.ja
	return word:sub(1, -4) .. "く"
end

-- ---------------------------------------------------------------------------------------
-- The clause parser
-- ---------------------------------------------------------------------------------------

local Clause = {}
Clause.__index = Clause

local StartsClause

local function NewClause(items)
	return setmetatable({ items = items, known = 0, unknown = 0 }, Clause)
end

function Clause:W(i)
	local item = self.items[i]
	return item and item.kind == "word" and item.w or nil
end

function Clause:Entry(i)
	local item = self.items[i]
	return item and item.entry or nil
end

function Clause:Pos(i)
	local entry = self:Entry(i)
	return entry and entry.pos or nil
end

function Clause:IsVerb(i)
	return self:Pos(i) == "v"
end

function Clause:Count(item)
	if item.counted then
		return
	end
	item.counted = true
	if item.kind ~= "word" then
		return
	end
	if item.entry or IsGrammarWord(item.w) or CONJUNCTIONS[item.w] then
		self.known = self.known + 1
	elseif item.orig and item.orig:match("^[A-Z]") and not item.sentenceStart then
		-- A capitalised word we do not know is most likely a name. It is neither evidence
		-- that the line is English nor evidence that it is not.
	else
		self.unknown = self.unknown + 1
	end
end

-- Can a noun phrase start at i?
function Clause:IsNounPhraseStart(i)
	local item = self.items[i]
	if not item then
		return false
	end
	if item.kind == "num" or item.kind == "raw" then
		return true
	end
	if item.kind ~= "word" then
		return false
	end
	local w = item.w
	if ARTICLES[w] or DEMONSTRATIVE_DET[w] then
		return true
	end
	local pos = self:Pos(i)
	if pos == "n" or pos == "pn" or pos == "det" or pos == "a" then
		return true
	end
	if pos == "adv" and self:Pos(i + 1) == "a" then
		return true
	end
	if pos == "v" and item.infl == "ing" then
		return true
	end
	if not item.entry and not IsGrammarWord(w) and not CONJUNCTIONS[w] then
		return true
	end
	return false
end

-- Parse one noun phrase. Returns { ja, pronoun, adjective, adjectivePrefix, place } and the
-- next index.
function Clause:NounPhrase(i)
	local parts = {}
	local info = {}
	local items = self.items

	while items[i] do
		local item = items[i]
		local w = item.kind == "word" and item.w or nil
		local entry = item.entry
		local numericWord = w and NUMBER_WORDS[w] and w ~= "a" and tonumber(NUMBER_WORDS[w])
		if numericWord and (self:IsNounPhraseStart(i + 1) or self:W(i + 1) == "more") then
			item = { kind = "num", v = NUMBER_WORDS[w] }
			self:Count(items[i])
		end

		if w == "left" and info.head and (info.countSuffix or info.negative) and not items[i + 1]
			and not T.userLexicon.left then
			self:Count(item)
			info.remaining = true
			i = i + 1
			break
		elseif item.kind == "num" and info.countSuffix and self:Entry(i + 1)
			and self:Pos(i + 1) == "n" and not self:Entry(i + 1).unit and not self:Entry(i + 1).time then
			-- "1 tank 2 dps": a fresh quantity starts the next member of a list.
			break
		elseif item.kind == "num" then
			self:Count(item)
			if self:W(i + 1) == "more" then
				self:Count(items[i + 1])
				-- Keep both role and quantity together: "two more healers".
				if self:Pos(i + 2) == "n" then
					parts[#parts + 1] = "あと"
					info.countSuffix = "×" .. item.v
				else
					parts[#parts + 1] = "あと" .. item.v .. "人"
				end
				i = i + 2
			else
				local nextEntry = self:Entry(i + 1)
				if nextEntry and nextEntry.pos == "n" and not nextEntry.time and not nextEntry.unit and #parts == 0 then
					-- "5 rams" -> 破城槌×5
					info.countSuffix = "×" .. item.v
				else
					parts[#parts + 1] = item.v
				end
				i = i + 1
			end
		elseif item.kind == "raw" then
			parts[#parts + 1] = item.v
			i = i + 1
		elseif not w then
			break
		elseif ARTICLES[w] then
			self:Count(item)
			info.determined = true
			i = i + 1
		elseif w == "'s" then
			self:Count(item)
			parts[#parts + 1] = "の"
			i = i + 1
		elseif DEMONSTRATIVE_DET[w] and #parts == 0 and self:IsNounPhraseStart(i + 1)
			and not BE[self:W(i + 1) or ""] then
			self:Count(item)
			parts[#parts + 1] = DEMONSTRATIVE_DET[w]
			info.determined = true
			i = i + 1
		elseif entry and entry.pos == "det" and #parts > 0 and not self:IsNounPhraseStart(i + 1) then
			-- "kill the adds first": a determiner with nothing after it is not one.
			break
		elseif entry and entry.pos == "det" and NUMBER_WORDS[w] and self:Entry(i + 1) and self:Entry(i + 1).time then
			-- "two years" -> 2年, not 2つの年
			self:Count(item)
			parts[#parts + 1] = NUMBER_WORDS[w]
			i = i + 1
		elseif entry and entry.pos == "det" then
			info.negative = info.negative or entry.negative
			info.neither = info.neither or entry.neither
			info.sufficient = info.sufficient or w == "enough" and not T.userLexicon.enough
			self:Count(item)
			parts[#parts + 1] = (w == "more" and info.negative) and "これ以上の" or entry.ja
			info.determined = true
			i = i + 1
		elseif entry and entry.pos == "v" and info.determined and not item.infl and items[i - 1] and items[i - 1].kind == "word"
			and (ARTICLES[items[i - 1].w] or (items[i - 1].entry and items[i - 1].entry.pos == "det")) then
			-- "the invite", "a try": a verb with nothing but a noun reading in front of it
			-- is its noun -- 招待, 試し.
			self:Count(item)
			local base = entry.ja
			if entry.class == "s" and base:sub(-6) == "する" then
				parts[#parts + 1] = base:sub(1, -7)
			elseif entry.class == "i" or entry.class == "na" then
				parts[#parts + 1] = base
			else
				parts[#parts + 1] = T.Stem(base, entry.class)
			end
			info.head = entry
			i = i + 1
		elseif entry and entry.pos == "pn" and #parts > 0 and self:W(i - 1) ~= "'s" then
			-- "is the lumbermill ours": a pronoun after a noun starts the next phrase
			break
		elseif w == "her" and #parts == 0 and (self:Pos(i + 1) == "n" or self:Pos(i + 1) == "a") then
			-- "her mother": the possessive, not the object pronoun
			self:Count(item)
			parts[#parts + 1] = "彼女の"
			info.determined = true
			i = i + 1
		elseif entry and entry.pos == "pn" then
			info.negative = info.negative or entry.negative
			self:Count(item)
			parts[#parts + 1] = entry.ja
			info.pronoun = w
			i = i + 1
			if self:W(i) ~= "'s" then
				break
			end
		elseif (w == "more" or w == "most") and self:Pos(i + 1) == "a" then
			-- "more expensive", "most important"
			self:Count(item)
			info.degree = w == "more" and "comparative" or "superlative"
			i = i + 1
		elseif entry and entry.pos == "adv" and self:Pos(i + 1) == "a" and w == "too" then
			-- "too expensive" -> 高すぎ
			self:Count(item)
			info.too = true
			i = i + 1
		elseif entry and entry.pos == "adv" and self:Pos(i + 1) == "a" and info.head and self.parsingSubject then
			-- "is the server so laggy": so belongs to laggy, not to the subject
			break
		elseif entry and entry.pos == "adv" and self:Pos(i + 1) == "a" then
			self:Count(item)
			if #parts == 0 then
				info.adjectivePrefix = entry.ja
			end
			parts[#parts + 1] = entry.ja
			i = i + 1
		elseif entry and entry.pos == "a" then
			if info.head and IsPlaceName(info.head.ja or "") and DIRECTIONS[w]
				and items[i + 1] and STRUCTURES[items[i + 1].base or items[i + 1].w] and not T.userLexicon[w] then
				parts[#parts + 1] = "の"
				info.head = nil
			end
			if item.infl == "adverb" or info.head then
				-- English adjectives come before their noun; one after it ("rss down")
				-- belongs to the clause, not to this phrase.
				break
			end
			self:Count(item)
			local onlyAdjective = not self:IsNounPhraseStart(i + 1) or self:Pos(i + 1) == "pn"
			local inflection = item.infl or info.degree
			if onlyAdjective and (#parts == 0 or info.adjectivePrefix and #parts == 1) then
				info.adjective = entry
				info.adjectiveInflection = inflection
			end
			if inflection == "superlative" then
				info.superlative = true
			end
			if info.too then
				parts[#parts + 1] = TooStem(entry) .. "る"
			else
				parts[#parts + 1] = AttributiveAdjective(entry, inflection)
			end
			i = i + 1
			if onlyAdjective then
				break
			end
		elseif entry and entry.pos == "n" and info.head and info.head.ja and IsPlaceName(info.head.ja)
			and IsPlaceName(entry.ja) then
			-- "bm roe": two keeps in a row are a list, not one name
			break
		elseif entry and entry.pos == "n" and entry.join and not info.head and self:Entry(i + 1)
			and self:Entry(i + 1).pos == "n" and IsPlaceName(self:Entry(i + 1).ja) then
			-- "fd kings" -> キングクレスト砦の正門
			self:Count(item)
			self:Count(items[i + 1])
			parts[#parts + 1] = self:Entry(i + 1).ja .. entry.join .. entry.ja
			info.head = entry
			i = i + 2
		elseif entry and entry.pos == "n" then
			self:Count(item)
			if info.head and IsPlaceName(info.head.ja or "") and DIRECTIONS[w]
				and items[i + 1] and STRUCTURES[items[i + 1].base or items[i + 1].w] and not T.userLexicon[w] then
				parts[#parts + 1] = "の"
			end
			if info.direction and STRUCTURES[item.base or w] then
				parts[#parts + 1] = "の"
			end
			info.direction = DIRECTIONS[w] and not T.userLexicon[w]
			if entry.join and info.head then
				parts[#parts + 1] = entry.join
			elseif info.head and info.head["then"] and not entry.ends then
				parts[#parts + 1] = info.head["then"]
			end
			parts[#parts + 1] = entry.ja
			info.place = info.place or entry.place
			info.head = entry
			i = i + 1
			if entry.ends then
				info.ended = true
				break
			end
		elseif entry and entry.pos == "v" and item.infl == "ing" and #parts == 0 then
			-- A gerund and what it takes: "playing a tank" -> タンクを遊ぶこと
			local stop = self:RelativeEnd(i)
			local gerundItems = {}
			for k = i, stop - 1 do
				gerundItems[#gerundItems + 1] = items[k]
			end
			local gerund = NewClause(gerundItems)
			local text = gerund:TranslateBare({ plain = true })
			self.known = self.known + gerund.known
			self.unknown = self.unknown + gerund.unknown
			parts[#parts + 1] = text .. "こと"
			info.head = entry
			info.gerund = true
			i = stop
			break
		elseif entry and entry.pos == "v" and item.infl == "ing" then
			-- "the guy standing there": a participle after the noun is a post-modifier
			break
		elseif not entry and not IsGrammarWord(w) and not CONJUNCTIONS[w] then
			self:Count(item)
			parts[#parts + 1] = item.orig or w
			info.unknownHead = true
			i = i + 1
		else
			break
		end
	end

	info.ja = Join(parts)
	if info.countSuffix and info.ja ~= "" then
		info.ja = info.ja .. info.countSuffix
	end
	if info.adjective and #parts > (info.adjectivePrefix and 2 or 1) then
		info.adjective = nil
	end

	-- "the end of the dungeon" -> ダンジョンの終わり
	if info.ja ~= "" and self:W(i) == "of" and self:IsNounPhraseStart(i + 1) then
		self:Count(items[i])
		local owner, nextIndex = self:NounPhrase(i + 1)
		if info.pronoun == "none" and (owner.pronoun == "us" or owner.pronoun == "you" or owner.pronoun == "them") then
			info.ja = owner.ja .. "の誰も"
		else
			info.ja = Join({ owner.ja, "の", info.ja })
		end
		info.adjective = nil
		i = nextIndex
	end

	-- "sword and shield" -> 剣と盾 (the clause splitter left this "and" in place because no
	-- new clause starts after it)
	local w = self:W(i)
	if info.ja ~= "" and (w == "and" or w == "or") and self:IsNounPhraseStart(i + 1) then
		self:Count(items[i])
		local other, nextIndex = self:NounPhrase(i + 1)
		info.ja = Join({ info.ja, w == "and" and "と" or "か", other.ja })
		info.adjective = nil
		info.pronoun = nil
		i = nextIndex
	end

	-- Post-modifiers: a relative clause or a participle after the noun. Japanese puts all of
	-- it in front: "the man who sold me this sword" -> 私にこの剣を売った男性.
	if info.ja ~= "" and (info.head or info.unknownHead or INDEFINITE_PRONOUNS[info.pronoun or ""]) then
		local start = self:PostModifierStart(i, info)
		if start then
			local stop = self:RelativeEnd(start)
			if stop > start then
				local relItems = {}
				for k = start, stop - 1 do
					relItems[#relItems + 1] = items[k]
				end
				for k = i, start - 1 do
					self:Count(items[k])
				end
				local sub = NewClause(relItems)
				local text = sub:Translate({ form = { plain = true }, subordinate = true, relative = true })
				self.known = self.known + sub.known
				self.unknown = self.unknown + sub.unknown
				if text ~= "" then
					info.ja = Join({ text, info.ja })
					info.adjective = nil
					info.relative = true
				end
				i = stop
			end
		end
	end

	if info.neither then info.ja = info.ja .. "も" end
	return info, i
end

-- Where a post-modifier begins after a noun phrase ending before i, or nil.
function Clause:PostModifierStart(i, info)
	local items = self.items
	local item = items[i]
	if not item or item.kind ~= "word" then
		return nil
	end
	local w = item.w
	local nextItem = items[i + 1]
	local following = nextItem and nextItem.kind == "word" and nextItem.w or nil

	if (w == "who" or w == "which" or w == "that" or w == "whom") and nextItem then
		return i + 1
	end
	if w == "where" and (info.place or (info.head and info.head.place)) and nextItem then
		return i + 1
	end
	if w == "when" and info.head and info.head.time and nextItem then
		return i + 1
	end
	if w == "why" and info.head and info.head.ja == "理由" and nextItem then
		return i + 1
	end
	-- "the item you need", "the sword I bought": a subject and a verb straight after the noun
	-- Chat runs sentences together ("go to chal i will port"), so only a determined noun
	-- ("the item", "this sword") followed straight by a verb counts.
	if CONTACT_SUBJECTS[w] and following and self:IsVerb(i + 1) and info.head and info.determined then
		return i
	end
	-- "the guy standing there", "a player using a bow"
	if self:IsVerb(i) and item.infl == "ing" and info.head then
		return i
	end
	-- "a sword made of iron", "a book written by him"
	if self:IsVerb(i) and info.head and (PARTICIPLE_PHRASES[w] or (item.infl == "past"
		and following and (following == "by" or following == "in" or following == "for" or following == "with"))) then
		if not self.parsingSubject or self:LaterPredicate(i + 1) then
			return i
		end
	end
	return nil
end

-- Is there a verb after the noun phrase that starts at i -- uninflected after do/can/will, a
-- past participle after have? That is what tells "does the trial start" from "does the trial".
function Clause:VerbAfterSubject(i, participle)
	local items = self.items
	local k = i
	-- skip the noun phrase: determiners, adjectives, nouns
	while items[k] and items[k].kind == "word" do
		local item = items[k]
		local entry = item.entry
		local isVerb = entry and (entry.pos == "v" or (entry.alts and entry.alts.v)) and not BE[item.w]
		if k > i and isVerb and (participle and item.infl == "past" or not participle and not item.infl) then
			return true
		end
		if k > i and not (ARTICLES[item.w] or entry and (entry.pos == "n" or entry.pos == "a" or entry.pos == "det"
			or (entry.alts and (entry.alts.n or entry.alts.a)))) then
			return false
		end
		k = k + 1
	end
	return false
end

-- Is there a be/modal/finite verb after i? (whether a subject noun phrase can still end)
function Clause:LaterPredicate(i)
	local items = self.items
	for k = i, #items do
		local w = self:W(k)
		if w and (BE[w] or MODALS[w]) then
			return true
		end
	end
	return false
end

-- The index just after a post-modifier starting at start.
function Clause:RelativeEnd(start)
	local items = self.items
	local j, sawVerb = start, false
	while items[j] do
		local item = items[j]
		local w = item.kind == "word" and item.w or nil
		if item.kind == "punct" then
			break
		end
		if j > start and w and CONJUNCTIONS[w] and not item.phrase and SPLIT_ONLY_BEFORE_CLAUSE[w] == nil then
			break
		end
		if sawVerb and self.parsingSubject and w and (BE[w] or MODALS[w] or DO[w]) then
			break
		end
		-- "is the boss that killed us dead?": in a question the predicate is the last word
		if sawVerb and self.parsingInvertedSubject and not items[j + 1] and (self:Pos(j) == "a"
			or (self:IsVerb(j) and not item.infl and IsStateVerb(item.entry))) then
			break
		end
		-- An intransitive relative action can be followed by the main past verb:
		-- "the healer who joined left". Keep "the player who turned left" directional.
		local prev = items[j - 1]
		if sawVerb and self.parsingSubject and not items[j + 1] and item.altInflection == "past"
			and prev and (prev.base == "join" or prev.base == "arrive" or prev.base == "respond")
			and not T.userLexicon[item.w] then
			local v = T.As(item.entry, "v")
			if v then item.entry, item.infl, item.base = v, item.altInflection, item.altBase; break end
		end
		if sawVerb and self.parsingSubject and self:IsVerb(j) and (item.infl == "past" or item.infl == "third")
			and self:W(j - 1) ~= "to" then
			break
		end
		if self:IsVerb(j) or (w and (BE[w] or MODALS[w])) then
			sawVerb = true
		end
		j = j + 1
	end
	return j
end

-- Auxiliaries. Returns true if the word at i was one (and advances past it).
function Clause:Auxiliary(i, form, state)
	local w = self:W(i)
	if not w then
		return false, i
	end
	local item = self.items[i]

	if NEGATORS[w] then
		self:Count(item)
		form.negative = true
		return true, i + 1
	elseif w == "no" and self:IsVerb(i + 1) then
		self:Count(item)
		form.negative = true
		return true, i + 1
	elseif MODALS[w] then
		self:Count(item)
		if w == "would" and (self:W(i + 1) == "like" or self:W(i + 1) == "love") and self:W(i + 2) == "to" then
			form.mode = "want"
			self:Count(self.items[i + 1])
			self:Count(self.items[i + 2])
			return true, i + 3
		end
		local modal = MODALS[w]
		state.modal = w
		if modal ~= "future" then
			form.mode = modal
		end
		return true, i + 1
	elseif DO[w] then
		local nextWord = self:W(i + 1)
		if NEGATORS[nextWord or ""] or self:IsVerb(i + 1) or state.inverted then
			self:Count(item)
			form.past = form.past or DO[w].past
			return true, i + 1
		end
	elseif HAVE[w] then
		if self:W(i + 1) == "to" then
			self:Count(item)
			self:Count(self.items[i + 1])
			form.mode = "have_to"
			form.past = form.past or HAVE[w].past
			return true, i + 2
		end
		local nextItem = self.items[i + 1]
		if state.modal then
			local k = i + 1
			while self:Pos(k) == "adv" or NEGATORS[self:W(k) or ""] do k = k + 1 end
			local candidate = self.items[k]
			if candidate and (candidate.w == "been" or candidate.infl == "past" and self:IsVerb(k)) then
				state.modalPerfect = true
				form.past = true
				if state.modal == "could" then form.mode = "could_perfect"
				elseif state.modal == "must" then form.mode = "deduction"
				elseif state.modal == "would" then form.mode = "counterfactual" end
			end
		end
		-- "have already won": look past adverbs for the participle
		-- "have never seen", "have you ever been": experience -> ～たことがある
		local k, experience = i + 1, false
		while self.items[k + 1] and (self:Pos(k) == "adv" or NEGATORS[self:W(k) or ""] or SUBJECT_PRONOUNS[self:W(k) or ""]) do
			if self:W(k) == "never" or self:W(k) == "ever" then
				experience = true
			end
			k = k + 1
		end
		if not state.modal and not experience and (w == "have" or w == "has") and self.items[k]
			and self.items[k].infl == "past" and self:IsVerb(k) then state.presentPerfect = true end
		if experience and self.items[k] and self.items[k].w == "been" then
			-- "have you ever been to Japan" -> 日本に行ったことがありますか
			self.items[k] = { kind = "word", w = "been:go", orig = "been", infl = "past", base = "go",
				entry = { pos = "v", ja = "行く", class = "5", particle = "に" } }
		end
		if self:W(k) == "been" then
			self:Count(item)
			form.past = form.past or HAVE[w].past
			return true, i + 1
		end
		if k > i + 1 and self.items[k] and self.items[k].infl == "past" and self:IsVerb(k) then
			self:Count(item)
			if experience then
				form.mode = form.mode or "experience"
			else
				form.past = true
			end
			return true, i + 1
		end
		if nextItem and (nextItem.infl == "past" or BE[nextItem.w or ""] or NEGATORS[nextItem.w or ""])
			and (self:IsVerb(i + 1) or BE[nextItem.w or ""] or NEGATORS[nextItem.w or ""]) then
			self:Count(item)
			form.past = true
			return true, i + 1
		end
		if state.inverted then
			self:Count(item)
			return true, i + 1
		end
	elseif BE[w] then
		self:Count(item)
		state.be = true
		if w == "being" then state.being = true end
		form.past = form.past or BE[w].past
		i = i + 1
		if NEGATORS[self:W(i) or ""] then
			self:Count(self.items[i])
			form.negative = true
			i = i + 1
		end
		if self:W(i) == "going" and self:W(i + 1) == "to" and self:IsVerb(i + 2) then
			self:Count(self.items[i])
			self:Count(self.items[i + 1])
			form.mode = "intend"
			state.be = false
			return true, i + 2
		end
		if self:W(i) == "able" and self:W(i + 1) == "to" then
			self:Count(self.items[i])
			self:Count(self.items[i + 1])
			form.mode = "can"
			state.be = false
			return true, i + 2
		end
		return true, i
	elseif w == "used" and self:W(i + 1) == "to" then
		self:Count(item)
		self:Count(self.items[i + 1])
		form.past = true
		return true, i + 2
	end
	return false, i
end

-- Translate one clause. options: { form = {plain, conditional, past}, subordinate = bool }
function Clause:Translate(options)
	options = options or {}
	local items = self.items
	local form = {}
	for key, value in pairs(options.form or {}) do
		form[key] = value
	end
	local state = {}

	if (self:W(1) == "no one" or self:W(1) == "nobody") and self:W(2) == "left" and not items[3]
		and not options.subordinate and not T.userLexicon[self:W(1)] and not T.userLexicon.left then
		self:Count(items[1]); self:Count(items[2])
		self.question = options.questionMark
		return "誰も残っていません" .. (options.questionMark and "か" or "")
	end

	-- Elliptical availability questions: require a question mark, a known noun and
	-- a fully parsed tail. "take any ..." and unknown player names are not inferred.
	if options.questionMark and self:W(1) == "any" and not T.userLexicon.any and self:IsNounPhraseStart(2) then
		local np, j = self:NounPhrase(2)
		local location, online = "", false
		if self:W(j) == "online" and not T.userLexicon.online then
			self:Count(items[j])
			online = true
			j = j + 1
		elseif self:Entry(j) and self:Entry(j).place and self:Pos(j) == "adv" then
			self:Count(items[j])
			location = self:Entry(j).ja .. "に"
			j = j + 1
		elseif (self:W(j) == "at" or self:W(j) == "in") and self:IsNounPhraseStart(j + 1) then
			self:Count(items[j])
			local place
			place, j = self:NounPhrase(j + 1)
			location = place.ja .. "に"
		end
		if np.head and not np.unknownHead and not items[j] and (not online or IsAnimate(np.head)) then
			self:Count(items[1])
			self.question = true
			return location .. (online and "オンラインの" or "") .. np.ja .. "は" .. (IsAnimate(np.head) and "いますか" or "ありますか")
		end
	end

	-- A common verbless warning. Only consume the rule when the whole remaining
	-- clause is its noun phrase; other constructions still go through the parser.
	if self:W(1) == "not" and self:W(2) == "enough" and self:IsNounPhraseStart(3)
		and not T.userLexicon.enough then
		local np, nextIndex = self:NounPhrase(3)
		if not items[nextIndex] then
			self:Count(items[1])
			self:Count(items[2])
			return np.ja .. "が足りません"
		end
	end

	-- Fixed expressions and "please" come out of the clause first. What remains is the
	-- sentence they were decorating: "hi, can you help" -> こんにちは + the question.
	local prefix, suffix, rest = {}, {}, {}
	local please = false
	local predicateExpression
	for _, item in ipairs(items) do
		local before = rest[#rest]
		if item.kind == "word" and item.entry and item.entry.pos == "x" and before and before.kind == "word"
			and BE[before.w] and not predicateExpression
			and (item.entry.ja:sub(-3) == "す" or item.entry.ja:sub(-3) == "ん" or item.entry.ja:sub(-3) == "た") then
			-- "the farm is under attack" -> 農場は攻撃を受けています: the expression is the predicate
			self:Count(item)
			self:Count(before)
			rest[#rest] = nil
			predicateExpression = item.entry.ja
		elseif item.kind == "word" and item.entry and item.entry.pos == "x" then
			self:Count(item)
			if #rest == 0 then
				prefix[#prefix + 1] = item.entry.ja
			else
				suffix[#suffix + 1] = item.entry.ja
			end
		elseif item.kind == "word" and item.w == "please" then
			self:Count(item)
			please = true
		else
			rest[#rest + 1] = item
		end
	end
	items = rest
	self.items = items

	-- "thank you for the help" -> 助けをありがとうございます; "welcome to the guild" -> ギルドへようこそ
	if #prefix > 0 and #suffix == 0 and items[1] and items[1].kind == "word" and self:IsNounPhraseStart(2) then
		local last = prefix[#prefix]
		for _, rule in ipairs(EXPRESSION_OBJECTS) do
			if items[1].w == rule[2] and last:find(rule[1], 1, true) then
				self:Count(items[1])
				local np, nextIndex = self:NounPhrase(2)
				if not items[nextIndex] then
					prefix[#prefix] = np.ja .. rule[3] .. last
					return table.concat(prefix, "、")
				end
				break
			end
		end
	end

	local i = 1
	local question = false
	local wh, whItem
	local subject
	local existential = false

	if self:W(i) == "only" and self:IsVerb(i + 1) and self:IsNounPhraseStart(i + 2) then
		self:Count(items[i])
		state.onlyObject = true
		i = i + 1
	end

	if self:W(i) == "let's" then
		self:Count(items[i])
		form.mode = "lets"
		i = i + 1
	elseif self:W(i) == "let" and self:W(i + 1) == "us" then
		self:Count(items[i])
		self:Count(items[i + 1])
		form.mode = "lets"
		i = i + 2
	end

	if self:Pos(i) == "wh" then
		whItem = items[i]
		wh = whItem.w
		self:Count(whItem)
		question = true
		i = i + 1
	end

	-- Inversion: "is it ...", "can you ...", "where do you ..."
	local invertedAux
	do
		local w = self:W(i)
		if w and (BE[w] or DO[w] or HAVE[w] or MODALS[w]) and not form.mode then
			local nextWord = self:W(i + 1)
			local subjectFollows
			if BE[w] then
				subjectFollows = self:IsNounPhraseStart(i + 1) or nextWord == "there"
			else
				subjectFollows = SUBJECT_PRONOUNS[nextWord or ""] or nextWord == "there" or self:Pos(i + 1) == "pn"
					or (NEGATORS[nextWord or ""] and SUBJECT_PRONOUNS[self:W(i + 2) or ""])
				-- "does the trial start tonight", "can the healer come", "has the boss spawned":
				-- a noun-phrase subject, then the bare verb (or participle) the auxiliary asked for.
				if not subjectFollows and (i == 1 or wh) and self:IsNounPhraseStart(i + 1) and not NEGATORS[nextWord or ""]
					and not BE[nextWord or ""] and self:VerbAfterSubject(i + 1, HAVE[w] ~= nil) then
					subjectFollows = true
				end
			end
			if subjectFollows and (i == 1 or wh) then
				invertedAux = i
				state.inverted = true
				question = true
				local _, nextIndex = self:Auxiliary(i, form, state)
				i = nextIndex > i and nextIndex or i + 1
				if NEGATORS[self:W(i) or ""] then
					self:Auxiliary(i, form, state)
					i = i + 1
				end
				state.inverted = false
			end
		end
	end

	-- Subject.
	local imperative = false
	if form.mode ~= "lets" then
		local w = self:W(i)
		if wh and not invertedAux and self:IsVerb(i) then
			-- "who killed you" -- the question word is the subject.
			state.whSubject = true
		elseif w == "there" and (BE[self:W(i + 1) or ""] or (invertedAux and BE[self:W(invertedAux) or ""])
			or MODALS[self:W(i + 1) or ""]) then
			self:Count(items[i])
			existential = true
			i = i + 1
		elseif self:IsVerb(i) and not items[i].infl and not invertedAux and not options.relative then
			local class = items[i].entry.class
			if class ~= "i" and class ~= "na" and not IsStateVerb(items[i].entry) then
				imperative = true
			end
		elseif options.relative and self:IsVerb(i) then
			-- a relative clause or participle with its subject gapped: "standing there"
		elseif self:IsNounPhraseStart(i) then
			self.parsingSubject = true
			self.parsingInvertedSubject = invertedAux ~= nil
			subject, i = self:NounPhrase(i)
			self.parsingSubject = false
			self.parsingInvertedSubject = false
		end
	end

	if subject and subject.negative then form.negative = true end

	-- Auxiliaries after the subject, and the adverbs English puts among them:
	-- "I usually get up", "we have already won", "I really want to go".
	state.preAdverbs = {}
	while true do
		local handled, nextIndex = self:Auxiliary(i, form, state)
		if handled then
			i = nextIndex
		elseif self:Pos(i) == "adv" and not self:Entry(i).place and self:W(i) ~= "too" and items[i + 1] and items[i + 1].kind == "word"
			and (self:IsVerb(i + 1) or BE[self:W(i + 1)] or MODALS[self:W(i + 1)] or DO[self:W(i + 1)]
				or HAVE[self:W(i + 1)] or NEGATORS[self:W(i + 1)] or self:Pos(i + 1) == "adv") then
			self:Count(items[i])
			state.preAdverbs[#state.preAdverbs + 1] = items[i].entry.ja
			i = i + 1
		else
			break
		end
	end
	if invertedAux and BE[self:W(invertedAux) or ""] then
		state.be = true
	end

	-- The verb.
	local verbItem
	local extraVerbTe
	if self:IsVerb(i) then
		local item = items[i]
		local isBeHelper = state.be
		if isBeHelper and item.infl == "ing" then
			if form.mode then form.aspect = "progressive" end
			form.mode = form.mode or "progressive"
			verbItem = item
		elseif isBeHelper and item.infl == "past" then
			if form.mode then form.aspect = "passive" end
			form.mode = form.mode or "passive"
			if state.being then form.passiveProgressive = true end
			verbItem = item
		elseif isBeHelper and item.infl == nil then
			-- "I am tired" where tired is stored as the state verb 疲れている.
			verbItem = item
		elseif not isBeHelper then
			verbItem = item
			if item.infl == "past" then
				form.past = true
			elseif item.infl == "ing" then
				form.mode = form.mode or "progressive"
			end
		end
		if verbItem then
			self:Count(item)
			i = i + 1
			state.be = false
		end
	end

	-- "got disconnected", "get killed" -> passive
	if verbItem and verbItem.base == "get" and self:IsVerb(i) and items[i].infl == "past" then
		form.past = form.past or verbItem.infl == "past"
		form.mode = form.mode or "passive"
		verbItem = items[i]
		self:Count(verbItem)
		i = i + 1
	end

	if verbItem and (verbItem.base == "keep" or verbItem.base == "stop") and self:IsVerb(i) and items[i].infl == "ing" then
		state.aspect = verbItem.base == "keep" and "continue" or "stop"
		verbItem = items[i]
		self:Count(verbItem)
		i = i + 1
	end

	if verbItem and verbItem.base == "want" and self:Pos(i) == "pn" and self:W(i + 1) == "to" and self:IsVerb(i + 2) then
		state.wantedActor = items[i].entry.ja
		self:Count(items[i])
		self:Count(items[i + 1])
		verbItem = items[i + 2]
		self:Count(verbItem)
		form.mode = "want_person"
		i = i + 3
	end

	-- want to / need to / try to ...
	while verbItem and self:W(i) == "to" do
		local chain = CHAIN[verbItem.base]
		if not chain then
			break
		end
		if BE[self:W(i + 1) or ""] and chain == "want" then
			self:Count(items[i])
			self:Count(items[i + 1])
			form.mode = "become"
			form.past = form.past or verbItem.infl == "past"
			verbItem = nil
			state.be = true
			i = i + 2
			break
		end
		if not self:IsVerb(i + 1) then
			break
		end
		self:Count(items[i])
		form.mode = chain == "try" and form.mode == "progressive" and "try_progressive" or chain
		form.past = form.past or verbItem.infl == "past"
		verbItem = items[i + 1]
		self:Count(verbItem)
		i = i + 2
	end

	-- Past inability is common in post-fight reports. Preserve requests, future
	-- contexts and conditional clauses, where could is not necessarily past.
	if state.modal == "could" and not state.modalPerfect and not question and not options.subordinate then
		local future, pastCue = false, false
		for _, token in ipairs(items) do
			if token.w == "tomorrow" or token.w == "tonight" or token.w == "later" or token.w == "next" or token.w == "now" then future = true end
			if token.w == "yesterday" or token.w == "ago" then pastCue = true end
		end
		if not future and (form.negative or pastCue) then form.past = true end
	end

	if question and form.mode == "could_perfect" then form.mode = "can" end

	-- can you / could you / will you  -> ～てもらえますか
	if question and not state.modalPerfect and subject and verbItem and REQUEST_SUBJECTS[subject.pronoun or ""]
		and (state.modal == "can" or state.modal == "could" or state.modal == "will" or state.modal == "would") then
		form.mode = "request"
		-- "can someone ..." keeps who is being asked: 誰か、～てもらえますか
		if subject.pronoun ~= "you" then
			prefix[#prefix + 1] = subject.ja
		end
		subject = nil
	end

	if please and verbItem and not question then
		imperative = true
		subject = nil
	end
	if not subject and not question and verbItem and self:W(1) == "never" then imperative = true end
	if not subject and not question and state.be and not form.mode
		and (self:W(1) == "be" or (self:W(1) == "do" and self:W(2) == "not" and self:W(3) == "be")
			or (self:W(1) == "never" and self:W(2) == "be")) then
		imperative = true
	end
	if imperative then
		form.mode = form.mode == "can" and "request" or (form.mode or "imperative")
		if form.mode ~= "imperative" and form.mode ~= "request" then
			form.mode = "imperative"
		end
	end

	-- A clause as the object: "think (that) ...", "know where ..."
	local embedded
	if verbItem and REPORT_VERBS[verbItem.base] then
		local j = i
		if self:W(j) == "that" and items[j + 1] then
			j = j + 1
		end
		local embeddedWh = self:Pos(j) == "wh"
		if embeddedWh and self:W(j + 1) == "to" and self:IsVerb(j + 2) then
			-- "how to get there" -> 行き方; "what to do" -> 何をすべきか
			local whEntry = items[j].entry
			local verb = items[j + 2]
			self:Count(items[j])
			self:Count(items[j + 1])
			self:Count(verb)
			local restItems = {}
			for k = j + 3, #items do
				restItems[#restItems + 1] = items[k]
			end
			local rest = NewClause(restItems)
			local tail = {}
			local k = 1
			while restItems[k] do
				local item = restItems[k]
				if item.kind == "word" and item.entry and item.entry.pos == "prep" and rest:IsNounPhraseStart(k + 1) then
					rest:Count(item)
					local np, nextIndex = rest:NounPhrase(k + 1)
					tail[#tail + 1] = np.ja .. (item.w == "to" and "への" or (item.entry.ja .. "の"))
					k = nextIndex
				elseif rest:IsNounPhraseStart(k) then
					local np, nextIndex = rest:NounPhrase(k)
					tail[#tail + 1] = np.ja .. (verb.entry.particle or "を")
					k = nextIndex > k and nextIndex or k + 1
				else
					rest:Count(item)
					k = k + 1
				end
			end
			self.known = self.known + rest.known
			self.unknown = self.unknown + rest.unknown
			if items[j].w == "how" then
				local stem = verb.entry.class == "s" and verb.entry.ja:gsub("する$", "") or T.Stem(verb.entry.ja, verb.entry.class)
				for index, part in ipairs(tail) do
					tail[index] = part:gsub("に$", "への"):gsub("を$", "の")
				end
				embedded = Join(tail) .. stem .. "方を"
			else
				local particle = items[j].w == "where" and (verb.entry.particle == "に" and "に" or "で") or "を"
				embedded = Join(tail) .. whEntry.ja .. particle .. verb.entry.ja .. "べきか"
			end
			i = #items + 1
		elseif items[j] and (embeddedWh or StartsClause(items, j)) then
			local subItems = {}
			for k = j, #items do
				subItems[#subItems + 1] = items[k]
			end
			local sub = NewClause(subItems)
			local subText = sub:Translate({ form = { plain = true }, subordinate = true })
			self.known = self.known + sub.known
			self.unknown = self.unknown + sub.unknown
			if j > i then
				self:Count(items[i])
			end
			if subText ~= "" then
				if embeddedWh then
					embedded = subText:gsub("の$", "") .. "か"
				elseif verbItem.base == "wish" then
					-- "I wish I could go" -> 行けたらいいのに
					embedded = subText .. "といいのに"
					state.wishOnly = true
				else
					embedded = subText .. "と"
				end
				i = #items + 1
			end
		end
	end

	-- Whatever follows the verb: objects, prepositional phrases, adverbs.
	local objects, phrases, adverbs = {}, {}, {}
	local phraseParts = {}
	local complement
	local isCopula = not verbItem and (state.be or existential or form.mode == "become")
	local verbParticle = verbItem and verbItem.entry.particle
	local remainder = {}

	while items[i] do
		local item = items[i]
		local w = item.kind == "word" and item.w or nil
		local pos = self:Pos(i)

		-- Short chat can omit the subject/conjunction of a second clause:
		-- "defend roe [hk] will bone". Once a verb and its object were read,
		-- a modal followed by a verb starts a separate predicate, not another object.
		local modalIndex = SUBJECT_PRONOUNS[w or ""] and i + 1 or i
		local nextVerb = modalIndex + 1
		while items[nextVerb] and (NEGATORS[self:W(nextVerb) or ""] or self:Pos(nextVerb) == "adv") do
			nextVerb = nextVerb + 1
		end
		local separateAction = form.mode == "imperative" and verbItem and #objects > 0
			and COMBAT_ACTIONS[verbItem.base] and COMBAT_ACTIONS[item.base or w]
			and self:IsVerb(i) and not item.infl and self:IsNounPhraseStart(i + 1)
			and not T.userLexicon[verbItem.base] and not T.userLexicon[item.base or w]
		if separateAction or ((MODALS[self:W(modalIndex) or ""] or DO[self:W(modalIndex) or ""] and NEGATORS[self:W(modalIndex + 1) or ""]) and verbItem and (#objects > 0 or #phrases > 0)
			and self:IsVerb(nextVerb)) then
			local tail = {}
			for k = i, #items do tail[#tail + 1] = items[k] end
			local clause = NewClause(tail)
			local translated = clause:Translate()
			self.known = self.known + clause.known
			self.unknown = self.unknown + clause.unknown
			remainder[#remainder + 1] = translated
			i = #items + 1
		elseif item.kind == "punct" then
			i = i + 1
		elseif (pos == "prep" or w == "to") and w ~= nil then
			self:Count(item)
			if w == "to" and self:IsVerb(i + 1) then
				-- "came to help you" -> あなたを手伝うために
				local purposeItems = {}
				for k = i + 1, #items do
					purposeItems[#purposeItems + 1] = items[k]
				end
				local purpose = NewClause(purposeItems)
				local tooTarget = complement and complement.too
				local ja = purpose:TranslateBare(tooTarget and { mode = "can", negative = true, past = form.past } or { plain = true })
				self.known = self.known + purpose.known
				self.unknown = self.unknown + purpose.unknown
				if tooTarget then
					-- "too tired to play" -> 疲れすぎて遊べません
					complement.tooResult = ja
				elseif verbItem and not MOTION_VERBS[verbItem.base] and #objects == 0 and not embedded then
					-- "decided to postpone the meeting" -> 会議を延期することを決めました
					local particle = verbItem.entry.particle
						or ((verbItem.entry.class == "i" or verbItem.entry.class == "na") and "が" or "を")
					embedded = ja .. "こと" .. particle
				elseif not verbItem and complement and not complement.adjective and complement.ja ~= ""
					and subject and subject.pronoun == "it" then
					-- "it is time to go" -> 行く時間です
					complement = { ja = ja .. complement.ja, head = complement.head }
					subject = nil
				elseif not verbItem and (isCopula or complement) and subject and subject.pronoun == "it" then
					-- "it is difficult to predict the outcome" -> 結果を予測するのは難しいです
					subject = { ja = ja .. "の" }
				elseif not verbItem and (isCopula or complement) then
					-- "she was reluctant to accept" -> 受け入れるのに気が進まなかった
					phrases[#phrases + 1] = ja .. "のに"
				else
					-- "came to help you" -> あなたを手伝うために
					phrases[#phrases + 1] = ja .. "ために"
				end
				i = #items + 1
			elseif self:IsNounPhraseStart(i + 1) then
				local np, nextIndex = self:NounPhrase(i + 1)
				local particle = item.entry and item.entry.ja or "に"
				if w == "in" and complement and complement.superlative then
					-- "the best set in the game" -> ゲームで一番いいセット
					particle = "で"
				elseif (w == "in" or w == "at" or w == "on") and (isCopula or verbParticle == "に") then
					particle = "に"
				elseif isCopula and particle:sub(-3) == "で" and #particle > 3 then
					-- "near the wayshrine" with be/there is -> ウェイシュラインの近くに
					particle = particle:sub(1, -4) .. "に"
				end
				if w == "to" or (w == "by" and form.mode == "passive") then
					particle = "に"
				end
				if w == "at" and np.ja:match("^[0-9]+$") then
					-- "at 9" -> 9時に
					np = { ja = np.ja .. "時", head = { time = true } }
					particle = "に"
				end
				if (w == "on" or w == "in" or w == "at") and np.head and np.head.time then
					-- "in April", "on Monday", "at night" -> 4月に
					particle = "に"
				end
				if (w == "on" or w == "in" or w == "at") and verbItem and PLACING_VERBS[verbItem.base] then
					-- "put oils on the fd" -> 正門に
					particle = "に"
				end
				if w == "for" and np.head and np.head.time then
					particle = "間"
				elseif w == "for" and verbItem and (verbItem.entry.class == "na" or verbItem.entry.class == "i") then
					-- "need 2 more for ic" -> インペリアルシティに
					particle = "に"
				end
				if w == "with" and verbItem and verbItem.base == "help" and (#objects == 0 or objects[1].ja == "私") then
					-- "help me with this" -> これを手伝う
					particle = "を"
				elseif w == "with" and items[i - 1] and items[i - 1].base == "help" then
					-- "need help with this" -> これの助け
					particle = "の"
				end
				if w == "from" and isCopula and not verbItem then
					-- "I am from America" -> アメリカ出身です
					complement = complement or { ja = np.ja .. "出身" }
					i = nextIndex
					particle = nil
				end
				if not particle then
					-- handled above
				elseif w == "in" and np.head and DURATION_WORDS[np.head.ja] then
					-- "in 5 minutes" -> 5分後に. Time goes first in a Japanese clause.
					table.insert(phrases, 1, Join({ np.ja, "後に" }))
					for index = #phrases, 2, -1 do
						phraseParts[index] = phraseParts[index - 1]
					end
					phraseParts[1] = { np = np.ja, w = w }
				else
					phrases[#phrases + 1] = Join({ np.ja, particle })
					phraseParts[#phrases] = { np = np.ja, w = w }
				end
				i = nextIndex
			else
				-- "what are you looking for" -- a stranded preposition says nothing here.
				i = i + 1
			end
		elseif w == "as" and self:Pos(i + 1) == "a" and self:W(i + 2) == "as" and self:IsNounPhraseStart(i + 3) then
			-- "as tall as her mother" -> 母と同じくらい背が高い
			self:Count(item)
			self:Count(items[i + 1])
			self:Count(items[i + 2])
			local other, nextIndex = self:NounPhrase(i + 3)
			complement = { adjective = items[i + 1].entry, adjectivePrefix = other.ja .. "と同じくらい", ja = "" }
			i = nextIndex
		elseif w == "too" and self:IsVerb(i + 1) and (IsStateVerb(items[i + 1].entry)
			or items[i + 1].entry.class == "i" or items[i + 1].entry.class == "na") then
			-- "too tired to play", "too busy": a verb that works as the adjective
			self:Count(item)
			self:Count(items[i + 1])
			local entry = items[i + 1].entry
			local adjective = IsStateVerb(entry) and { ja = entry.ja:sub(1, -10), class = "state" }
				or { ja = entry.ja, class = entry.class }
			complement = { too = true, ja = "", adjective = adjective }
			isCopula = true
			state.be = true
			i = i + 2
		elseif w == "only" and self:IsNounPhraseStart(i + 1) then
			self:Count(item)
			state.onlyObject = true
			i = i + 1
		elseif (pos == "adv" and self:Pos(i + 1) ~= "a") or pos == "wh" then
			self:Count(item)
			if item.entry.place and (isCopula or verbItem) then
				-- "I will be there" -> そこにいます; "go there" -> そこに行きます; "farm here" -> ここで
				local place = item.entry.ja
				local particle = (isCopula or verbParticle == "に") and "に" or "で"
				phrases[#phrases + 1] = place .. particle
			elseif complement == nil and isCopula and not items[i + 1] and #phrases == 0 then
				complement = { ja = item.entry.ja }
			else
				adverbs[#adverbs + 1] = item.entry.ja
			end
			i = i + 1
		elseif pos == "det" and T.As(item.entry, "adv") and not self:IsNounPhraseStart(i + 1) then
			self:Count(item)
			adverbs[#adverbs + 1] = T.As(item.entry, "adv").ja
			i = i + 1
		elseif pos == "a" and (item.infl == "adverb" or (verbItem and not isCopula and not state.be
			and not self:IsNounPhraseStart(i + 1) and #objects == 0)) then
			-- "quickly", and a bare adjective after the verb: "get up early" -> 早く起きる
			self:Count(item)
			adverbs[#adverbs + 1] = AdverbFromAdjective(item.entry)
			i = i + 1
		elseif w and NEGATORS[w] then
			self:Count(item)
			form.negative = true
			i = i + 1
		elseif self:IsVerb(i) and verbItem and #objects == 0 and item.infl ~= "ing" then
			-- "go kill the boss" / "come help" -> 行って倒します
			self:Count(item)
			extraVerbTe = Join({ extraVerbTe or "", T.TeForm(verbItem.entry.ja, verbItem.entry.class) })
			verbItem = item
			verbParticle = item.entry.particle
			i = i + 1
		elseif self:IsNounPhraseStart(i) then
			local np, nextIndex = self:NounPhrase(i)
			if np.head and np.head.time and self:W(nextIndex) == "ago" then
				-- "two years ago" -> 2年前
				self:Count(items[nextIndex])
				table.insert(adverbs, 1, np.ja .. "前に")
				nextIndex = nextIndex + 1
			elseif isCopula and not complement then
				complement = np
			else
				objects[#objects + 1] = np
			end
			if nextIndex == i then
				i = i + 1
			else
				i = nextIndex
			end
		elseif self:IsVerb(i) and not verbItem and state.be then
			self:Count(item)
			verbItem = item
			isCopula = false
			i = i + 1
		else
			if item.kind == "word" then
				self:Count(item)
				-- Knowing a word does not mean we parsed it. Keep unhandled words visible.
				if not (CONJUNCTIONS[w or ""] and #prefix > 0 and #suffix > 0 and not verbItem and not subject) then
					remainder[#remainder + 1] = item.orig or item.w
				end
			end
			i = i + 1
		end
	end

	for _, object in ipairs(objects) do
		if object.negative then
			form.negative = true
			if not verbItem and not isCopula and not existential then object.ja = object.ja .. "なし" end
		end
	end
	if complement and complement.negative then form.negative = true end
	if subject and subject.negative and not subject.pronoun and not verbItem and not isCopula then
		subject.ja = subject.ja .. "なし"
	end

	if state.presentPerfect and form.negative and not form.mode then
		form.mode = "progressive"
		form.past = false
	end
	if options.invertNegation then form.negative = not form.negative end

	-- ---- assemble -------------------------------------------------------------------
	local out = {}

	local hasPredicate = verbItem or existential or isCopula or predicateExpression

	-- Elliptical counts, including "only two enemies left".
	local remaining = not hasPredicate and (subject and subject.remaining and #objects == 0 and subject
		or not subject and #objects == 1 and objects[1].remaining and objects[1])
	if remaining and not options.subordinate and #phrases == 0 and #remainder == 0 then
		local text = remaining.ja:gsub("なし$", "") .. (state.onlyObject and "だけ" or "")
		text = table.concat(adverbs) .. text .. (remaining.negative and "は残っていません" or "が残っています")
		if question or options.questionMark then text = text .. "か" end
		self.question = question or options.questionMark
		return Join({table.concat(prefix, "、"), text, table.concat(suffix, "、")}, "、")
	end

	-- Possessing people means having them available, not owning an object.
	if verbItem and verbItem.base == "have" and not T.userLexicon.have and #objects == 1 then
		local availableRoles = { ["ヒーラー"] = true, ["タンク"] = true, ["DPS"] = true, ["DD"] = true,
			["プレイヤー"] = true, ["メンバー"] = true, ["仲間"] = true, ["友達"] = true }
		state.haveAnimate = objects[1].head and availableRoles[objects[1].head.ja]
		state.insufficient = form.negative and objects[1].sufficient
		if state.insufficient then objects[1].ja = objects[1].ja:gsub("^十分な", "") end
	end

	-- "no healers online" reports absence, not that particular healers are offline.
	local onlineReport = complement or (#objects == 1 and objects[1])
	if (not verbItem and onlineReport and onlineReport.ja == "オンライン" or verbItem and verbItem.base == "online")
		and subject and subject.negative and IsAnimate(subject.head) and not form.mode
		and #adverbs == 0 and #(state.preAdverbs or {}) == 0 and #phrases == 0 and #remainder == 0 and not T.userLexicon.online then
		local text = "オンラインの" .. subject.ja:gsub("なし$", "") .. "は" .. T.Predicate({ja = "いる", class = "1"}, {negative = true, past = form.past})
		if question or options.questionMark then text = text .. "か" end
		self.question = question or options.questionMark
		return Join({table.concat(prefix, "、"), text, table.concat(suffix, "、")}, "、")
	end

	-- "rss down", "fd open": a noun and a lone adjective with no verb between them
	if not hasPredicate and subject and #objects == 1 and objects[1].adjective and #phrases == 0 then
		isCopula = true
		complement = objects[1]
		objects = {}
		hasPredicate = true
	end

	-- "healer here": location reports with a known entity and no other predicate.
	if not hasPredicate and subject and subject.head and #objects == 0 and #phrases == 0
		and #adverbs == 1 and #remainder == 0 and #prefix == 0 and #suffix == 0 then
		local last = items[#items]
		if last and last.entry and last.entry.place and last.entry.pos == "adv" then
			if subject.negative then
				-- The verbless fallback above appends なし; use the negative predicate here.
				return adverbs[1] .. "に" .. subject.ja:gsub("なし$", "") .. "は" .. (IsAnimate(subject.head) and "いません" or "ありません")
			end
			return adverbs[1] .. "に" .. subject.ja .. "が" .. (IsAnimate(subject.head) and "います" or "あります")
		end
	end

	-- No verb at all.
	if not hasPredicate then
		local whJaBare = whItem and whItem.entry.ja
		-- "how much for this sword?" -> この剣はいくらですか
		if whJaBare then
			local topic = phraseParts[1] and phraseParts[1].np or (objects[1] and objects[1].ja) or (subject and subject.ja)
			local text = (topic and topic ~= "" and (topic .. "は") or "") .. whJaBare .. "ですか"
			self.question = true
			return Join({ table.concat(prefix, "、"), text }, #prefix > 0 and "、" or nil)
		end
		-- "tank for vss" -> vSS用のタンク; "ball group at bd" -> 裏門にボールグループ
		for index, part in pairs(phraseParts) do
			if part.w == "for" then
				phrases[index] = part.np .. "用の"
			elseif part.w == "at" or part.w == "in" or part.w == "on" then
				phrases[index] = part.np .. "に"
			end
		end
		-- "ball group inc bd" -> 裏門にボールグループインカミング
		if subject and subject.ended and #objects > 0 then
			for index = #objects, 1, -1 do
				table.insert(phrases, 1, objects[index].ja .. "に")
			end
			objects = {}
		end
		if subject and #phrases > 0 then
			local words = {}
			for _, phrase in ipairs(phrases) do
				words[#words + 1] = phrase
			end
			words[#words + 1] = subject.ja
			subject = { ja = Join(words) }
			phrases = {}
		end
	end

	-- Omit only an unmodified first-person speaker in a complete standalone
	-- statement. Keep questions, conditions, contrasts and custom pronouns explicit.
	local speakerEmphasis, speakerAlso = false, false
	if subject and subject.pronoun == "i" then
		for _, item in ipairs(items) do
			if item.w == "only" or item.w == "too" or item.w == "also" or item.w == "alone" or item.w == "myself" then speakerEmphasis = true end
		end
		if subject.ja == "私" and #objects == 0 and not options.subordinate and not T.userLexicon.i and not T.userLexicon.too and not T.userLexicon.also then
			for _, list in ipairs({adverbs, state.preAdverbs or {}}) do
				for i = #list, 1, -1 do
					if list[i] == "も" then table.remove(list, i); speakerAlso = true end
				end
			end
		end
	end
	local omitSpeaker = subject and subject.pronoun == "i" and subject.ja == "私"
		and not speakerEmphasis and hasPredicate and not question and (not options.subordinate or options.sameSubject)
		and not options.questionMark and not options.keepSubject
		and not options.plain and self.unknown == 0 and not T.userLexicon.i
-- The person spoken to is left out of Japanese: "do you know where it is" -> どこにあるか知っていますか.
	-- Kept for a contrast, an emphasis, a relative clause ("the item you need"), and "who are you".
	local addresseeEmphasis = false
	for _, item in ipairs(items) do
		if item.w == "only" or item.w == "too" or item.w == "also" or item.w == "yourself" or item.w == "alone" then addresseeEmphasis = true end
	end
	if not omitSpeaker and subject and subject.pronoun == "you" and subject.ja == "あなた" and hasPredicate
		and not addresseeEmphasis and not options.keepSubject and not options.relative and not options.plain
		and not (isCopula and whItem ~= nil) and self.unknown == 0 and not T.userLexicon.you then
		omitSpeaker = true
	end
	-- "We" in an action sentence is left out the same way: "we lost the keep" -> 砦を失いました.
	-- A description of the group ("we are friendly") keeps it.
	if not omitSpeaker and subject and subject.pronoun == "we" and subject.ja == "私たち" and hasPredicate
		and not isCopula and not speakerEmphasis and not question and (not options.subordinate or options.sameSubject)
		and not options.questionMark
		and not options.keepSubject and not options.plain and self.unknown == 0 and not T.userLexicon.we then
		omitSpeaker = true
	end
if subject and subject.ja ~= "" and form.mode ~= "request" and not omitSpeaker then
		if hasPredicate then
			local particle = (subject.negative and (subject.pronoun or subject.neither)) and "" or ((options.subordinate or INDEFINITE_PRONOUNS[subject.pronoun or ""]) and "が" or "は")
			if verbItem and verbItem.base == "have" and objects[1] and (objects[1].remaining or state.haveAnimate) and not T.userLexicon.have then particle = "には" end
			if verbItem and verbItem.base == "need" and not subject.negative and not T.userLexicon.need then
				if options.questionMark and INDEFINITE_PRONOUNS[subject.pronoun or ""] then
					particle = "、"
				elseif options.subordinate then
					particle = "に"
				end
			end
			if speakerAlso then particle = "も" end
			out[#out + 1] = subject.ja .. particle
		else
			-- No verb at all: "nice sword", "2 dps lf healer". Say the words, not a sentence.
			out[#out + 1] = subject.ja
		end
	end

	local whJa = whItem and whItem.entry.ja
	if whJa and state.whSubject then
		out[#out + 1] = whJa .. "が"
	end

	for index = #(state.preAdverbs or {}), 1, -1 do
		table.insert(adverbs, 1, state.preAdverbs[index])
	end
	for _, adverb in ipairs(adverbs) do
		out[#out + 1] = adverb
	end
	if whJa and not state.whSubject and (wh == "when" or wh == "why" or wh == "how") and not isCopula then
		out[#out + 1] = whJa
	end
	for _, phrase in ipairs(phrases) do
		out[#out + 1] = phrase
	end
	if state.wantedActor then out[#out + 1] = state.wantedActor .. "に" end

	local isStative = verbItem and (verbItem.entry.class == "i" or verbItem.entry.class == "na")
	local objectParticle = verbParticle or (isStative and "が" or "を")
	if verbItem and verbItem.base == "have" and objects[1] and (objects[1].remaining or state.haveAnimate or state.insufficient) and not T.userLexicon.have then objectParticle = "が" end
	if state.onlyObject and objects[1] then objects[1].ja = objects[1].ja .. "だけ" end
	if verbItem and verbItem.base == "ask" and objects[1] and objects[1].pronoun then objectParticle = "に" end

	if whJa and not state.whSubject and verbItem and not (wh == "when" or wh == "why" or wh == "how") then
		if wh == "where" then
			out[#out + 1] = verbParticle == "に" and "どこに" or "どこで"
		elseif wh == "who" and verbParticle then
			out[#out + 1] = whJa .. verbParticle
		else
			out[#out + 1] = whJa .. objectParticle
		end
	end

	if (form.mode == "request" or form.mode == "imperative") and #objects == 1 and objects[1].ja == "私"
		and verbItem and verbItem.base == "help" then
		-- "can you help me" -> 手伝ってもらえますか; the 私を is implied by the request.
		table.remove(objects, 1)
	end

	if subject and subject.pronoun and subject.ja ~= "" then
		local own = subject.ja .. "の"
		for _, object in ipairs(objects) do
			if object.ja:sub(1, #own) == own and #object.ja > #own then
				object.ja = object.ja:sub(#own + 1)
			end
		end
	end

	local quantityList = #objects >= 2
	for _, object in ipairs(objects) do quantityList = quantityList and object.countSuffix ~= nil end
	if quantityList then
		local parts = {}
		for _, object in ipairs(objects) do parts[#parts + 1] = object.ja end
		out[#out + 1] = table.concat(parts, "と") .. objectParticle
	elseif #objects >= 2 then
		out[#out + 1] = objects[1].ja .. "に"
		for k = 2, #objects do
			out[#out + 1] = objects[k].ja .. objectParticle
		end
	elseif #objects == 1 and objects[1].ja ~= "" then
		if not hasPredicate and #out > 0 then
			-- no verb: "bm roe inner 80 percent" is a list
			out[#out] = out[#out] .. "、"
		end
		out[#out + 1] = objects[1].ja .. (verbItem and not (objects[1].negative and (objects[1].pronoun or objects[1].neither)) and objectParticle or "")
	end

	if extraVerbTe then
		out[#out + 1] = extraVerbTe
	end

	if embedded then
		out[#out + 1] = embedded
	end

	-- "give me X" -> Xをください / Xをもらえますか
	if verbItem and verbItem.base == "give" and (form.mode == "imperative" or form.mode == "request") then
		for index = #out, 1, -1 do
			if out[index] == "私に" then
				table.remove(out, index)
				local verbText = form.mode == "request" and "もらえます" or "ください"
				out[#out + 1] = verbText
				verbItem = nil
				hasPredicate = true
				break
			end
		end
	end

	if state.wishOnly then
		-- the wish is already said
	elseif predicateExpression and not verbItem then
		out[#out + 1] = predicateExpression
	elseif verbItem then
		local verbEntry = verbItem.entry
		if verbItem.base == "have" and objects[1] and objects[1].remaining and not T.userLexicon.have then
			verbEntry = {ja = "残っている", class = "1"}
		elseif state.haveAnimate then
			verbEntry = {ja = "いる", class = "1"}
		end
		if state.insufficient then verbEntry = {ja = "足りる", class = "1"} end
		if options.subordinate and verbItem.base == "ready" and verbEntry.ja == "準備ができている"
			and not T.userLexicon.ready then
			verbEntry = { ja = "準備できる", class = "1" }
		end
		if verbItem.base == "leave" and not T.userLexicon.leave and objects[1] and objects[1].pronoun
			and ({ me = true, us = true, you = true, him = true, her = true, them = true })[objects[1].pronoun] then
			verbEntry = { ja = "置き去りにする", class = "s" }
		end
		if #objects == 0 and not embedded and subject and not PERSON_PRONOUNS[subject.pronoun or ""]
			and INTRANSITIVE[verbEntry.ja] and form.mode ~= "passive" then
			-- "the event starts" -> 始まります, not 始めます
			verbEntry = INTRANSITIVE[verbEntry.ja]
		end
		if state.aspect then
			verbEntry = { class = "1" }
			if state.aspect == "continue" then
				verbEntry.ja = T.Stem(verbItem.entry.ja, verbItem.entry.class) .. "続ける"
			elseif form.mode == "imperative" and not form.negative then
				-- "stop attacking" is an instruction to cease this action.
				verbEntry = verbItem.entry
				form.negative = true
			else
				verbEntry.ja = T.PlainPredicate(verbItem.entry, {}) .. "のをやめる"
			end
		end
		out[#out + 1] = T.Predicate(verbEntry, form)
	elseif out[#out] == "ください" or out[#out] == "もらえます" then
		-- already said
	elseif existential then
		local animate = complement and (IsAnimate(complement.head) or ({someone=true,somebody=true,anyone=true,anybody=true,
			nobody=true,["no one"]=true,everyone=true,everybody=true})[complement.pronoun or ""])
		local exists = animate and { ja = "いる", class = "1" } or { ja = "ある", class = "5" }
		if complement then
			out[#out + 1] = complement.ja .. (complement.negative and complement.pronoun and "" or "が")
		end
		out[#out + 1] = T.Predicate(exists, form)
	elseif isCopula then
		if whJa and not complement then
			complement = { ja = whJa }
		end
		if complement and complement.adjective then
			local prefix = complement.adjectivePrefix or ""
			local adjective = complement.adjective
			local inflection = complement.adjectiveInflection
			local head = inflection == "comparative" and "もっと" or (inflection == "superlative" and "一番" or "")
			for _, part in pairs(phraseParts) do
				if part.w == "than" then
					-- "stronger than a healer" -> ヒーラーより強い: より already says "more"
					head = ""
				end
			end
			if complement.too and complement.tooResult then
				out[#out + 1] = prefix .. TooStem(adjective) .. "て" .. complement.tooResult
			elseif complement.too then
				out[#out + 1] = prefix .. T.Masu(TooStem(adjective), form.past, form.negative)
			elseif form.mode == "maybe" then
				out[#out + 1] = prefix .. head .. adjective.ja .. "かもしれません"
			else
				out[#out + 1] = prefix .. head .. T.Copula(adjective.ja, adjective.class, form)
			end
		elseif complement and complement.ja ~= "" then
			if form.mode == "maybe" then
				out[#out + 1] = complement.ja .. "かもしれません"
			else
				out[#out + 1] = T.Copula(complement.ja, "n", form)
			end
		elseif #phrases > 0 then
			-- people and names are いる; things are ある ("the scroll is at alessia")
			local animate = subject and (subject.pronoun or subject.unknownHead or IsAnimate(subject.head))
			out[#out + 1] = T.Predicate(animate and { ja = "いる", class = "1" } or { ja = "ある", class = "5" }, form)
		elseif subject then
			out[#out + 1] = T.Copula("", "n", form)
		end
	end

	local body = Join(out)
	if question and not options.subordinate and body ~= "" then
		body = body .. "か"
	end

	local text = body
	if #prefix > 0 then
		text = Join({ table.concat(prefix, "、"), body }, body ~= "" and "、" or nil)
	end
	if #suffix > 0 then
		text = Join({ text, table.concat(suffix, "、") }, text ~= "" and "、" or nil)
	end
	if #remainder > 0 then
		text = Join({ text, table.concat(remainder, " ") }, text ~= "" and "、" or nil)
	end
	self.question = question
	return text
end

-- A clause with no subject of its own and a plain verb, used for "to" purposes.
function Clause:TranslateBare(form)
	local items = self.items
	local verbItem = items[1]
	local rest = {}
	for k = 2, #items do
		rest[#rest + 1] = items[k]
	end
	self:Count(verbItem)
	local tail = NewClause(rest)
	local objects = {}
	local particle = verbItem.entry.particle or "を"
	local i = 1
	while rest[i] do
		if tail:IsNounPhraseStart(i) then
			local np, nextIndex = tail:NounPhrase(i)
			objects[#objects + 1] = np.ja .. particle
			i = nextIndex > i and nextIndex or i + 1
		else
			local item = rest[i]
			if item.kind == "word" and item.entry and item.entry.pos == "prep" and tail:IsNounPhraseStart(i + 1) then
				tail:Count(item)
				local np, nextIndex = tail:NounPhrase(i + 1)
				objects[#objects + 1] = np.ja .. item.entry.ja
				i = nextIndex
			elseif item.kind == "word" and item.entry and item.entry.pos == "adv" then
				-- "to meet tomorrow" -> 明日会う: adverbs go in front
				tail:Count(item)
				table.insert(objects, 1, item.entry.ja)
				i = i + 1
			else
				if item.kind == "word" then
					tail:Count(item)
				end
				i = i + 1
			end
		end
	end
	self.known = self.known + tail.known
	self.unknown = self.unknown + tail.unknown
	if form.mode then
		objects[#objects + 1] = T.Predicate(verbItem.entry, form)
	else
		objects[#objects + 1] = T.PlainPredicate(verbItem.entry, form)
	end
	return Join(objects)
end

-- ---------------------------------------------------------------------------------------
-- Sentences
-- ---------------------------------------------------------------------------------------

StartsClause = function(items, i)
	local item = items[i]
	if not item or item.kind ~= "word" then
		return false
	end
	local w = item.w
	local nextItem = items[i + 1]
	if (INDEFINITE_PRONOUNS[w] or w == "everyone" or w == "everybody") and nextItem
		and (BE[nextItem.w] or MODALS[nextItem.w] or DO[nextItem.w] or HAVE[nextItem.w]
			or (nextItem.entry and nextItem.entry.pos == "v")) then
		return true
	end
	if SUBJECT_PRONOUNS[w] or w == "there" or w == "let's" or BE[w] or MODALS[w] then
		return true
	end
	if item.entry and item.entry.pos == "v" and not item.infl then
		return true
	end
	-- A complete fixed call can start the next clause: "stop dps then rez me".
	if item.phrase and item.entry and item.entry.pos == "x" then
		return true
	end
	-- "and my friend is..." -- a noun phrase followed by a verb or auxiliary.
	local k = i
	while items[k] and items[k].kind == "word" and (ARTICLES[items[k].w] or (items[k].entry and
		(items[k].entry.pos == "det" or items[k].entry.pos == "n" or items[k].entry.pos == "a"))) do
		k = k + 1
	end
	local after = items[k]
	return k > i and after and after.kind == "word" and (BE[after.w] or MODALS[after.w]
		or (after.entry and after.entry.pos == "v" and after.infl ~= "ing")) or false
end

-- Split a run of items into { conj = word|nil, items = {...} }.
local function SplitClauses(items)
	local clauses = { { items = {} } }
	for i, item in ipairs(items) do
		local w = item.kind == "word" and item.w or nil
		local conj = w and not item.phrase and CONJUNCTIONS[w]
		local current = clauses[#clauses]
		local split = false
		if conj then
			if w == "when" and i == 1 and (BE[items[i + 1] and items[i + 1].w or ""] or DO[items[i + 1] and items[i + 1].w or ""]
				or MODALS[items[i + 1] and items[i + 1].w or ""]) then
				-- "when is the raid?" -- a question, not a subordinate clause.
				split = false
			elseif w == "when" and items[i - 1] and items[i - 1].entry and items[i - 1].entry.time then
				-- "the day when we met" -- a relative clause on a time noun
				split = false
			elseif SPLIT_ONLY_BEFORE_CLAUSE[w] then
				split = StartsClause(items, i + 1) and (#current.items > 0 or w == "so" or w == "then")
			else
				split = true
			end
		end
		local previous = current.items[#current.items]
		if not conj and (current.conj == "if" or current.conj == "unless" or current.conj == "when")
			and previous and previous.base == "ready" and not T.userLexicon.ready
			and item.entry and item.entry.pos == "v" and not item.infl
			and item.entry.class ~= "i" and item.entry.class ~= "na" and not IsStateVerb(item.entry) then
			-- "if you are ready push fd": the state ends the condition, push starts the call.
			clauses[#clauses + 1] = { items = { item } }
		elseif split then
			if #current.items == 0 and not current.conj then
				current.conj = w
			else
				clauses[#clauses + 1] = { conj = w, items = {} }
			end
		else
			current.items[#current.items + 1] = item
		end
	end
	if T.Semantic then
		local expanded = {}
		for _, clause in ipairs(clauses) do
			local boundary = (clause.conj == "if" or clause.conj == "unless" or clause.conj == "when")
				and T.Semantic.FindBoundary(clause.items)
			if boundary then
				local condition, main = {}, {}
				for i, item in ipairs(clause.items) do
					local target = i < boundary and condition or main
					target[#target + 1] = item
				end
				expanded[#expanded + 1] = {conj = clause.conj, items = condition}
				expanded[#expanded + 1] = {items = main}
			else expanded[#expanded + 1] = clause end
		end
		return expanded
	end
	return clauses
end

-- Structured readers never mutate the tokens or dictionary of another candidate.
T.IsAnimateEntry = IsAnimate
function T.ReadNominal(items, first, last)
	local copy = {}
	for i = first, last do
		local item = {}
		for k, v in pairs(items[i]) do if k ~= "counted" then item[k] = v end end
		copy[#copy + 1] = item
	end
	if #copy == 0 then return nil end
	local parser = NewClause(copy)
	local np, nextIndex = parser:NounPhrase(1)
	if nextIndex ~= #copy + 1 or np.ja == "" or np.unknownHead or parser.unknown > 0 then return nil end
	return np
end

-- Who a clause is about, when it says so: its first word if that is a person pronoun, or a noun
-- phrase. Imperatives and verbless calls name no one.
local function LeadSubject(items)
	local first = items[1]
	if first and first.kind == "word" and CONJUNCTIONS[first.w] and not first.phrase then
		-- "..., so you should hurry": a consequence is not a contrast
		if first.w == "so" or first.w == "because" or first.w == "since" or first.w == "then" then return nil end
		first = items[2]
	end
	if not first or first.kind ~= "word" then return nil end
	local w = first.w
	if SUBJECT_PRONOUNS[w] then return w end
	if w == "there" or IsGrammarWord(w) and not ARTICLES[w] then return nil end
	if ARTICLES[w] or DEMONSTRATIVE_DET[w] then return "n:" .. w end
	local pos = first.entry and first.entry.pos
	if pos == "n" or pos == "det" or pos == "pn" then return "n:" .. w end
	return nil
end

-- Two parallel clauses about different people are a contrast, and keep their subjects:
-- "I heal but you attack". A single speaker's run of clauses does not: "thanks, I appreciate it".
-- A subordinate clause ("before we pull the boss") is not parallel to the one it hangs on.
local PERSON_LEADS = { i = true, you = true, we = true, he = true, she = true, they = true }
local function HasContrast(leads, hasBut)
	if hasBut then return true end
	local seen, distinct = {}, 0
	for _, lead in ipairs(leads) do
		-- a thing as the other subject ("I got a sword and it is strong") is not a contrast
		if lead and PERSON_LEADS[lead] and not seen[lead] then
			seen[lead] = true
			distinct = distinct + 1
		end
	end
	return distinct >= 2
end

local function TranslateSegment(items, stats, questionMark, keepSubject, isLast)
	local clauses = SplitClauses(items)
	local leads, hasBut = {}, false
	for _, clause in ipairs(clauses) do
		local conj = clause.conj and CONJUNCTIONS[clause.conj]
		if clause.conj == "but" then hasBut = true end
		if #clause.items > 0 and not (conj and conj.kind == "sub") then
			leads[#leads + 1] = LeadSubject(clause.items)
		end
	end
	local contrast = HasContrast(leads, hasBut)

	-- The structural reader answers first, when it understood every word of the segment and
	-- no clause is one the PvP readers (Semantic.lua) know by heart.
	if T.Syntax and T.Syntax.enabled and T.Syntax.Translate then
		local semantic = false
		if T.Semantic then
			-- fixed expressions around the clause ("hi", "pls") do not stop Semantic reading it
			local bare = {}
			for _, item in ipairs(items) do
				if not (item.kind == "word" and (item.w == "please" or (item.entry and item.entry.pos == "x"))) then bare[#bare + 1] = item end
			end
			for _, clause in ipairs(SplitClauses(bare)) do
				if #clause.items > 0 and T.Semantic.Analyze(clause.items, {}) then semantic = true break end
			end
		end
		if not semantic then
			local text, question = T.Syntax.Translate(items, stats, questionMark, keepSubject or contrast, isLast)
			if text then return text, question end
		end
	end
	local mainLead
	for _, lead in ipairs(leads) do
		if lead then mainLead = lead break end
	end
	local subordinate, main = {}, {}
	local mainQuestion = false

	for _, clause in ipairs(clauses) do
		if #clause.items > 0 then
			local conj = clause.conj and CONJUNCTIONS[clause.conj]
			local parser = NewClause(clause.items)
			local text
			-- "when I was a kid, I played": the same speaker twice says it once. The person spoken to
			-- is understood under an imperative ("if you need help, let me know").
			local lead = conj and conj.kind == "sub" and LeadSubject(clause.items)
			local sameSubject = lead and (lead == mainLead or (lead == "you" and mainLead == nil)) and not contrast
			local options = conj and conj.kind == "sub" and { form = conj.form, subordinate = true, invertNegation = conj.invertNegation,
				sameSubject = sameSubject or nil }
				or { questionMark = questionMark, keepSubject = keepSubject or contrast }
			local plan = T.Semantic and T.Semantic.Analyze(clause.items, options)
			if plan then
				text, parser.question = T.Semantic.Render(plan, options)
				for _, item in ipairs(clause.items) do parser:Count(item) end
				stats.structured = (stats.structured or 0) + 1
			end
			if conj and conj.kind == "sub" then
				text = text or parser:Translate({ form = conj.form, subordinate = true, invertNegation = conj.invertNegation,
						sameSubject = options.sameSubject })
				if text ~= "" then
					subordinate[#subordinate + 1] = (conj.before or "") .. text .. conj.after
				end
			else
				text = text or parser:Translate({ questionMark = questionMark, keepSubject = keepSubject or contrast })
				if text ~= "" then
					local joined = text
					if conj and #main > 0 then
						main[#main] = main[#main] .. conj.join
					elseif conj and conj.join and #main == 0 and clause.conj ~= "and" then
						-- "but I can't" at the start of a line
						local lead = conj.join:gsub("^、", ""):gsub("、$", "")
						if lead ~= "" and lead ~= "が" and lead ~= "ので" then
							joined = lead .. "、" .. text
						end
					end
					main[#main + 1] = joined
				end
				mainQuestion = mainQuestion or parser.question
			end
			stats.known = stats.known + parser.known
			stats.unknown = stats.unknown + parser.unknown
		end
	end

	-- A subordinate clause with no main clause after it ("if you want.") still needs its
	-- trailing comma gone.
	local text = table.concat(subordinate) .. table.concat(main)
	text = text:gsub("、$", "")
	return text, mainQuestion
end

local END_MARK = { ["."] = "。", ["!"] = "！", ["?"] = "？" }

-- Translate a whole chat line. Returns the Japanese text and { known, unknown }.
function T.Translate(text)
	T.ReclaimTemporaryMemory()
	local stats = { known = 0, unknown = 0 }
	if type(text) ~= "string" then return "", stats end
	-- Chat input and analysis are bounded; never truncate names or link markup.
	if #text > 4096 then return text, {known = 0, unknown = 1, limited = "bytes"} end
	local tokens = T.Tokenize(text)
	if #tokens > 256 then return text, {known = 0, unknown = 1, limited = "tokens"} end
	local items = T.Tag(tokens)

	-- Mark the first word of every sentence: capitalisation there says nothing about names.
	local atStart = true
	for _, item in ipairs(items) do
		if item.kind == "word" then
			if atStart then
				item.sentenceStart = true
			end
			atStart = false
		elseif item.kind == "punct" and END_MARK[item.v] then
			atStart = true
		end
	end

	local sentences = {}
	local segment, segments = {}, {}
	local function FinishSegment()
		if #segment > 0 then
			segments[#segments + 1] = segment
		end
		segment = {}
	end
	local function FinishSentence(mark)
		FinishSegment()
		if #segments > 0 then
			local parts = {}
			local question = false
			local leads, hasBut = {}, false
			for _, run in ipairs(segments) do
				leads[#leads + 1] = LeadSubject(run)
				if run[1] and run[1].kind == "word" and run[1].w == "but" and not run[1].phrase then hasBut = true end
			end
			local contrast = #segments > 1 and HasContrast(leads, hasBut)
			for index, run in ipairs(segments) do
				local ja, isQuestion = TranslateSegment(run, stats, mark == "?", contrast, index == #segments)
				if ja ~= "" then
					parts[#parts + 1] = ja
				end
				question = question or isQuestion
			end
			local ja = table.concat(parts, "、")
			if ja ~= "" then
				local ending = mark and END_MARK[mark] or ""
				-- an expression that already ends in the mark ("ram on!" -> 破城槌に乗って！)
				if ending ~= "" and ja:sub(-#ending) == ending then
					ending = ""
				end
				if mark == "." and question then
					ending = "？"
				end
				-- "anyone know where it is?" -- asked without the auxiliary
				if mark == "?" and not question and ja:sub(-3) == "す" then
					ja = ja .. "か"
				end
				sentences[#sentences + 1] = ja .. ending
			end
		end
		segments = {}
	end

	for _, item in ipairs(items) do
		if item.kind == "punct" then
			if END_MARK[item.v] then
				FinishSentence(item.v)
			else
				FinishSegment()
			end
		else
			-- "bb gone fare gone bm lit": a status word followed by another word ends a clause,
			-- the way a comma would -- zone chat is typed without them.
			local last = segment[#segment]
			if last and last.kind == "word" and STATUS_WORDS[last.w] and item.kind == "word"
				and not (item.entry and (item.entry.pos == "prep" or item.entry.pos == "det" or item.entry.pos == "pn"))
				and not ARTICLES[item.w] and not DEMONSTRATIVE_DET[item.w] and not CONJUNCTIONS[item.w] then
				FinishSegment()
			end
			segment[#segment + 1] = item
		end
	end
	FinishSentence(nil)

	local out = ""
	for index, sentence in ipairs(sentences) do
		local last = out:sub(-3)
		if index > 1 and last ~= "。" and last ~= "！" and last ~= "？" then
			out = out .. "。"
		end
		out = out .. sentence
	end
	T.ReclaimTemporaryMemory()
	return out, stats
end
