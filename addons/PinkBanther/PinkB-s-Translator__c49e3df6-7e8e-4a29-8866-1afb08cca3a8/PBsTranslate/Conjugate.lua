-- PB's Translate -- Japanese predicate building
--
-- English grammar is carried almost entirely by word order and auxiliaries; Japanese carries
-- it on the end of the verb. So everything the parser learns about a clause -- tense,
-- negation, "can", "want to", "please" -- ends up here, as a suffix on one predicate.
--
-- Output is always polite (desu/masu). Chat addressed to strangers reads naturally in it, and
-- it is the register in which a rough word-by-word rendering sounds least rude.
--
-- A verb entry carries its dictionary form and a class:
--
--   1   ichidan    食べる -> 食べます
--   5   godan      行く   -> 行きます     (the last kana moves along its row)
--   s   suru       参加する -> 参加します
--   k   kuru       来る   -> 来ます
--   i   i-adjective used as a predicate    欲しい -> 欲しいです
--   na  na-adjective / noun predicate      好き   -> 好きです
--
-- Kana are three bytes in UTF-8, and every ending this file edits is a kana, so string.sub
-- with -3 is the whole of the Unicode handling it needs. Lua 5.1: no utf8 library on the
-- client.

PBsTranslate = PBsTranslate or {}
local T = PBsTranslate

local GODAN = {
	--          i       a       e       te        ta
	["う"] = { "い", "わ", "え", "って", "った" },
	["く"] = { "き", "か", "け", "いて", "いた" },
	["ぐ"] = { "ぎ", "が", "げ", "いで", "いだ" },
	["す"] = { "し", "さ", "せ", "して", "した" },
	["つ"] = { "ち", "た", "て", "って", "った" },
	["ぬ"] = { "に", "な", "ね", "んで", "んだ" },
	["ぶ"] = { "び", "ば", "べ", "んで", "んだ" },
	["む"] = { "み", "ま", "め", "んで", "んだ" },
	["る"] = { "り", "ら", "れ", "って", "った" },
}

local function SplitLast(word)
	return word:sub(1, -4), word:sub(-3)
end

local function SuruBase(word)
	if word:sub(-6) == "する" then
		return word:sub(1, -7)
	end
	return word
end

-- 行く is the one godan verb whose te-form breaks its row.
local function IsIku(word)
	return word:sub(-6) == "行く" or word:sub(-6) == "いく"
end

-- 来る in kana compounds (持ってくる) changes its vowel: き / こ. The kanji 来 hides that.
local function KuruStem(word, vowel)
	if word:sub(-6) == "くる" then
		return word:sub(1, -7) .. vowel
	end
	return (word:sub(1, -4))
end

-- The masu stem: 食べ / 行き / 参加し / 来
local function Stem(word, class)
	if class == "1" then
		return (SplitLast(word))
	elseif class == "5" then
		local head, last = SplitLast(word)
		local row = GODAN[last]
		return row and (head .. row[1]) or head
	elseif class == "s" then
		return SuruBase(word) .. "し"
	elseif class == "k" then
		return KuruStem(word, "き")
	end
	return word
end

-- What ない attaches to: 食べ / 行か / 参加し / 来
local function NaiStem(word, class)
	if class == "k" then
		return KuruStem(word, "こ")
	end
	if class == "5" then
		local head, last = SplitLast(word)
		local row = GODAN[last]
		return row and (head .. row[2]) or head
	end
	return Stem(word, class)
end

local function TeForm(word, class)
	if class == "k" then
		return KuruStem(word, "き") .. "て"
	elseif class == "1" then
		return (SplitLast(word)) .. "て"
	elseif class == "5" then
		if IsIku(word) then
			return (SplitLast(word)) .. "って"
		end
		local head, last = SplitLast(word)
		local row = GODAN[last]
		return row and (head .. row[4]) or word
	elseif class == "s" then
		return SuruBase(word) .. "して"
	end
	return word
end

-- The potential form's masu stem, which is itself ichidan: 食べられ / 行け / 参加でき / 来られ
local function PotentialStem(word, class)
	if class == "k" then
		return KuruStem(word, "こ") .. "られ"
	elseif class == "1" then
		return (SplitLast(word)) .. "られ"
	elseif class == "5" then
		local head, last = SplitLast(word)
		local row = GODAN[last]
		return row and (head .. row[3]) or head
	elseif class == "s" then
		-- タンクをする -> タンクができる
		local base = SuruBase(word)
		if base:sub(-3) == "を" then
			base = base:sub(1, -4) .. "が"
		end
		return base .. "でき"
	end
	return word
end

