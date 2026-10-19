-- PB's Translate -- Japanese to English
--
-- Used by /en and by the "Japanese to English" chat direction. Japanese has no spaces, drops
-- its subjects and puts the verb last, so the result is a rough reading, not a translation.
--
-- Two sources of words:
--
--   * the hand-written tables below -- fixed expressions (ありがとう -> ty) and Cyrodiil
--     callouts (チャルマン砦の正門が攻撃されている -> chal fd lit), in the short forms chat uses.
--     They always win.
--   * the English -> Japanese dictionary read backwards, built on first use: nouns,
--     adjectives, adverbs and expressions by their Japanese, and every verb in the forms
--     Conjugate.lua would make of it (食べる 食べた 食べない 食べたい 食べられる ...), so both
--     directions agree on what a verb looks like.
--
-- The sentence is cut into pieces by the reading that leaves the fewest characters unknown
-- (T.JaSegment), then read clause by clause: は/が mark the subject, を the object,
-- に/で/へ/から a place, and the predicate -- a verb, an adjective, or a noun with です --
-- puts them in English order. Anything not in either source is reported back, never guessed.

PBsTranslate = PBsTranslate or {}
local T = PBsTranslate

-- ---------------------------------------------------------------------------------------
-- Hand-written tables
-- ---------------------------------------------------------------------------------------

-- Whole expressions. Matched as pieces, so "了解、向かってる" is two of them.
local EXPRESSIONS = {
	["ありがとうございます"] = "thank you", ["ありがとう"] = "ty", ["サンキュー"] = "ty",
	["グループありがとう"] = "ty for group", ["蘇生ありがとう"] = "ty for rez",
	["よろしくお願いします"] = "hi, nice to meet you", ["よろしく"] = "hi",
	["お疲れ様でした"] = "gg", ["お疲れさまでした"] = "gg", ["お疲れ様"] = "gg", ["おつかれ"] = "gg",
	["いい戦いでした"] = "gf", ["ナイス"] = "nice", ["ナイスプレイ"] = "wp",
	["こんにちは"] = "hello", ["こんばんは"] = "good evening", ["おはよう"] = "good morning",
	["おはようございます"] = "good morning", ["おやすみ"] = "good night", ["おやすみなさい"] = "good night",
	["またね"] = "cya", ["さようなら"] = "bye", ["また明日"] = "see you tomorrow",
	["ごめんなさい"] = "sorry", ["ごめん"] = "sorry", ["すみません"] = "sorry", ["私のミスです"] = "my bad",
	["了解"] = "roger", ["了解です"] = "roger", ["わかりました"] = "ok", ["分かりました"] = "ok", ["OK"] = "ok",
	["はい"] = "yes", ["いいえ"] = "no", ["大丈夫"] = "np", ["問題ない"] = "np",
	["ちょっと待って"] = "wait a sec", ["待って"] = "wait", ["すぐ戻ります"] = "brb", ["すぐ戻る"] = "brb",
	["離席"] = "afk", ["離席します"] = "afk", ["戻りました"] = "back", ["もう寝ます"] = "going to bed",
	["おめでとう"] = "gz", ["おめでとうございます"] = "congrats",
	["招待してください"] = "inv pls", ["招待して"] = "inv pls", ["グループ募集"] = "lfg",
	["グループメンバーを探している"] = "lfg", ["蘇生してください"] = "rez pls", ["蘇生して"] = "rez pls",
	["助けて"] = "help", ["助けてください"] = "help pls",
	["向かっている途中"] = "omw", ["向かっています"] = "omw", ["向かってる"] = "omw", ["今行きます"] = "omw",
	["破城槌に乗って"] = "ram on", ["突入"] = "go in", ["撤退"] = "retreat", ["後退"] = "fall back",
	["散開"] = "spread", ["固まって"] = "stack", ["集合"] = "stack", ["待機"] = "hold",
	["英語は話せません"] = "I don't speak English", ["英語は苦手です"] = "my English is not good",
	["日本人です"] = "I'm Japanese", ["翻訳アドオンを使っています"] = "I'm using a translation add-on",
}

-- Everyday chat the dictionary does not read well on its own.
for japanese, english in pairs({
	["草"] = "lol", ["笑"] = "lol", ["ｗｗ"] = "lol", ["ｗｗｗ"] = "lol", ["やばい"] = "omg", ["ヤバい"] = "omg",
	["マジ"] = "seriously", ["マジで"] = "seriously", ["おつ"] = "gg", ["乙"] = "gg", ["よろ"] = "hi",
	["ドンマイ"] = "nt", ["いいね"] = "nice",
	["お腹すいた"] = "I'm hungry", ["お腹空いた"] = "I'm hungry", ["腹減った"] = "I'm hungry",
	["準備できた"] = "ready", ["準備できました"] = "ready", ["準備OK"] = "ready", ["準備完了"] = "ready",
	["準備はいいですか"] = "ready?", ["準備いい"] = "ready?",
	["助かりました"] = "that helped, ty", ["助かった"] = "that helped, ty", ["助かる"] = "that helps, ty",
	["ありがとうございました"] = "thank you", ["最高"] = "awesome", ["最高です"] = "awesome",
}) do
	EXPRESSIONS[japanese] = english
end

