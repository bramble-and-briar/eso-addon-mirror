-- PB's Translate -- Japanese from a Syntax.lua tree
--
-- The parser says what the sentence is made of; this says how Japanese puts it. A clause comes
-- out as
--
--   [time] [topic]は [place] [other phrases] [object]を [manner adverb] [predicate]
--
-- with the predicate built by Conjugate.lua, so both directions of the add-on and both engines
-- agree on how a verb ends. What is left out matters as much as what is said: Japanese does not
-- name "I" or "you" unless it has to, so neither does this (the first-person and second-person
-- subject comes back only for a contrast, an emphasis, or a relative clause).
--
-- Every function that cannot say something returns nil, and the caller gives the whole segment
-- back to the old engine. A construction this file does not know is never guessed at.

PBsTranslate = PBsTranslate or {}
local T = PBsTranslate
local S = T.Syntax
if not S then return end
local L = S.L

local G = {}
S.G = G

-- Verbs whose place is a に: stand in the fire, live in a village, put it on the door.
-- "is on vacation", "is in progress": a state said with a preposition.
L.STATE_PP = {
	["on vacation"] = "休暇中", ["on holiday"] = "休暇中", ["on leave"] = "休暇中", ["on break"] = "休憩中", ["on sale"] = "セール中",
	["on fire"] = "炎上中", ["in progress"] = "進行中", ["in trouble"] = "困っている", ["in danger"] = "危険な状態",
	["on cooldown"] = "クールタイム中", ["in combat"] = "戦闘中", ["on duty"] = "勤務中", ["at work"] = "仕事中",
	["in a hurry"] = "急いでいる", ["on time"] = "時間通り", ["in love"] = "恋している", ["at home"] = "自宅",
}
-- "for a good price", "for 200 gold": what something costs.
L.PRICE_NOUN = { price = true, gold = true, money = true, cost = true, fee = true, amount = true, bargain = true, deal = true }
L.LOCATIVE = { stand = true, sit = true, stay = true, live = true, lie = true, remain = true, exist = true, dwell = true }
L.PLACING = { put = true, drop = true, place = true, set = true, stack = true, port = true, ["drop siege"] = true,
	["set up siege"] = true, ["put down"] = true, move = true, bring = true, take = true, send = true, hang = true }
-- Adverbs that go after the subject, before the objects: もう, まだ, いつも, 本当に.
L.FRONT_ADV = {
	already = true, still = true, yet = true, always = true, usually = true, often = true, sometimes = true,
	just = true, ever = true, finally = true, almost = true, soon = true, probably = true, maybe = true,
	actually = true, definitely = true, totally = true, completely = true, simply = true, certainly = true,
	obviously = true, basically = true, seriously = true, honestly = true, apparently = true, eventually = true,
	immediately = true, really = true, again = true, even = true, all = true, both = true,
}

local function Join(parts, separator)
	return T.Join(parts, separator)
end

local function Fail(reason)
	error({ syntaxGenFail = reason or "unsupported" }, 0)
end
G.Fail = Fail

local function Animate(np)
	if not np then return false end
	if np.animate then return true end
	if np.head and T.IsAnimateEntry and T.IsAnimateEntry(np.head) then return true end
	if np.unknown or np.name then return true end
	return false
end
G.Animate = Animate

-- ---------------------------------------------------------------------------------------
-- Verb forms
-- ---------------------------------------------------------------------------------------

-- The form table Conjugate.lua's T.Predicate reads, from what the verb group said.
function G.Form(cl, o)
	local vg = cl.vg
	local form = {}
	local modal = vg.modal
	if vg.past then form.past = true end
	if vg.neg then form.negative = true end
	local mode
	if modal == "can" or modal == "could" then mode = "can"
	elseif modal == "should" then mode = "should"
	elseif modal == "must" then mode = "must"
	elseif modal == "may" or modal == "might" then mode = "maybe"
	end
	if vg.haveto then mode = "have_to" end
	if vg.goingto then mode = "intend" end
	if vg.ableto then mode = "can" end
	if vg.perfect then
		form.past = true
		if mode == "can" and not modal then
			-- "I haven't been able to heal": can't, not couldn't
			form.past = vg.haveWord == "had" or nil
		elseif modal == "could" then mode = "could_perfect"
		elseif modal == "must" then mode = "deduction"
		elseif modal == "would" then mode = "counterfactual"
		elseif modal == "should" then mode = "should"
		elseif modal == "may" or modal == "might" then mode = "maybe"
		elseif not modal then
			local ever = vg.never
			for _, adv in ipairs(vg.advs or {}) do
				if adv.w == "ever" or adv.w == "never" then ever = true end
			end
			if ever then
				mode = "experience"
			elseif vg.neg and not vg.prog and not vg.passive and mode == nil then
				-- "I have not seen it yet": 見ていません
				mode = "progressive"
				form.past = nil
			elseif vg.prog then
				-- "I have been waiting": 待っています
				form.past = vg.past and vg.haveWord == "had" or nil
			end
		end
	end
	if vg.prog and vg.passive then
		mode = mode or "passive"
		form.passiveProgressive = true
	elseif vg.prog then
		if mode and mode ~= "progressive" then form.aspect = "progressive" else mode = mode or "progressive" end
	elseif vg.passive then
		if mode and mode ~= "passive" then form.aspect = "passive" else mode = mode or "passive" end
	end
	form.mode = mode
	return form
end

-- The Japanese predicate for a verb entry in a form, polite or plain.
local function Predicate(entry, form, style)
	local f = {}
	for k, v in pairs(form) do f[k] = v end
	if style == "plain" or style == "attr" or style == "quote" or style == "rel" then
		f.plain = true
	elseif style == "cond" then
		f.conditional = true
	end
	return T.Predicate(entry, f)
end
G.Predicate = Predicate

-- 食べて / 強くて / 静かで: the form that joins a clause to the next ("and").
function G.TePredicate(entry, form)
	local mode = form.mode
	if mode and mode ~= "progressive" and mode ~= "passive" then return nil end
	local word, class = entry.ja, entry.class
	local negative = form.negative
	if class == "i" then
		local stem = (word == "いい" and "よい" or word):sub(1, -4)
		return stem .. (negative and "くなくて" or "くて")
	elseif class == "na" or class == nil or class == "rel" then
		return nil
	end
	if mode == "progressive" then
		local te = T.TeForm(word, class)
		if negative then return te .. "いなくて" end
		return te .. "いて"
	elseif mode == "passive" then
		local stem = T.PassiveStem(word, class)
		if negative then return stem .. "なくて" end
		return stem .. "て"
	end
	if negative then return T.NaiStem(word, class) .. "なくて" end
	return T.TeForm(word, class)
end

-- A verb stem for 食べさせて / 行かせて: the causative, used by "let me ...".
function G.CausativeStem(word, class)
	if class == "1" then return word:sub(1, -4) .. "させ" end
	if class == "s" then
		local base = word:sub(-6) == "する" and word:sub(1, -7) or word
		return base .. "させ"
	end
	if class == "k" then return T.KuruStem(word, "こ") .. "させ" end
	local head, last = word:sub(1, -4), word:sub(-3)
	local row = T.GODAN and T.GODAN[last]
	if row then
		if last == "う" then return head .. "わせ" end
		return head .. row[2] .. "せ"
	end
	return nil
end

-- ---------------------------------------------------------------------------------------
-- Noun phrases and prepositional phrases
-- ---------------------------------------------------------------------------------------

local function DigitsOnly(text) return text:match("^[0-9]+$") ~= nil end

-- The words of a noun phrase. role is "subject" when a gerund has to become "...のは".
-- Words: the relative clause, infinitive or participle in front of the noun it describes.
function G.RelText(np)
	local rel = np.rel
	if rel.kind == "pp" then
		local text = G.NPText(rel.pp.np, "pp", {})
		local w = rel.pp.prep
		if rel.general then
			if w == "to" then return text .. "への" end
			if w == "from" then return text .. "からの" end
			if w == "for" then return text .. (np.animate and "のための" or "用の") end
			if w == "in" or w == "at" or w == "on" then return text .. "の" end
			return text .. "の"
		end
		if w == "with" then return text .. "の" end
		return text .. "についての"
	end
	if rel.kind == "inf" then
		return G.InfText(rel.inf, { style = "rel", subordinate = true, noSubject = true })
	elseif rel.kind == "subj" then
		local cl = { cat = "CL", kind = "decl", vg = rel.vg, comps = rel.comps, implied = "i" }
		return G.Clause(cl, { style = "rel", relative = true, subordinate = true, noSubject = true })
	elseif rel.kind == "obj" then
		-- "the best run we ever had": 今までで一番いい周回
		if np.superlative then
			for _, adv in ipairs(rel.vg.advs or {}) do
				if adv.w == "ever" then return "今までで" end
			end
		end
		local cl = { cat = "CL", kind = "decl", subj = rel.subj, vg = rel.vg, comps = rel.comps }
		return G.Clause(cl, { style = "rel", relative = true, subordinate = true })
	end
	return G.Clause(rel.clause, { style = "rel", relative = true, subordinate = true })
end