local O_ROW = { ["う"]="お", ["く"]="こ", ["ぐ"]="ご", ["す"]="そ", ["つ"]="と", ["ぬ"]="の", ["ぶ"]="ぼ", ["む"]="も", ["る"]="ろ" }
local function Volitional(word, class)
	if class == "s" then return SuruBase(word) .. "しよう" end
	if class == "k" then return KuruStem(word, "こ") .. "よう" end
	local head, last = SplitLast(word)
	if class == "1" then return head .. "よう" end
	return head .. (O_ROW[last] or last) .. "う"
end

T.Stem = Stem
T.NaiStem = NaiStem
T.TeForm = TeForm
T.PotentialStem = PotentialStem
T.KuruStem = KuruStem
T.GODAN = GODAN

-- ますの活用 on any masu stem.
local function Masu(stem, past, negative)
	if past and negative then
		return stem .. "ませんでした"
	elseif past then
		return stem .. "ました"
	elseif negative then
		return stem .. "ません"
	end
	return stem .. "ます"
end

-- です after a noun or a na-adjective.
local function Desu(word, past, negative)
	if past and negative then
		return word .. "ではありませんでした"
	elseif past then
		return word .. "でした"
	elseif negative then
		return word .. "ではありません"
	end
	return word .. "です"
end

-- です after an i-adjective. いい conjugates on its older form よい.
local function AdjectiveDesu(word, past, negative)
	if not past and not negative then
		return word .. "です"
	end
	if word == "いい" then
		word = "よい"
	end
	local head = word:sub(-3) == "い" and word:sub(1, -4) or word
	if past and negative then
		return head .. "くなかったです"
	elseif past then
		return head .. "かったです"
	elseif negative then
		return head .. "くないです"
	end
	return word .. "です"
end

T.Masu = Masu
T.Desu = Desu
T.AdjectiveDesu = AdjectiveDesu

-- The predicate for a noun, adjective or stative entry.
--   kind  "n" | "i" | "na"
function T.Copula(word, kind, form)
	form = form or {}
	if form.mode == "imperative" and kind ~= "rel" then
		if kind == "i" then
			local stem = (word == "いい" and "よい" or word):sub(1, -4)
			return stem .. (form.negative and "くならないでください" or "くなってください")
		end
		return word .. (form.negative and "でいないでください" or "でいてください")
	end
	if kind ~= "rel" and (form.mode == "must" or form.mode == "have_to" or form.mode == "should" or form.mode == "need") then
		local isI = kind == "i"
		local stem = isI and ((word == "いい" and "よい" or word):sub(1, -4)) or word
		local plain = isI and word or (word .. "である")
		local result
		if form.mode == "must" or form.mode == "have_to" then
			if form.negative and form.mode == "must" then
				result = stem .. (isI and "くてはいけません" or "であってはいけません")
			elseif form.negative then
				result = stem .. (isI and "くなくてもいいです" or "でなくてもいいです")
			else
				result = stem .. (isI and "くなければなりません" or "でなければなりません")
			end
		elseif form.mode == "should" then
			if isI then
				result = (form.negative and (stem .. "くない") or word) .. "ほうがいいです"
			else
				result = plain .. (form.negative and "べきではありません" or "べきです")
			end
		else
			result = plain .. (form.negative and "必要はありません" or "必要があります")
		end
		return form.plain and T.ToPlain(result) or result
	end
	if (form.plain or form.conditional) and kind == "rel" then
		return T.ToPlain(T.RelativePredicate(word, form))
	end
	if form.plain or form.conditional then
		return T.PlainPredicate({ ja = word, class = kind == "i" and "i" or "na" },
			{ past = form.past, negative = form.negative, conditional = form.conditional, noun = kind == "n" })
	end
	if form.mode == "become" then
		-- "want to be", "will be" with a want: 強くなりたいです / 騎士になりたいです
		local target
		if kind == "i" then
			local w = word == "いい" and "よい" or word
			target = w:sub(1, -4) .. "く"
		else
			target = word .. "に"
		end
		return target .. (form.negative and "なりたくないです" or "なりたいです")
	end
	if kind == "i" then
		return AdjectiveDesu(word, form.past, form.negative)
	end
	if kind == "rel" then
		return T.RelativePredicate(word, form)
	end
	return Desu(word, form.past, form.negative)
end

-- Predicate for an adjective written as a verb form or a の/な noun:
--   乾いた -> 乾いています, できる -> できます, 頼りになる -> 頼りになります, 魔法の -> 魔法です
function T.RelativePredicate(word, form)
	local last = word:sub(-3)
	if last == "た" then
		return Masu(word:sub(1, -4) .. "てい", form.past, form.negative)
	elseif last == "だ" then
		-- 富んだ -> 富んでいます
		return Masu(word:sub(1, -4) .. "でい", form.past, form.negative)
	elseif last == "る" then
		local tail = word:sub(-6)
		if tail == "する" then
			return Masu(word:sub(1, -7) .. "し", form.past, form.negative)
		elseif tail == "ある" or tail == "なる" or tail == "かる" or tail == "わる" then
			return Masu(word:sub(1, -4) .. "り", form.past, form.negative)
		end
		return Masu(word:sub(1, -4), form.past, form.negative)
	elseif last == "の" or last == "な" then
		return Desu(word:sub(1, -4), form.past, form.negative)
	end
	return Desu(word, form.past, form.negative)
