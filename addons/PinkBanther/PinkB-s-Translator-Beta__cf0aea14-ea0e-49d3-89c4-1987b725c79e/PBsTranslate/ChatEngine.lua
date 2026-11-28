-- PB's Translate -- MMO chat shorthand, telegraphic frames, and discourse layer
--
-- Online game chat rarely arrives as textbook prose. Players drop subjects, auxiliaries and
-- copulas, pack role counts into tokens ("lf1t 1h 2dd vrg hm"), glue status reports onto
-- commands ("tank down rez pls"), and mix discourse markers ("tbh idk if we can clear",
-- "mb didnt see aoe", "full now sry") straight into a clause.
--
-- This module handles two things cleanly and compositionally, without blowing the memory
-- budget or overriding any user dictionary entry:
--
--   1. ChatEngine.Translate: complete, high-confidence MMO chat frames (LFG/recruitment,
--      trade, movement/AFK/timer reports, combat/PvP callouts, telegraphic status reports).
--   2. ChatEngine.Preprocess: separates leading/trailing discourse markers, splits glued
--      chat calls, normalises colloquial tokens ("dc ed", "real quick", "idk + wh/if"),
--      so Syntax.lua and Grammar.lua receive clean clauses.
--
-- Lua 5.1 compatible: no goto, no //, byte-safe ASCII patterns only.

PBsTranslate = PBsTranslate or {}
local T = PBsTranslate

local C = { enabled = true }
T.ChatEngine = C

-- ---------------------------------------------------------------------------------------
-- Helpers & user-dictionary guard
-- ---------------------------------------------------------------------------------------

local function W(item)
	return item and item.kind == "word" and item.w or nil
end

local function HasUserWord(items, a, b)
	local u = T.userLexicon
	if not u or not next(u) then return false end
	for i = a or 1, b or #items do
		local it = items[i]
		if it and it.kind == "word" then
			if u[it.w] or (it.base and u[it.base]) then return true end
			for part in (it.w or ""):gmatch("[^ \t\r\n]+") do
				if u[part] then return true end
			end
		end
	end
	return false
end