-- Nouns, with the English chat uses for them.
local NOUNS = {
	-- keeps, outposts, towns
	["チャルマン砦"] = "chal", ["アリウス砦"] = "arrius", ["キングクレスト砦"] = "kc", ["ファラガット砦"] = "farra",
	["ブルーロード砦"] = "brk", ["ドレイクロー砦"] = "drake", ["セヤヌス基地"] = "sej", ["ハルルン基地"] = "ho",
	["ブラックブート砦"] = "bb", ["ブラッドメイン砦"] = "bm", ["フェアユール砦"] = "fare", ["ローベック砦"] = "roe",
	["アレッシア砦"] = "alessia", ["ブリンドル砦"] = "brindle", ["ニケリ基地"] = "nikel", ["カーマラ基地"] = "carmala",
	["ウォーデン砦"] = "warden", ["レイレス砦"] = "rayles", ["グレイドミスト砦"] = "glade", ["アッシュ砦"] = "ash",
	["アレスウェル砦"] = "ales", ["ドラゴンクロー砦"] = "dragon", ["侵入者の基地"] = "bleaks",
	["ウィンターズ・ピークス基地"] = "wp", ["ブルーマの街"] = "bruma", ["ブルーマ"] = "bruma",
	["クロップスの街"] = "cropsford", ["ヴラスタルスの街"] = "vlastarus", ["インペリアルシティ"] = "ic",
	["チャルマン"] = "chal", ["アリウス"] = "arrius", ["キングクレスト"] = "kc", ["ファラガット"] = "farra",
	["ブルーロード"] = "brk", ["ドレイクロー"] = "drake", ["ブラックブート"] = "bb", ["ブラッドメイン"] = "bm",
	["フェアユール"] = "fare", ["ローベック"] = "roe", ["アレッシア"] = "alessia", ["ブリンドル"] = "brindle",
	["グレイドミスト"] = "glade", ["アレスウェル"] = "ales", ["ドラゴンクロー"] = "dragon",
	-- keep structure and resources
	["正門"] = "fd", ["裏門"] = "bd", ["内門"] = "inner", ["内郭の扉"] = "ifd", ["外壁"] = "outer",
	["通用門"] = "postern", ["壁"] = "wall", ["門"] = "door", ["旗"] = "flag",
	["資源"] = "rss", ["リソース"] = "rss", ["農場"] = "farm", ["鉱山"] = "mine", ["製材所"] = "lm",
	["鉱山サイド"] = "ms", ["製材所サイド"] = "ls", ["農場サイド"] = "fs", ["マイルゲート"] = "milegate", ["橋"] = "bridge",
	-- siege and camps
	["破城槌"] = "rams", ["燃え盛る油"] = "oils", ["油"] = "oils", ["攻城兵器"] = "siege",
	["カタパルト"] = "catas", ["トレビュシェット"] = "trebs", ["バリスタ"] = "ballistas", ["肉袋"] = "meatbags",
	["前線キャンプ"] = "camp", ["テント"] = "camp", ["キャンプ"] = "camp", ["修理キット"] = "repair kits",
	["塁壁石工修理キット"] = "wall repair kits", ["扉維持用木工修理キット"] = "door repair kits",
	-- the war
	["皇帝"] = "emp", ["星霜の書"] = "scroll", ["ヴォレンドラング"] = "hammer", ["トランシタスの祠"] = "transitus",
	["大集団"] = "zerg", ["ボールグループ"] = "ball group", ["敵"] = "enemy", ["ボマー"] = "bomber",
	["ガンカー"] = "ganker", ["ドミニオン"] = "ad", ["カバナント"] = "dc", ["パクト"] = "ep",
	["アルドメリ・ドミニオン"] = "ad", ["ダガーフォール・カバナント"] = "dc", ["エボンハート・パクト"] = "ep",
	["グループリーダー"] = "crown", ["クラウン"] = "crown", ["リーダー"] = "crown",
	-- roles and group
	["タンク"] = "tank", ["ヒーラー"] = "healer", ["DPS"] = "dps", ["グループ"] = "group", ["みんな"] = "everyone",
	["私"] = "me", ["ここ"] = "here", ["そこ"] = "there", ["ヒール"] = "heal", ["回復"] = "heal",
	-- determiners read as the word before the noun: このダンジョン -> this dungeon
	["この"] = "this", ["その"] = "that", ["あの"] = "that", ["どの"] = "which",
}

-- Predicates. {np} is where the noun phrase goes; a template without {np} ignores it.
-- The polite and casual endings players actually type are listed as separate keys.
local PREDICATES = {}

local function Predicate(template, ...)
	for index = 1, select("#", ...) do
		PREDICATES[select(index, ...)] = template
	end
end

Predicate("{np} lit", "攻撃されている", "攻撃されています", "攻撃されてる", "攻撃中", "攻撃を受けている", "攻撃を受けています")
Predicate("{np} ua", "奇襲", "奇襲されている", "奇襲されています")
Predicate("{np} down", "破られた", "破られました", "破られている", "破られています", "壊れた", "壊れました", "壊れています")
Predicate("{np} inc", "インカミング", "来る", "来ます", "来てる", "来ています", "向かってきている", "向かってきます")
Predicate("{np} lost", "奪われた", "奪われました", "取られた", "取られました")
Predicate("stack at {np}", "集合", "集合して", "集合してください", "集まって", "集まってください")
Predicate("push {np}", "攻めて", "攻めてください", "攻める", "攻めます", "攻めろ", "押して")
Predicate("def {np}", "防衛", "防衛して", "防衛してください", "守って", "守ってください", "防衛お願いします")
Predicate("need {np}", "必要", "必要です", "が必要", "が必要です", "欲しい", "欲しいです", "募集")
Predicate("omw to {np}", "向かっている", "向かっています", "向かってる", "向かっている途中", "向かいます")
Predicate("port to {np}", "ポートして", "ポートしてください", "テレポートして", "テレポートしてください")
Predicate("go {np}", "行って", "行ってください", "行こう", "行きます")
Predicate("repair {np}", "修理して", "修理してください", "直して", "直してください")
Predicate("drop {np}", "置いて", "置いてください", "出して", "出してください")
Predicate("retake {np}", "取り戻して", "取り戻してください", "奪還")
Predicate("{np} open", "開いた", "開いています")
Predicate("heal {np}", "回復して", "回復してください", "ヒールして", "ヒールしてください", "ヒールお願いします", "回復お願いします")
Predicate("follow {np}", "についていって", "について行って", "についてきて", "についてきてください")