end

-- The predicate for a verb entry.
--
-- form.mode is one of
--   nil          plain statement                  行きます
--   progressive  be + -ing                        行っています
--   want         want to / would like to          行きたいです
--   can          can / be able to                 行けます
--   request      can you / could you / will you   行ってもらえます   (the clause adds か)
--   imperative   a bare verb, or please           行ってください
--   lets         let's                            行きましょう
--   must         must (negative: prohibition)     行かなければなりません
--   have_to      have to (negative: optional)     行かなければなりません
--   should       should                           行くべきです
--   need         need to                          行く必要があります
--   try          try to                           行ってみます
--   intend       be going to                      行くつもりです
-- Polite endings that follow an ichidan-shaped stem, and their plain forms. Every mode
-- except the plain statement ends in one of these, so a subordinate clause can take the
-- polite predicate and swap the ending: 来ています -> 来ている.
local PLAIN_ENDINGS = {
	{ "なくてもいいです", "なくてもいい" },
	{ "ませんでした", "なかった" },
	{ "ました", "た" },
	{ "ません", "ない" },
	{ "ます", "る" },
	{ "たくなかったです", "たくなかった" },
	{ "たかったです", "たかった" },
	{ "たくないです", "たくない" },
	{ "たいです", "たい" },
	{ "なければなりません", "なければならない" },
	{ "かもしれません", "かもしれない" },
	{ "ではありません", "ではない" },
	{ "つもりはありません", "つもりはない" },
	{ "必要はありません", "必要はない" },
	{ "必要があります", "必要がある" },
	{ "くないです", "くない" },
	{ "です", "だ" },
}

