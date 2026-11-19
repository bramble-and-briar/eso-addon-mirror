-- Battle report data: what the match looked like over time, what you gained, and
-- how close it was. Recorded cheaply alongside the normal snapshots (no extra
-- events): one small sample of team totals every SAMPLE_SEC seconds.
--
--   match.timeline = { teams = { teamId, ... }, samples = { { t, score1, damage1,
--                      healing1, kills1, score2, ... }, ... } }   (flat numbers, light)
--   match.haul     = AP / XP / Champion Points / AvA rank gained, your medals
--   match.balance  = 0..100, how even the match was (red stomp .. green even fight)
--   match.titles   = player key -> title earned in the match ("Slayer", ...)
--   match.profile  = your stats against the best in the match, 0..1 per axis
local SBR = ScoreboardRemastered
local R = {}
SBR.Report = R

local SAMPLE_SEC = 15
local FIELDS = 4 -- per team in a sample: score, damage, healing, kills

local function Num(v) return type(v) == "number" and v or 0 end
local function Key(p) return (p.displayName and p.displayName ~= "") and p.displayName or p.characterName end

---------------------------------------------------------------------------
-- haul: what the match earned you
---------------------------------------------------------------------------
local function ReadHaul()
    local API = SBR.API
    return {
        ap = API("GetCurrencyAmount", CURT_ALLIANCE_POINTS, CURRENCY_LOCATION_CHARACTER),
        level = API("GetUnitLevel", "player"),
        xp = API("GetUnitXP", "player"),
        cp = API("GetPlayerChampionPointsEarned"),
        cpXp = API("GetPlayerChampionXP"),
        rank = API("GetUnitAvARank", "player"),
        rankPoints = API("GetUnitAvARankPoints", "player"),
    }
end

-- XP gained, across level-ups / champion points
local function XPGained(a, b)
    if type(a.cp) == "number" and type(b.cp) == "number" and type(a.cpXp) == "number" and type(b.cpXp) == "number"
        and (a.cp > 0 or b.cp > 0) then
        local gained = b.cpXp - a.cpXp
        for cp = a.cp, b.cp - 1 do gained = gained + Num(SBR.API("GetNumChampionXPInChampionPoint", cp)) end
        return gained
    end
    if type(a.xp) ~= "number" or type(b.xp) ~= "number" then return nil end
    local gained = b.xp - a.xp
    for level = Num(a.level), Num(b.level) - 1 do gained = gained + Num(SBR.API("GetNumExperiencePointsInLevel", level)) end
    return gained
end

function R:OnBegin(match)
    match.haulStart = ReadHaul()
end