-- Particles. は/が/も mark the subject, を the object; に/で/へ/から/まで a place.
local PARTICLES = {
	["が"] = "subject", ["は"] = "subject", ["も"] = "subject", ["を"] = "object",
	["に"] = "at", ["で"] = "at", ["へ"] = "to", ["から"] = "from", ["まで"] = "to",
	["の"] = "of", ["と"] = "and",
}
-- Pieces that carry no meaning of their own.
local FILLERS = {
	["ます"] = true, ["ください"] = true, ["よ"] = true, ["ね"] = true, ["な"] = true, ["わ"] = true,
	["！"] = true, ["!"] = true, ["・"] = true, [" "] = true, ["　"] = true, ["〜"] = true,
	["。"] = "break", ["、"] = "break", ["，"] = "break", ["．"] = "break",
	["？"] = "question", ["?"] = "question", ["か"] = "question", ["の？"] = "question",
	["お願いします"] = "please", ["お願い"] = "please", ["おねがい"] = "please",
}
-- です and its relatives, after a noun or an adjective.
local COPULA = {
	["です"] = "present", ["だ"] = "present", ["でした"] = "past", ["だった"] = "past",
	["じゃない"] = "neg", ["ではない"] = "neg", ["じゃないです"] = "neg", ["ではありません"] = "neg",
	["じゃありません"] = "neg", ["じゃなかった"] = "pastneg", ["ではなかった"] = "pastneg",
	["ではありませんでした"] = "pastneg", ["じゃありませんでした"] = "pastneg",
	["でしょう"] = "maybe", ["だろう"] = "maybe",
}

-- Adverbs the reverse dictionary reads as something else (少し -> "bit").
local ADVERBS = {
	["少し"] = "a little", ["ちょっと"] = "a bit", ["すこし"] = "a little", ["もう少し"] = "a little more",
}

-- いる / ある: read as "there is" rather than whatever the dictionary calls them. ない is the
-- negative of ある (not あらない).
local EXISTENCE = {
	["いる"] = "present", ["います"] = "present", ["いた"] = "past", ["いました"] = "past", ["いない"] = "neg",
	["いません"] = "neg", ["いなかった"] = "pastneg", ["ある"] = "present", ["あります"] = "present",
	["あった"] = "past", ["ありました"] = "past", ["ない"] = "neg", ["ありません"] = "neg", ["なかった"] = "pastneg",
	["いる？"] = "present", ["ありません？"] = "neg",
}

-- Every hand-written key, by its Japanese.
local CURATED = {}
local CURATED_MAX = 0
do
	local function Collect(tableOfKeys, kind)
		for key, value in pairs(tableOfKeys) do
			if not CURATED[key] then
				CURATED[key] = { kind = kind, key = key, value = value }
			end
		end
	end
	Collect(PREDICATES, "predicate")
	Collect(EXPRESSIONS, "expression")
	Collect(NOUNS, "noun")
	Collect(PARTICLES, "particle")
	Collect(FILLERS, "filler")
	Collect(COPULA, "copula")
	Collect(ADVERBS, "adverb")
end

-- ---------------------------------------------------------------------------------------
-- Text helpers
-- ---------------------------------------------------------------------------------------

-- Byte length of the UTF-8 character starting at i.
local function CharLength(text, i)
	local byte = text:byte(i)
	if not byte or byte < 0x80 then
		return 1
	elseif byte >= 0xF0 then
		return 4
	elseif byte >= 0xE0 then
		return 3
	elseif byte >= 0xC0 then
		return 2
	end
	return 1
end

local function CountChars(text)
	local count, i = 0, 1
	while i <= #text do
		count = count + 1
		i = i + CharLength(text, i)
	end
	return count
end

local function IsASCIIWordByte(byte)
	return byte and ((byte >= 48 and byte <= 57) or (byte >= 65 and byte <= 90) or (byte >= 97 and byte <= 122)
		or byte == 43 or byte == 45)
end

-- One kana on its own (て, な, ア) says nothing as a dictionary word and would shred the
-- sentence, so the reverse dictionary never keys on one.
local function IsSingleKana(text)
	if #text ~= 3 or text:byte(1) ~= 0xE3 then
		return false
	end
	local b2 = text:byte(2)
	return b2 == 0x81 or b2 == 0x82 or b2 == 0x83
end

-- ---------------------------------------------------------------------------------------
-- English inflection
-- ---------------------------------------------------------------------------------------

local function DoublesFinal(word)
	return #word <= 4 and word:match("^[^aeiou]*[aeiou][bdgklmnprt]$") ~= nil
end

local function PastWord(word)
	local irregular = T.irregularPast and T.irregularPast[word]
	if irregular then return irregular end
	if word:sub(-1) == "e" then return word .. "d" end
	if word:match("[^aeiou]y$") then return word:sub(1, -2) .. "ied" end
	if DoublesFinal(word) then return word .. word:sub(-1) .. "ed" end
	return word .. "ed"
end

local function ParticipleWord(word)
	local irregular = T.irregularParticiple and T.irregularParticiple[word]
	return irregular or PastWord(word)
end

local function IngWord(word)
	if word == "be" then return "being" end
	if word:sub(-2) == "ie" then return word:sub(1, -3) .. "ying" end
	if word:sub(-1) == "e" and not word:match("[eoy]e$") then return word:sub(1, -2) .. "ing" end
	if DoublesFinal(word) then return word .. word:sub(-1) .. "ing" end
	return word .. "ing"
end

-- Inflect the first word of a phrase: "give up" -> "gave up".
local function OnFirst(phrase, inflect)
	local first, rest = phrase:match("^(%S+)(.*)$")
	if not first then return phrase end
	return inflect(first) .. rest
end

local function Be(subject, past)
	if subject == "I" then return past and "was" or "am" end
	if subject == "you" or subject == "we" or subject == "they" then return past and "were" or "are" end
	return past and "was" or "is"
end