local function ToPlain(text)
	for _, pair in ipairs(PLAIN_ENDINGS) do
		local polite, plain = pair[1], pair[2]
		if #text >= #polite and text:sub(-#polite) == polite then
			return text:sub(1, #text - #polite) .. plain
		end
	end
	return text
end

T.ToPlain = ToPlain

local PoliteOnlyModes = { imperative = true, request = true, lets = true }

function T.Predicate(entry, form)
	form = form or {}
	if form.aspect and entry.class and entry.class ~= "i" and entry.class ~= "na" and entry.class ~= "rel" then
		local nested = {}
		for key, value in pairs(form) do nested[key] = value end
		nested.aspect = nil
		local ja = form.aspect == "passive" and (T.PassiveStem(entry.ja, entry.class) .. (form.passiveProgressive and "ている" or "る"))
			or (TeForm(entry.ja, entry.class) .. "いる")
		return T.Predicate({ja = ja, class = "1"}, nested)
	end
	if form.conditional and form.mode == "can" then
		return T.PlainPredicate({ja = PotentialStem(entry.ja, entry.class) .. "る", class = "1"}, form)
	end
	if form.plain and form.mode and not PoliteOnlyModes[form.mode] and entry.class ~= "i" and entry.class ~= "na" then
		local polite = T.Predicate(entry, { past = form.past, negative = form.negative, mode = form.mode, passiveProgressive = form.passiveProgressive })
		return ToPlain(polite)
	end
	local word, class = entry.ja, entry.class
	local past, negative, mode = form.past, form.negative, form.mode

	if class == "i" or class == "na" or class == "rel" or class == nil then
		return T.Copula(word, class or "na", form)
	end

	if mode == "progressive" then
		return Masu(TeForm(word, class) .. "い", past, negative)
	elseif mode == "want_person" then
		return TeForm(word, class) .. AdjectiveDesu("ほしい", past, negative)
	elseif mode == "want" then
		local stem = Stem(word, class)
		if past and negative then
			return stem .. "たくなかったです"
		elseif past then
			return stem .. "たかったです"
		elseif negative then
			return stem .. "たくないです"
		end
		return stem .. "たいです"
	elseif mode == "can" then
		return Masu(PotentialStem(word, class), past, negative)
	elseif mode == "request" then
		if negative then
			return NaiStem(word, class) .. "ないでもらえます"
		end
		return TeForm(word, class) .. "もらえます"
	elseif mode == "imperative" then
		if negative then
			return NaiStem(word, class) .. "ないでください"
		end
		return TeForm(word, class) .. "ください"
	elseif mode == "lets" then
		if negative then
			return NaiStem(word, class) .. "ないでおきましょう"
		end
		return Stem(word, class) .. "ましょう"
	elseif mode == "must" or mode == "have_to" then
		if negative then
			if mode == "must" then
				return TeForm(word, class) .. "はいけません"
			end
			return NaiStem(word, class) .. (past and "なくてもよかったです" or "なくてもいいです")
		end
		return NaiStem(word, class) .. (past and "なければなりませんでした" or "なければなりません")
	elseif mode == "should" then
		return word .. (past and (negative and "べきではありませんでした" or "べきでした") or (negative and "べきではありません" or "べきです"))
	elseif mode == "need" then
		return word .. (past and (negative and "必要はありませんでした" or "必要がありました") or (negative and "必要はありません" or "必要があります"))
	elseif mode == "try_progressive" then
		return Masu(Volitional(word, class) .. "としてい", past, negative)
	elseif mode == "try" then
		return Masu(TeForm(word, class) .. "み", past, negative)
	elseif mode == "intend" then
		return word .. (negative and "つもりはありません" or "つもりです")
	elseif mode == "maybe" then
		return T.PlainPredicate(entry, {past = past, negative = negative}) .. "かもしれません"
	elseif mode == "could_perfect" then
		return ToPlain(Masu(PotentialStem(word, class), true, false))
			.. (negative and "はずがありません" or "かもしれません")
	elseif mode == "deduction" then
		return T.PlainPredicate(entry, {past = past, negative = negative}) .. "に違いありません"
	elseif mode == "counterfactual" then
		return T.PlainPredicate(entry, {past = past, negative = negative}) .. "でしょう"
	elseif mode == "likes" then
		return word .. (negative and "のは好きではありません" or "のが好きです")
	elseif mode == "experience" then
		-- "have (never) seen" -> 見たことがあります / 見たことがありません
		return T.PlainPredicate(entry, { past = true }) .. (negative and "ことがありません" or "ことがあります")
	elseif mode == "passive" then
		if not past or form.passiveProgressive then
			-- "the keep is flipped" is a state: 奪われています
			return Masu(T.PassiveStem(word, class) .. "てい", past, negative)
		end
		return Masu(T.PassiveStem(word, class), past, negative)
	end

	if form.plain or form.conditional then
		return T.PlainPredicate(entry, form)
	end

	-- 知っている is the one state verb whose negative drops the ている: 知りません.
	if negative and word:sub(-15) == "知っている" then
		return Masu(word:sub(1, -16) .. "知り", past, negative)
	end

	return Masu(Stem(word, class), past, negative)
end

-- 食べられ / 倒され / 参加され / 来られ
function T.PassiveStem(word, class)
	if class == "1" or class == "k" then
		return (SplitLast(word)) .. "られ"
	elseif class == "5" then
		local head, last = SplitLast(word)
		local row = GODAN[last]
		if last == "う" then
			return head .. "われ"
		end
		return row and (head .. row[2] .. "れ") or head
	elseif class == "s" then
		return SuruBase(word) .. "され"
	end
	return word
end

local function PlainPast(word, class)
	if class == "k" then
		return KuruStem(word, "き") .. "た"
	elseif class == "1" then
		return (SplitLast(word)) .. "た"
	elseif class == "5" then
		if IsIku(word) then
			return (SplitLast(word)) .. "った"
		end
		local head, last = SplitLast(word)
		local row = GODAN[last]
		return row and (head .. row[5]) or word
	elseif class == "s" then
		return SuruBase(word) .. "した"
	end
	return word
end

T.PlainPast = PlainPast

-- Plain (dictionary-register) forms, for the inside of a subordinate clause, where polite
-- forms are wrong: 行くとき, 行ったら.
--   form.conditional  -> the たら form
function T.PlainPredicate(entry, form)
	local word, class = entry.ja, entry.class
	local past, negative = form.past, form.negative

	if class == "i" or class == "na" or class == nil then
		local isI = class == "i"
		local w = (isI and word == "いい") and "よい" or word
		local head = isI and w:sub(1, -4) or w
		if form.conditional then
			if negative then
				return isI and (head .. "くなかったら") or (w .. "でなかったら")
			end
			return isI and (head .. "かったら") or (w .. "だったら")
		end
		if past and negative then
			return isI and (head .. "くなかった") or (w .. "ではなかった")
		elseif past then
			return isI and (head .. "かった") or (w .. "だった")
		elseif negative then
			return isI and (head .. "くない") or (w .. "ではない")
		end
		return isI and word or (w .. (form.noun and "の" or "な"))
	end

	if form.conditional then
		if negative then
			return NaiStem(word, class) .. "なかったら"
		end
		return PlainPast(word, class) .. "ら"
	end
	if past and negative then
		return NaiStem(word, class) .. "なかった"
	elseif past then
		return PlainPast(word, class)
	elseif negative then
		return NaiStem(word, class) .. "ない"
	end
	return word
end
