-- Groupbound_Parse.lua : reads one chat post ("LFM vSS HM prog need 1 heal 2 dd 1800cp 8pm EST")
-- and tells what it is:
--   content  which trial / arena / dungeon (Groupbound_Content nicknames or full names)
--   vet / hm difficulty (v / n in front of the nickname, "vet", "normal", "hm")
--   kind     "group" (a group looking for people), "player" (someone looking for a group),
--            "sale" (WTS / carries), "recruit" (guild ads), "full" (the group is full now)
--   need     { tank = n, heal = n, dps = n, any = n } or nil when the post doesn't say
--   tags     prog / farm / teach / score
--   cp       minimum CP, startAt (UTC timestamp) / startNow
-- Word lists cover English, German and French; nicknames are the same everywhere.

local G = Groupbound
local Content = G.Content
local Parse = {}
G.Parse = Parse

local function Set(list)
    local s = {}
    for _, w in ipairs(list) do s[w] = true end
    return s
end

local VET = Set({ "vet", "vets", "veteran", "veteranen", "vétéran", "veteran" })
local NORMAL = Set({ "normal", "norm", "normale", "normaux" })
local HMWORD = Set({ "hm", "hardmode", "hardmodes" })
-- a group looking for people
local NEED = Set({ "lfm", "lf", "need", "needs", "needed", "needing", "seeking", "brauchen", "brauche",
    "benötigen", "benoetigen", "gesucht", "suchen", "sucht", "suche", "cherche", "cherchons", "recherche",
    "recherchons", "besoin", "manque", "manquent" })
-- someone looking for a group
local LFG = Set({ "lfg", "lft" })
local LOOKING = Set({ "looking", "suche", "sucht", "cherche", "recherche" })
local GROUPWORD = Set({ "group", "grp", "team", "gruppe", "groupe", "raid" })
local SALE = Set({ "wts", "selling", "sell", "sale", "carry", "carries", "carrying", "verkaufe", "verkauf",
    "vends", "vend", "vente", "boost", "boosting" })
local GUILDWORD = Set({ "guild", "guilds", "gilde", "gilden", "guilde", "guildes", "trialguild" })
local RECRUIT = Set({ "recruit", "recruiting", "recruits", "recruitment", "rekrutiert", "rekrutieren",
    "recrute", "recrutons", "recrutement", "members", "mitglieder", "membres" })