-- The English for a verb in one of the forms the reader recognizes.
local function VerbEnglish(base, form, subject)
	if form == "present" or form == "te" then return base
	elseif form == "past" then return OnFirst(base, PastWord)
	elseif form == "neg" then return "don't " .. base
	elseif form == "pastneg" then return "didn't " .. base
	elseif form == "please" then return "please " .. base
	elseif form == "dont" then return "don't " .. base
	elseif form == "lets" then return "let's " .. base
	elseif form == "shall" then return "shall we " .. base
	elseif form == "want" then return "want to " .. base
	elseif form == "wantneg" then return "don't want to " .. base
	elseif form == "wantpast" then return "wanted to " .. base
	elseif form == "wantpastneg" then return "didn't want to " .. base
	elseif form == "prog" then return (subject and (Be(subject) .. " ") or "") .. OnFirst(base, IngWord)
	elseif form == "progneg" then return (subject and (Be(subject) .. " ") or "") .. "not " .. OnFirst(base, IngWord)
	elseif form == "progpast" then return Be(subject, true) .. " " .. OnFirst(base, IngWord)
	elseif form == "can" then return "can " .. base
	elseif form == "cannot" then return "can't " .. base
	elseif form == "could" then return "could " .. base
	elseif form == "couldnt" then return "couldn't " .. base
	elseif form == "passive" then return Be(subject) .. " " .. OnFirst(base, ParticipleWord)
	elseif form == "passivepast" then return Be(subject, true) .. " " .. OnFirst(base, ParticipleWord)
	elseif form == "must" then return "must " .. base
	elseif form == "try" then return "try to " .. base
	elseif form == "couldyou" then return "could you " .. base
	end
	return base
end

-- ---------------------------------------------------------------------------------------
-- The reverse dictionary
-- ---------------------------------------------------------------------------------------

-- Endings on a verb stem, and the form they make. Each ending is tried against the stem
-- table it attaches to; the longest ending wins.
local STEM_ENDINGS = {
	masu = {
		{ "ませんでした", "pastneg" }, { "ましょうか", "shall" }, { "ましょう", "lets" }, { "ません", "neg" },
		{ "ました", "past" }, { "ます", "present" }, { "たくなかった", "wantpastneg" }, { "たくないです", "wantneg" },
		{ "たくない", "wantneg" }, { "たかった", "wantpast" }, { "たいです", "want" }, { "たい", "want" },
		{ "なさい", "please" },
	},
	nai = {
		{ "なければならない", "must" }, { "なければいけない", "must" }, { "なくてはいけない", "must" },
		{ "なきゃ", "must" }, { "なかった", "pastneg" }, { "ないでください", "dont" }, { "ないで", "dont" },
		{ "ないです", "neg" }, { "ない", "neg" },
	},
	te = {
		{ "ください", "please" }, { "くれ", "please" }, { "ほしい", "please" }, { "いました", "progpast" },
		{ "いません", "progneg" }, { "います", "prog" }, { "いない", "progneg" }, { "いる", "prog" },
		{ "いた", "progpast" }, { "ない", "progneg" }, { "ます", "prog" }, { "る", "prog" }, { "た", "progpast" },
		{ "しまった", "past" }, { "みる", "try" }, { "みます", "try" },
		{ "くれませんか", "couldyou" }, { "くれますか", "couldyou" }, { "くれない", "couldyou" },
		{ "もらえませんか", "couldyou" }, { "もらえますか", "couldyou" }, { "もらえる", "couldyou" },
	},
	pot = {
		{ "なかった", "couldnt" }, { "ません", "cannot" }, { "ました", "could" }, { "ない", "cannot" },
		{ "ます", "can" }, { "る", "can" }, { "た", "could" },
	},
	pass = {
		{ "ています", "passive" }, { "ている", "passive" }, { "てる", "passive" }, { "ました", "passivepast" },
		{ "ます", "passive" }, { "る", "passive" }, { "た", "passivepast" },
	},
}
STEM_ENDINGS.potr = STEM_ENDINGS.pot
local STEM_ORDER = { "masu", "nai", "te", "pot", "potr", "pass" }
-- Every ending, filed under its last character: a surface is only tried against the endings
-- that could close it. In stem-table order, longest ending first.
local ENDINGS_BY_LAST = {}
for order, name in ipairs(STEM_ORDER) do
	for _, ending in ipairs(STEM_ENDINGS[name]) do
		local suffix = ending[1]
		local last = suffix:sub(-3)
		ENDINGS_BY_LAST[last] = ENDINGS_BY_LAST[last] or {}
		table.insert(ENDINGS_BY_LAST[last], { suffix = suffix, stems = name, form = ending[2], order = order })
	end
end
for _, list in pairs(ENDINGS_BY_LAST) do
	table.sort(list, function(a, b)
		if a.order ~= b.order then return a.order < b.order end
		return #a.suffix > #b.suffix
	end)
end

-- o-row of a godan ending, for the volitional: 行く -> 行こう
local O_ROW = { ["う"] = "お", ["く"] = "こ", ["ぐ"] = "ご", ["す"] = "そ", ["つ"] = "と", ["ぬ"] = "の", ["ぶ"] = "ぼ", ["む"] = "も", ["る"] = "ろ" }

local REV            -- built by BuildReverse
local reverseUserTable

-- Lower is better: the player's own words, then the dictionary in definition order, and never
-- an English spelled with digits (gr8, 2ez) when a word will do.
local function Score(english, entry, bias)
	local score = (entry.seq or 1e6) + bias
	if english:find("%d") then score = score + 1e7 end
	-- "late for", "afraid of": a dictionary phrase whose object was cut off
	local last = english:match("(%a+)$")
	if last and english:find(" ", 1, true) and ({ ["for"] = 1, ["to"] = 1, ["of"] = 1, ["at"] = 1, ["on"] = 1,
		["in"] = 1, ["with"] = 1, ["about"] = 1, ["from"] = 1 })[last] then
		score = score + 5e6
	end
	-- "bblr", "thx": chat shorthand only when no word says it
	if not english:find("[aeiouy]") then
		score = score + 2e6
	end
	return score
end

-- A dictionary value that is a whole clause (攻城兵器を置く, 破城槌が必要です) is left to the
-- reader, which puts the same clause together from its parts -- and keeps the callout form.
local function IsClause(surface)
	if surface:find("を", 1, true) then return true end
	local at = surface:find("が", 4, true)
	if not at then return false end
	local b1, b2, b3 = surface:byte(at - 3, at - 1)
	local hiragana = b1 == 0xE3 and (b2 == 0x81 or (b2 == 0x82 and b3 <= 0x9F))
	return not hiragana
end

-- Scores of what each table holds, kept only while building: lower wins.
local buildScores