function G.NPText(np, role, o)
	if np.tooMany then Fail("too many") end
	if np.gerund then
		local inner = G.ClauseText(np.gerund, { style = "plain", subordinate = true, noSubject = true })
		return inner .. (role == "subject" and "の" or "こと")
	end
	if np.list and np.first and np.second then
		return G.NPText(np.first, role, o) .. np.joiner .. G.NPText(np.second, role, o)
	end
	local ja = np.ja or ""
	if o and o.dropPoss and o.possJa and np.possJa == o.possJa and ja:sub(1, #o.possJa) == o.possJa and #ja > #o.possJa then
		ja = ja:sub(#o.possJa + 1)
	end
	if np.rel then
		local pre = G.RelText(np)
		if np.rel.kind == "inf" and np.pron and L.INF_PRON[np.pron] then
			return pre .. L.INF_PRON[np.pron]
		end
		-- "a way to change": 変える方法, not 変える道
		if np.rel.kind == "inf" and not np.head_ja_is_changed then
			local w = np.w
			if w == "way" then return pre .. "方法" end
			if w == "chance" then return pre .. "機会" end
			if w == "reason" then return pre .. "理由" end
		end
		if pre == "今までで" then return pre .. ja end
		ja = pre .. ja
	end
	return ja
end

-- Is this noun phrase a time? (flagged in the dictionary, or a day or a month by its name)
function G.IsTime(np)
	if np.time then return true end
	local ja = np.ja or ""
	return ja:match("曜日$") ~= nil or ja:match("^[0-9]+月$") ~= nil
end

local TIME_ADV_STARTS = { "今", "昨", "明", "来", "先", "去", "毎", "最近", "さっき", "後で", "もうすぐ", "すぐ", "以前", "そのうち", "late", "ついさっき" }
function G.IsTimeAdv(adv)
	if L.TIME_ADV[adv.w or ""] or (adv.entry and adv.entry.time) then return true end
	local ja = adv.ja or ""
	for _, start in ipairs(TIME_ADV_STARTS) do
		if ja:sub(1, #start) == start then return true end
	end
	return false
end

-- A prepositional phrase: its Japanese with the particle that suits the verb it hangs on.
-- Returns the text and a category (time / place / other) that decides where it goes.
function G.PPText(pp, ctx)
	local np = pp.np
	local w = pp.prep
	local e = pp.entry or {}
	local ja = ctx.NPT and ctx.NPT(np, "pp") or G.NPText(np, "pp", ctx)
	local particle = e.ja or "に"

	if w == "than" then return ja .. "より", "other" end
	if w == "in" or w == "at" or w == "on" then
		if G.IsTime(np) or (w == "at" and DigitsOnly(ja)) then
			if w == "in" and np.count and np.time then return ja .. "後に", "time" end
			if w == "at" and DigitsOnly(ja) then return ja .. "時に", "time" end
			return ja .. "に", "time"
		end
		local goes = ctx.existence or ctx.motion or ctx.placing or ctx.verbParticle == "に"
		return ja .. (goes and "に" or "で"), "place"
	end
	if G.IsTime(np) and np.count and (w == "for" or w == "over") then
		return ja .. (ja:sub(-3) == "間" and "" or "間"), "time"
	end
	if G.IsTime(np) and np.plural and not np.count and w == "for" then
		local many = ({ ["時間"] = "何時間も", ["日"] = "何日も", ["週"] = "何週間も", ["月"] = "何か月も", ["年"] = "何年も",
			["分"] = "何分も", ["秒"] = "何秒も" })[np.headJa or ""]
		if many then return many, "time" end
	end
	if w == "for" and np.unit and np.count then return ja .. "で", "other" end
	if w == "for" and L.PRICE_NOUN[np.w or ""] then return ja .. "で", "other" end
	if w == "until" or w == "till" then return ja .. "まで", "time" end
	if w == "for" and ctx.adjective and (np.pron or Animate(np)) and not np.time then return ja .. "には", "other" end
	if w == "by" and np.time then return ja .. "までに", "time" end
	if w == "by" then return ja .. (ctx.passive and "に" or "で"), "other" end
	if w == "to" or w == "into" or w == "onto" or w == "towards" or w == "toward" then
		if w == "to" then return ja .. "に", "place" end
		return ja .. particle, "place"
	end
	if w == "from" then return ja .. "から", "place" end
	if w == "with" then
		if Animate(np) then return ja .. "と", "other" end
		return ja .. "で", "other"
	end
	if w == "without" then return ja .. "なしで", "other" end
	if w == "about" then return ja .. "について", "other" end
	if w == "like" then return ja .. "のように", "other" end
	if w == "as" then return ja .. "として", "other" end
	if w == "of" then return ja .. "の", "other" end
	-- positional words: near, behind, under, in front of ... say "で" for an action and "に" for a place
	if (particle:sub(-3) == "で" and #particle > 3) and (ctx.existence or ctx.motion) then
		particle = particle:sub(1, -4) .. "に"
	end
	local category = L.PLACE_PREP[w] and "place" or "other"
	return ja .. particle, category
end

-- ---------------------------------------------------------------------------------------
-- Classifying what follows the verb
-- ---------------------------------------------------------------------------------------

function G.Classify(cl)
	local vg = cl.vg
	local copular = vg and vg.be and not vg.verb
	local c = { objs = {}, times = {}, pps = {}, advs = {}, timeAdvs = {}, placeAdvs = {} }
	for _, comp in ipairs(cl.comps or {}) do
		local k, n = comp.kind, comp.node
		if k == "np" then
			if copular and not c.compNP and not n.place and not c.adj and not (G.IsTime(n) and n.ago) and not n.freq then
				c.compNP = n
			elseif G.IsTime(n) then
				c.times[#c.times + 1] = n
			else
				c.objs[#c.objs + 1] = n
			end
		elseif k == "pp" then
			if n.stranded then
				if not (cl.wh and cl.wh.np) then Fail("stranded preposition") end
				n = { cat = "PP", prep = n.prep, entry = n.entry, np = cl.wh.np, w = n.w }
				c.stranded = true
			end
			if n.prep == "than" then c.than = n.np else c.pps[#c.pps + 1] = n end
		elseif k == "adv" then
			if G.IsTimeAdv(n) then
				c.timeAdvs[#c.timeAdvs + 1] = n
			elseif n.entry and n.entry.place then
				c.placeAdvs[#c.placeAdvs + 1] = n
			else
				c.advs[#c.advs + 1] = n
			end
		elseif k == "adj" then c.adj = n
		elseif k == "than" then c.than = n
		elseif k == "inf" then
			if c.inf then Fail("two infinitives") end
			c.inf = n
		elseif k == "bare" then c.bare = n
		elseif k == "ger" then c.ger = n
		elseif k == "that" then c.that = n
		elseif k == "wh" then c.wh = n
		end
	end
	return c
end

-- ---------------------------------------------------------------------------------------
-- Subjects: left out, or marked
-- ---------------------------------------------------------------------------------------

local EMPHASIS = { only = true, too = true, also = true, alone = true, myself = true, yourself = true }

-- The first, second, and plural speaker are left out of Japanese. Returns true to leave out.
function G.DropSubject(cl, o, copular)
	local subj = cl.subj
	if not subj then return true end
	if o.noSubject then return true end
	local pron = subj.pron
	if not pron then return false end
	if T.userLexicon and T.userLexicon[pron] then return false end
	if o.keepSubject or o.relative then return false end
	if subj.ja ~= "私" and subj.ja ~= "あなた" and subj.ja ~= "私たち" then return false end
	for _, adv in ipairs((cl.vg and cl.vg.advs) or {}) do
		if EMPHASIS[adv.w or ""] then return false end
	end
	for _, comp in ipairs(cl.comps or {}) do
		if comp.kind == "adv" and EMPHASIS[comp.node.w or ""] then return false end
	end
	if pron == "i" then
		if o.subordinate and not o.sameSubject then return false end
		return true
	elseif pron == "you" then
		if cl.copularWh then return false end
		if o.subordinate and not o.sameSubject then return false end
		return true
	elseif pron == "we" then
		if copular then return false end
		if o.subordinate and not o.sameSubject then return false end
		return true
	end
	return false
end

-- Whether an eventive predicate (something happens) or a stative one (something is).
local function Eventive(cl, c)
	local vg = cl.vg
	if not vg or (vg.be and not vg.verb) then return false end
	if vg.modal or vg.haveto or vg.ableto then return false end
	local entry = vg.verb and vg.verb.entry
	if entry and (entry.class == "i" or entry.class == "na" or (entry.ja or ""):sub(-9) == "ている") then return false end
	return true
end

function G.SubjectParticle(cl, o, c)
	local subj = cl.subj
	if subj.wh or subj.whDet then return "が" end
	local needy = cl.vg and cl.vg.verb and (cl.vg.verb.base or cl.vg.verb.w) == "need"
	if needy and (o.subordinate or o.relative) and not T.userLexicon.need and not subj.neg and not subj.wh
		and not (subj.pron and L.INDEF_PRON[subj.pron]) then
		return "に"
	end
	if subj.neg and subj.pron then return "" end
	if o.subordinate or o.relative then return "が" end
	if subj.pron == "everyone" or subj.pron == "everybody" or subj.pron == "everything" then return "は" end
	if subj.pron and L.INDEF_PRON[subj.pron] then return "が" end
	if subj.neither then return "" end
	local verb = cl.vg and cl.vg.verb
	if verb and (verb.base or verb.w) == "need" and (o.subordinate or o.relative) and not T.userLexicon.need and not subj.pron then
		return "に"
	end
	if verb and (verb.base or verb.w) == "need" and (o.subordinate or o.relative) and not T.userLexicon.need and subj.pron
		and not L.INDEF_PRON[subj.pron] then
		return "に"
	end
	if (subj.indef or (subj.bare and subj.plural)) and not subj.pron and Eventive(cl, c) then return "が" end
	return "は"
end

-- ---------------------------------------------------------------------------------------
-- Verb frames
-- ---------------------------------------------------------------------------------------

-- "want to go" is 行きたい, "need to go" 行く必要がある: the verb that wants merges into the one
-- that is wanted, as a mode of its predicate.
L.CHAIN_MODE = { want = "want", wish = "want", hope = "want", need = "need", try = "try", like = "likes",
	love = "likes", prefer = "likes", plan = "intend", intend = "intend" }

-- Verbs of saying and thinking: the particle the clause takes, and the verb in Japanese.
L.THAT_FRAMES = {
	think = { "と", "思う", "5" }, guess = { "と", "思う", "5" }, suppose = { "と", "思う", "5" }, believe = { "と", "信じる", "1" },
	say = { "と", "言う", "5" }, hope = { "ことを", "願う", "5" }, feel = { "と", "感じる", "1" }, bet = { "と", "思う", "5" },
	hear = { "と", "聞く", "5" }, heard = { "と", "聞く", "5" }, know = { "ことを", "知っている", "1" },
	understand = { "ことを", "理解する", "s" }, realize = { "ことに", "気づく", "5" }, realise = { "ことに", "気づく", "5" },
	notice = { "ことに", "気づく", "5" }, remember = { "ことを", "覚えている", "1" }, forget = { "ことを", "忘れる", "1" },
	mean = { "という", "意味だ", "na" }, mention = { "と", "言う", "5" }, explain = { "と", "説明する", "s" },
	agree = { "ことに", "同意する", "s" }, promise = { "と", "約束する", "s" }, warn = { "と", "警告する", "s" },
	discover = { "ことを", "発見する", "s" }, learn = { "ことを", "知る", "5" }, expect = { "と", "思う", "5" },
	assume = { "と", "思う", "5" }, imagine = { "と", "想像する", "s" }, doubt = { "と", "疑う", "5" },
	suggest = { "と", "提案する", "s" }, insist = { "と", "主張する", "s" }, claim = { "と", "主張する", "s" },
	admit = { "と", "認める", "1" }, tell = { "と", "言う", "5" }, show = { "ことを", "示す", "5" },
	find = { "ことを", "知る", "5" }, see = { "ことを", "知る", "5" }, check = { "ことを", "確認する", "s" },
	decide = { "ことを", "決める", "1" }, worry = { "ことを", "心配する", "s" },
}
-- "know where ...": the question verb.
L.WH_FRAMES = {
	know = { "知っている", "1" }, wonder = { "気になる", "5" }, ask = { "聞く", "5" }, tell = { "教える", "1" },
	show = { "教える", "1" }, see = { "確認する", "s" }, check = { "確認する", "s" }, understand = { "理解する", "s" },
	remember = { "覚えている", "1" }, forget = { "忘れる", "1" }, decide = { "決める", "1" }, explain = { "説明する", "s" },
	find = { "探す", "5" }, learn = { "学ぶ", "5" }, realize = { "気づく", "5" }, realise = { "気づく", "5" },
	think = { "考える", "1" }, guess = { "推測する", "s" }, imagine = { "想像する", "s" }, worry = { "心配する", "s" },
	hear = { "聞く", "5" }, say = { "言う", "5" }, mean = { "意味する", "s" },
}
-- Verbs with "to + verb" that are not a mode: the suffix that makes the Japanese verb.
L.INF_FRAMES = {
	decide = { "ことにする", "s" }, start = { "始める", "1", stem = true }, begin = { "始める", "1", stem = true },
	continue = { "続ける", "1", stem = true }, forget = { "のを忘れる", "1" }, remember = { "のを覚えている", "1" },
	manage = { "ことができる", "1", past = true }, refuse = { "のを断る", "5" }, learn = { "ことを学ぶ", "5" },
	offer = { "と申し出る", "1" }, agree = { "ことに同意する", "s" }, promise = { "と約束する", "s" },
	afford = { "余裕がある", "5" }, choose = { "ことにする", "s" },
}
-- Verbs with an -ing form.
L.GER_FRAMES = {
	stop = { "のをやめる", "1" }, keep = { "続ける", "1", stem = true }, enjoy = { "のを楽しむ", "5" },
	finish = { "終える", "1", stem = true }, start = { "始める", "1", stem = true }, begin = { "始める", "1", stem = true },
	continue = { "続ける", "1", stem = true }, avoid = { "のを避ける", "1" }, quit = { "のをやめる", "1" },
	recommend = { "ことをお勧めする", "s" }, practice = { "練習をする", "s" }, consider = { "ことを考える", "1" }, suggest = { "ことを提案する", "s" },
	mind = { "のを気にする", "s" }, miss = { "ことを惜しむ", "5" }, imagine = { "ことを想像する", "s" },
	like = { "のが好き", "na" }, love = { "のが大好き", "na" }, hate = { "のが嫌い", "na" },
	remember = { "のを覚えている", "1" }, forget = { "のを忘れる", "1" }, try = { "ことを試す", "5" },
}

-- Adjective + infinitive: how Japanese says "easy to use", "happy to help", "ready to go".
L.ADJ_INF = {
	easy = "nominal", hard = "nominal", difficult = "nominal", good = "nominal", important = "nominal", safe = "nominal",
	fun = "nominal", nice = "nominal", better = "nominal", best = "nominal", necessary = "nominal", impossible = "nominal",
	possible = "nominal", bad = "nominal", dangerous = "nominal", ["worth"] = "nominal",
	happy = "te", glad = "te", pleased = "te", excited = "te", sad = "te", sorry = "te", surprised = "te", relieved = "te",
	proud = "te", delighted = "te", thrilled = "te",
	ready = "ready", prepared = "ready",
}

-- The entry for a verb, with the readings that need a different Japanese word in context.
function G.VerbEntry(cl, c, form)
	local vg = cl.vg
	local verb = vg.verb
	if not verb then return nil end
	local entry = verb.entry
	local base = verb.base or verb.w
	if T.userLexicon and T.userLexicon[base] then return entry end
	-- leaving a person behind, not walking out of a place
	if base == "leave" and #c.objs == 1 and c.objs[1].pron and ({ me = true, us = true, you = true, him = true, her = true, them = true })[c.objs[1].pron]
		and not T.userLexicon.leave then
		return { ja = "置き去りにする", class = "s", particle = "を" }
	end
	-- having a person is having them available: ヒーラーがいる; not having enough: 足りない
	if base == "have" and #c.objs == 1 and not T.userLexicon.have then
		local obj = c.objs[1]
		local roles = { ["ヒーラー"] = true, ["タンク"] = true, ["DPS"] = true, ["DD"] = true, ["プレイヤー"] = true, ["メンバー"] = true,
			["仲間"] = true, ["友達"] = true }
		if obj.enough and form.negative then
			return { ja = "足りる", class = "1", particle = "が", insufficient = true }
		elseif obj.head and roles[obj.head.ja] then
			return { ja = "いる", class = "1", particle = "が", haveAnimate = true }
		end
	end
	-- "get there" is 着く, "get ready" a state, "get the sword" 手に入れる
	if base == "get" and (c.placeAdvs[1] or (c.pps[1] and (c.pps[1].prep == "to" or c.pps[1].prep == "from" or c.pps[1].prep == "into"))) and #c.objs == 0 then
		return { ja = "着く", class = "5", particle = "に" }
	end
	if base == "get" and #c.objs >= 1 and not vg.passive then
		return { ja = "手に入れる", class = "1", particle = "を" }
	end
	-- "the event starts": 始まる, not 始める
	local subj = cl.subj
	if #c.objs == 0 and not c.that and not c.wh and not vg.passive and subj and not subj.animate and not subj.pron
		and T.INTRANSITIVE and T.INTRANSITIVE[entry.ja] and not cl.actor then
		return T.INTRANSITIVE[entry.ja]
	end
	return entry
end

-- "is down": a place adverb that says how a thing is
L.STATE_ADV = { down = { ja = "ダウンしている", class = "1" } }

-- Linking verbs other than be: "look good", "get cold", "stay safe".
local function LinkPredicate(base, adj, form, style)
	local entry = adj.entry
	local class = entry.class
	if class == "state" or adj.fromVerb and entry.stateVerb then return nil end
	local word = entry.ja
	local stem = class == "i" and ((word == "いい" and "よ" or word:sub(1, -4))) or word
	if base == "look" or base == "seem" or base == "sound" or base == "appear" then
		-- 強そう, 静かそう, よさそう
		local text
		if class == "i" then
			text = (word == "いい" and "よさ" or stem) .. "そう"
		elseif class == "na" then
			text = word .. "そう"
		else
			return nil
		end
		return T.Copula(text, "na", form)
	elseif base == "get" or base == "become" or base == "grow" or base == "turn" then
		local target = class == "i" and (stem .. "く") or (class == "na" and (word .. "に") or nil)
		if not target then return nil end
		return Predicate({ ja = target .. "なる", class = "5" }, form, style)
	elseif base == "stay" or base == "remain" or base == "keep" then
		if class == "i" then
			return Predicate({ ja = stem .. "くいる", class = "1" }, form, style)
		end
		return Predicate({ ja = word .. "でいる", class = "1" }, form, style)
	elseif base == "feel" then
		if class == "i" then return T.Copula(word, "i", form) end
		return T.Copula(word, "na", form)
	end
	return nil
end
G.LinkPredicate = LinkPredicate

-- ---------------------------------------------------------------------------------------
-- Predicates in a style: polite (final), quote (plain, sentence-final), attr (plain, before a
-- noun), cond (if), te (joins to the next clause)
-- ---------------------------------------------------------------------------------------

local function CopyForm(form)
	local f = {}
	for k, v in pairs(form) do f[k] = v end
	return f
end

-- The たら form of a plain predicate: 待ちたくない -> 待ちたくなかったら, 行ける -> 行けたら.
function G.CondFromPlain(plain)
	local function Swap(suffix, with)
		if plain:sub(-#suffix) == suffix then return plain:sub(1, -#suffix - 1) .. with end
	end
	return Swap("ない", "なかったら") or Swap("たい", "たかったら") or Swap("いる", "いたら") or Swap("ある", "あったら")
		or Swap("できる", "できたら") or Swap("れる", "れたら") or Swap("だ", "だったら") or Swap("い", "かったら")
		or Swap("る", "たら") or (plain .. "なら")
end

function G.Pred(entry, form, style)
	-- ready is 準備ができている as a statement and 準備できる inside another clause
	if entry.ja == "準備ができている" and style ~= "polite" and style ~= "te" and not T.userLexicon.ready then
		entry = { ja = "準備できる", class = "1" }
	end
	if style == "te" then
		local te = G.TePredicate(entry, form)
		if te then return te end
		return Predicate(entry, form, "polite")
	end
	if style == "cond" and form.mode and form.mode ~= "can" and entry.class ~= "i" and entry.class ~= "na" and entry.class ~= "rel" then
		return G.CondFromPlain(Predicate(entry, form, "plain"))
	end
	return Predicate(entry, form, style)
end

function G.Cop(word, kind, form, style)
	local f = CopyForm(form)
	if style == "quote" then
		-- sentence-final plain: 強い, 静かだ, ヒーラーだ; the rest is the plain predicate
		if not f.mode and not f.past and not f.negative then
			if kind == "i" then return word end
			if kind == "n" or kind == "na" then return word .. "だ" end
		end
		f.plain = true
		return T.Copula(word, kind, f)
	end
	if style == "rel" then
		-- before a noun: ヒーラーである人, 強い剣
		if not f.mode and not f.past and not f.negative and kind == "n" then return word .. "である" end
		f.plain = true
		return T.Copula(word, kind, f)
	end
	if style == "te" then
		if f.mode then return T.Copula(word, kind, f) end
		if kind == "i" then
			local stem = (word == "いい" and "よい" or word):sub(1, -4)
			return stem .. (f.negative and "くなくて" or "くて")
		end
		return word .. (f.negative and "ではなくて" or "で")
	end
	if style == "plain" or style == "attr" then f.plain = true elseif style == "cond" then f.conditional = true end
	return T.Copula(word, kind, f)
end

-- The Japanese for adverbs standing before the verb.
local function AdverbText(adv, cl, form)
	local ja = adv.ja
	local w = adv.w
	if w == "just" then
		if cl.kind == "imp" then return "ちょっと" end
		if form.past and not form.mode and not (cl.vg and cl.vg.perfect) then return "さっき" end
		return "ちょうど"
	end
	if w == "ever" or w == "never" then return "" end
	return ja
end

local EXISTS_ANIMATE = { ja = "いる", class = "1" }
local EXISTS_THING = { ja = "ある", class = "5" }

local function AddAll(list, items)
	for _, v in ipairs(items) do
		if v ~= "" then list[#list + 1] = v end
	end
end

-- ---------------------------------------------------------------------------------------
-- One clause
--
-- o.style     how the predicate ends
-- o.subordinate / o.relative / o.keepSubject / o.sameSubject / o.noSubject
-- Returns the text, and whether it asked a question.
-- ---------------------------------------------------------------------------------------

function G.Clause(cl, o)
	local saved = G.currentOwn
	local ok, text, asked = pcall(G.ClauseCore, cl, o)
	G.currentOwn = saved
	if not ok then error(text, 0) end
	return text, asked
end

function G.ClauseCore(cl, o)
	o = o or {}
	-- "want to go", "decide to wait", "tell him to stop": the verb merges into the one it governs
	if cl.vg and cl.vg.verb and not cl.merged then
		local merged = G.MergeChain(cl, o)
		if merged then return G.Clause(merged, o) end
	end
	local style = o.style or "polite"
	local vg = cl.vg
	local kind = cl.kind
	local c = G.Classify(cl)
	local copular = vg.be and not vg.verb
	local form = G.Form(cl, o)
	if cl.formOverride then
		for k, v in pairs(cl.formOverride) do form[k] = v end
	end
	if o.formOverride then
		for k, v in pairs(o.formOverride) do form[k] = v end
	end
	if o.invertNegation then form.negative = not form.negative end
	local base = vg.verb and (vg.verb.base or vg.verb.w) or (copular and "be") or nil
	local question = (kind == "ynq" or kind == "whq" or cl.ynq == true or o.question == true) and true or false
	local subj = cl.subj
	local entry
	local whyQuestion = cl.wh and cl.wh.word == "why" and style == "polite"
	local predStyle = whyQuestion and "quote" or style
	local ctx = {
		whyQuestion = whyQuestion or nil,
		cl = cl, o = o, c = c, form = form, existence = false,
		motion = L.MOTION[base or ""] or L.LOCATIVE[base or ""] or false,
		placing = L.PLACING[base or ""] or false,
		passive = vg.passive,
	}
	-- "I could heal yesterday": could is the past of can unless something says it is not
	if vg.modal == "could" and not vg.perfect and kind ~= "ynq" and not o.subordinate and not cl.formOverride then
		local future, pastCue = false, false
		local function Look(w)
			if w == "tomorrow" or w == "tonight" or w == "later" or w == "next" or w == "now" or w == "soon" then future = true end
			if w == "yesterday" or w == "ago" then pastCue = true end
		end
		for _, comp in ipairs(cl.comps or {}) do
			if comp.node then Look(comp.node.w) end
			if comp.node and comp.node.ago then pastCue = true end
		end
		for _, adv in ipairs(cl.frontAdv or {}) do Look(adv.w) end
		if not future and (form.negative or pastCue) then form.past = true end
	end
	-- "can I / may we": asking leave to
	local permission = kind == "ynq" and subj and (subj.pron == "i" or subj.pron == "we")
		and (vg.modal == "can" or vg.modal == "could" or vg.modal == "may") and not vg.perfect and not form.negative
		and not vg.be and cl.vg.verb and not cl.wh and not cl.actor
	if permission then ctx.permission = true; form.mode = nil end

	if kind == "imp" then
		form.mode = form.mode or "imperative"
	elseif kind == "lets" then
		form.mode = "lets"
	end

	-- "can you / could you / will you ...": a request
	local requestPrefix
	if kind == "ynq" and subj and (vg.modal == "can" or vg.modal == "could" or vg.modal == "will" or vg.modal == "would")
		and not vg.perfect and ({ you = true, someone = true, somebody = true, anyone = true, anybody = true })[subj.pron or ""] then
		form.mode = "request"
		form.past = nil
		if subj.pron ~= "you" then requestPrefix = subj.ja end
	end

	-- a negative subject ("nobody left") makes the verb negative
	if subj and subj.neg and not subj.wh then form.negative = true end
	for _, obj in ipairs(c.objs) do
		if obj.neg then form.negative = true end
	end

	local drop = G.DropSubject(cl, o, copular)
	if form.mode == "request" or kind == "imp" or kind == "lets" then drop = true end
	if cl.implied then drop = true end
	local ownPoss = ({ i = "私の", we = "私たちの", you = "あなたの" })[subj and subj.pron or ""]
	if kind == "imp" then ownPoss = "あなたの" end
	-- an infinitive or gerund with no subject of its own speaks for the clause it belongs to
	ownPoss = ownPoss or o.ownPoss
	G.currentOwn = ownPoss
	local npOptions = { dropPoss = ownPoss ~= nil, possJa = ownPoss }

	local function NPT(np, role)
		local text = G.NPText(np, role, npOptions)
		if ownPoss and np.possJa == ownPoss and text:sub(1, #ownPoss) == ownPoss and #text > #ownPoss then
			text = text:sub(#ownPoss + 1)
		end
		return text
	end
	ctx.NPT = NPT

	local timePhrases, placePhrases, otherPhrases, objectPhrases, manner = {}, {}, {}, {}, {}
	local frontPhrases = {}
	local subjectPhrase = ""
	local clauseText = ""
	local predicate

	-- time and sentence adverbs in front of the clause
	for _, adv in ipairs(cl.frontAdv or {}) do
		if adv.w == "only" then
			-- said after the object below
		elseif adv.aspect then
			if kind == "imp" and (cl.let or ({ tell = true, ask = true, message = true, whisper = true, pm = true })[base or ""]) then
				frontPhrases[#frontPhrases + 1] = "気軽に"
			else
				frontPhrases[#frontPhrases + 1] = "ちょっと"
			end
		elseif adv.sentence then
			frontPhrases[#frontPhrases + 1] = adv.ja .. "、"
		else
			frontPhrases[#frontPhrases + 1] = adv.ja
		end
	end
	for _, pp in ipairs(cl.frontPP or {}) do
		local text = G.PPText(pp, ctx)
		frontPhrases[#frontPhrases + 1] = text
	end
	if cl.vocative then frontPhrases[#frontPhrases + 1] = G.NPText(cl.vocative, "subject", {}) .. "、" end
	if vg.usedto then timePhrases[#timePhrases + 1] = "以前は" end
	for _, adv in ipairs(c.timeAdvs) do
		if adv.w == "ever" and c.compNP and c.compNP.superlative and not c.compNP.everDone then
			-- "the best run ever": 今までで一番いい周回
			local copy = {}
			for key, value in pairs(c.compNP) do copy[key] = value end
			copy.ja = "今までで" .. copy.ja
			copy.everDone = true
			c.compNP = copy
		else
			timePhrases[#timePhrases + 1] = adv.ja
		end
	end
	-- "it takes ten minutes": the duration belongs to the verb, not to the scene
	local takeTime = base == "take" and c.times[1] and not c.times[1].ago and not T.userLexicon.take and c.times[1] or nil
	c.takeTime = takeTime
	for _, np in ipairs(c.times) do
		if np == takeTime then
			-- said with the verb below
		elseif np.repeatCount then
			-- "three times": next to the verb, after the place
			manner[#manner + 1] = NPT(np)
		elseif np.ago then
			timePhrases[#timePhrases + 1] = NPT(np) .. "に"
		elseif np.count then
			local text = NPT(np)
			timePhrases[#timePhrases + 1] = text .. (text:sub(-3) == "間" and "" or "間")
		else
			timePhrases[#timePhrases + 1] = NPT(np)
		end
	end

	local earlyTimes = #timePhrases

	-- "only": だけ after the object
	for index = #frontPhrases, 1, -1 do
	end
	local onlyFlag = false
	-- "too" / "also": と the subject, as in 私も
	local alsoSubject = false
	local advWords = {}
	for _, adv in ipairs(vg.advs or {}) do advWords[#advWords + 1] = adv end
	for _, adv in ipairs(c.advs) do advWords[#advWords + 1] = adv end
	local filtered = {}
	for _, adv in ipairs(advWords) do
		if adv.ja == "も" and (adv.w == "too" or adv.w == "also") then
			alsoSubject = true
		else
			filtered[#filtered + 1] = adv
		end
	end
	advWords = filtered
	if alsoSubject then drop = false end
	-- "we all focus": 私たちはみんな, the subject stays
	for _, adv in ipairs(advWords) do
		if adv.w == "all" or adv.w == "both" then drop = false end
	end
	local aspectAdv = {}
	do
		local rest = {}
		for _, adv in ipairs(advWords) do
			if adv.w == "only" then
				onlyFlag = true
			elseif L.FRONT_ADV[adv.w or ""] then
				aspectAdv[#aspectAdv + 1] = adv
			else
				rest[#rest + 1] = adv
			end
		end
		advWords = rest
		for _, adv in ipairs(cl.frontAdv or {}) do
			if adv.w == "only" then onlyFlag = true end
		end
	end
	ctx.onlyFlag = onlyFlag

	-- place adverbs: here, there
	local function PlacePhrase(adv)
		local goes = ctx.existence or ctx.motion or (ctx.entry and ctx.entry.particle == "に") or (vg.verb and vg.verb.entry.particle == "に")
		return adv.ja .. (goes and "に" or "で")
	end

	-- ---- there is -------------------------------------------------------------------------
	if kind == "there" then
		local pivot = c.compNP
		if not pivot then Fail("there without a noun") end
		ctx.existence = true
		local animate = Animate(pivot)
		local negative = form.negative or pivot.neg
		form.negative = negative
		for _, pp in ipairs(c.pps) do
			local text, category = G.PPText(pp, ctx)
			if category == "time" then
				timePhrases[#timePhrases + 1] = text
			elseif category == "place" then
				placePhrases[#placePhrases + 1] = text
			else
				otherPhrases[#otherPhrases + 1] = text
			end
		end
		for _, adv in ipairs(c.placeAdvs) do placePhrases[#placePhrases + 1] = PlacePhrase(adv) end
		local particle = (negative or question) and "は" or "が"
		if pivot.neg and pivot.pron then particle = "" end
		local tooMany = pivot.tooMany
		if tooMany then
			local copy = {}
			for key, value in pairs(pivot) do copy[key] = value end
			copy.tooMany = nil
			pivot = copy
			if #placePhrases > 0 and placePhrases[#placePhrases]:sub(-3) == "に" then
				placePhrases[#placePhrases] = placePhrases[#placePhrases] .. "は"
			end
		end
		local pivotText = NPT(pivot):gsub("^いくつかの", "")
		objectPhrases[#objectPhrases + 1] = pivotText .. particle
		subjectPhrase = ""
		predicate = tooMany and G.Pred({ ja = "多すぎる", class = "1" }, form, predStyle)
			or G.Pred(animate and EXISTS_ANIMATE or EXISTS_THING, form, predStyle)
		-- done: assemble below
	elseif copular then
		-- ---- be ------------------------------------------------------------------------------
		G.Copular(ctx, {
			subj = subj, drop = drop, question = question, kind = kind, style = predStyle,
			timePhrases = timePhrases, placePhrases = placePhrases, otherPhrases = otherPhrases,
			objectPhrases = objectPhrases, manner = manner, advWords = advWords, form = form,
			NPT = NPT, PlacePhrase = PlacePhrase,
		})
		predicate = ctx.predicate
		subjectPhrase = ctx.subjectPhrase or ""
		drop = ctx.drop
		if ctx.skipSubject and not ctx.subjectSet then subjectPhrase = "" end
	else
		-- ---- an ordinary verb ---------------------------------------------------------------
		entry = G.VerbEntry(cl, c, form)
		G.Verbal(ctx, {
			subj = subj, drop = drop, question = question, kind = kind, style = predStyle, entry = entry, base = base,
			timePhrases = timePhrases, placePhrases = placePhrases, otherPhrases = otherPhrases,
			objectPhrases = objectPhrases, manner = manner, advWords = advWords, form = form,
			NPT = NPT, PlacePhrase = PlacePhrase,
		})
		predicate = ctx.predicate
		clauseText = ctx.clauseText or ""
		if ctx.mergedSubject ~= nil then subj = ctx.mergedSubject end
		if ctx.subjectFinal then drop = true end
	end

	-- adverbs beside the verb
	for _, adv in ipairs(advWords) do
		local text = AdverbText(adv, cl, form)
		if text ~= "" then manner[#manner + 1] = text end
	end

	-- the subject
	if kind ~= "there" and not copular then
		if subj and not drop and not cl.sharedSubject then
			local particle = alsoSubject and "も" or G.SubjectParticle(cl, o, c)
			if ctx.entry and ctx.entry.haveAnimate and particle == "は" then particle = "には" end
			local text = NPT(subj, "subject")
			if subj.gerund then text = G.NPText(subj, "subject", npOptions) end
			subjectPhrase = text .. particle
		elseif alsoSubject and subj then
			subjectPhrase = NPT(subj, "subject") .. "も"
		end
		if ctx.subjectFinal then subjectPhrase = ctx.subjectPhrase end
		if requestPrefix then subjectPhrase = requestPrefix .. "、" end
		if subj and not subj.neg and subj.pron and L.INDEF_PRON[subj.pron] and question and not o.subordinate and subjectPhrase ~= "" then
			-- "anyone want to run": a call to the room; "does anyone have the key" just asks
			local plain = base == "have" or base == "see" or base == "get" or base == "own"
			subjectPhrase = NPT(subj, "subject") .. (plain and "" or "、")
		end
	elseif copular and alsoSubject and subj and subjectPhrase == "" then
		subjectPhrase = NPT(subj, "subject") .. "も"
	end

	-- wh phrases: the question word in the place it would fill
	local whPhrase = ""
	if cl.wh and ctx.whPlaced ~= true and not c.stranded then
		whPhrase = G.WhPhrase(cl, ctx, copular)
	end

	-- ---- assemble --------------------------------------------------------------------------
	local parts = {}
	AddAll(parts, frontPhrases)
	-- "today", "two years ago" set the scene in front of the subject; "at midnight" follows it
	local early = (subj and subj.neg and subj.pron) and 0 or earlyTimes
	for index = 1, math.min(early, #timePhrases) do parts[#parts + 1] = timePhrases[index] end
	if subjectPhrase ~= "" then parts[#parts + 1] = subjectPhrase end
	for index = early + 1, #timePhrases do parts[#parts + 1] = timePhrases[index] end
	for _, adv in ipairs(aspectAdv) do
		local text = AdverbText(adv, cl, form)
		if text ~= "" then parts[#parts + 1] = text end
	end
	AddAll(parts, placePhrases)
	AddAll(parts, otherPhrases)
	if whPhrase ~= "" and ctx.whBeforeObjects then parts[#parts + 1] = whPhrase end
	AddAll(parts, objectPhrases)
	if whPhrase ~= "" and not ctx.whBeforeObjects then parts[#parts + 1] = whPhrase end
	if clauseText ~= "" then parts[#parts + 1] = clauseText end
	AddAll(parts, manner)
	if predicate and predicate ~= "" then parts[#parts + 1] = predicate end
	local text = Join(parts)

	if question and style == "polite" and not ctx.noQuestionMark then
		if ctx.whyQuestion then
			text = text .. "のですか"
		else
			text = text .. "か"
		end
	end
	return text, question
end

function G.ClauseText(cl, o)
	local text = G.Clause(cl, o)
	return text
end

-- ---------------------------------------------------------------------------------------
-- be
-- ---------------------------------------------------------------------------------------

local function TooStem(entry)
	if entry.class == "state" or entry.class == "na" or entry.class == "rel" then return entry.ja .. "すぎ" end
	local word = entry.ja == "いい" and "よい" or entry.ja
	return word:sub(1, -4) .. "すぎ"
end

local COPULA_MODES = { [false] = true, must = true, have_to = true, should = true, need = true, become = true,
	imperative = true, maybe = true }

function G.Copular(ctx, a)
	local cl, c, o = ctx.cl, ctx.c, ctx.o
	local subj, form, style, NPT = a.subj, a.form, a.style, a.NPT
	local vg = cl.vg
	local wh = cl.wh
	local mode = form.mode or false
	if not COPULA_MODES[mode] then Fail("copula mode " .. tostring(mode)) end

	local function Maybe(text, kindWord)
		if mode == "maybe" then
			return text .. (style == "polite" and "かもしれません" or "かもしれない")
		end
	end

	local function SubjectPhrase(keep)
		if not subj or cl.sharedSubject then return "" end
		if a.drop and not keep then return "" end
		local particle = G.SubjectParticle(cl, o, c)
		return NPT(subj, "subject") .. particle
	end

	local compNP, adj = c.compNP, c.adj

	-- phrases that are not the complement itself ("essential for a sustainable future")
	local pivotPP = c.pps[1] and not compNP and not adj and not c.inf and not c.ger and not c.placeAdvs[1] and (not wh or c.stranded)
	if not pivotPP then
		for _, pp in ipairs(c.pps) do
			local text, category = G.PPText(pp, ctx)
			if category == "time" then a.timePhrases[#a.timePhrases + 1] = text
			elseif category == "place" then a.placePhrases[#a.placePhrases + 1] = text
			else a.otherPhrases[#a.otherPhrases + 1] = text end
		end
	end

	-- no healers online: オンラインのヒーラーはいません
	local completeJa = (compNP and compNP.ja) or (adj and adj.entry and adj.entry.ja)
	if subj and subj.neg and not subj.pron and Animate(subj) and completeJa == "オンライン" and not T.userLexicon.online and mode == false then
		ctx.subjectPhrase = "オンラインの" .. NPT(subj, "subject") .. "は"
		ctx.predicate = G.Pred(EXISTS_ANIMATE, form, style)
		ctx.drop = false
		return
	end

	-- what is your name: the question word is the subject, the other noun is what is asked
	if cl.whSubject and compNP and not compNP.wh then
		ctx.subjectPhrase = NPT(compNP, "subject") .. "は"
		ctx.predicate = G.Cop(subj.ja, "n", form, style)
		ctx.drop = true
		return
	end

	-- it is time to go: 行く時間です
	if subj and subj.pron == "it" and compNP and compNP.rel and compNP.rel.kind == "inf" and not adj then
		ctx.skipSubject = true
		ctx.predicate = G.Cop(NPT(compNP, "complement"), "n", form, style)
		ctx.subjectPhrase = ""
		ctx.drop = true
		return
	end

	-- it is hard to play healer: the infinitive is the topic
	if subj and subj.pron == "it" and (c.inf or c.that) and (adj or compNP) and not (adj and adj.too) then
		local text
		if c.inf then
			text = G.InfText(c.inf, { style = "attr", subordinate = true, noSubject = true }) .. "の"
		else
			text = G.Clause(c.that, { style = "quote", subordinate = true }) .. "こと"
		end
		ctx.subjectPhrase = text .. "は"
		ctx.subjectSet = true
		subj = nil
		ctx.skipSubject = true
		if adj then
			local entry = adj.entry
			local c2 = {}
			for k, v in pairs(c) do c2[k] = v end
			c2.inf = nil
			c2.that = nil
			ctx.predicate = G.AdjPredicate(adj, form, style, c2) or Fail("adjective")
		else
			ctx.predicate = G.Cop(NPT(compNP), "n", form, style)
		end
		return
	end

	-- the topic
	local subjectPhrase
	local complementIsWh = (compNP and compNP.wh) or (wh and not compNP and not adj and not c.stranded)
	if complementIsWh and subj and (subj.pron == "you" or subj.pron == "i") and a.drop then
		a.drop = false
	end

	-- time questions about "it": what time is it
	if wh and wh.word == "what time" and subj and subj.pron == "it" then
		ctx.skipSubject = true
		ctx.predicate = G.Cop(wh.entry.ja, "n", form, style)
		ctx.whPlaced = true
		return
	end

	local stateAdv
	if not compNP and not adj and not c.inf and not c.ger then
		for index, adv in ipairs(a.advWords or {}) do
			if L.STATE_ADV[adv.w or ""] then
				stateAdv = table.remove(a.advWords, index)
				break
			end
		end
	end
	if compNP then
		local text = NPT(compNP, "complement")
		local predicate = Maybe(text) or G.Cop(text, "n", form, style)
		ctx.predicate = predicate
	elseif adj then
		ctx.adjective = true
		if c.objs[1] and adj.entry and adj.entry.particle then
			a.objectPhrases[#a.objectPhrases + 1] = NPT(c.objs[1]) .. adj.entry.particle
		end
		ctx.predicate = G.AdjPredicate(adj, form, style, c, ctx, a) or Fail("adjective")
		if cl.wh and cl.wh.word == "why" then ctx.whyQuestion = true end
		if ctx.predicate == nil then Fail("adjective") end
	elseif stateAdv then
		-- the server is down
		ctx.predicate = G.Pred(L.STATE_ADV[stateAdv.w], form, style)
		for _, pp in ipairs(c.pps) do
			local text, category = G.PPText(pp, ctx)
			if category == "time" then a.timePhrases[#a.timePhrases + 1] = text
			elseif category == "place" then a.placePhrases[#a.placePhrases + 1] = text
			else a.otherPhrases[#a.otherPhrases + 1] = text end
		end
	elseif c.pps[1] then
		local pp = c.pps[1]
		local w = pp.prep
		local np = pp.np
		local stateText = L.STATE_PP[w .. " " .. (np.w or "")]
		if stateText then
			ctx.predicate = G.Cop(stateText, stateText:sub(-3) == "る" and "rel" or "n", form, style)
			ctx.subjectPhrase = SubjectPhrase()
			ctx.drop = a.drop
			for index = 2, #c.pps do
				local text, category = G.PPText(c.pps[index], ctx)
				if category == "time" then a.timePhrases[#a.timePhrases + 1] = text
				elseif category == "place" then a.placePhrases[#a.placePhrases + 1] = text
				else a.otherPhrases[#a.otherPhrases + 1] = text end
			end
			return
		end
		if L.PLACE_PREP[w] then
			ctx.existence = true
			local rest = {}
			for index, other in ipairs(c.pps) do
				local text, category = G.PPText(other, ctx)
				if category == "time" then a.timePhrases[#a.timePhrases + 1] = text
				elseif category == "place" then a.placePhrases[#a.placePhrases + 1] = text
				else a.otherPhrases[#a.otherPhrases + 1] = text end
			end
			for _, adv in ipairs(c.placeAdvs) do a.placePhrases[#a.placePhrases + 1] = a.PlacePhrase(adv) end
			local animate = subj and (Animate(subj) or subj.pron ~= nil and subj.pron ~= "it" and subj.pron ~= "this"
				and subj.pron ~= "that" and subj.pron ~= "these" and subj.pron ~= "those" and not subj.thing)
			ctx.predicate = G.Pred(animate and EXISTS_ANIMATE or EXISTS_THING, form, style)
			if c.than then Fail("than") end
			ctx.subjectPhrase = SubjectPhrase()
			ctx.drop = a.drop
			return
		elseif w == "from" then
			ctx.predicate = G.Cop(NPT(np) .. "出身", "n", form, style)
		elseif w == "in the middle of" then
			ctx.predicate = G.Cop(NPT(np) .. "の最中", "n", form, style)
		elseif w == "with" then
			ctx.predicate = G.Cop(NPT(np) .. "と一緒", "n", form, style)
		elseif w == "for" then
			ctx.predicate = G.Cop(NPT(np) .. "のため", "n", form, style)
		elseif w == "like" then
			ctx.predicate = G.Cop(NPT(np) .. "のよう", "na", form, style)
		elseif w == "about" then
			ctx.predicate = G.Cop(NPT(np) .. "について", "n", form, style)
		else
			Fail("be + " .. w)
		end
		for index = 2, #c.pps do
			local text, category = G.PPText(c.pps[index], ctx)
			if category == "time" then a.timePhrases[#a.timePhrases + 1] = text
			elseif category == "place" then a.placePhrases[#a.placePhrases + 1] = text
			else a.otherPhrases[#a.otherPhrases + 1] = text end
		end
	elseif c.placeAdvs[1] then
		ctx.existence = true
		local adv = c.placeAdvs[1]
		local animate = subj and (Animate(subj) or (subj.pron ~= nil and not subj.thing))
		a.placePhrases[#a.placePhrases + 1] = adv.ja .. "に"
		if c.inf then
			-- "I am here to help": 手伝うためにここにいます
			local purpose = G.InfText(c.inf, { style = "attr", subordinate = true, noSubject = true })
			a.otherPhrases[#a.otherPhrases + 1] = purpose .. "ために"
		end
		ctx.predicate = G.Pred(animate and EXISTS_ANIMATE or EXISTS_THING, form, style)
	elseif c.inf then
		local text = G.InfText(c.inf, { style = "attr", subordinate = true, noSubject = true })
		ctx.predicate = G.Cop(text .. "こと", "n", form, style)
	elseif c.ger then
		local text = G.GerText(c.ger, { style = "attr", subordinate = true, noSubject = true })
		ctx.predicate = G.Cop(text .. "こと", "n", form, style)
	elseif wh and wh.adj then
		-- how long is the queue: どれくらい長いですか
		local text = G.AdjPredicate(wh.adj, form, style, c, ctx, a)
		if not text then Fail("how adjective") end
		ctx.predicate = "どれくらい" .. text
		ctx.whPlaced = true
	elseif wh and not compNP and wh.entry and wh.word == "where" then
		-- where is the healer: どこにいますか
		ctx.existence = true
		local animate = subj and (Animate(subj) or (subj.pron ~= nil and not subj.thing))
		a.placePhrases[#a.placePhrases + 1] = "どこに"
		ctx.predicate = G.Pred(animate and EXISTS_ANIMATE or EXISTS_THING, form, style)
		ctx.whPlaced = true
	elseif wh and not compNP and wh.entry then
		-- when is the raid / how is it
		local ja = wh.entry.ja
		if wh.word == "how" then ja = "どう" end
		ctx.predicate = G.Cop(ja, "n", form, style)
		ctx.whPlaced = true
	elseif c.timeAdvs[1] then
		-- the reset is soon / the event is tomorrow
		local adv = c.timeAdvs[1]
		for index = #a.timePhrases, 1, -1 do
			if a.timePhrases[index] == adv.ja then table.remove(a.timePhrases, index) break end
		end
		ctx.predicate = G.Cop(adv.w == "soon" and "もうすぐ" or adv.ja, "n", form, style)
	else
		Fail("be with nothing")
	end
	-- "I will be right there": a place beside an adjective or a noun is still said
	if c.placeAdvs[1] and (compNP or adj or c.inf or c.ger or stateAdv) then
		for _, adv in ipairs(c.placeAdvs) do a.placePhrases[#a.placePhrases + 1] = a.PlacePhrase(adv) end
	end
	ctx.subjectPhrase = SubjectPhrase()
	ctx.drop = a.drop
end

-- An adjective phrase as a predicate: とても強いです, 高すぎます, ヒーラーより強いです.
function G.AdjPredicate(adj, form, style, c, ctx, a)
	if adj.list then
		local c2 = {}
		for k, v in pairs(c) do c2[k] = v end
		c2.inf = nil
		local firstStyle = adj.conj == "and" and "te" or "polite"
		local first = G.AdjPredicate(adj.first, form, firstStyle, c2, ctx, a)
		local second = G.AdjPredicate(adj.second, form, style, c, ctx, a)
		if not first or not second then return nil end
		local joiner = adj.conj == "but" and "が、" or (adj.conj == "or" and "か、" or "")
		if style ~= "polite" and adj.conj ~= "and" then first = G.AdjPredicate(adj.first, form, style, c2, ctx, a) end
		return first .. joiner .. second
	end
	local entry = adj.entry
	local prefix = adj.degree or ""
	local head = ""
	local than = ""
	if c.than then
		than = (ctx and ctx.NPT or function(n) return G.NPText(n, "pp", {}) end)(c.than, "pp") .. "より"
	end
	if adj.infl == "comparative" and than == "" then head = "もっと"
	elseif adj.infl == "superlative" then head = "一番" end
	if adj.fromVerb and entry.stateVerb and not adj.too then
		return than .. prefix .. head .. G.Pred(entry.stateVerb, form, style)
	end
	if adj.too then
		local base = TooStem(entry)
		if c.inf then
			local inner = G.InfText(c.inf, { style = "polite", subordinate = true, noSubject = true, form = { mode = "can", negative = true } })
			return than .. prefix .. base .. "て" .. inner
		end
		local text = base .. "る"
		return than .. prefix .. G.Pred({ ja = text, class = "1" }, form, style)
	end
	-- adjective + to-verb: easy to use, ready to go, glad to help
	if c.inf then
		local english = adj.w or ""
		local how = L.ADJ_INF[english]
		if not how then return nil end
		local inner = G.InfText(c.inf, { style = how == "te" and "te" or "attr", subordinate = true, noSubject = true })
		if how == "nominal" then
			return than .. prefix .. head .. inner .. "のが" .. G.Cop(entry.ja, entry.class, form, style)
		elseif how == "te" then
			return than .. prefix .. head .. inner .. G.Cop(entry.ja, entry.class, form, style)
		elseif how == "ready" then
			return inner .. G.Pred({ ja = "準備ができている", class = "1" }, form, style)
		end
	end
	local class = entry.class
	if class == "state" then Fail("state") end
	return than .. prefix .. head .. G.Cop(entry.ja, class, form, style)
end

function G.ObjectParticle(entry)
	if not entry then return "を" end
	-- "it costs 200 gold": 200ゴールドかかります
	if entry.ja == "かかる" then return "" end
	if entry.particle then return entry.particle end
	if entry.class == "i" or entry.class == "na" then return "が" end
	return "を"
end

-- ---------------------------------------------------------------------------------------
-- Infinitives, gerunds and the verbs that govern them
-- ---------------------------------------------------------------------------------------

-- A "to + verb" or "-ing" clause as text. The subject is the speaker's or the main clause's.
function G.InfText(inf, o)
	local cl = { cat = "CL", kind = "decl", vg = inf.vg, comps = inf.comps, implied = "i", formOverride = o.form }
	o.ownPoss = o.ownPoss or G.currentOwn
	local text = G.Clause(cl, o)
	return text
end

function G.GerText(ger, o)
	local cl = { cat = "CL", kind = "decl", vg = ger.vg, comps = ger.comps, implied = "i", formOverride = o.form }
	o.ownPoss = o.ownPoss or G.currentOwn
	local text = G.Clause(cl, o)
	return text
end

local function CopyVG(vg)
	return S.CopyState(vg)
end

-- Merge a governing verb and the infinitive or gerund after it into one clause, or return nil
-- when the verb is an ordinary one. Fail() when it governs one in a way not understood.
function G.MergeChain(cl, o)
	local vg = cl.vg
	local verb = vg.verb
	local base = verb.base or verb.w
	if T.userLexicon and T.userLexicon[base] then return nil end
	local comps = cl.comps
	local infIndex, gerIndex
	for index, comp in ipairs(comps) do
		if (comp.kind == "inf" or comp.kind == "bare") and not infIndex then infIndex = index end
		if comp.kind == "ger" and not gerIndex then gerIndex = index end
	end
	if not infIndex and not gerIndex then return nil end
	local outerForm = G.Form(cl, o)

	local function Without(skip, extra)
		local out = {}
		for index, comp in ipairs(comps) do
			if not skip[index] then out[#out + 1] = comp end
		end
		for _, comp in ipairs(extra or {}) do out[#out + 1] = comp end
		return out
	end

	local function Synthetic(ja, class, particle)
		local copy = CopyVG(vg)
		copy.verb = { cat = "V", w = base, base = base, entry = { ja = ja, class = class, particle = particle }, pref = verb.pref, item = verb.item }
		return copy
	end

	if gerIndex then
		local frame = L.GER_FRAMES[base]
		if not frame then return nil end
		local inner = comps[gerIndex].node
		-- "stop attacking": don't
		if (base == "stop" or base == "quit") and cl.kind == "imp" and not outerForm.negative and not inner.vg.be then
			local innerVG = CopyVG(inner.vg)
			return { cat = "CL", kind = "imp", vg = innerVG, merged = true, comps = Without({ [gerIndex] = true }, inner.comps),
				frontAdv = cl.frontAdv, frontPP = cl.frontPP, formOverride = { negative = true, mode = "imperative" } }
		end
		if frame.stem then
			local ie = inner.vg.verb.entry
			if ie.class == "i" or ie.class == "na" then return nil end
			local ja = T.Stem(ie.ja, ie.class) .. frame[1]
			local merged = { cat = "CL", kind = cl.kind, subj = cl.subj, vg = Synthetic(ja, frame[2]), merged = true,
				comps = Without({ [gerIndex] = true }, inner.comps), frontAdv = cl.frontAdv, frontPP = cl.frontPP, implied = cl.implied,
				wh = cl.wh, whSubject = cl.whSubject, ynq = cl.ynq, causee = cl.causee, let = cl.let, sharedSubject = cl.sharedSubject }
			return merged
		end
		local text = G.GerText(inner, { style = "quote", subordinate = true, noSubject = true })
		local ja = text .. frame[1]
		return { cat = "CL", kind = cl.kind, subj = cl.subj, vg = Synthetic(ja, frame[2]), merged = true,
			comps = Without({ [gerIndex] = true }), frontAdv = cl.frontAdv, frontPP = cl.frontPP, implied = cl.implied,
			wh = cl.wh, whSubject = cl.whSubject, ynq = cl.ynq, causee = cl.causee, let = cl.let, sharedSubject = cl.sharedSubject }
	end

	-- an infinitive
	local inner = comps[infIndex].node
	local bareKind = comps[infIndex].kind == "bare"
	local nps = {}
	for index = 1, infIndex - 1 do
		if comps[index].kind == "np" then nps[#nps + 1] = index end
	end
	local controlled
	if #nps == 1 and L.OBJ_INF[base] then
		controlled = comps[nps[1]].node
	elseif #nps > 0 then
		return nil
	end
	-- "would like to" is a want
	local mode = L.CHAIN_MODE[base]
	if (base == "like" or base == "love") and vg.modal == "would" then mode = "want" end
	if bareKind and not controlled then return nil end

	local modalOk = vg.modal == nil or vg.modal == "will" or vg.modal == "would" or vg.modal == "shall"
	local requestModal = cl.kind == "ynq" and (vg.modal == "can" or vg.modal == "could")
	local innerForm = G.Form({ vg = inner.vg }, o)

	if controlled then
		-- who does it: "want you to wait", "need him to heal"
		local skip = { [infIndex] = true, [nps[1]] = true }
		local actorText
		local function Merged(vgNode, mode2, extraComps)
			return { cat = "CL", kind = cl.kind, subj = cl.subj, vg = vgNode, merged = true, comps = Without(skip, extraComps),
				frontAdv = cl.frontAdv, frontPP = cl.frontPP, implied = cl.implied, wh = cl.wh, whSubject = cl.whSubject,
				ynq = cl.ynq, actor = controlled, formOverride = mode2, sharedSubject = cl.sharedSubject }
		end
		if not (modalOk or requestModal) or (vg.perfect and not vg.prog) or vg.passive then return nil end
		if inner.vg.be and not inner.vg.verb then return nil end
		local innerVG = CopyVG(inner.vg)
		local adverbs = {}
		for _, adv in ipairs(vg.advs or {}) do adverbs[#adverbs + 1] = adv end
		for _, adv in ipairs(innerVG.advs or {}) do adverbs[#adverbs + 1] = adv end
		innerVG.advs = adverbs
		if requestModal and (base == "want" or base == "wish" or base == "need" or base == "like" or base == "love") then return nil end
		if base == "want" or base == "wish" or ((base == "like" or base == "love") and vg.modal == "would") then
			return Merged(innerVG, { mode = "want_person", past = outerForm.past, negative = outerForm.negative or inner.vg.neg }, inner.comps)
		elseif base == "need" then
			local you = controlled.pron == "you"
			if you and not outerForm.past and not outerForm.negative and not inner.vg.neg then
				local merged = Merged(innerVG, { mode = "want_person", past = false, negative = inner.vg.neg }, inner.comps)
				merged.actorDrop = true
				return merged
			end
			local ie = inner.vg.verb.entry
			if ie.class == "i" or ie.class == "na" then return nil end
			local te = T.TeForm(ie.ja, ie.class) .. "もらう"
			if inner.vg.neg then te = T.NaiStem(ie.ja, ie.class) .. "ないでもらう" end
			local copy = CopyVG(innerVG)
			copy.verb = { cat = "V", w = "need", base = "need", entry = { ja = te, class = "5" }, pref = 0 }
			copy.neg = outerForm.negative
			return Merged(copy, { mode = "need", past = outerForm.past, negative = outerForm.negative }, inner.comps)
		elseif base == "let" or base == "make" then
			-- let him go, make them wait: the causative; "let you know" is to inform
			local ie = inner.vg.verb.entry
			local innerBase = inner.vg.verb.base or inner.vg.verb.w
			local copy = CopyVG(vg)
			if base == "let" and innerBase == "see" and (controlled.pron == "me" or controlled.pron == "us") then
				-- let me see it: 見せてください
				copy.verb = { cat = "V", w = "let", base = "let", entry = { ja = "見せる", class = "1", particle = "を" }, pref = 0 }
				local merged = Merged(copy, nil, inner.comps)
				merged.actorDrop = true
				return merged
			end
			if base == "let" and innerBase == "know" then
				-- let you know / let me know: to inform
				copy.verb = { cat = "V", w = "let", base = "let", entry = { ja = "知らせる", class = "1", particle = "に" }, pref = 0 }
				local merged = Merged(copy, nil, inner.comps)
				if controlled.pron == "you" or controlled.pron == "me" or controlled.pron == "us" then merged.actorDrop = true end
				return merged
			end
			if ie.class == "i" or ie.class == "na" or inner.vg.neg or inner.vg.be then return nil end
			local stem = G.CausativeStem(ie.ja, ie.class)
			if not stem then return nil end
			local transitive = false
			for _, comp in ipairs(inner.comps) do
				if comp.kind == "np" and not comp.node.time then transitive = true end
			end
			copy.verb = { cat = "V", w = base, base = base, entry = { ja = stem .. "る", class = "1", particle = transitive and "を" or "を" }, pref = 0 }
			local merged = Merged(copy, nil, inner.comps)
			merged.actorParticle = transitive and "に" or "を"
			return merged
		elseif base == "have" and bareKind then
			local ie = inner.vg.verb.entry
			if ie.class == "i" or ie.class == "na" then return nil end
			local te = T.TeForm(ie.ja, ie.class) .. "もらう"
			local copy = CopyVG(vg)
			copy.verb = { cat = "V", w = "have", base = "have", entry = { ja = te, class = "5" }, pref = 0 }
			return Merged(copy, { past = outerForm.past, negative = outerForm.negative }, inner.comps)
		elseif base == "see" or base == "hear" or base == "watch" then
			local text = G.InfText(inner, { style = "quote", subordinate = true, noSubject = true })
			local copy = CopyVG(vg)
			local suffix, class = "のを見る", "1"
			if base == "hear" then suffix, class = "のを聞く", "5" end
			copy.verb = { cat = "V", w = base, base = base, entry = { ja = text .. suffix, class = class }, pref = 0 }
			local merged = Merged(copy, nil, nil)
			merged.actorParticle = "が"
			return merged
		elseif base == "tell" or base == "order" or base == "ask" or base == "invite" or base == "remind" or base == "advise"
			or base == "warn" or base == "teach" or base == "allow" or base == "get" or base == "help" then
			local text = G.InfText(inner, { style = "quote", subordinate = true, noSubject = true })
			local suffix, class
			if base == "tell" or base == "order" then suffix, class = "ように言う", "5"
			elseif base == "ask" then suffix, class = "ようにお願いする", "s"
			elseif base == "invite" then suffix, class = "よう招待する", "s"
			elseif base == "remind" then suffix, class = "ように念を押す", "5"
			elseif base == "advise" then suffix, class = "よう助言する", "s"
			elseif base == "warn" then suffix, class = "よう警告する", "s"
			elseif base == "allow" then suffix, class = "のを許可する", "s"
			elseif base == "get" then
				-- get him to wait -> 彼に待ってもらう
				local ie = inner.vg.verb.entry
				if ie.class == "i" or ie.class == "na" then return nil end
				local te = T.TeForm(ie.ja, ie.class) .. "もらう"
				local copy = CopyVG(vg)
				copy.verb = { cat = "V", w = "get", base = "get", entry = { ja = te, class = "5" }, pref = 0 }
				return Merged(copy, { past = outerForm.past, negative = outerForm.negative }, inner.comps)
			elseif base == "help" then
				suffix, class = "のを手伝う", "5"
			elseif base == "teach" then suffix, class = "方を教える", "1"
			end
			local copy = CopyVG(vg)
			copy.verb = { cat = "V", w = base, base = base, entry = { ja = text .. suffix, class = class, particle = "に" }, pref = 0 }
			local merged = Merged(copy, nil, nil)
			if base == "allow" or base == "help" then merged.actorParticle = "が" end
			-- "help me find it" asked of someone: the helped person is the speaker, not said
			if base == "help" and (controlled.pron == "me" or controlled.pron == "us") and (cl.kind == "imp" or cl.kind == "ynq") then
				merged.actorDrop = true
			end
			return merged
		end
		return nil
	end

	if mode then
		if not modalOk or (vg.perfect and not vg.prog) or vg.passive then return nil end
		if vg.prog and base ~= "try" then return nil end
		local innerVG = CopyVG(inner.vg)
		local adverbs = {}
		for _, adv in ipairs(vg.advs or {}) do adverbs[#adverbs + 1] = adv end
		for _, adv in ipairs(innerVG.advs or {}) do adverbs[#adverbs + 1] = adv end
		innerVG.advs = adverbs
		if innerVG.be and not innerVG.verb and mode ~= "want" then return nil end
		if (innerVG.modal or innerVG.perfect or innerVG.prog or innerVG.passive) and mode ~= "want" then return nil end
		local override = { mode = mode, past = outerForm.past, negative = outerForm.negative or inner.vg.neg }
		if vg.prog and base == "try" then override.mode = "try_progressive" end
		if innerVG.be and not innerVG.verb then override.mode = "become" end
		if (innerVG.modal or innerVG.passive or innerVG.prog) then return nil end
		return { cat = "CL", kind = cl.kind, subj = cl.subj, vg = innerVG, merged = true, comps = Without({ [infIndex] = true }, inner.comps),
			frontAdv = cl.frontAdv, frontPP = cl.frontPP, implied = cl.implied, wh = cl.wh, whSubject = cl.whSubject, ynq = cl.ynq,
			formOverride = override, sharedSubject = cl.sharedSubject }
	end

	local frame = L.INF_FRAMES[base]
	if frame then
		if not modalOk or vg.perfect or vg.passive then return nil end
		if inner.vg.be and not inner.vg.verb then return nil end
		local ie = inner.vg.verb.entry
		if frame.stem then
			if ie.class == "i" or ie.class == "na" or inner.vg.modal or inner.vg.neg then return nil end
			local ja = T.Stem(ie.ja, ie.class) .. frame[1]
			return { cat = "CL", kind = cl.kind, subj = cl.subj, vg = Synthetic(ja, frame[2]), merged = true,
				comps = Without({ [infIndex] = true }, inner.comps), frontAdv = cl.frontAdv, frontPP = cl.frontPP, implied = cl.implied,
				wh = cl.wh, whSubject = cl.whSubject, ynq = cl.ynq, sharedSubject = cl.sharedSubject }
		end
		local text = G.InfText(inner, { style = "quote", subordinate = true, noSubject = true })
		return { cat = "CL", kind = cl.kind, subj = cl.subj, vg = Synthetic(text .. frame[1], frame[2]), merged = true,
			comps = Without({ [infIndex] = true }), frontAdv = cl.frontAdv, frontPP = cl.frontPP, implied = cl.implied,
			wh = cl.wh, whSubject = cl.whSubject, ynq = cl.ynq, sharedSubject = cl.sharedSubject }
	end
	return nil
end

-- ---------------------------------------------------------------------------------------
-- An ordinary verb and what it takes
-- ---------------------------------------------------------------------------------------

L.ME_DROPPED = { help = true, tell = true, show = true, give = true, teach = true, send = true, bring = true, ask = true }
L.SPECIAL_LET = {
	know = { "知らせ", "1" }, see = { "見せ", "1" }, try = { "試さ", "5" }, think = { "考えさせ", "1" },
}

-- "how to get to X from here": the way, as a noun.
function G.HowTo(inf, ctx)
	local verb = inf.vg.verb
	if not verb then Fail("how to be") end
	local entry = verb.entry
	local base = verb.base or verb.w
	local mods = {}
	for _, comp in ipairs(inf.comps) do
		if comp.kind == "pp" then
			local pp = comp.node
			local np = G.NPText(pp.np, "pp", {})
			local w = pp.prep
			if w == "to" then mods[#mods + 1] = np .. "への"
			elseif w == "from" then mods[#mods + 1] = np .. "からの"
			elseif w == "in" or w == "at" then mods[#mods + 1] = np .. "での"
			elseif w == "with" then mods[#mods + 1] = np .. "との"
			else mods[#mods + 1] = np .. (pp.entry and pp.entry.ja or "") .. "の" end
		elseif comp.kind == "np" then
			local gets = base == "get to" or base == "go to" or base == "get" or base == "go"
			mods[#mods + 1] = G.NPText(comp.node, "object", {}) .. (gets and "への" or "の")
		elseif comp.kind == "adv" then
			if comp.node.entry and comp.node.entry.place then mods[#mods + 1] = comp.node.ja .. "への" else Fail("how-to adverb") end
		else
			Fail("how-to complement")
		end
	end
	local ja
	if base == "get to" or base == "go" or base == "get" or base == "come" then
		ja = "行き"
	elseif entry.class == "i" or entry.class == "na" then
		Fail("how to be adjective")
	else
		ja = T.Stem(entry.ja, entry.class)
	end
	return Join(mods) .. ja .. "方"
end

local function SubjectPron(cl)
	return cl.subj and cl.subj.pron or nil
end

function G.Verbal(ctx, a)
	local cl, c, o = ctx.cl, ctx.c, ctx.o
	local entry, base, form, style, NPT = a.entry, a.base, a.form, a.style, a.NPT
	ctx.entry = entry
	local vg = cl.vg
	local objectParticle = G.ObjectParticle(entry)
	ctx.objectParticle = objectParticle
	local request = form.mode == "request" or form.mode == "imperative"

	-- who does it, for "want you to wait"
	if cl.actor and not cl.actorDrop then
		a.otherPhrases[#a.otherPhrases + 1] = NPT(cl.actor) .. (cl.actorParticle or "に")
	end

	-- "tell me where ...", "show me how to ..."
	local objs = {}
	for _, obj in ipairs(c.objs) do objs[#objs + 1] = obj end
	if (base == "tell" or base == "show") and (c.wh or (#objs >= 1 and c.that == nil)) and not (T.userLexicon and T.userLexicon.tell) then
		entry = { ja = "教える", class = "1", particle = "を" }
		objectParticle = "を"
	end

	-- give me X: Xをください
	if base == "give" and #objs == 2 and objs[1].pron == "me" and (form.mode == "imperative" or form.mode == "request") and not form.negative then
		a.objectPhrases[#a.objectPhrases + 1] = NPT(objs[2]) .. "を"
		ctx.predicate = form.mode == "request" and "もらえます" or "ください"
		ctx.noQuestionMark = false
		for _, pp in ipairs(c.pps) do
			local text, category = G.PPText(pp, ctx)
			a.otherPhrases[#a.otherPhrases + 1] = text
		end
		return
	end

	-- let me know
	if cl.let then
		local causee = cl.causee
		if not (causee.pron == "me" or causee.pron == "us") then Fail("let them") end
		if style ~= "polite" then Fail("let in subordinate") end
		local special = L.SPECIAL_LET[base]
		local stem
		local ie = entry
		if special then
			stem = special[1]
		else
			if ie.class == "i" or ie.class == "na" then Fail("let me be adjective") end
			stem = G.CausativeStem(ie.ja, ie.class)
			if not stem then Fail("causative") end
		end
		for _, obj in ipairs(objs) do
			a.objectPhrases[#a.objectPhrases + 1] = NPT(obj) .. objectParticle
		end
		for _, pp in ipairs(c.pps) do
			local text, category = G.PPText(pp, ctx)
			if category == "time" then a.timePhrases[#a.timePhrases + 1] = text
			elseif category == "place" then a.placePhrases[#a.placePhrases + 1] = text
			else a.otherPhrases[#a.otherPhrases + 1] = text end
		end
		ctx.predicate = stem .. (form.negative and "ないでください" or "てください")
		if form.negative then ctx.predicate = stem:gsub("[せさ]$", "") .. "せないでください" end
		return
	end

	-- it takes ten minutes to clear the dungeon: ダンジョンをクリアするのに10分かかります
	local howLong = cl.wh and cl.wh.word == "how long"
	if base == "take" and (c.takeTime or howLong) and not T.userLexicon.take and #objs <= 1 and not c.that and not c.wh and not c.ger
		and not form.mode and not cl.actor then
		local subj = cl.subj
		if objs[1] and not (objs[1].pron == "me" or objs[1].pron == "us") then Fail("take with a person") end
		if subj and not (subj.pron == "it" or (not subj.pron and not Animate(subj))) then Fail("take with a person subject") end
		local duration = c.takeTime
		local inf = c.inf
		if duration and duration.rel and duration.rel.kind == "inf" and not inf then
			-- "an hour to finish": the infinitive came with the noun phrase
			inf = duration.rel.inf
			local plain = {}
			for key, value in pairs(duration) do plain[key] = value end
			plain.rel = nil
			duration = plain
		end
		if inf then
			a.objectPhrases[#a.objectPhrases + 1] = G.InfText(inf, { style = "attr", subordinate = true, noSubject = true }) .. "のに"
		end
		if howLong then
			a.objectPhrases[#a.objectPhrases + 1] = "どのくらい"
			ctx.whPlaced = true
		else
			local text = NPT(duration)
			a.objectPhrases[#a.objectPhrases + 1] = text .. (duration.count and "" or "が")
		end
		ctx.predicate = G.Pred({ ja = "かかる", class = "5" }, form, style)
		if subj and subj.pron == "it" then
			ctx.subjectPhrase = ""
		elseif subj then
			ctx.subjectPhrase = NPT(subj, "subject") .. "は"
		end
		ctx.subjectFinal = true
		return
	end

	-- look / seem / sound / get / stay + an adjective: すごそうです, 寒くなります
	if c.adj and L.LINK[base or ""] and not T.userLexicon[base or ""] then
		local text = G.LinkPredicate(base, c.adj, form, style)
		if not text then Fail("link verb " .. tostring(base)) end
		ctx.predicate = text
		for _, pp in ipairs(c.pps) do
			local t, category = G.PPText(pp, ctx)
			if category == "time" then a.timePhrases[#a.timePhrases + 1] = t
			elseif category == "place" then a.placePhrases[#a.placePhrases + 1] = t
			else a.otherPhrases[#a.otherPhrases + 1] = t end
		end
		return
	end

	-- no healers online: オンラインのヒーラーはいません
	if base == "online" and cl.subj and cl.subj.neg and not cl.subj.pron and Animate(cl.subj) and #objs == 0
		and not T.userLexicon.online and not form.mode then
		ctx.subjectPhrase = "オンラインの" .. NPT(cl.subj, "subject") .. "は"
		ctx.subjectFinal = true
		ctx.predicate = G.Pred(EXISTS_ANIMATE, form, style)
		return
	end

	if c.bare then Fail("bare infinitive after " .. tostring(base)) end

	-- I can't hear you: あなたの声が聞こえません
	if base == "hear" and form.mode == "can" and #objs == 1 and (objs[1].pron or Animate(objs[1])) and not c.ger and not c.that
		and not c.wh and not T.userLexicon.hear then
		local plain = {}
		for key, value in pairs(form) do plain[key] = value end
		plain.mode = nil
		a.objectPhrases[#a.objectPhrases + 1] = NPT(objs[1]) .. "の声が"
		ctx.predicate = G.Pred({ ja = "聞こえる", class = "1" }, plain, style)
		return
	end

	-- I have no idea: 全然分かりません
	if base == "have" and #objs == 1 and objs[1].neg and objs[1].w == "idea" and not c.wh and not T.userLexicon.have then
		a.manner[#a.manner + 1] = "全然"
		ctx.predicate = G.Pred({ ja = "分かる", class = "5" }, form, style)
		return
	end

	-- objects
	if #objs >= 3 then Fail("three objects") end
	local dropMe = request and ({ help = true, tell = true, show = true, teach = true })[base or ""] and #objs >= 1 and objs[1].pron == "me"
	if base == "help" and c.pps[1] and c.pps[1].prep == "with" then
		-- help me with this: これを手伝う
		local pp = table.remove(c.pps, 1)
		objs = {}
		local person = c.objs[1]
		local first = person and person.pron
		if person and not dropMe and first ~= "me" and first ~= "us" and not form.negative then
			-- help him with the quest: 彼のクエストを手伝う
			a.objectPhrases[#a.objectPhrases + 1] = NPT(person) .. "の" .. NPT(pp.np) .. "を"
		else
			a.objectPhrases[#a.objectPhrases + 1] = NPT(pp.np) .. "を"
			if cl.actor == nil and person and not dropMe and not (first == "me" or first == "us") then
				a.otherPhrases[#a.otherPhrases + 1] = NPT(person) .. "を"
			end
		end
		entry = { ja = "手伝う", class = "5", particle = "を" }
		if (first == "me" or first == "us") and not request then entry = { ja = "手伝ってくれる", class = "1", particle = "を" } end
		ctx.predicate = G.Pred(entry, form, style)
		objs = {}
	end
	if #objs == 2 then
		a.objectPhrases[#a.objectPhrases + 1] = NPT(objs[1]) .. "に"
		a.objectPhrases[#a.objectPhrases + 1] = NPT(objs[2]) .. objectParticle
	elseif #objs == 1 and not dropMe then
		local text = NPT(objs[1])
		if (c.that or c.wh) and objs[1].pron then
			-- "told me that ...": a person who is told is 私に
			objectParticle = "に"
		end
		if entry and entry.insufficient then text = text:gsub("^十分な", "") end
		if ctx.onlyFlag and not objs[1].onlyNP then text = text .. "だけ" end
		if objs[1].neg and objs[1].pron then
			a.objectPhrases[#a.objectPhrases + 1] = text
		else
			a.objectPhrases[#a.objectPhrases + 1] = text .. ((base == "ask" and objs[1].pron) and "に" or objectParticle)
		end
	end

	-- phrases
	for _, pp in ipairs(c.pps) do
		local text, category = G.PPText(pp, ctx)
		if category == "time" then a.timePhrases[#a.timePhrases + 1] = text
		elseif category == "place" then a.placePhrases[#a.placePhrases + 1] = text
		else a.otherPhrases[#a.otherPhrases + 1] = text end
	end
	for _, adv in ipairs(c.placeAdvs) do a.placePhrases[#a.placePhrases + 1] = a.PlacePhrase(adv) end
	-- "runs faster than me": the standard of comparison goes in front of the adverb
	if c.than then a.otherPhrases[#a.otherPhrases + 1] = ctx.NPT(c.than, "pp") .. "より" end

	-- a clause as the object
	local frameEntry
	if c.that then
		local frame = L.THAT_FRAMES[base]
		-- make sure you bring food: 持ってくるようにしてください
		if base == "make sure" and not T.userLexicon["make sure"] then frame = { "ように", "する", "s" } end
		if not frame then Fail("that after " .. tostring(base)) end
		local innerCl = c.that
		local outerPron, innerPron = SubjectPron(cl), SubjectPron(innerCl)
		local same = outerPron and innerPron and (outerPron == innerPron or ((outerPron == "i" or outerPron == "we") and (innerPron == "i" or innerPron == "we")))
		-- a command to you about what you do: the subject is understood
		if base == "make sure" and innerPron == "you" and (form.mode == "imperative" or form.mode == "request") then same = true end
		local text = G.Clause(innerCl, { style = "quote", subordinate = true, sameSubject = same, noSubject = same, embedded = true,
			keepSubject = o.keepSubject })
		ctx.clauseText = text .. frame[1]
		entry = { ja = frame[2], class = frame[3] }
		if frame[1] == "という" then Fail("mean") end
	elseif c.wh then
		local frame = L.WH_FRAMES[base]
		if base == "have" and objs[1] and objs[1].neg and objs[1].w == "idea" then
			-- "I have no idea what I'm doing": 何をしているのか分かりません
			frame = { "分かる", "5" }
			for index = #a.objectPhrases, 1, -1 do a.objectPhrases[index] = nil end
			objs = {}
		end
		if not frame then Fail("wh after " .. tostring(base)) end
		local inner = c.wh
		if inner.inf then
			if inner.wh ~= "how" then Fail("wh to") end
			ctx.clauseText = G.HowTo(inner.inf, ctx) .. "を"
		else
			local innerCl = {}
			for k, v in pairs(inner.clause) do innerCl[k] = v end
			if inner.yesno then
				local same = SubjectPron(cl) and SubjectPron(cl) == SubjectPron(innerCl)
				local text = G.Clause(innerCl, { style = "quote", subordinate = true, sameSubject = same, embedded = true, noQuestionMark = true })
				ctx.clauseText = text .. "かどうか"
			else
				if inner.subjectWh then
					-- who killed the boss: the wh word is the subject
				elseif inner.whNP then
					innerCl.wh = { word = inner.wh, np = inner.whNP }
				elseif L.WH_NP[inner.wh] then
					innerCl.wh = { word = inner.wh, np = { ja = inner.whEntry.ja } }
				else
					innerCl.wh = { word = inner.wh, entry = inner.whEntry }
				end
				innerCl.subj = innerCl.subj
				local same = SubjectPron(cl) and SubjectPron(cl) == SubjectPron(innerCl)
				local text = G.Clause(innerCl, { style = "quote", subordinate = true, sameSubject = same, embedded = true,
					noQuestionMark = true, question = false })
				ctx.clauseText = text .. "か"
			end
		end
		entry = { ja = frame[1], class = frame[2], particle = "を" }
		if base == "tell" or base == "show" or base == "ask" then entry.particle = "を" end
	elseif c.inf then
		-- an infinitive of purpose: 手伝いに来ました / 手伝うために
		local ie = c.inf.vg.verb and c.inf.vg.verb.entry
		if L.MOTION[base or ""] and ie and ie.class ~= "i" and ie.class ~= "na" and not c.inf.vg.modal and not c.inf.vg.neg then
			local stem = T.Stem(ie.ja, ie.class)
			local objs2 = {}
			local inner = G.InfText(c.inf, { style = "attr", subordinate = true, noSubject = true })
			-- 手伝いに: the stem of the verb, with its own phrases in front
			a.otherPhrases[#a.otherPhrases + 1] = inner:sub(1, #inner - #ie.ja) .. stem .. "に"
		else
			local text = G.InfText(c.inf, { style = "attr", subordinate = true, noSubject = true })
			a.otherPhrases[#a.otherPhrases + 1] = text .. "ために"
		end
	elseif c.ger then
		Fail("gerund after " .. tostring(base))
	end

	if not ctx.predicate then
		if ctx.permission and entry.class ~= "i" and entry.class ~= "na" and style == "polite" then
			-- "can I join": 参加してもいいですか
			ctx.predicate = G.Pred({ ja = T.TeForm(entry.ja, entry.class) .. "もいい", class = "i" }, {}, style)
		else
			ctx.predicate = G.Pred(entry, form, style)
		end
	end
	ctx.entry = entry
end

-- The question word in the place it would fill.
function G.WhPhrase(cl, ctx, copular)
	local wh = cl.wh
	if wh.np then
		local particle = ctx.objectParticle or "を"
		return (wh.np.ja or "") .. particle
	end
	local w = wh.word
	local ja = wh.entry and wh.entry.ja or ""
	ctx.whBeforeObjects = true
	if w == "where" then
		local goes = ctx.motion or (ctx.entry and ctx.entry.particle == "に")
		return "どこ" .. (goes and "に" or "で")
	elseif w == "why" then
		ctx.whyQuestion = true
		return "なぜ"
	elseif w == "how" then
		return "どうやって"
	elseif w == "what time" then
		return "何時に"
	end
	return ja
end

-- ---------------------------------------------------------------------------------------
-- A whole segment
-- ---------------------------------------------------------------------------------------

-- How each subordinating conjunction ends its clause.
G.SUB_FORMS = {
	["if"] = { style = "cond", before = "もし", after = "、" },
	unless = { style = "cond", after = "、", invertNegation = true },
	when = { style = "attr", after = "とき、" },
	["while"] = { style = "attr", after = "間に、" },
	["until"] = { style = "attr", after = "まで、" },
	because = { style = "attr", after = "ので、", because = true },
	since = { style = "attr", after = "ので、", because = true },
	although = { style = "polite", after = "が、" },
	after = { style = "attr", after = "後で、", formOverride = { past = true } },
	before = { style = "attr", after = "前に、" },
	whenever = { style = "attr", after = "ときはいつでも、" },
}

local function SubjectKey(cl)
	local subj = cl and cl.subj
	if not subj then return nil end
	return subj.pron or subj.ja
end

-- 悪いですので -> 悪いので, 雨ですので -> 雨なので
local function SoForm(text)
	if text:sub(-9) == "いです" then return text:sub(1, -7) end
	if text:sub(-6) == "です" then return text:sub(1, -7) .. "な" end
	return text
end

function G.Utterance(best, opts)
	local parts = best.parts
	-- the first main clause's subject, for the subordinate clauses that share it
	local mainClause
	for _, p in ipairs(parts) do
		if p.kind == "main" and not mainClause then mainClause = p.clause end
	end
	local mainKey = mainClause and SubjectKey(mainClause)
	local mainPron = mainClause and mainClause.subj and mainClause.subj.pron
	local lone = mainClause == nil

	local subs, mains = {}, {}
	for _, p in ipairs(parts) do
		if p.kind == "sub" then
			local form = G.SUB_FORMS[p.conj]
			if not form then Fail("subordinator " .. tostring(p.conj)) end
			local cl = p.clause
			local lead = cl.subj and cl.subj.pron
			local speakerGroup = { i = true, we = true }
			local same = (lead ~= nil and (lead == mainPron or (speakerGroup[lead] and speakerGroup[mainPron or ""])))
				or (lead == "you" and mainPron == nil and mainClause ~= nil and (mainClause.kind == "imp" or mainClause.kind == "lets"))
				or (lead == "you" and lone)
			local o = { style = form.style, subordinate = true, sameSubject = same and not opts.keepSubject,
				keepSubject = opts.keepSubject, formOverride = form.formOverride, invertNegation = form.invertNegation, noQuestionMark = true }
			local text = G.Clause(cl, o)
			if form.because and text:sub(-3) == "の" then text = text:sub(1, -4) .. "な" end
			subs[#subs + 1] = (form.before or "") .. text .. form.after
		else
			mains[#mains + 1] = p
		end
	end
	if #mains == 0 then
		-- only subordinate clauses: no trailing comma (the sentence joins its segments itself)
		local joined = table.concat(subs)
		if joined:sub(-3) == "、" then joined = joined:sub(1, -4) end
		return joined, false
	end

	-- "stay behind the tank so you don't die": the purpose goes in front of the request
	if #mains == 2 and mains[1].clause.kind == "imp" and mains[2].conj == "so" and mains[2].clause.kind == "decl" then
		local cl2 = mains[2].clause
		local lead = cl2.subj and cl2.subj.pron
		local purpose = G.Clause(cl2, { style = "attr", subordinate = true, noQuestionMark = true,
			noSubject = (lead == "you" and not opts.keepSubject) or nil, keepSubject = opts.keepSubject })
		subs[#subs + 1] = purpose .. "ように、"
		mains = { mains[1] }
	end

	-- "we had to wipe and start over": the second verb carries the auxiliary, the first is a plain te-form
	for index, p in ipairs(mains) do
		local prev = mains[index - 1]
		if p.elliptical and prev and prev.clause.vg and p.clause.vg then
			local pv, v = prev.clause.vg, p.clause.vg
			if v.verb and v.verb.infl == nil and not (v.modal or v.haveto or v.goingto or v.ableto or v.perfect or v.prog or v.passive or v.doSupport or v.be)
				and (pv.haveto or pv.modal or pv.goingto or pv.ableto) and pv.verb then
				local inherited = S.CopyState(v)
				for _, key in ipairs({ "modal", "haveto", "goingto", "ableto", "past", "neg" }) do
					if pv[key] then inherited[key] = pv[key] end
				end
				local plain = S.CopyState(pv)
				for _, key in ipairs({ "modal", "haveto", "goingto", "ableto", "past", "neg" }) do plain[key] = nil end
				local copyPrev = {}
				for k, val in pairs(prev.clause) do copyPrev[k] = val end
				copyPrev.vg = plain
				local copyCur = {}
				for k, val in pairs(p.clause) do copyCur[k] = val end
				copyCur.vg = inherited
				prev = { conj = prev.conj, kind = prev.kind, clause = copyPrev, elliptical = prev.elliptical }
				mains[index - 1] = prev
				mains[index] = { conj = p.conj, kind = p.kind, clause = copyCur, elliptical = p.elliptical }
			end
		end
	end

	local out = {}
	local question = false
	local previous
	for index, p in ipairs(mains) do
		local nextMain = mains[index + 1]
		local nextConj = nextMain and nextMain.conj
		local isLast = nextMain == nil
		local style, suffix = "polite", ""
		if nextConj == "and" then style, suffix = "te", "、"
		elseif nextConj == "but" then style, suffix = "polite", "が、"
		elseif nextConj == "or" then style, suffix = "polite", "、それとも"
		elseif nextConj == "so" then style, suffix = "polite", "ので、"
		elseif nextConj == "then" then style, suffix = "polite", "、それから"
		elseif nextMain then style, suffix = "polite", "、" end
		local cl = p.clause
		-- the same person acting again is not named again
		local drop = p.elliptical or (previous and SubjectKey(cl) ~= nil and SubjectKey(cl) == SubjectKey(previous.clause))
		local o = { style = style, keepSubject = opts.keepSubject, noSubject = drop or nil }
		local text, asked = G.Clause(cl, o)
		if suffix == "ので、" then text = SoForm(text) end
		if style == "te" and (text:sub(-6) == "です" or text:sub(-6) == "ます" or text:sub(-3) == "た") then
			-- no te-form for this predicate: join with a comma instead
			suffix = "、"
		end
		if isLast then
			question = asked
			if opts.questionMark and not asked then
				text = text .. "か"
				question = true
			end
		end
		out[#out + 1] = text .. suffix
		previous = p
	end
	return table.concat(subs) .. table.concat(out), question
end

-- ---------------------------------------------------------------------------------------
-- Entry point from Grammar.lua
-- ---------------------------------------------------------------------------------------

local GRAMMAR_ONLY = { to = true, ["let's"] = true, let = true, ["'s"] = true, please = true, of = true, as = true, there = true,
	["than"] = true, that = true }

-- Count the words of a segment the way Grammar.lua does: known, unknown, and names that are
-- neither.
local function CountWords(items, stats)
	for _, item in ipairs(items) do
		if item.kind == "word" then
			local known = item.entry or L.NUMWORD[item.w] or L.BE[item.w] or L.DO[item.w] or L.HAVE[item.w] or L.MODAL[item.w] or L.NEG[item.w]
				or L.ART[item.w] or L.CO[item.w] or L.SUB[item.w] or GRAMMAR_ONLY[item.w]
			if known then
				stats.known = stats.known + 1
			elseif item.orig and item.orig:match("^[A-Z]") and not item.sentenceStart then
				-- a name
			else
				stats.unknown = stats.unknown + 1
			end
		end
	end
end

-- A PvP call: a verb, adjective, adverb or expression that only the Cyrodiil dictionary defines
-- (inc, lit, open, def, hk). The old engine has those calls by heart.
local function UsesCyrodiilCall(items)
	local cyro = T.cyrodiilLexicon
	if not cyro then return false end
	for _, item in ipairs(items) do
		if item.kind == "word" and item.entry then
			local c = cyro[item.w] or (item.base and cyro[item.base])
			if c then
				local function Call(e) return e and (e.pos == "v" or e.pos == "a" or e.pos == "x" or e.pos == "adv") end
				if item.entry == c and Call(c) then return true end
				for _, alt in pairs(item.entry.alts or {}) do
					if alt == c and Call(c) then return true end
				end
				-- the same word is also in the general dictionary: the Cyrodiil meaning wins only with priority
				if T.cyrodiilPriority and Call(c) then return true end
			end
		end
	end
	return false
end

-- A word nothing here knows, in lower case: the old engine keeps such a line honest.
local function HasUnknownWord(items)
	for _, item in ipairs(items) do
		if item.kind == "word" and not item.entry then
			local w = item.w
			local grammar = L.NUMWORD[w] or L.BE[w] or L.DO[w] or L.HAVE[w] or L.MODAL[w] or L.NEG[w] or L.ART[w] or L.CO[w] or L.SUB[w] or GRAMMAR_ONLY[w]
			if not grammar then
				local name = item.orig and item.orig:match("^[A-Z]") and not item.sentenceStart
				if not name then return true end
			end
		end
	end
	return false
end

-- "thank you so much for helping me": ありがとう with what it is for, said the way a person says it.
local THANKS_NP = { help = "助けてくれて", hand = "手伝ってくれて", support = "サポートしてくれて", patience = "待ってくれて" }
local THANKS_INTENSIFIER = { { "so", "much" }, { "a", "lot" }, { "very", "much" }, { "again" }, { "all" } }
local function ThanksFor(prefix, rest)
	if #prefix ~= 1 or not prefix[1]:find("ありがとう", 1, true) then return nil end
	local k, strong = 1, false
	local thanks = prefix[1]
	if thanks:sub(1, 9) == "本当に" then
		strong = true
		thanks = thanks:sub(10)
	end
	while rest[k] do
		local matched
		for _, words in ipairs(THANKS_INTENSIFIER) do
			local ok = true
			for offset, word in ipairs(words) do
				local item = rest[k + offset - 1]
				if not (item and item.kind == "word" and item.w == word) then ok = false break end
			end
			if ok then matched = #words break end
		end
		if not matched then break end
		strong = true
		k = k + matched
	end
	if not (rest[k] and rest[k].kind == "word" and rest[k].w == "for") or not rest[k + 1] then return nil end
	local remainder = {}
	for index = k + 1, #rest do remainder[#remainder + 1] = rest[index] end
	local parser = S.NewParser(remainder)
	local body
	for _, g in ipairs(parser:Gerund(1)) do
		if g.stop == #remainder + 1 and g.node.vg and g.node.vg.verb then
			local comps = {}
			for _, comp in ipairs(g.node.comps or {}) do
				if not (comp.kind == "np" and (comp.node.pron == "me" or comp.node.pron == "us")) then comps[#comps + 1] = comp end
			end
			local node = { cat = g.node.cat, vg = g.node.vg, comps = comps }
			body = G.GerText(node, { style = "te", subordinate = true, noSubject = true }) .. "くれて"
			break
		end
	end
	if not body then
		for _, np in ipairs(parser:NP(1)) do
			if np.stop == #remainder + 1 and not np.node.wh and not np.node.gerund then
				body = THANKS_NP[np.node.w or ""] or (G.NPText(np.node, "object", {}) .. "")
				break
			end
		end
	end
	if not body or body == "" then return nil end
	return (strong and "本当に" or "") .. body .. thanks
end

-- Translate one segment, or return nil to hand it to the old engine.
function S.Translate(items, stats, questionMark, keepSubject, isLast)
	if not S.enabled then return nil end
	local rest, prefix, suffix = {}, {}, {}
	for _, item in ipairs(items) do
		if item.kind == "word" and item.entry and item.entry.pos == "x" then
			local before = rest[#rest]
			if before and before.kind == "word" and L.BE[before.w] then return nil end
			if #rest == 0 then prefix[#prefix + 1] = item.entry.ja else suffix[#suffix + 1] = item.entry.ja end
		elseif item.kind == "word" and item.w == "please" then
			-- only makes a request politer; the command is polite already
		elseif item.kind == "punct" then
			return nil
		else
			rest[#rest + 1] = item
		end
	end
	-- "like twenty minutes": a hedge
	do
		local kept = {}
		for index, item in ipairs(rest) do
			local following = rest[index + 1]
			if item.kind == "word" and item.w == "like" and following and (following.kind == "num" or (following.kind == "word" and L.NUMWORD[following.w])) then
				-- dropped
			else
				kept[#kept + 1] = item
			end
		end
		rest = kept
	end
	-- "fifty thousand", "twenty five": one number
	do
		local TENS = { twenty = true, thirty = true, forty = true, fifty = true, sixty = true, seventy = true, eighty = true, ninety = true }
		local MULTIPLIER = { hundred = 100, thousand = 1000 }
		local joined, index = {}, 1
		while index <= #rest do
			local item = rest[index]
			local value = item.kind == "word" and L.NUMWORD[item.w] and not T.userLexicon[item.w] and item.w ~= "dozen"
			local stop = index
			if value then
				local previous = item.w
				local total, current = 0, 0
				local function Take(word)
					local n = L.NUMWORD[word]
					if MULTIPLIER[word] then
						if current == 0 then current = 1 end
						if word == "hundred" then current = current * 100 else total = total + current * 1000 current = 0 end
					else
						current = current + n
					end
				end
				Take(item.w)
				while true do
					local nextItem = rest[stop + 1]
					local word = nextItem and nextItem.kind == "word" and nextItem.w
					if not (word and L.NUMWORD[word] and not T.userLexicon[word]) then break end
					local fits = MULTIPLIER[word] or (TENS[previous] and L.NUMWORD[word] >= 1 and L.NUMWORD[word] <= 9)
						or (MULTIPLIER[previous] and not MULTIPLIER[word] and L.NUMWORD[word] < 100)
					if not fits then break end
					Take(word)
					previous = word
					stop = stop + 1
				end
				if stop > index then
					local number = total + current
					local text = tostring(number)
					local formatted
					if number >= 10000 then
						formatted = tostring(math.floor(number / 10000)) .. "万" .. (number % 10000 > 0 and tostring(number % 10000) or "")
					end
					joined[#joined + 1] = { kind = "num", v = text, formatted = formatted, orig = text }
					index = stop + 1
				else
					joined[#joined + 1] = item
					index = index + 1
				end
			else
				joined[#joined + 1] = item
				index = index + 1
			end
		end
		rest = joined
	end
	if #rest == 0 then return nil end
	if HasUnknownWord(rest) then return nil end
	if UsesCyrodiilCall(rest) then return nil end
	-- "any tanks online?": the old engine reads these elliptical questions
	if rest[1].kind == "word" and rest[1].w == "any" then return nil end
	if #prefix == 1 and #suffix == 0 and rest[1].kind == "word" then
		local ok, text = pcall(ThanksFor, prefix, rest)
		if ok and text then
			CountWords(items, stats)
			return text, false
		end
	end
	-- "thanks for the help", "what do you think about this": an expression and its object
	if #prefix > 0 and rest[1].kind == "word" and rest[1].entry and rest[1].entry.pos == "prep" then return nil end
	-- "let me know when you are ready": the old engine puts the condition in front of the request
	if #prefix > 0 and rest[1].kind == "word" and L.SUB[rest[1].w] then return nil end
	if #prefix > 0 and rest[1].kind == "word" and (rest[1].w == "for" or rest[1].w == "to" or rest[1].w == "about" or rest[1].w == "of" or rest[1].w == "on") then return nil end

	local ok, result = pcall(function()
		local best = S.Parse(rest)
		if not best then return nil end
		local text, question = G.Utterance(best, { questionMark = questionMark and isLast ~= false, keepSubject = keepSubject })
		if not text or text == "" then return nil end
		return { text = text, question = question }
	end)
	if not ok then
		S.lastError = type(result) == "table" and result.syntaxGenFail or tostring(result)
		return nil
	end
	if not result then
		S.lastError = "no parse"
		return nil
	end
	S.lastError = nil
	local text = result.text
	local pieces = {}
	if #prefix > 0 then pieces[#pieces + 1] = table.concat(prefix, "、") end
	pieces[#pieces + 1] = text
	if #suffix > 0 then pieces[#pieces + 1] = table.concat(suffix, "、") end
	local joined = T.Join(pieces, "、")
	CountWords(items, stats)
	return joined, result.question
end