local function Slice(items, a, b)
	local out = {}
	for i = a, b do out[#out + 1] = items[i] end
	return out
end

local function CountSpan(items, a, b, stats)
	if not stats then return end
	for i = a, b do
		local it = items[i]
		if it and it.kind == "word" then
			stats.known = (stats.known or 0) + 1
		end
	end
end

-- Look up a word preferring Cyrodiil meanings when the surrounding syntax is clearly a
-- PvP keep/faction callout, even outside Cyrodiil.
local function LookupPvP(w)
	if T.userLexicon and T.userLexicon[w] then return T.userLexicon[w] end
	return (T.cyrodiilLexicon and T.cyrodiilLexicon[w]) or (T.lexicon and T.lexicon[w])
end

local function LookupNormal(w)
	if T.userLexicon and T.userLexicon[w] then return T.userLexicon[w] end
	return T.Exact and T.Exact(w)
end

local function IsPlaceName(ja)
	if type(ja) ~= "string" then return false end
	for _, ending in ipairs({ "砦", "基地", "城", "街" }) do
		if ja:sub(-#ending) == ending then return true end
	end
	return false
end

-- ---------------------------------------------------------------------------------------
-- Shared MMO vocabulary sets
-- ---------------------------------------------------------------------------------------

local ROLE_MAP = {
	t = "タンク", tank = "タンク", tanks = "タンク",
	h = "ヒーラー", heal = "ヒーラー", heals = "ヒーラー", healer = "ヒーラー", healers = "ヒーラー",
	dd = "DPS", dds = "DPS", dps = "DPS", d = "DPS",
}

local FACTIONS = {
	ad = "アルドメリ・ドミニオン",
	dc = "ダガーフォール・カバナント",
	ep = "エボンハート・パクト",
	yellows = "ドミニオン勢", yellow = "ドミニオン勢",
	blues = "カバナント勢", blue = "カバナント勢",
	reds = "パクト勢", red = "パクト勢",
	zerg = "大集団", zergs = "大集団",
	ball = "ボールグループ", ["ball group"] = "ボールグループ",
	enemy = "敵", enemies = "敵",
	["small group"] = "少人数グループ",
	bananas = "ドミニオン勢", smurfs = "カバナント勢",
	dominion = "ドミニオン", covenant = "カバナント", pact = "パクト",
}

local COMBATANT_DOWN = {
	tank = "タンク", healer = "ヒーラー", dps = "DPS", dd = "DD",
	boss = "ボス", wb = "ワールドボス", ["world boss"] = "ワールドボス",
	crown = "グループリーダー", emp = "皇帝", emperor = "皇帝",
	ally = "味方", allies = "味方", enemy = "敵", enemies = "敵",
}

local STRUCTURE_WORD = {
	fd = "正門", ["front door"] = "正門", ["front gate"] = "正門", ["main gate"] = "正門",
	bd = "裏門", ["back door"] = "裏門", ["back gate"] = "裏門",
	ifd = "内郭の扉", ["inner fd"] = "内郭の扉", ["inner front door"] = "内郭の扉",
	inner = "内門", ["inner door"] = "内門", ["inner gate"] = "内門", ["inner wall"] = "内壁", ["inner walls"] = "内壁",
	outer = "外壁", ["outer wall"] = "外壁", ["outer walls"] = "外壁", ["outer door"] = "外門",
	wall = "壁", walls = "壁", door = "門", doors = "門", gate = "門", gates = "門",
	postern = "通用門", ["postern door"] = "通用門",
	milegate = "マイルゲート", bridge = "橋", keep = "砦",
}

local SPAWN_TARGETS = {
	wb = "ワールドボス", ["world boss"] = "ワールドボス", boss = "ボス",
	dolmen = "ドルメン", geyser = "ゲイザー", dragon = "ドラゴン",
	harrowstorm = "ハロウストーム", portal = "ポータル", ["oblivion portal"] = "オブリビオンポータル",
	vent = "火山噴出孔", chest = "宝箱", hs = "重い袋", ["heavy sack"] = "重い袋",
}

local CAMP_WORDS = { camp = true, fc = true, ["forward camp"] = true, tent = true }

local DANGER_WORDS = {
	aoe = "範囲攻撃", red = "赤い範囲", fire = "火", adds = "雑魚", add = "雑魚",
	boss = "ボス", mech = "ギミック", mechs = "ギミック", mechanics = "ギミック",
	mechanic = "ギミック", ["one shot"] = "即死攻撃", bomb = "爆撃", bomber = "ボマー",
	zerg = "大集団", flank = "側面", behind = "背後", left = "左", right = "右",
	ganker = "ガンカー", gankers = "ガンカー", siege = "攻城兵器", oil = "燃え盛る油",
}

local LOST_STATE = {
	taunt = "挑発が外れました",
	aggro = "敵の狙いが外れました",
	buff = "バフが切れました",
	buffs = "バフが切れました",
	food = "食事バフが切れました",
	pot = "ポーション効果が切れました",
	los = "射線が切れました",
}

local PUSH_VERBS = {
	pushing = "攻めています",
	sieging = "包囲攻撃しています",
	attacking = "攻撃しています",
	hitting = "攻めています",
	taking = "制圧しています",
	capping = "占領しています",
	flipping = "奪っています",
	defending = "防衛しています",
	repairing = "修理しています",
}

-- Leading/trailing discourse markers that frame a chat line without belonging inside its syntax.
local LEAD_MARKERS = {
	tbh = "正直に言うと",
	imo = "私の考えでは",
	imho = "私の考えでは",
	btw = "ところで",
	ngl = "正直",
	mb = "ごめん",
	np = "どういたしまして",
	sry = "ごめんなさい",
	sorry = "ごめんなさい",
	thx = "ありがとう",
	thanks = "ありがとう",
	ty = "ありがとう",
	tyvm = "本当にありがとう",
	tysm = "本当にありがとう",
	nvm = "やっぱりいいです",
	back = "戻りました",
	pls = "お願いします",
	plz = "お願いします",
}

local TRAIL_MARKERS = {
	sry = "ごめんなさい",
	sorry = "ごめんなさい",
	mb = "ごめん",
	tbh = "正直に言うと",
	imo = "私の考えでは",
	btw = "ところで",
	ngl = "正直",
	asap = "至急",
	pst = "ささやいてください",
	obo = "価格相談可",
	ty = "ありがとう",
	thx = "ありがとう",
	thanks = "ありがとう",
	tyvm = "本当にありがとう",
	tysm = "本当にありがとう",
	lol = "(笑)",
	lmao = "(爆笑)",
	gg = "お疲れさまでした",
	wp = "ナイスプレイ",
	glhf = "頑張って楽しんで",
	tyfg = "グループありがとう",
}

local GREET_OR_PRAISE = {
	gg = true, ggs = true, wp = true, gj = true, ty = true, thx = true, thanks = true,
	tyvm = true, tysm = true, gl = true, hf = true, glhf = true, tyfg = true,
	hi = true, hey = true, hello = true, bye = true, cya = true, gn = true, gm = true,
	sry = true, sorry = true, np = true, nw = true, gratz = true, gz = true, congrats = true,
}

-- ---------------------------------------------------------------------------------------
-- Small pattern parsers
-- ---------------------------------------------------------------------------------------

-- Parse a compact duration: "5 mins", "2m", "30s", "1hr", "10 minutes"
local function ParseDuration(items, i)
	local it = items[i]
	if not it then return nil end
	if it.kind == "word" then
		local n, unit = it.w:match("^(%d+)([a-z]+)$")
		if n then
			if unit == "m" or unit == "min" or unit == "mins" then return n .. "分", i + 1 end
			if unit == "s" or unit == "sec" or unit == "secs" then return n .. "秒", i + 1 end
			if unit == "h" or unit == "hr" or unit == "hrs" then return n .. "時間", i + 1 end
		end
	elseif it.kind == "num" then
		local nxt = W(items[i + 1])
		if nxt == "m" or nxt == "min" or nxt == "mins" or nxt == "minute" or nxt == "minutes" then
			return it.v .. "分", i + 2
		elseif nxt == "s" or nxt == "sec" or nxt == "secs" or nxt == "second" or nxt == "seconds" then
			return it.v .. "秒", i + 2
		elseif nxt == "h" or nxt == "hr" or nxt == "hrs" or nxt == "hour" or nxt == "hours" then
			return it.v .. "時間", i + 2
		end
	end
	return nil
end

-- Parse a price token: "50k", "10k", "1.5m", "500g", or "50 k" / "500 gold"
local function ParsePrice(items, i)
	local it = items[i]
	if not it then return nil end
	if it.kind == "word" then
		local n, u = it.w:match("^(%d+%.?%d*)([kmg])$")
		if n then
			if u == "g" then return n .. "ゴールド", i + 1 end
			return n .. u, i + 1
		end
	elseif it.kind == "num" then
		local nxt = W(items[i + 1])
		if nxt == "k" or nxt == "m" then
			return it.v .. nxt, i + 2
		elseif nxt == "g" or nxt == "gold" then
			return it.v .. "ゴールド", i + 2
		end
	end
	return nil
end

-- Parse a compact count with optional "+": "10+", "20+", "5"
local function ParseApproxCount(items, i)
	local it = items[i]
	if not it then return nil end
	if it.kind == "num" then
		local nxt = items[i + 1]
		if nxt and nxt.kind == "raw" and nxt.v == "+" then
			return it.v .. "人以上", i + 2, true
		end
		return it.v .. "人", i + 1, false
	elseif it.kind == "word" then
		local n = it.w:match("^(%d+)%+$")
		if n then return n .. "人以上", i + 1, true end
	end
	return nil
end

-- Parse a PvP place phrase: "roe fd", "chal bd", "ales", "fare", "sej", "the keep", "fd", "roe south wall"
local function ParsePlace(items, a, b, preferPvP)
	if a > b then return nil end
	local i = a
	if W(items[i]) == "the" and i < b then i = i + 1 end
	local parts = {}
	local hasPvPPlace = false
	for k = i, b do
		local it = items[k]
		if it.kind == "raw" then
			parts[#parts + 1] = it.v
		elseif it.kind == "word" then
			local w = it.w
			local structJa = STRUCTURE_WORD[w]
			local e = preferPvP and LookupPvP(w) or LookupNormal(w)
			if preferPvP and e and e.pos ~= "n" and e.alts and e.alts.n then
				e = e.alts.n
			end
			if e and e.pos == "n" then
				if IsPlaceName(e.ja) then hasPvPPlace = true end
				parts[#parts + 1] = { ja = e.ja, join = e.join, isPlace = IsPlaceName(e.ja), isStruct = structJa ~= nil }
			elseif structJa then
				hasPvPPlace = true
				parts[#parts + 1] = { ja = structJa, join = "の", isStruct = true }
			elseif it.entry and T.As(it.entry, "n") then
				local ne = T.As(it.entry, "n")
				parts[#parts + 1] = { ja = ne.ja, join = ne.join, isPlace = IsPlaceName(ne.ja) }
			else
				return nil
			end
		else
			return nil
		end
	end
	if #parts == 0 then return nil end
	-- Join keep + structure naturally: "roe fd" -> ローベック砦の正門, "fd kings" -> キングクレスト砦の正門
	local out = ""
	if #parts == 2 and type(parts[1]) == "table" and type(parts[2]) == "table" then
		if parts[1].isStruct and parts[2].isPlace then
			return parts[2].ja .. "の" .. parts[1].ja, hasPvPPlace
		elseif parts[1].isPlace and parts[2].isStruct then
			return parts[1].ja .. "の" .. parts[2].ja, hasPvPPlace
		end
	end
	local prev
	for _, p in ipairs(parts) do
		if type(p) == "string" then
			out = out .. p
			prev = nil
		else
			if prev and (p.join or (prev.isPlace and p.isStruct)) then
				out = out .. (p.join or "の") .. p.ja
			else
				out = out .. p.ja
			end
			prev = p
		end
	end
	return out, hasPvPPlace
end

-- Parse a dungeon/trial/content target for LFG: "vrg hm", "vcr+0", "vdsa", "vka", "rnd normal", "dolmen"
local function ParseContent(items, a, b)
	if a > b then return nil end
	local out = {}
	local i = a
	while i <= b do
		local it = items[i]
		local w = W(it)
		if w == "rnd" and W(items[i + 1]) == "normal" then
			out[#out + 1] = "ランダムノーマルダンジョン"
			i = i + 2
		elseif w == "rnd" then
			out[#out + 1] = "ランダムノーマルダンジョン"
			i = i + 1
		elseif w == "hm" or w == "hardmode" or w == "hard mode" then
			out[#out + 1] = "ハードモード"
			i = i + 1
		elseif w == "vet" or w == "veteran" then
			out[#out + 1] = "ベテラン"
			i = i + 1
		elseif w == "normal" or w == "norm" then
			out[#out + 1] = "ノーマル"
			i = i + 1
		elseif w and w:match("^[vn][a-z]+%+[0-3]$") then
			if it.entry and it.entry.ja then
				out[#out + 1] = it.entry.ja
			else
				out[#out + 1] = w:sub(1, 1) .. w:sub(2):upper()
			end
			i = i + 1
		elseif it.kind == "word" and it.entry and (it.entry.pos == "n" or (it.entry.alts and it.entry.alts.n)) then
			local ne = T.As(it.entry, "n")
			out[#out + 1] = ne.ja
			i = i + 1
		elseif it.kind == "word" and it.orig and it.orig:match("^[vVnN][A-Za-z0-9%+]+$") then
			out[#out + 1] = it.orig
			i = i + 1
		elseif it.kind == "raw" then
			out[#out + 1] = it.v
			i = i + 1
		else
			return nil
		end
	end
	return table.concat(out, "")
end

-- Parse a role spec token in LFG/recruitment context:
-- "1t", "1h", "2dd", "2dps", "lf1t", "lf1h", "lf2dd", or "1 tank", "2 healers"
local function ParseRoleSpec(items, i)
	local w = W(items[i])
	if not w then
		-- "1 tank", "2 dps"
		if items[i] and items[i].kind == "num" then
			local rw = W(items[i + 1])
			local role = rw and ROLE_MAP[rw]
			if role then return role .. items[i].v .. "人", i + 2, false end
		end
		return nil
	end
	local lfn, lfr = w:match("^lf(%d+)([a-z]+)$")
	if lfn and ROLE_MAP[lfr] then
		return ROLE_MAP[lfr] .. lfn .. "人", i + 1, true
	end
	local n, r = w:match("^(%d+)([a-z]+)$")
	if n and ROLE_MAP[r] then
		return ROLE_MAP[r] .. n .. "人", i + 1, false
	end
	return nil
end

-- ---------------------------------------------------------------------------------------
-- Frame 1: LFG / Recruitment / Invites / Availability
-- ---------------------------------------------------------------------------------------

local function ReadLFG(items, questionMark)
	local n = #items
	local w1 = W(items[1])

	-- "x for vka", "+ for dolmen", "1 for vss"
	-- Do not hijack existing fixed expressions like "x for invite" / "x for inv".
	if n >= 3 and W(items[2]) == "for" then
		local mark
		if w1 == "x" then mark = "x"
		elseif items[1].kind == "raw" and items[1].v == "+" then mark = "+"
		elseif items[1].kind == "num" and items[1].v == "1" then mark = "1"
		end
		local w3 = W(items[3])
		if mark and not (n == 3 and (w3 == "invite" or w3 == "inv")) then
			local target = ParseContent(items, 3, n)
			if target then
				return target .. "の招待希望（" .. mark .. "）", false
			end
		end
	end

	-- "still lfm?" / "still lfg?"
	if n == 2 and w1 == "still" and (W(items[2]) == "lfm" or W(items[2]) == "lfg") then
		local label = W(items[2]) == "lfm" and "メンバー募集中" or "グループ募集中"
		return "まだ" .. label .. "です" .. (questionMark and "か" or ""), questionMark
	end

	-- "full now" / "full" (only with "now" so standalone "full" stays unchanged)
	if n == 2 and w1 == "full" and W(items[2]) == "now" then
		return "今は満員です", false
	end

	-- "spot open?" / "spots open?" / "any spot open?" / "any spots open?"
	if (n == 2 and (w1 == "spot" or w1 == "spots") and W(items[2]) == "open")
		or (n == 3 and w1 == "any" and (W(items[2]) == "spot" or W(items[2]) == "spots") and W(items[3]) == "open") then
		return "枠は空いています" .. (questionMark and "か" or ""), questionMark
	end

	-- "got room for 1 more?" / "room for 2 more?" / "have room for 1?"
	do
		local idx = 1
		if w1 == "you" or w1 == "u" then idx = 2 end
		if W(items[idx]) == "got" or W(items[idx]) == "have" then idx = idx + 1 end
		if W(items[idx]) == "room" and W(items[idx + 1]) == "for" and items[idx + 2] then
			local num = items[idx + 2].kind == "num" and items[idx + 2].v or nil
			local more = W(items[idx + 3]) == "more"
			if num and ((more and idx + 3 == n) or (not more and idx + 2 == n)) then
				local prefix = more and "あと" or ""
				return prefix .. num .. "人入れます" .. (questionMark and "か" or ""), questionMark
			end
		end
	end

	-- "lf1t 1h 2dd vrg hm" / "lf1t 1h vss" / "lfm rnd normal" / "lf2m vcr+0"
	-- Must have compact role specs, "rnd normal", or a trial+difficulty token so existing
	-- tests like "lfg vma" and "LF1M healer for vSS" keep their exact snapshot output.
	if w1 then
		local firstRole, nextIdx, isLfRole = ParseRoleSpec(items, 1)
		if isLfRole then
			local roles = { firstRole }
			local k = nextIdx
			while k <= n do
				if W(items[k]) == "and" or (items[k].kind == "raw" and items[k].v == "/") then
					k = k + 1
				end
				local r, nk = ParseRoleSpec(items, k)
				if r then
					roles[#roles + 1] = r
					k = nk
				else
					break
				end
			end
			if W(items[k]) == "for" then k = k + 1 end
			local content = k <= n and ParseContent(items, k, n) or nil
			if k > n or content then
				local roleText = table.concat(roles, "・") .. "募集"
				if content then return content .. "、" .. roleText, false end
				return roleText, false
			end
		end

		-- "lfm rnd normal" / "lfg rnd normal"
		if (w1 == "lfm" or w1 == "lfg") and n >= 2 and W(items[2]) == "rnd" then
			local content = ParseContent(items, 2, n)
			if content then
				local verb = w1 == "lfm" and "メンバー募集中" or "グループ募集中"
				return content .. "、" .. verb, false
			end
		end

		-- "lf2m vcr+0" / "lf1m vcr+1" (trial+difficulty or multi-word content after lfNm)
		local lfmNum = w1:match("^lf(%d+)m$")
		if lfmNum and n >= 2 then
			local hasCompact = false
			for k = 2, n do
				local wk = W(items[k])
				if wk and wk:match("^[vn][a-z]+%+[0-3]$") then hasCompact = true break end
			end
			if hasCompact then
				local content = ParseContent(items, 2, n)
				if content then
					return content .. "、あと" .. lfmNum .. "人募集", false
				end
			end
		end

		-- "need 1t 1h for vdsa" / "need 1t 1h 2dd vrg" / "need tank and heal"
		if w1 == "need" and n >= 2 then
			-- Role list with "heal" (which otherwise gets misread as an imperative verb): "need tank and heal"
			if n == 4 and W(items[3]) == "and" and ROLE_MAP[W(items[2]) or ""] and ROLE_MAP[W(items[4]) or ""]
				and (W(items[2]) == "heal" or W(items[4]) == "heal" or W(items[2]) == "heals" or W(items[4]) == "heals") then
				return ROLE_MAP[W(items[2])] .. "と" .. ROLE_MAP[W(items[4])] .. "が必要です", false
			end
			local r1, nk1 = ParseRoleSpec(items, 2)
			-- Only trigger when compact shorthand like "1t"/"1h"/"2dd" is present
			local w2 = W(items[2])
			if r1 and w2 and w2:match("^%d+[a-z]+$") then
				local roles = { r1 }
				local k = nk1
				while k <= n do
					if W(items[k]) == "and" then k = k + 1 end
					local r, nk = ParseRoleSpec(items, k)
					if r then
						roles[#roles + 1] = r
						k = nk
					else
						break
					end
				end
				if W(items[k]) == "for" then k = k + 1 end
				local content = k <= n and ParseContent(items, k, n) or nil
				if k > n or content then
					local roleText = table.concat(roles, "・") .. "が必要です"
					if content then return content .. "用に" .. roleText, false end
					return roleText, false
				end
			end
		end
	end

	return nil
end

-- ---------------------------------------------------------------------------------------
-- Frame 2: Trade / Price Check / COD
-- ---------------------------------------------------------------------------------------

local function ParseItemSpan(items, a, b)
	if a > b then return nil end
	local qty
	local i = a
	if items[i].kind == "num" and i < b then
		qty = items[i].v
		i = i + 1
	end
	local parts = {}
	for k = i, b do
		local it = items[k]
		if it.kind == "raw" then
			parts[#parts + 1] = it.v
		elseif it.kind == "word" then
			local e = it.entry
			if e and (e.pos == "n" or e.pos == "pn" or e.pos == "a") then
				parts[#parts + 1] = e.ja
			elseif e and e.alts and e.alts.n then
				parts[#parts + 1] = e.alts.n.ja
			elseif it.orig then
				parts[#parts + 1] = it.orig
			else
				return nil
			end
		elseif it.kind == "num" then
			parts[#parts + 1] = it.v
		else
			return nil
		end
	end
	if #parts == 0 then return nil end
	local name = T.Join(parts)
	if qty then return name .. "×" .. qty end
	return name
end

local function ReadTrade(items)
	local n = #items
	while n > 1 and W(items[n]) == "please" do n = n - 1 end
	local w1 = W(items[1])

	-- "pc on this" / "pc this" / "price check on <item>"
	if (w1 == "pc" or w1 == "price check" or w1 == "pricecheck") and n >= 2 then
		local start = (W(items[2]) == "on" or W(items[2]) == "for") and 3 or 2
		if start <= n then
			local target = ParseItemSpan(items, start, n)
			if target then
				return target .. "の相場を教えてください", false
			end
		end
	end

	-- "cod me 10k" / "cod 10k"
	if w1 == "cod" and n >= 2 then
		local start = (W(items[2]) == "me" or W(items[2]) == "us") and 3 or 2
		if start <= n then
			local price, nxt = ParsePrice(items, start)
			if price and nxt == n + 1 then
				return price .. "の代金引換で送ってください", false
			end
		end
	end

	-- "wts <item> <price> [cod]" / "wtb <qty> <item> [<price>] [cod]"
	if (w1 == "wts" or w1 == "wtb") and n >= 2 then
		local last = n
		local cod = false
		if W(items[last]) == "cod" then
			cod = true
			last = last - 1
		end
		local price
		if last >= 3 then
			local p, nxt = ParsePrice(items, last)
			if p and nxt == last + 1 then
				price = p
				last = last - 1
			elseif last >= 4 then
				local p2, nxt2 = ParsePrice(items, last - 1)
				if p2 and nxt2 == last + 1 then
					price = p2
					last = last - 2
				end
			end
		end
		-- Only fire when price or cod is present so plain "wts gold jewelry" stays untouched.
		if (price or cod) and last >= 2 then
			local itemText = ParseItemSpan(items, 2, last)
			if itemText then
				local verb = w1 == "wts" and "売りたいです" or "買いたいです"
				local cond = ""
				if price and cod then cond = price .. "の代金引換で"
				elseif price then cond = price .. "で"
				elseif cod then cond = "代金引換で" end
				return itemText .. "を" .. cond .. verb, false
			end
		end
	end

	return nil
end

-- ---------------------------------------------------------------------------------------
-- Frame 3: Movement / AFK / BRB / Countdown / Regroup
-- ---------------------------------------------------------------------------------------

local function ReadStatusTime(items)
	local n = #items
	local w1 = W(items[1])

	-- "brb 5 mins" / "brb 2m"
	if w1 == "brb" and n >= 2 then
		local dur, nxt = ParseDuration(items, 2)
		if dur and nxt == n + 1 then
			return dur .. "ほどすぐ戻ります", false
		end
	end

	-- "afk 2m" / "afk 5 mins"
	if w1 == "afk" and n >= 2 then
		local dur, nxt = ParseDuration(items, 2)
		if dur and nxt == n + 1 then
			return dur .. "ほど離席します", false
		end
	end

	-- "gtg soon" / "g2g soon"
	if (w1 == "gtg" or w1 == "g2g") and n == 2 and W(items[2]) == "soon" then
		return "もうすぐ行かないと", false
	end

	-- "omw to roe" / "otw to chal" / "on my way to keep"
	do
		local toIdx
		if (w1 == "omw" or w1 == "otw" or w1 == "on my way" or w1 == "on the way") and W(items[2]) == "to" then
			toIdx = 3
		elseif w1 == "on" and W(items[2]) == "my" and W(items[3]) == "way" and W(items[4]) == "to" then
			toIdx = 5
		end
		if toIdx and toIdx <= n then
			local place = ParsePlace(items, toIdx, n, true)
			if place then
				local ending = T.cyrodiilPriority and "に向かっている途中" or "に向かっています"
				return place .. ending, false
			end
		end
	end

	-- "pulling in 3" / "pulling in 5 secs" / "pull in 3"
	if (w1 == "pulling" or w1 == "pull") and W(items[2]) == "in" and n >= 3 then
		if items[3].kind == "num" and n == 3 then
			return "あと" .. items[3].v .. "秒で釣ります", false
		end
		local dur, nxt = ParseDuration(items, 3)
		if dur and nxt == n + 1 then
			return "あと" .. dur .. "で釣ります", false
		end
	end

	-- "all to roe [now]" / "everyone to roe [now]"
	if (w1 == "all" or w1 == "everyone") and W(items[2]) == "to" and n >= 3 then
		local last = n
		local timeLead = ""
		if W(items[last]) == "now" or W(items[last]) == "right now" then
			timeLead = "今すぐ"
			last = last - 1
		end
		local place = ParsePlace(items, 3, last, true)
		if place then
			return timeLead .. "全員" .. place .. "へ", false
		end
	end

	return nil
end

-- ---------------------------------------------------------------------------------------
-- Frame 4: Combat / PvP / Status Callouts
-- ---------------------------------------------------------------------------------------

local function ReadCallout(items, questionMark)
	local n = #items
	local w1 = W(items[1])

	-- "u there?" / "you there?"
	if n == 2 and (w1 == "you" or w1 == "u") and W(items[2]) == "there" and questionMark then
		return "いますか", true
	end

	-- "ready when you are" / "ready when u r"
	if n == 4 and (w1 == "ready" or w1 == "rdy") and W(items[2]) == "when"
		and W(items[3]) == "you" and W(items[4]) == "are" then
		return "あなたが準備できたらこちらも準備OKです", false
	end

	-- "watch aoe" / "watch red" / "watch the fire"
	if w1 == "watch" and n >= 2 then
		local k = W(items[2]) == "the" and 3 or 2
		if k == n then
			local danger = DANGER_WORDS[W(items[k]) or ""]
			if danger then
				return danger .. "に気をつけてください", false
			end
		end
	end

	-- "lost taunt" / "lost aggro" / "lost food"
	if w1 == "lost" and n == 2 then
		local msg = LOST_STATE[W(items[2]) or ""]
		if msg then return msg, false end
	end

	-- "too far for heals" / "too far for healing"
	if w1 == "too" and W(items[2]) == "far" and W(items[3]) == "for" and n == 4 then
		local w4 = W(items[4])
		if w4 == "heals" or w4 == "heal" or w4 == "healing" then
			return "回復するには遠すぎます", false
		end
	end

	-- "los me"
	if w1 == "los" and n == 2 and W(items[2]) == "me" then
		return "私との射線が切れています", false
	end

	-- "stuck in load screen" / "stuck in loading screen" / "stuck in <place>"
	if w1 == "stuck" and W(items[2]) == "in" and n >= 3 then
		local k = W(items[3]) == "the" and 4 or 3
		local target = ParseItemSpan(items, k, n)
		if target then
			return target .. "で固まっています", false
		end
	end

	-- "healer down" / "tank down" / "boss down" (without copula)
	if n == 2 and W(items[2]) == "down" and COMBATANT_DOWN[w1 or ""] then
		-- Preserve existing Cyrodiil fixed entry for "crown down" -> グループリーダーが死にました
		if not (w1 == "crown" and T.cyrodiilPriority) then
			return COMBATANT_DOWN[w1] .. "が倒れました", false
		end
	end

	-- "walls down at roe" / "fd down at chal" / "inner down at roe"
	if n >= 4 and W(items[2]) == "down" and (W(items[3]) == "at" or W(items[3]) == "on") and STRUCTURE_WORD[w1 or ""] then
		local place = ParsePlace(items, 4, n, true)
		if place then
			return place .. "の" .. STRUCTURE_WORD[w1] .. "が破られました", false
		end
	end

	-- "wb up?" / "boss up?" / "dolmen up?"
	if n == 2 and W(items[2]) == "up" and SPAWN_TARGETS[w1 or ""] then
		return SPAWN_TARGETS[w1] .. "は湧いています" .. (questionMark and "か" or ""), questionMark
	end

	-- "camp up at chal" / "camp down at roe" / "fc up at ales"
	if n >= 4 and CAMP_WORDS[w1 or ""] and (W(items[2]) == "up" or W(items[2]) == "down")
		and (W(items[3]) == "at" or W(items[3]) == "in" or W(items[3]) == "near" or W(items[3]) == "on") then
		local place = ParsePlace(items, 4, n, true)
		if place then
			return place .. "に前線キャンプが建っています", false
		end
	end

	-- "need camp at roe" / "need fc at chal"
	if n >= 4 and w1 == "need" and CAMP_WORDS[W(items[2]) or ""]
		and (W(items[3]) == "at" or W(items[3]) == "in" or W(items[3]) == "near" or W(items[3]) == "on") then
		local place = ParsePlace(items, 4, n, true)
		if place then
			return place .. "で前線キャンプが必要です", false
		end
	end

	-- "fd at 50%" / "inner at 30%" / "roe fd at 40%" / "boss at 20%"
	do
		local atIdx
		for k = 2, n - 1 do
			if W(items[k]) == "at" then atIdx = k break end
		end
		if atIdx and items[atIdx + 1] and items[atIdx + 1].kind == "num" then
			local pct = items[atIdx + 2]
			if pct and pct.kind == "raw" and pct.v == "%" and atIdx + 2 == n then
				local subj = ParsePlace(items, 1, atIdx - 1, true)
				if not subj and atIdx == 2 and COMBATANT_DOWN[w1 or ""] then
					subj = COMBATANT_DOWN[w1]
				end
				if subj then
					return subj .. "は" .. items[atIdx + 1].v .. "%です", false
				end
			end
		end
	end

	-- "inc 10+ ad roe fd" / "inc 20+ blues chal bd" / "20+ blues inc chal bd"
	if (w1 == "inc" or w1 == "incoming") and n >= 3 then
		local cnt, idx, approx = ParseApproxCount(items, 2)
		if cnt and approx then
			local faction = FACTIONS[W(items[idx]) or ""]
			if faction then idx = idx + 1 end
			if W(items[idx]) == "at" or W(items[idx]) == "on" then idx = idx + 1 end
			local place = idx <= n and ParsePlace(items, idx, n, true) or nil
			if place then
				local who = faction and (faction .. cnt) or cnt
				return place .. "に" .. who .. "インカミング", false
			elseif not faction and idx > n then
				return cnt .. "インカミング", false
			end
		end
	end

	do
		local cnt, idx, approx = ParseApproxCount(items, 1)
		if cnt and approx and idx <= n then
			local faction = FACTIONS[W(items[idx]) or ""]
			if faction and (W(items[idx + 1]) == "inc" or W(items[idx + 1]) == "incoming") then
				local pStart = idx + 2
				if W(items[pStart]) == "at" or W(items[pStart]) == "on" then pStart = pStart + 1 end
				local place = pStart <= n and ParsePlace(items, pStart, n, true) or nil
				if place then
					return place .. "に" .. faction .. cnt .. "インカミング", false
				end
			end
		end
	end

	-- "outer open" / "inner open" / "fd open" / "bd open" (works even outside Cyrodiil)
	if n == 2 and W(items[2]) == "open" and STRUCTURE_WORD[w1 or ""]
		and (w1 == "outer" or w1 == "inner" or w1 == "fd" or w1 == "bd" or w1 == "ifd" or w1 == "postern") then
		return STRUCTURE_WORD[w1] .. "は破られています", false
	end

	-- "dc on chal fd" / "ad at roe" / "ep on ales bd" (named factions only so "ball group at bd" / "bananas at blk" stay intact)
	local NAMED_FACTIONS = {
		ad = "アルドメリ・ドミニオン", dc = "ダガーフォール・カバナント", ep = "エボンハート・パクト",
		dominion = "ドミニオン", covenant = "カバナント", pact = "パクト",
		yellows = "ドミニオン勢", blues = "カバナント勢", reds = "パクト勢",
	}
	if NAMED_FACTIONS[w1 or ""] and (W(items[2]) == "on" or W(items[2]) == "at" or W(items[2]) == "in") and n >= 3 then
		local place, isPvP = ParsePlace(items, 3, n, true)
		if place and (isPvP or T.cyrodiilPriority) then
			return NAMED_FACTIONS[w1] .. "が" .. place .. "にいます", false
		end
	end

	-- "ep pushing ales" / "ad sieging chal fd"
	if FACTIONS[w1 or ""] and PUSH_VERBS[W(items[2]) or ""] and n >= 3 then
		local place = ParsePlace(items, 3, n, true)
		if place then
			return FACTIONS[w1] .. "が" .. place .. "を" .. PUSH_VERBS[W(items[2])], false
		end
	end

	-- "zerg heading to sej" / "scroll heading to fare" / "ep heading to roe"
	do
		local headIdx
		for k = 2, n - 2 do
			if W(items[k]) == "heading" and (W(items[k + 1]) == "to" or W(items[k + 1]) == "for") then
				headIdx = k
				break
			end
		end
		if headIdx then
			local place = ParsePlace(items, headIdx + 2, n, true)
			if place then
				local subj
				if headIdx == 2 and FACTIONS[w1 or ""] then
					subj = FACTIONS[w1]
				elseif headIdx == 2 and (w1 == "scroll" or w1 == "elder scroll") then
					subj = T.cyrodiilPriority and "星霜の書" or "エルダースクロール"
				else
					subj = ParsePlace(items, 1, headIdx - 1, true)
				end
				if subj then
					return subj .. "が" .. place .. "に向かっています", false
				end
			end
		end
	end

	-- "lagging so bad [right now / now]"
	if w1 == "lagging" and W(items[2]) == "so" and W(items[3]) == "bad" then
		if n == 3 then
			return "すごくラグいです", false
		elseif n == 4 and (W(items[4]) == "now" or W(items[4]) == "right now") then
			return "今すごくラグいです", false
		elseif n == 5 and W(items[4]) == "right" and W(items[5]) == "now" then
			return "今すごくラグいです", false
		end
	end

	-- "dc ed" (space-typed "dced")
	if n == 2 and w1 == "dc" and W(items[2]) == "ed" then
		return "切断されました", false
	end

	return nil
end

local FRAMES = { ReadLFG, ReadTrade, ReadStatusTime, ReadCallout }

-- Try complete MMO chat frames on a clean (marker-stripped) segment.
function C.MatchFrame(items, stats, questionMark)
	if not C.enabled or #items == 0 or HasUserWord(items) then return nil end
	for _, reader in ipairs(FRAMES) do
		local text, isQ = reader(items, questionMark)
		if text then
			CountSpan(items, 1, #items, stats)
			return text, isQ
		end
	end
	return nil
end

-- ---------------------------------------------------------------------------------------
-- Discourse marker stripping, run-on splitting, and colloquial normalisation
-- ---------------------------------------------------------------------------------------

local EMBEDDED_OPENERS = {
	what = true, where = true, when = true, who = true, how = true, why = true,
	["if"] = true, whether = true, which = true,
}

-- Normalise colloquial token sequences before parsing, without touching user lexicon words.
local function NormalizeItems(items)
	if HasUserWord(items) then return items end
	local out = {}
	local i, n = 1, #items
	while i <= n do
		local it = items[i]
		local w = W(it)
		local w2 = W(items[i + 1])

		-- "dc ed" -> single "dced" expression
		if w == "dc" and w2 == "ed" then
			out[#out + 1] = {
				kind = "word", w = "dced", base = "dced", orig = it.orig,
				entry = { pos = "x", ja = "切断されました" },
			}
			i = i + 2
		-- "idk what/if/where..." -> "i do not know ..." so Syntax parses the embedded clause!
		elseif (w == "idk" or w == "dunno") and w2 and EMBEDDED_OPENERS[w2] then
			out[#out + 1] = { kind = "word", w = "i", base = "i", orig = it.orig, entry = LookupNormal("i") }
			out[#out + 1] = { kind = "word", w = "do", base = "do", orig = "do", entry = LookupNormal("do") }
			out[#out + 1] = { kind = "word", w = "not", base = "not", orig = "not" }
			out[#out + 1] = { kind = "word", w = "know", base = "know", orig = "know", entry = LookupNormal("know"), fromIdk = true }
			i = i + 1
		-- "sorry for wait" -> fixed expression
		elseif (w == "sorry" or w == "sry") and w2 == "for" and W(items[i + 2]) == "wait" and i + 2 == n then
			out[#out + 1] = {
				kind = "word", w = "sorry for the wait", base = "sorry for the wait", orig = it.orig,
				entry = { pos = "x", ja = "お待たせしてごめんなさい" }, phrase = true,
			}
			i = i + 3
		-- "real quick" -> adverb "すぐ"
		elseif w == "real" and w2 == "quick" then
			out[#out + 1] = {
				kind = "word", w = "quickly", base = "quick", orig = it.orig,
				entry = { pos = "adv", ja = "すぐ" },
			}
			i = i + 2
		-- "so bad" after a verb (e.g. "lagging so bad") -> adverb "ひどく"
		elseif w == "so" and w2 == "bad" and i > 1 and items[i - 1].kind == "word"
			and items[i - 1].entry and items[i - 1].entry.pos == "v" then
			out[#out + 1] = {
				kind = "word", w = "badly", base = "bad", orig = it.orig,
				entry = { pos = "adv", ja = "すごく" },
			}
			i = i + 2
		else
			out[#out + 1] = it
			i = i + 1
		end
	end
	return out
end

-- Split glued multi-call lines:
--   "tank down rez pls" -> { "tank down", "rez pls" }
--   "lf2m vcr+0 need tank and heal" -> { "lf2m vcr+0", "need tank and heal" }
local function SplitGluedCalls(items)
	if #items < 3 or HasUserWord(items) then return nil end
	local w1 = W(items[1])

	-- "<combatant> down <next clause>"
	if COMBATANT_DOWN[w1 or ""] and W(items[2]) == "down" and #items >= 3 then
		local w3 = W(items[3])
		if w3 ~= "at" and w3 ~= "in" and w3 ~= "on" and w3 ~= "near" and w3 ~= "here" and w3 ~= "there" then
			return { Slice(items, 1, 2), Slice(items, 3, #items) }
		end
	end

	-- "lf2m <content> need <roles>"
	if w1 and (w1 == "lfm" or w1 == "lfg" or w1:match("^lf%d+m$")) then
		for k = 2, #items - 1 do
			if W(items[k]) == "need" then
				return { Slice(items, 1, k - 1), Slice(items, k, #items) }
			end
		end
	end

	return nil
end

-- Strip leading/trailing discourse markers cleanly when a real clause remains.
-- Never strips "sorry for ...", "thanks for ...", "ty for ...", or standalone expressions.
local function StripDiscourse(items)
	if #items < 2 or HasUserWord(items) then return nil, items, nil end
	local prefix, suffix = {}, {}
	local first, last = 1, #items

	-- Leading markers
	while first < last do
		local w = W(items[first])
		local wNext = W(items[first + 1])
		local marker = w and LEAD_MARKERS[w]
		-- Guard: "sorry for ...", "thanks for ...", "ty for ...", "sorry i am late", "np" alone
		if marker and not ((w == "sorry" or w == "sry" or w == "thanks" or w == "thx" or w == "ty"
				or w == "tyvm" or w == "tysm") and wNext == "for")
			and not (w == "back" and (wNext == "to" or wNext == "in" or wNext == "at" or wNext == "on" or wNext == "bar" or wNext == "door" or wNext == "gate"))
			and not (w == "pls" or w == "plz") then
			-- Only strip if the remaining words are not just a single preposition or adjective
			-- and avoid altering existing snapshot "sorry, my bad" (already comma-split) or "ty all"
			if not ((w == "ty" or w == "thanks" or w == "thx") and (wNext == "all" or wNext == "everyone")) then
				prefix[#prefix + 1] = marker
				first = first + 1
			else
				break
			end
		else
			break
		end
	end

	-- Trailing "all" as vocative after greetings/praise: "gg wp all" -> "お疲れさまでした、ナイスプレイ、皆さん"
	if last > first and W(items[last]) == "all" then
		local prevIt = items[last - 1]
		local pw = W(prevIt) or ""
		local isPraise = GREET_OR_PRAISE[pw]
			or (prevIt.entry and prevIt.entry.pos == "x" and (pw:find("gg", 1, true) or pw:find("wp", 1, true)
				or pw:find("gl", 1, true) or pw:find("ty", 1, true) or pw:find("thx", 1, true)))
		if isPraise then
			suffix[#suffix + 1] = "皆さん"
			last = last - 1
		end
	end

	-- Trailing markers ("full now sry", "gtg soon sry", "wts motif 50k pst", "dc ed sry")
	while last > first do
		local w = W(items[last])
		local prev = W(items[last - 1])
		local marker = w and TRAIL_MARKERS[w]
		-- Do not strip "sorry" after "am/is/are/was/were/so/very/really" ("I am sorry", "so sorry")
		local predSorry = (w == "sorry" or w == "sry") and (prev == "am" or prev == "is" or prev == "are"
			or prev == "was" or prev == "were" or prev == "so" or prev == "very" or prev == "really" or prev == "be")
		-- Do not strip "gg"/"wp" etc. when preceded by a determiner/preposition/verb
		local prevGrammar = prev == "a" or prev == "an" or prev == "the" or prev == "my" or prev == "your"
			or prev == "for" or prev == "to" or prev == "of" or prev == "in" or prev == "at" or prev == "on"
			or prev == "is" or prev == "was" or prev == "are" or prev == "were" or prev == "be"
		if marker and not predSorry and not prevGrammar then
			-- Only strip trailing sry/sorry/mb/pst/obo/asap/lol/all-vocative safely
			if w == "sry" or w == "sorry" or w == "mb" or w == "pst" or w == "obo"
				or (w == "asap" and prev ~= nil) or w == "wp" or w == "glhf" then
				table.insert(suffix, 1, marker)
				last = last - 1
			else
				break
			end
		else
			break
		end
	end

	if #prefix == 0 and #suffix == 0 then
		return nil, items, nil
	end
	return prefix, Slice(items, first, last), suffix
end

-- Entry point called by Grammar.lua's TranslateSegment.
-- translateCore(subItems, stats, questionMark, keepSubject, isLast) translates a cleaned sub-segment.
function C.TranslateSegment(items, stats, questionMark, keepSubject, isLast, translateCore)
	if not C.enabled or #items == 0 then return nil end

	-- 1. First try direct complete frame match on the raw segment.
	local direct, directQ = C.MatchFrame(items, stats, questionMark)
	if direct then return direct, directQ end

	-- 2. Check glued multi-call lines ("tank down rez pls", "lf2m vcr+0 need tank and heal").
	local glued = SplitGluedCalls(items)
	if glued then
		local out, q = {}, false
		for idx, part in ipairs(glued) do
			local subQ = questionMark and idx == #glued
			local subLast = isLast and idx == #glued
			local ja, partQ = C.MatchFrame(part, stats, subQ)
			if not ja then
				ja, partQ = translateCore(part, stats, subQ, keepSubject, subLast)
			end
			if ja and ja ~= "" then out[#out + 1] = ja end
			q = q or partQ
		end
		if #out > 0 then return table.concat(out, "、"), q end
	end

	-- 3. Normalise colloquial tokens ("idk what...", "dc ed", "real quick", "so bad", "sorry for wait").
	local norm = NormalizeItems(items)
	local changed = norm ~= items

	-- 4. Strip leading/trailing discourse markers ("tbh ...", "mb ...", "... sry", "... pst", "gg wp all").
	local prefix, core, suffix = StripDiscourse(norm)
	if prefix or suffix or changed then
		-- Try frame match on the cleaned core first.
		local body, bodyQ = C.MatchFrame(core, stats, questionMark)
		if not body then
			body, bodyQ = translateCore(core, stats, questionMark, keepSubject, isLast)
		end
		if body and body ~= "" then
			if prefix then
				for _ = 1, #prefix do stats.known = (stats.known or 0) + 1 end
			end
			if suffix then
				for _ = 1, #suffix do stats.known = (stats.known or 0) + 1 end
			end
			local pieces = {}
			if prefix and #prefix > 0 then pieces[#pieces + 1] = table.concat(prefix, "、") end
			pieces[#pieces + 1] = body
			if suffix and #suffix > 0 then pieces[#pieces + 1] = table.concat(suffix, "、") end
			return table.concat(pieces, "、"), bodyQ
		end
	end

	return nil
end