-- Store value under surface in map, unless something better is already there. stem: the key
-- only ever matches with an ending after it, so one kana is safe (いる -> い|ます). formMap and
-- form record which form of the word the surface is, beside it rather than in a table of its own.
local function Offer(map, surface, value, score, stem, formMap, form)
	if not surface or surface == "" or (IsSingleKana(surface) and not stem) or not surface:find("[\128-\255]")
		or IsClause(surface) then
		return
	end
	local scores = buildScores[map]
	if not scores then
		scores = {}
		buildScores[map] = scores
	end
	local current = scores[surface]
	if not current or score < current then
		scores[surface] = score
		map[surface] = value
		if formMap then formMap[surface] = form end
		local chars = CountChars(surface)
		if chars > REV.maxChars then REV.maxChars = chars end
	end
end

local function AddVerb(english, entry, score)
	local word, class = entry.ja, entry.class
	if type(word) ~= "string" or word == "" then return end
	local record = { english = english }
	local verb, forms = REV.verb, REV.verbForm
	Offer(verb, word, record, score, false, forms, "present")
	Offer(verb, T.PlainPast(word, class), record, score, false, forms, "past")
	Offer(verb, T.TeForm(word, class), record, score, false, forms, "te")
	local stems = REV.stems
	Offer(stems.masu, T.Stem(word, class), record, score, true)
	Offer(stems.nai, T.NaiStem(word, class), record, score, true)
	Offer(stems.te, T.TeForm(word, class), record, score, true)
	Offer(stems.pot, T.PotentialStem(word, class), record, score, true)
	Offer(stems.pass, T.PassiveStem(word, class), record, score, true)
	local head, last = word:sub(1, -4), word:sub(-3)
	if class == "1" then
		Offer(stems.potr, head .. "れ", record, score, true)
		Offer(verb, head .. "よう", record, score, false, forms, "lets")
	elseif class == "5" and O_ROW[last] then
		Offer(verb, head .. O_ROW[last] .. "う", record, score, false, forms, "lets")
	elseif class == "s" then
		local base = word:sub(-6) == "する" and word:sub(1, -7) or word
		Offer(verb, base .. "しよう", record, score, false, forms, "lets")
	elseif class == "k" then
		Offer(stems.potr, T.NaiStem(word, class) .. "れ", record, score, true)
		Offer(verb, T.NaiStem(word, class) .. "よう", record, score, false, forms, "lets")
	end
end

-- English verbs whose Japanese is an adjective and whose が-noun is the object.
local VERBAL = { like = true, love = true, hate = true, dislike = true, want = true, need = true, prefer = true,
	fear = true, envy = true, miss = true }

-- verbal: a verb whose Japanese is an adjective (like = 好き, want = 欲しい). Its が-noun is
-- the object: ケーキが好き -> I like cake.
local function AddAdjective(english, entry, score, class, verbal)
	local word = entry.ja
	if type(word) ~= "string" or word == "" then return end
	local record = { english = english, verbal = verbal }
	local adj, forms = REV.adj, REV.adjForm
	local function Form(surface, form)
		Offer(adj, surface, record, score, false, forms, form)
	end
	Form(word, "plain")
	if class == "i" and word:sub(-3) == "い" then
		local head = (word == "いい" and "よ") or word:sub(1, -4)
		Form(head .. "くない", "neg")
		Form(head .. "くないです", "neg")
		Form(head .. "かった", "past")
		Form(head .. "かったです", "past")
		Form(head .. "くなかった", "pastneg")
		Form(head .. "くて", "plain")
		Form(head .. "く", "adverb")
	elseif class == "na" then
		Form(word .. "な", "plain")
	end
end