---------------------------------------------------------------------------
-- timeline
---------------------------------------------------------------------------
function R:Sample(match, force)
    local t = Num(match.elapsed)
    match.timeline = match.timeline or { samples = {} }
    local tl = match.timeline
    local last = tl.samples[#tl.samples]
    if not force and last and t - last[1] < SAMPLE_SEC then return end
    if not SBR.Battleground:IsRunning(match.state) and not force then return end
    if not tl.teams then
        local ids = {}
        for id in pairs(match.teams or {}) do ids[#ids + 1] = id end
        table.sort(ids)
        if #ids == 0 then return end
        tl.teams = ids
    end
    local byTeam = {}
    for i, id in ipairs(tl.teams) do byTeam[id] = { Num(match.teams[id] and match.teams[id].score), 0, 0, 0 } end
    for _, p in pairs(match.players or {}) do
        local b = byTeam[p.team]
        if b then
            local s = p.scores or {}
            b[2] = b[2] + Num(s.DAMAGE_DONE)
            b[3] = b[3] + Num(s.HEALING_DONE)
            b[4] = b[4] + Num(s.KILL)
        end
    end
    local sample = { math.floor(t) }
    for _, id in ipairs(tl.teams) do
        for f = 1, FIELDS do sample[#sample + 1] = byTeam[id][f] end
    end
    tl.samples[#tl.samples + 1] = sample
end

-- field: 1 score, 2 damage, 3 healing, 4 kills. Returns { teamId = { {t, v}, ... } }
function R:Series(match, field)
    local tl = match and match.timeline
    local out = {}
    if not tl or not tl.teams then return out, {} end
    for i, id in ipairs(tl.teams) do
        local list = {}
        for _, s in ipairs(tl.samples) do list[#list + 1] = { s[1], Num(s[1 + (i - 1) * FIELDS + field]) } end
        out[id] = list
    end
    return out, tl.teams
end

-- Kills per minute per team, from the kill feed: { teamId = { [minute] = kills } }
function R:Momentum(match)
    local out, minutes = {}, 0
    for _, k in ipairs(match.killFeed or {}) do
        if k.killerTeam and k.t then
            local m = math.floor(k.t / 60) + 1
            out[k.killerTeam] = out[k.killerTeam] or {}
            out[k.killerTeam][m] = (out[k.killerTeam][m] or 0) + 1
            if m > minutes then minutes = m end
        end
    end
    return out, minutes
end

---------------------------------------------------------------------------
-- balance, titles, profile
---------------------------------------------------------------------------
-- 0..100: how close the final scores were, plus how often the lead changed hands
local function Balance(match)
    local scores = {}
    for _, t in pairs(match.teams or {}) do scores[#scores + 1] = Num(t.score) end
    if #scores < 2 then return nil end
    table.sort(scores, function(a, b) return a > b end)
    local closeness = scores[1] > 0 and (scores[2] / scores[1]) or 1
    local changes, leader = 0, nil
    local tl = match.timeline
    if tl and tl.teams then
        for _, s in ipairs(tl.samples) do
            local best, bestId = -1, nil
            for i, id in ipairs(tl.teams) do
                local v = Num(s[1 + (i - 1) * FIELDS + 1])
                if v > best then best, bestId = v, id elseif v == best then bestId = nil end
            end
            if bestId and leader and bestId ~= leader then changes = changes + 1 end
            if bestId then leader = bestId end
        end
    end
    local value = closeness * 75 + math.min(changes, 3) / 3 * 25
    return math.max(0, math.min(100, math.floor(value + 0.5)))
end

-- Each player's title: the stat where they did best relative to the best in the match.
R.TITLES = {
    { key = "kills", title = "Slayer", get = function(p) return Num(p.scores and p.scores.KILL) end },
    { key = "damage", title = "Vanguard", get = function(p) return Num(p.scores and p.scores.DAMAGE_DONE) end },
    { key = "healing", title = "Lifeline", get = function(p) return Num(p.scores and p.scores.HEALING_DONE) end },
    { key = "assists", title = "Wingman", get = function(p) return Num(p.scores and p.scores.ASSISTS) end },
    { key = "objectives", title = "Objective runner", get = function(p)
        local s = p.scores or {}
        return Num(s.FLAG_CAPTURED) * 3 + Num(s.CAPTURE_DEFENSE_POINTS) + Num(s.KILLED_FLAG_CARRIER) + Num(s.FLAG_CARRIED_TIME) / 30
    end },
    { key = "medals", title = "Medalist", get = function(p) return Num(p.medalCount) end },
}
local SURVIVOR = { key = "survival", title = "Unbreakable" }

local function Best(match)
    local best = {}
    for _, def in ipairs(R.TITLES) do
        local m = 0
        for _, p in pairs(match.players or {}) do m = math.max(m, def.get(p)) end
        best[def.key] = m
    end
    local maxDeaths = 0
    for _, p in pairs(match.players or {}) do maxDeaths = math.max(maxDeaths, Num(p.scores and p.scores.DEATH)) end
    best.deaths = maxDeaths
    return best
end

local function Titles(match, best)
    local out = {}
    for _, p in pairs(match.players or {}) do
        local title, top = nil, 0
        for _, def in ipairs(R.TITLES) do
            local v, m = def.get(p), best[def.key]
            local share = m > 0 and v / m or 0
            if share > top then title, top = def.title, share end
        end
        -- no deaths in a match where others died, and nothing better
        if Num(p.scores and p.scores.DEATH) == 0 and best.deaths > 0 and top < 0.6 then title = SURVIVOR.title end
        if title then out[Key(p)] = title end
    end
    return out
end

-- your stats against the best in the match, 0..1 each
local function Profile(match, best)
    local me
    for _, p in pairs(match.players or {}) do if p.isLocal then me = p break end end
    if not me then return nil end
    local out = {}
    for _, def in ipairs(R.TITLES) do
        local m = best[def.key]
        out[#out + 1] = { key = def.key, label = def.title, value = def.get(me), share = m > 0 and def.get(me) / m or 0 }
    end
    local d = Num(me.scores and me.scores.DEATH)
    out[#out + 1] = { key = "survival", label = "Survival", value = d,
        share = best.deaths > 0 and (1 - d / best.deaths) or 1 }
    return out
end

function R:OnFinalize(match)
    self:Sample(match, true)
    local best = Best(match)
    match.balance = Balance(match)
    match.titles = Titles(match, best)
    match.profile = Profile(match, best)
    local a, b = match.haulStart, ReadHaul()
    if a then
        local medals = 0
        for _, m in ipairs(match.myMedals or {}) do medals = medals + 1 end
        match.haul = {
            ap = (type(a.ap) == "number" and type(b.ap) == "number") and (b.ap - a.ap) or nil,
            xp = XPGained(a, b),
            cp = (type(a.cp) == "number" and type(b.cp) == "number") and (b.cp - a.cp) or nil,
            rank = b.rank, rankUp = type(a.rank) == "number" and type(b.rank) == "number" and b.rank > a.rank or nil,
            rankPoints = b.rankPoints,
            medals = medals,
        }
    end
    match.haulStart = nil
end

-- Color for a balance value: red (stomp) -> yellow -> green (even)
function R.BalanceColor(v)
    v = math.max(0, math.min(100, Num(v))) / 100
    if v < 0.5 then return 0.90, 0.30 + v * 0.9, 0.28 end
    return 0.90 - (v - 0.5) * 1.1, 0.75 + (v - 0.5) * 0.2, 0.30
end

function R.BalanceText(v)
    if v == nil then return "-" end
    if v >= 80 then return "Even fight" elseif v >= 55 then return "Contested" elseif v >= 30 then return "One-sided" end
    return "Stomp"
end

ScoreboardRemastered.Mark("Data/Report.lua")