-- words of guild ads that never say "recruiting" ("Join our supportive community! 3 Guilds,
-- Guildhall, taxback, lottery, Discord, apply...", seen 2026-10-13): several of them = a guild ad
local GUILD_AD = Set({ "guild", "guilds", "guildhall", "guildies", "community", "taxback", "tax", "lottery",
    "lotto", "raffle", "raffles", "trader", "traders", "trading", "discord", "apply", "applications",
    "inclusive", "supportive", "friendly", "social", "events", "giveaways", "bank",
    "gilde", "gilden", "gildenhalle", "gemeinschaft", "verlosung", "händler", "bewerben", "bewerbung",
    "guilde", "guildes", "communauté", "tombola", "marchand", "postuler", "candidature" })
local FULL = Set({ "full", "filled", "voll", "complet", "komplett", "geschlossen", "fermé" })
local HAVE = Set({ "have", "got", "with", "habe", "haben", "hab", "avons", "ai", "avec", "mit" })
local ALLWORD = Set({ "all", "any", "alle", "tous", "toutes" })
local ROLESWORD = Set({ "role", "roles", "rollen", "rolle", "rôles", "rôle" })
local NOW = Set({ "now", "asap", "jetzt", "sofort", "maintenant", "immédiatement", "direct" })
local IN = Set({ "in", "dans" })
local MIN = Set({ "m", "min", "mins", "minute", "minutes", "minuten" })

local ROLEWORD = {
    tank = "tank", tanks = "tank", mt = "tank", ot = "tank", offtank = "tank", maintank = "tank",
    heal = "heal", heals = "heal", healer = "heal", healers = "heal", oh = "heal", offheal = "heal",
    offhealer = "heal", heiler = "heal", soin = "heal", soins = "heal", soigneur = "heal", soigneurs = "heal",
    dd = "dps", dds = "dps", dps = "dps", damage = "dps", dmg = "dps", degats = "dps", ["dégâts"] = "dps",
}

local TAGS = {
    prog = Set({ "prog", "progression", "progress" }),
    farm = Set({ "farm", "farming", "farms", "farmen" }),
    teach = Set({ "teach", "teaching", "learn", "learning", "newbie", "newbies", "beginner", "beginners",
        "guided", "explain", "explained", "lehr", "lernen", "lerngruppe", "anfänger", "anfaenger",
        "neulinge", "neuling", "débutant", "debutant", "débutants", "debutants", "apprentissage", "apprendre",
        "découverte", "decouverte" }),
    score = Set({ "score", "trifecta", "nodeath", "speed", "speedrun", "achiev", "achievement",
        "achievements", "erfolg", "erfolge", "succès", "succes" }),
}

-- time zones people write after a time: hours from UTC
local TZ = { utc = 0, gmt = 0, bst = 1, cet = 1, cest = 2, mez = 1, mesz = 2, eet = 2, eest = 3, msk = 3,
    est = -5, edt = -4, cst = -6, cdt = -5, mst = -7, mdt = -6, pst = -8, pdt = -7 }

-- plain text: links keep their visible name, colors and icons go
function Parse.Clean(raw)
    local s = raw or ""
    s = s:gsub("|H[^|]*|h%[?([^|%]]*)%]?|h", "%1")
    s = s:gsub("|c%x%x%x%x%x%x", ""):gsub("|r", "")
    s = s:gsub("|t[^|]*|t", "")
    return s
end

local function Tokens(text)
    local low, orig = {}, {}
    for w in text:gmatch("[%w\128-\255]+") do
        orig[#orig + 1] = w
        low[#low + 1] = zo_strlower(w)
    end
    return low, orig
end

local function IsUpper(word)
    return word:find("%u") ~= nil and word:find("%l") == nil
end

-- one nickname token: "vss", "hmas", "vsshm", "nfg1" -> key, vet (true / false / nil), hm
-- baseUpper: the part after a v / n is written in capitals ("vIA"); a "strict" nickname (ia, as,
-- so...) only counts then or next to vet / normal / hm, so "via" isn't vIA and "vas" isn't vAS
local function Nick(t, strictOK, baseUpper)
    local base, hm = t, false
    if #base > 3 and base:sub(-2) == "hm" then
        base, hm = base:sub(1, -3), true
    elseif #base > 3 and base:sub(1, 2) == "hm" then
        base, hm = base:sub(3), true
    end
    local a = Content.alias[base]
    if a and (not a.strict or strictOK or hm) then
        return a.key, hm or nil, hm
    end
    local p = base:sub(1, 1)
    if (p == "v" or p == "n") and #base >= 3 then
        a = Content.alias[base:sub(2)]
        if a and (not a.strict or strictOK or baseUpper or hm) then return a.key, p == "v", hm end
    end
end

-- a nickname glued to other words, told by its capital letters: "vKAfirst2HM", "nSSfarm",
-- "vKAFirst" (the capitals may have eaten the next word's first letter: try one shorter too)
local function GluedNick(word)
    if not word then return nil end
    local p, caps = word:match("^([vVnN]?)(%u[%u%d]+)%l")
    if not caps then return nil end
    local hm = word:find("HM", #p + #caps + 1, true) ~= nil
    for _, c in ipairs({ caps, caps:sub(1, -2) }) do
        if #c >= 2 then
            local key, vet, hmNick = Nick(zo_strlower(p .. c), true)
            if key then return key, vet, hm or hmNick end
        end
    end
end

local function FindContent(low, orig, hasLower, diffWord)
    for i, t in ipairs(low) do
        local strictOK = diffWord or (hasLower and IsUpper(orig[i]) and #orig[i] >= 2)
            or (low[i - 1] and (HMWORD[low[i - 1]] or VET[low[i - 1]] or NORMAL[low[i - 1]]))
            or (low[i + 1] and (HMWORD[low[i + 1]] or VET[low[i + 1]] or NORMAL[low[i + 1]]))
        -- "vIA" / "nAS": the nickname part in capitals
        local rest = orig[i]:sub(2)
        local baseUpper = #rest >= 2 and IsUpper(rest)
        local key, vet, hm = Nick(t, strictOK, baseUpper)
        if not key then
            -- "fg 1", "vbc 2", "coa ii"
            local nxt = low[i + 1]
            local num = nxt == "1" and "1" or nxt == "2" and "2" or nxt == "i" and "1" or nxt == "ii" and "2" or nil
            if num then key, vet, hm = Nick(t .. num, strictOK, baseUpper) end
        end
        if not key then
            key, vet, hm = GluedNick(orig[i])
        end
        if key then return key, vet, hm end
    end
    -- full names ("dreadsail reef", "Sonnenspitze", "Fungal Grotto 2")
    local key = Content.FromName(table.concat(low, ""))
    return key, nil, false
end

local function Number(t)
    if not t then return nil end
    if t:match("^%d+$") then return tonumber(t) end
    local x = t:match("^x(%d+)$") or t:match("^(%d+)x$")
    return x and tonumber(x) or nil
end

local function Roles(low)
    local need, found = {}, false
    for i, t in ipairs(low) do
        local role, num = ROLEWORD[t], nil
        if not role then
            local d, w = t:match("^(%d+)x?(%a+)$")
            if d and ROLEWORD[w] then role, num = ROLEWORD[w], tonumber(d) end
        end
        if not role then
            -- "ddx2" first (else the x would stick to the word), then "dd2"
            local w, d = t:match("^(%a-)x(%d+)$")
            if not (w and ROLEWORD[w]) then w, d = t:match("^(%a+)(%d+)$") end
            if w and ROLEWORD[w] then role, num = ROLEWORD[w], tonumber(d) end
        end
        if role then
            local before = i - 1
            if not num then
                num = Number(low[i - 1])
                if num then before = i - 2 end
                if not num then
                    local nxt = low[i + 1]
                    local x = nxt and nxt:match("^x(%d+)$")
                    if x then num = tonumber(x) end
                end
            end
            if not (low[before] and HAVE[low[before]]) then
                if not num or num < 1 or num > 12 then num = 1 end
                need[role] = (need[role] or 0) + num
                found = true
            end
        end
        if ALLWORD[t] and low[i + 1] and ROLESWORD[low[i + 1]] then
            need.any = math.max(need.any or 0, 1)
            found = true
        end
    end
    return found and need or nil
end

local function CP(low)
    local best
    for i, t in ipairs(low) do
        local n = tonumber(t:match("^(%d+)cp$") or t:match("^cp(%d+)$") or "")
        if not n and t == "cp" then n = Number(low[i - 1]) or Number(low[i + 1]) end
        if n and n >= 10 and n <= 3600 then best = math.max(best or 0, n) end
    end
    return best
end

local function Time(low)
    local now = G.Now()
    for i, t in ipairs(low) do
        if NOW[t] then return nil, true end
        -- "in 15 min", "in 15min", "dans 10 minutes"
        if IN[t] and low[i + 1] then
            local n, unit = low[i + 1]:match("^(%d+)(%a*)$")
            n = tonumber(n)
            if n and n > 0 and n <= 240 and ((unit ~= "" and MIN[unit]) or (unit == "" and low[i + 2] and MIN[low[i + 2]])) then
                return now + n * 60
            end
        end
        local off = TZ[t]
        if off and i > 1 then
            local j = i - 1
            local ampm
            if low[j] == "am" or low[j] == "pm" then
                ampm = low[j]
                j = j - 1
            end
            local tok = low[j]
            local h, m
            if tok then
                local hh, ap = tok:match("^(%d%d?)([ap]m)$")
                if hh then
                    ampm = ap
                    -- "8.30pm" -> "8", "30pm"
                    if low[j - 1] and low[j - 1]:match("^%d%d?$") and #hh == 2 then
                        h, m = tonumber(low[j - 1]), tonumber(hh)
                    else
                        h = tonumber(hh)
                    end
                elseif tok:match("^%d%d?$") then
                    if #tok == 2 and low[j - 1] and low[j - 1]:match("^%d%d?$") then
                        h, m = tonumber(low[j - 1]), tonumber(tok)
                    else
                        h = tonumber(tok)
                    end
                else
                    local a, b = tok:match("^(%d%d?)h(%d%d)$")
                    if a then h, m = tonumber(a), tonumber(b) end
                end
            end
            if h then
                m = m or 0
                if ampm == "pm" and h < 12 then h = h + 12 elseif ampm == "am" and h == 12 then h = 0 end
                if h >= 0 and h <= 23 and m >= 0 and m <= 59 then
                    local ts = now - now % 86400 + (h - off) * 3600 + m * 60
                    while ts < now - 6 * 3600 do ts = ts + 86400 end
                    while ts > now + 18 * 3600 do ts = ts - 86400 end
                    return ts
                end
            end
        end
    end
end

-- ---------------------------------------------------------------------------
-- Language of a post (players complained about pick-up groups where nobody speaks the same
-- language): everyday words only one language uses. Short posts ("LFM vSS 2dd") have none and
-- stay unknown (nil), so they're never hidden.

local LANG_WORDS = {
    en = Set({ "need", "needs", "looking", "for", "the", "and", "with", "anyone", "please", "pls", "more",
        "group", "we", "our", "have", "new", "learning", "starting", "last", "boss", "know", "experienced",
        "clear", "who", "want", "join", "whisper", "just", "some" }),
    de = Set({ "suche", "suchen", "sucht", "brauchen", "brauche", "noch", "für", "fuer", "und", "mit", "bitte",
        "wir", "ich", "gruppe", "einen", "eine", "der", "das", "auch", "erfahrung", "erfahren", "jetzt",
        "gerne", "heiler", "schaden", "wer", "lust", "hat", "kein", "keine" }),
    fr = Set({ "cherche", "cherchons", "besoin", "groupe", "pour", "avec", "et", "des", "une", "nous", "svp",
        "merci", "soigneur", "soigneurs", "dégâts", "degats", "expérience", "maintenant", "qui", "les", "pas",
        "veut", "venir", "chuchotez", "mp" }),
    es = Set({ "busco", "buscamos", "necesitamos", "necesito", "grupo", "para", "con", "los", "las", "sanador",
        "favor", "que", "alguien", "somos", "tenemos", "susurro" }),
}
Parse.LANGS = { "en", "de", "fr", "es" }

-- "en" / "de" / "fr" / "es" or nil (not enough words, or a tie)
function Parse.Language(raw)
    local low = Tokens(Parse.Clean(raw or ""))
    local best, bestN, tie = nil, 0, false
    for _, lang in ipairs(Parse.LANGS) do
        local n = 0
        for _, t in ipairs(low) do
            if LANG_WORDS[lang][t] then n = n + 1 end
        end
        if n > bestN then
            best, bestN, tie = lang, n, false
        elseif n == bestN and n > 0 then
            tie = true
        end
    end
    if tie or bestN == 0 then return nil end
    return best
end

-- everything we can read from a text (no decision whether it's worth keeping)
function Parse.Scan(raw)
    local text = Parse.Clean(raw)
    local low, orig = Tokens(text)
    local info = { text = text, tags = {} }
    if #low == 0 then return info end
    local function Has(set)
        for _, t in ipairs(low) do
            if set[t] then return true end
        end
        return false
    end
    local hasLower = text:find("%l") ~= nil
    local vetWord, normWord, hmWord = Has(VET), Has(NORMAL), Has(HMWORD)
    local key, vet, hm = FindContent(low, orig, hasLower, vetWord or normWord or hmWord)
    info.content = key
    info.hm = hm or hmWord or nil
    if vet == nil then
        if vetWord or info.hm then vet = true elseif normWord then vet = false end
    end
    info.vet = vet
    for tag, set in pairs(TAGS) do
        if Has(set) then info.tags[tag] = true end
    end
    info.need = Roles(low)
    -- "lf2m" = 2 more of anything
    local lfN
    for _, t in ipairs(low) do
        local n = t:match("^lf(%d+)m?$")
        if n then lfN = tonumber(n) end
    end
    if not info.need and lfN and lfN >= 1 and lfN <= 11 then info.need = { any = lfN } end
    info.cp = CP(low)
    info.startAt, info.startNow = Time(low)
    info.lang = Parse.Language(text)

    -- what kind of post
    local lfm = Has(NEED) or lfN ~= nil
    local lookingForGroup = Has(LFG) or (Has(LOOKING) and Has(GROUPWORD))
    -- guild-ad words (each word counted once)
    local adWords, adSeen = 0, {}
    for _, t in ipairs(low) do
        if GUILD_AD[t] and not adSeen[t] then
            adSeen[t] = true
            adWords = adWords + 1
        end
    end
    if Has(SALE) then
        info.kind = "sale"
    elseif Has(GUILDWORD) and Has(RECRUIT) then
        info.kind = "recruit"
    elseif adWords >= 3 and Has(GUILDWORD) and not info.need and not (lfm and info.content) then
        -- an ad for a guild, not a group (a group post names roles or "LFM" + a run:
        -- "LFM vSS guild run, friendly, discord" stays a group)
        info.kind = "recruit"
    elseif #low <= 6 and Has(FULL) then
        info.kind = "full"
    elseif lfm and (info.need or info.content) and not (Has(LFG) and not Has(NEED) and not lfN) then
        info.kind = "group"
    elseif lookingForGroup then
        info.kind = "player"
    elseif lfm then
        info.kind = "group"
    end
    -- an ad isn't a run: a trial / dungeon named in passing ("IA", "trials") isn't what it offers
    if info.kind == "recruit" then
        info.content, info.vet, info.hm, info.need = nil, nil, nil, nil
    end
    return info
end

-- a chat post worth showing on the board, or nil
function Parse.Post(raw)
    local info = Parse.Scan(raw)
    if not info.kind then return nil end
    if info.kind == "full" then return info end
    if info.kind == "group" and not info.content and not info.need then return nil end
    if info.kind == "player" and not info.content and not info.need then return nil end
    -- (guild ads are kept: hidden by "Hide selling posts and guild ads", labeled "Guild ad" when shown)
    if info.kind == "sale" and not info.content then return nil end
    return info
end

-- ---------------------------------------------------------------------------
-- Your own post (the "Post a group" form). Chat posts use the community's short English words
-- (LFM, need, heal, dd, CP), which every player reads, on every server.

-- "now" / "" / "20:00" (your local time) / "30" (minutes) -> minutes from now, or nil
function Parse.StartInput(text)
    text = zo_strlower(zo_strtrim(text or ""))
    if text == "" then return nil end
    if NOW[text] then return 0 end
    local h, m = text:match("^(%d%d?)[:%.h](%d%d)$")
    if not h then h = text:match("^(%d%d?)h$") end
    if h then
        h, m = tonumber(h), tonumber(m or 0)
        if h > 23 or m > 59 then return nil end
        local localNow = (G.Now() + G.LocalOffset()) % 86400
        local diff = h * 3600 + m * 60 - localNow
        if diff < -1800 then diff = diff + 86400 end
        return math.max(0, math.floor(diff / 60 + 0.5))
    end
    local n = tonumber(text:match("^(%d+)%s*m?i?n?$") or "")
    if n and n <= 600 then return n end
end

-- spec = { key, vet, hm, raw, need = { tank, heal, dps }, cp, startIn (minutes), note, ach }
-- forFinder: the Group Finder's description gets the achievement's plain name (chat gets its link)
function Parse.BuildPost(spec, forFinder)
    local what = spec.key and Content.Short(spec.key, spec.vet) or zo_strtrim(spec.raw or "")
    if spec.hm then what = what .. " HM" end
    local parts = { zo_strtrim("LFM " .. what) }
    local roles = {}
    local need = spec.need or {}
    if (need.tank or 0) > 0 then roles[#roles + 1] = need.tank .. " tank" end
    if (need.heal or 0) > 0 then roles[#roles + 1] = need.heal .. " heal" end
    if (need.dps or 0) > 0 then roles[#roles + 1] = need.dps .. " dd" end
    if #roles > 0 then parts[#parts + 1] = "need " .. table.concat(roles, ", ") end
    if spec.cp and spec.cp > 0 then parts[#parts + 1] = spec.cp .. "+ CP" end
    if spec.ach and G.Achieve then
        local what = forFinder and G.Achieve.Name(spec.ach) or G.Achieve.Link(spec.ach)
        if what and what ~= "" then parts[#parts + 1] = "needs " .. what end
    end
    if spec.startIn then
        parts[#parts + 1] = spec.startIn <= 0 and "start now" or ("start in " .. spec.startIn .. " min")
    end
    local note = zo_strtrim(spec.note or "")
    if note ~= "" then parts[#parts + 1] = note end
    return table.concat(parts, " - ")
end