local function AddEntry(english, entry, bias)
	if type(entry) ~= "table" or type(entry.ja) ~= "string" then return end
	local pos, class = entry.pos, entry.class
	english = english == "i" and "I" or english
	local score = Score(english, entry, bias)
	if pos == "n" or pos == "pn" then
		Offer(REV.noun, entry.ja, english, score)
	elseif pos == "a" then
		AddAdjective(english, entry, score, class)
	elseif pos == "v" then
		if class == "i" or class == "na" then
			-- 好き (like) takes an object; 忙しい (busy) is only an adjective with a verb's pos
			local plain = english:gsub("^be ", "")
			AddAdjective(plain, entry, score, class, VERBAL[plain] or false)
		else
			AddVerb(english, entry, score)
		end
	elseif pos == "adv" then
		Offer(REV.adv, entry.ja, english, score)
	elseif pos == "wh" then
		-- 何 / 誰 / どこ read as the noun they stand for: 何をしていますか -> what are you doing?
		Offer(REV.noun, entry.ja, english, score)
	elseif pos == "x" then
		-- A long run of consonants (bblr, dbmib) is shorthand no reader of English knows;
		-- leave the Japanese to be read word by word.
		if not (#english >= 4 and not english:find("[aeiouy]")) then
			Offer(REV.expr, entry.ja, english, score)
		end
	end
end

local function AddLexicon(lexicon, bias)
	local scanned = 0
	for english, entry in pairs(lexicon or {}) do
		scanned = scanned + 1
		if scanned % 64 == 0 then T.ReclaimTemporaryMemory() end
		if type(english) == "string" then
			AddEntry(english, entry, bias)
			for _, alternative in pairs(entry.alts or {}) do
				AddEntry(english, alternative, bias)
			end
		end
	end
end

-- Built on first use, after every dictionary file has loaded, and again whenever the player's
-- own words change (SetUserEntries replaces the table).
local function BuildReverse()
	REV = {
		noun = {}, adj = {}, adjForm = {}, adv = {}, expr = {}, verb = {}, verbForm = {},
		stems = { masu = {}, nai = {}, te = {}, pot = {}, potr = {}, pass = {} },
		maxChars = 1,
	}
	buildScores = {}
	AddLexicon(T.userLexicon, -1e9)
	AddLexicon(T.lexicon, 0)
	AddLexicon(T.cyrodiilLexicon, 1e8)
	buildScores = nil
	for key in pairs(CURATED) do
		local chars = CountChars(key)
		if chars > REV.maxChars then REV.maxChars = chars end
	end
	-- An ending can make a surface longer than any stored key.
	REV.maxChars = math.min(REV.maxChars + 8, 24)
	reverseUserTable = T.userLexicon
	T.ReclaimTemporaryMemory(true)
end

local function EnsureReverse()
	if not REV or reverseUserTable ~= T.userLexicon then
		BuildReverse()
	end
end

-- What a stretch of text is, or nil. The hand-written tables win, then grammar, then the
-- reverse dictionary: verbs, adjectives, nouns, adverbs, expressions.
local function Lookup(surface)
	local curated = CURATED[surface]
	if curated then
		return { kind = curated.kind, key = surface, value = curated.value }
	end
	local existence = EXISTENCE[surface]
	if existence then
		return { kind = "verb", key = surface, value = "be", form = existence }
	end
	local record = REV.verb[surface]
	if record then
		return { kind = "verb", key = surface, value = record.english, form = REV.verbForm[surface] }
	end
	for _, ending in ipairs(ENDINGS_BY_LAST[surface:sub(-3)] or {}) do
		local suffix = ending.suffix
		if #surface > #suffix and surface:sub(-#suffix) == suffix then
			local stemRecord = REV.stems[ending.stems][surface:sub(1, -#suffix - 1)]
			if stemRecord then
				return { kind = "verb", key = surface, value = stemRecord.english, form = ending.form }
			end
		end
	end
	record = REV.adj[surface]
	if record then
		return { kind = "adjective", key = surface, value = record.english, form = REV.adjForm[surface], verbal = record.verbal }
	end
	local english = REV.noun[surface]
	if english then
		return { kind = "noun", key = surface, value = english }
	end
	english = REV.adv[surface]
	if english then
		return { kind = "adverb", key = surface, value = english }
	end
	english = REV.expr[surface]
	if english then
		return { kind = "expression", key = surface, value = english }
	end
end

-- ---------------------------------------------------------------------------------------
-- Segmentation
-- ---------------------------------------------------------------------------------------

local UNKNOWN_COST = 10
-- A particle costs a little less than a word, so that on a tie 敵|は|いない beats 敵|はい|ない.
local PARTICLE_COST = 0.9

-- Cut the text into pieces: { kind, key, value, form }. kind is one of noun, verb, adjective,
-- adverb, expression, predicate, particle, filler, copula, ascii, unknown.
-- Every reading is scored -- one point a piece (a particle a little less), ten a character
-- nobody knows -- and the cheapest wins, so 今日はいい reads as 今日|は|いい, not 今日|はい|い.
function T.JaSegment(text)
	EnsureReverse()
	local starts = {}
	local i = 1
	while i <= #text do
		starts[#starts + 1] = i
		i = i + CharLength(text, i)
	end
	local n = #starts
	starts[n + 1] = #text + 1

	local best, choice = {}, {}
	best[n + 1] = 0
	for index = n, 1, -1 do
		local from = starts[index]
		best[index] = math.huge
		-- A run of ASCII passes through as itself: "vMA", "2", "x"
		if IsASCIIWordByte(text:byte(from)) then
			local length = 0
			while IsASCIIWordByte(text:byte(from + length)) do length = length + 1 end
			local cost = 1 + best[index + length]
			local curated = CURATED[text:sub(from, from + length - 1)]
			best[index] = cost
			choice[index] = curated and { kind = curated.kind, key = curated.key, value = curated.value, span = length }
				or { kind = "ascii", key = text:sub(from, from + length - 1), value = text:sub(from, from + length - 1), span = length }
		end
		for span = math.min(REV.maxChars, n - index + 1), 1, -1 do
			local surface = text:sub(from, starts[index + span] - 1)
			local piece = Lookup(surface)
			if piece then
				local cost = (piece.kind == "particle" and PARTICLE_COST or 1) + best[index + span]
				if cost < best[index] then
					piece.span = span
					best[index], choice[index] = cost, piece
				end
			end
		end
		local cost = UNKNOWN_COST + best[index + 1]
		if cost < best[index] then
			best[index] = cost
			choice[index] = { kind = "unknown", key = text:sub(from, starts[index + 1] - 1), span = 1 }
		end
	end

	local pieces = {}
	local index = 1
	while index <= n do
		local piece = choice[index]
		local last = pieces[#pieces]
		if piece.kind == "unknown" and last and last.kind == "unknown" then
			last.key = last.key .. piece.key
		else
			pieces[#pieces + 1] = piece
		end
		index = index + piece.span
	end
	return pieces
end

-- ---------------------------------------------------------------------------------------
-- Reading
-- ---------------------------------------------------------------------------------------

local function Join(...)
	local words = {}
	for index = 1, select("#", ...) do
		local part = select(index, ...)
		if type(part) == "table" then
			for _, word in ipairs(part) do words[#words + 1] = word end
		elseif type(part) == "string" and part ~= "" then
			words[#words + 1] = part
		end
	end
	return table.concat(words, " ")
end

local function Tidy(english)
	english = english:gsub("^ +", ""):gsub(" +$", ""):gsub(" +", " ")
	-- The dictionary is lower case; the pronoun is not.
	english = (" " .. english .. " "):gsub(" i([ '])", " I%1"):gsub(" i([ '])", " I%1")
	return english:sub(2, -2)
end

local function SubjectWord(words)
	local text = Join(words)
	if text == "me" or text == "i" then return "I" end
	return text ~= "" and text or nil
end

-- Translate. Returns the English, a list of the Japanese it could not read (empty when
-- everything was understood), and how many pieces it did read.
function T.TranslateJaToEn(text)
	T.ReclaimTemporaryMemory()
	local out, unknown, known = {}, {}, 0
	local pieces = T.JaSegment(tostring(text or ""))

	-- The clause being read: who (は/が), what (を), the noun phrase still open, where.
	local subject, object, phrase = nil, nil, {}
	local subjectByGa -- the subject came with が, not は
	local place, placeWord
	local adverbs = {}

	local function Emit(english)
		out[#out + 1] = Tidy(english)
	end

	local function Reset()
		subject, object, phrase, place, placeWord, adverbs = nil, nil, {}, nil, nil, {}
		subjectByGa = nil
	end

	-- Whatever is left of a clause with no predicate: the words, in the order they came.
	local function Flush()
		if place then
			out[#out + 1] = (placeWord == "from" and "from " or "") .. place
		end
		local rest = Join(subject, object, phrase, adverbs)
		if rest ~= "" then
			out[#out + 1] = rest
		end
		Reset()
	end

	-- に after a verb of motion is "to" (go to roe); after anything else "at" (drop siege at bd).
	local MOTION = { go = true, come = true, move = true, run = true, walk = true, head = true, ["return"] = true,
		travel = true, port = true, teleport = true, arrive = true, get = true, send = true, bring = true, fly = true }
	-- Verbs whose に-noun is their object: 馬に乗る -> ride horse, 彼に会う -> meet him
	local NI_OBJECT = { ride = true, meet = true, join = true, enter = true, answer = true, reply = true, tell = true,
		ask = true, call = true, win = true, lose = true, follow = true, touch = true, board = true, attend = true }
	local function PlaceTail(verb)
		if not place then return "" end
		local first = verb and verb:match("^(%a+)")
		local word = placeWord
		if word == "at" and first and NI_OBJECT[first] then return " " .. place end
		if word == "at" and first and MOTION[first] then word = "to" end
		return " " .. word .. " " .. place
	end

	local WH = { what = true, where = true, who = true, when = true, why = true, how = true, which = true }
	-- The question word of a clause, taken out of where it stood: 何を / どこに
	local function TakeQuestionWord()
		local function From(list)
			if type(list) ~= "table" then return nil end
			for position, word in ipairs(list) do
				if WH[word] then return table.remove(list, position) end
			end
		end
		local word = From(object) or From(phrase)
		if not word and place and WH[place] then
			word, place = place, nil
		end
		return word
	end
	-- The auxiliary a question moves to the front: どこに行きますか -> where do you go?
	local QUESTION_AUX = { present = "do", te = "do", past = "did", neg = "don't", pastneg = "didn't", want = "do",
		wantneg = "don't", wantpast = "did", can = "can", cannot = "can't", could = "could", prog = "are" }

	-- Is the next piece that carries anything a question mark?
	local function AsksAt(index)
		for next = index + 1, #pieces do
			local piece = pieces[next]
			if piece.kind == "filler" and piece.value == "question" then
				return true
			elseif not (piece.kind == "filler" and piece.value ~= "break") then
				return false
			end
		end
		return false
	end

	local skip = 0
	local lastAdverb -- index of the adverb just read, so only とても強い attaches to the adjective
	for index, piece in ipairs(pieces) do
		local kind = piece.kind
		if skip > 0 then
			skip = skip - 1
		elseif kind == "noun" or kind == "ascii" then
			if kind == "noun" then known = known + 1 end
			phrase[#phrase + 1] = piece.value
		elseif kind == "particle" then
			local role = piece.value
			if role == "subject" and #phrase == 0 and lastAdverb == index - 1 then
				-- 今日は: the topic is a time, which stays an adverb
				lastAdverb = index
			elseif role == "subject" and subject and piece.key == "が" then
				-- 私はケーキが好き: after a topic, the が-noun is what is liked or wanted
				if #phrase > 0 then object, phrase = phrase, {} end
			elseif role == "subject" then
				if #phrase > 0 then subject, phrase, subjectByGa = phrase, {}, piece.key == "が" end
			elseif role == "object" then
				if #phrase > 0 then object, phrase = phrase, {} end
			elseif role == "at" or role == "to" or role == "from" then
				if #phrase > 0 then
					place, placeWord, phrase = table.concat(phrase, " "), role, {}
				end
			elseif role == "and" then
				if #phrase > 0 then phrase[#phrase + 1] = "and" end
			end
			-- の joins nouns as they stand: チャルマン砦の正門 -> chal fd
		elseif kind == "predicate" then
			-- The hand-written callouts: {np} takes every noun of the clause.
			known = known + 1
			local np = Join(subject, object, phrase)
			local extra = ""
			if np == "" and place then
				np = (placeWord == "from" and "from " or "") .. place
			elseif place then
				extra = " " .. (placeWord == "to" and "at" or placeWord) .. " " .. place
			end
			local english = Join(piece.value:gsub("{np}", np), adverbs) .. extra
			if WH[np] and AsksAt(index) and not piece.value:find("^{np}") then
				-- どこに行きますか -> where do you go?  何が欲しいですか -> what do you need?
				english = Join(np, "do you", (piece.value:gsub(" ?{np}", "")), adverbs) .. "?"
			end
			english = Tidy(english)
			-- "to" or "at" with nothing after it: "omw to" -> "omw"
			english = english:gsub(" to$", ""):gsub(" at$", "")
			english = english:gsub(" at here", " here"):gsub(" to here", " here"):gsub(" at there", " there"):gsub(" to there", " there")
			english = english:gsub("^stack at crown", "stack on crown"):gsub(" to from ", " from "):gsub(" at from ", " from ")
			Emit(english)
			Reset()
		elseif kind == "verb" then
			known = known + 1
			local who = SubjectWord(subject)
			-- 食べたい with nobody named is the speaker's own wish.
			local asksHere = piece.form == "shall" or piece.form == "couldyou" or AsksAt(index)
			if not who and not asksHere and (piece.form == "want" or piece.form == "wantneg" or piece.form == "wantpast"
				or piece.form == "wantpastneg") then
				who = "I"
			end
			local asks = piece.form == "shall" or piece.form == "couldyou" or AsksAt(index)
			local english
			if piece.value == "be" then
				-- いる / ある: ヒーラーいますか -> any healer?  敵がいない -> no enemy
				local thing = Join(subject, object, phrase)
				local form = piece.form
				if asks then
					english = (form == "neg" and "no " or "any ") .. thing
				elseif form == "neg" or form == "pastneg" then
					english = "no " .. thing
				elseif form == "past" then
					english = "there was " .. thing
				else
					english = "there is " .. thing
				end
				english = Join(english, adverbs) .. PlaceTail()
			else
				local wh = asks and QUESTION_AUX[piece.form] and TakeQuestionWord()
				local what = object and Join(object, phrase) or Join(phrase)
				if wh and wh ~= who then
					-- 何をしていますか -> what are you doing?
					local verb = piece.form == "prog" and OnFirst(piece.value, IngWord) or
						((piece.form == "want" or piece.form == "wantneg" or piece.form == "wantpast") and ("want to " .. piece.value) or piece.value)
					local person = who == "I" and (piece.form == "want" or piece.form == "wantneg" or piece.form == "wantpast") and "you" or (who or "you")
					local aux = QUESTION_AUX[piece.form]
					if aux == "are" then aux = Be(person) end
					english = Join(wh, aux, person, verb, what, adverbs) .. PlaceTail(piece.value)
				elseif asks and not who and QUESTION_AUX[piece.form] then
					-- 明日行けますか -> can you go tomorrow?  魔法を使えますか -> can you use magic?
					local verb = piece.form == "prog" and OnFirst(piece.value, IngWord) or
						((piece.form == "want" or piece.form == "wantneg" or piece.form == "wantpast") and ("want to " .. piece.value) or piece.value)
					english = Join(QUESTION_AUX[piece.form], "you", verb, what, adverbs) .. PlaceTail(piece.value)
				else
					local verb = VerbEnglish(piece.value, piece.form, who)
					if what == "" and not place then
						-- a dictionary phrase whose object was cut off: 遅れて -> late
						verb = verb:gsub(" for$", ""):gsub(" to$", ""):gsub(" of$", ""):gsub(" with$", ""):gsub(" about$", "")
					end
					english = Join(who, verb, what, adverbs) .. PlaceTail(piece.value)
				end
			end
			if asks then english = english .. "?" end
			Emit(english)
			Reset()
		elseif kind == "adjective" then
			known = known + 1
			local nextPiece = pieces[index + 1]
			local adjective = piece.value
			if #adverbs > 0 and lastAdverb == index - 1 and not (pieces[index - 1] and pieces[index - 1].kind == "particle") then
				-- とても強い -> very strong
				adjective = Join(table.remove(adverbs), adjective)
			end
			if piece.form == "adverb" then
				adverbs[#adverbs + 1] = adjective
			elseif nextPiece and (nextPiece.kind == "noun" or nextPiece.kind == "ascii") then
				-- いい天気 -> good weather
				phrase[#phrase + 1] = (piece.form == "neg" and "not " or "") .. adjective
			else
				-- A predicate: 強い / 強くない / 静かじゃない
				local form = piece.form
				if nextPiece and nextPiece.kind == "copula" then
					local copula = nextPiece.value
					if copula == "neg" or copula == "pastneg" or copula == "past" then form = copula end
					skip = 1
				end
				local english
				if piece.verbal then
					-- 好き / 欲しい behave as verbs: (私は)ケーキが好き -> I like cake
					if subjectByGa and not object then
						object, subject = subject, nil
					end
					local who = SubjectWord(subject) or "I"
					local verbForm = form == "plain" and "present" or form
					english = Join(who, VerbEnglish(adjective, verbForm, who), object, phrase, adverbs) .. PlaceTail()
				else
					local who = SubjectWord(subject) or (#phrase > 0 and Join(phrase)) or nil
					local be = ""
					if who then
						be = Be(who, form == "past" or form == "pastneg") .. ((form == "neg" or form == "pastneg") and " not" or "")
					elseif form == "neg" then be = "not"
					elseif form == "past" then be = "it was"
					elseif form == "pastneg" then be = "it wasn't"
					end
					if who and AsksAt(index + skip) then
						-- このクエストは難しいですか -> is this quest hard?
						english = Join(Be(who, form == "past" or form == "pastneg"), who,
							(form == "neg" or form == "pastneg") and "not" or "", adjective, adverbs) .. PlaceTail()
					else
						english = Join(who, be, adjective, adverbs) .. PlaceTail()
					end
				end
				if AsksAt(index + skip) then english = english .. "?" end
				Emit(english)
				Reset()
			end
		elseif kind == "copula" then
			-- 天気です, 敵じゃない
			local form = piece.value
			local who = SubjectWord(subject)
			local what = Join(object, phrase)
			if who or what ~= "" then
				local english
				if who and what ~= "" and AsksAt(index) then
					-- 彼はヒーラーですか -> is he healer?
					english = Join(Be(who, form == "past" or form == "pastneg"), who,
						(form == "neg" or form == "pastneg") and "not" or "", what)
				elseif who and what ~= "" then
					english = Join(who, Be(who, form == "past" or form == "pastneg")
						.. ((form == "neg" or form == "pastneg") and " not" or ""), form == "maybe" and "probably" or "", what)
				else
					local only = who or what
					english = (form == "neg" and "not " or (form == "past" and "was " or (form == "pastneg" and "wasn't " or
						(form == "maybe" and "probably " or "")))) .. only
				end
				english = Join(english, adverbs)
				english = english .. PlaceTail()
				if AsksAt(index) then english = english .. "?" end
				Emit(english)
				Reset()
			end
		elseif kind == "adverb" then
			known = known + 1
			adverbs[#adverbs + 1] = piece.value
			lastAdverb = index
		elseif kind == "expression" then
			known = known + 1
			local pending = (#phrase == 0 and not subject and not object and not place) and adverbs or nil
			if pending then adverbs = {} end
			Flush()
			local english = Join(piece.value, pending)
			if AsksAt(index) then
				-- 元気ですか: the dictionary's "I am fine", asked, is about the other person
				english = english:gsub("^[Ii] am ", "are you "):gsub("^[Ii]'m ", "are you ") .. "?"
			end
			Emit(english)
		elseif kind == "filler" then
			if piece.value == "break" then
				Flush()
			elseif piece.value == "please" then
				-- ヒールお願いします -> heal please
				local np = Join(subject, object, phrase)
				if np ~= "" then
					Emit(np .. " please")
					Reset()
				end
			end
		elseif kind == "unknown" then
			unknown[#unknown + 1] = piece.key
		end
	end
	Flush()

	-- One clause per callout, joined the way chat joins them.
	return table.concat(out, ", "), unknown, known
end
