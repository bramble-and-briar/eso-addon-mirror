-- Match database: a compact, long-lived index of every match you've played.
--
-- Full matches (every player, kill feed, recaps) are heavy, so only the last
-- `maxHistory` are kept in sv.history. Each finished match also writes one small
-- summary record to sv.db.records, which is kept far longer (`maxRecords`). The
-- history browser, lifetime stats, and per-map and per-class records all read
-- from these records. A record points back at its full match by id while that
-- match is still stored.
local SBR = ScoreboardRemastered
local DB = {}
SBR.MatchDB = DB

DB.FILTERS = { "all", "won", "lost", "map", "class" }
DB.FILTER_LABELS = { all = "All matches", won = "Victories", lost = "Defeats", map = "This map", class = "This class" }
DB.SORTS = { "newest", "score", "kills", "kda", "damage", "healing", "medals" }
DB.SORT_LABELS = {
    newest = "Newest", score = "Score", kills = "Kills", kda = "K/D/A", damage = "Damage", healing = "Healing", medals = "Medals",
}

local function Num(v) return type(v) == "number" and v or 0 end

function DB:Init(sv)
    sv.db = sv.db or { version = 1, records = {} }
    sv.db.players = sv.db.players or {}
    sv.db.applied = sv.db.applied or {}
    -- shared icon lookups: a player entry stores ability / class -> number only
    -- (saved variables are rebuilt on every load, so fewer tables load faster)
    sv.db.icons = sv.db.icons or {}
    sv.db.classIcons = sv.db.classIcons or {}
    self.icons, self.classIcons = sv.db.icons, sv.db.classIcons
    self.sv = sv
    self.applied = sv.db.applied
    -- Storage: records and players are saved packed (SBR.Pack, Util.lua), one or a
    -- few strings each, and unpacked the first time they're read:
    --   sv.db.recordsPacked  list of { id, at, p }
    --   sv.db.playersPacked  key -> { p, t = lastSeen, y = isYou }
    -- sv.db.records / sv.db.players hold what older versions saved as plain tables
    -- until the background job (MigrateStep) packs them.
    local db = sv.db
    db.records = db.records or {}
    db.recordsPacked = db.recordsPacked or {}
    db.playersPacked = db.playersPacked or {}
    self.records = {}
    for _, r in ipairs(db.records) do self.records[#self.records + 1] = r end
    for _, e in ipairs(db.recordsPacked) do self.records[#self.records + 1] = SBR.LazyUnpack(e.p, { id = e.id, at = e.at }) end
    table.sort(self.records, function(a, b) return Num(a.at) < Num(b.at) end)
    self.players = {}
    for k, e in pairs(db.players) do self.players[k] = e end
    for k, st in pairs(db.playersPacked) do self.players[k] = SBR.LazyUnpack(st.p, { key = k }) end
    -- matches saved before the database (or the player index) existed
    for _, m in ipairs(SBR.MatchLog:GetHistory()) do
        if not self.applied[m.id] and m.endedAt then self:Add(m) end
    end
end

function DB:StoreRecord(rec)
    local db = self.sv.db
    local entry = { id = rec.id, at = rec.at, p = SBR.Pack(SBR.Realize(rec)) }
    for i = #db.records, 1, -1 do if db.records[i].id == rec.id then table.remove(db.records, i) end end
    for i, e in ipairs(db.recordsPacked) do
        if e.id == rec.id then db.recordsPacked[i] = entry return end
    end
    db.recordsPacked[#db.recordsPacked + 1] = entry
end

function DB:DropRecord(id)
    local db = self.sv.db
    for _, store in ipairs({ db.recordsPacked, db.records }) do
        for i = #store, 1, -1 do if store[i].id == id then table.remove(store, i) end end
    end
end

function DB:StorePlayer(key, e)
    SBR.Realize(e)
    self.sv.db.playersPacked[key] = { p = SBR.Pack(e), t = e.lastSeen, y = e.isYou or nil }
    self.sv.db.players[key] = nil
end

-- lastSeen / isYou without unpacking the player
function DB:PlayerMeta(key)
    local st = self.sv.db.playersPacked[key]
    if st then return Num(st.t), st.y == true end
    local e = self.sv.db.players[key] or self.players[key]
    if e then return Num(e.lastSeen), e.isYou == true end
    return 0, false
end

function DB:DropPlayer(key)
    self.players[key] = nil
    self.sv.db.playersPacked[key] = nil
    self.sv.db.players[key] = nil
end

-- Drop the players seen longest ago until the index fits maxPlayers. Returns true
-- when nothing was dropped.
function DB:TrimPlayers()
    local max = SBR.sv.maxPlayers or 1000
    local count, oldestKey, oldest = 0, nil, nil
    for k in pairs(self.players) do
        count = count + 1
        local seen, isYou = self:PlayerMeta(k)
        if not isYou and (not oldest or seen < oldest) then oldestKey, oldest = k, seen end
    end
    if count > max and oldestKey then
        self:DropPlayer(oldestKey)
        return false
    end
    return true
end

-- One background step (UI/MatchLog.lua): pack a few records / players that older
-- versions saved as tables, then trim the player index. Returns true when done.
local MIGRATE_CHUNK = 25
function DB:MigrateStep()
    local db = self.sv.db
    if #db.records > 0 then
        for _ = 1, MIGRATE_CHUNK do
            local r = db.records[1]
            if not r then break end
            self:StoreRecord(r)
        end
        return false
    end
    if next(db.players) ~= nil then
        for _ = 1, MIGRATE_CHUNK do
            local k, e = next(db.players)
            if not k then break end
            self:StorePlayer(k, e)
        end
        return false
    end
    return self:TrimPlayers()
end

-- Where your row ranks in a match, by score.
local function Rank(match, me, sameTeamOnly)
    local list = {}
    for _, p in pairs(match.players or {}) do
        if not sameTeamOnly or p.team == me.team then list[#list + 1] = Num(p.scores and p.scores.SCORE) end
    end
    table.sort(list, function(a, b) return a > b end)
    local mine = Num(me.scores and me.scores.SCORE)
    for i, v in ipairs(list) do if v == mine then return i, #list end end
    return nil, #list
end

function DB:Summarize(match)
    local me
    for _, p in pairs(match.players or {}) do if p.isLocal then me = p break end end
    local s = me and me.scores or {}
    local f = me and me.fight or {}
    local rec = {
        id = match.id,
        at = match.startedAt,
        map = match.name or match.zoneName or "Battleground",
        gameType = match.gameTypeName,
        teamSize = match.teamSize,
        result = match.result or "unknown",
        duration = match.duration,
        character = match.character,
        account = match.account,
        localTeam = match.localTeam,
        teams = {},
        kills = s.KILL, deaths = s.DEATH, assists = s.ASSISTS, score = s.SCORE,
        damage = s.DAMAGE_DONE or f.damageDone, healing = s.HEALING_DONE or f.healingDone,
        flags = s.FLAG_CAPTURED,
        medalCount = me and me.medalCount or 0,
        medals = {},
        classId = me and me.classId, className = me and me.className, classIcon = me and me.classIcon,
        dps = f.dps, hps = f.hps, maxHit = f.maxHit, maxHitAbility = f.maxHitAbility,
        critRate = f.critRate, damageTaken = f.damageTaken, killingBlows = f.killingBlows,
        fights = match.lf and match.lf.fightList and #match.lf.fightList or nil,
        recaps = match.lf and match.lf.deaths and #match.lf.deaths or nil,
        top = {},
    }
    for id, t in pairs(match.teams or {}) do
        rec.teams[#rec.teams + 1] = { id = id, name = t.name, color = t.color, score = t.score }
    end
    table.sort(rec.teams, function(a, b) return a.id < b.id end)
    for _, m in ipairs(me and me.medals or {}) do
        rec.medals[#rec.medals + 1] = { name = m.name, icon = m.icon, count = m.count }
    end
    table.sort(rec.medals, function(a, b) return (a.count or 0) > (b.count or 0) end)
    for i, a in ipairs(f.topAbilities or {}) do
        if i > 3 then break end
        rec.top[#rec.top + 1] = { name = a.name, icon = a.icon, damage = a.damage }
    end
    if me then
        rec.teamRank, rec.teamSizeRanked = Rank(match, me, true)
        rec.rank, rec.players = Rank(match, me, false)
    end
    -- match MVP: top score across both teams
    local best
    for _, p in pairs(match.players or {}) do
        if not best or Num(p.scores and p.scores.SCORE) > Num(best.scores and best.scores.SCORE) then best = p end
    end
    if best then rec.mvp = { name = best.characterName, team = best.team, isYou = best.isLocal or nil } end
    return rec
end

function DB:Add(match)
    local rec = self:Summarize(match)
    self:AddPlayers(match, rec)
    self:StoreRecord(rec)
    for i, r in ipairs(self.records) do
        if r.id == rec.id then
            self.records[i] = rec
            return rec
        end
    end
    table.insert(self.records, rec)
    local max = SBR.sv.maxRecords or 500
    while #self.records > max do
        local old = table.remove(self.records, 1)
        self:DropRecord(old.id)
    end
    return rec
end

function DB:GetRecords() return self.records end

function DB:FindMatch(id)
    for i, m in ipairs(SBR.MatchLog:GetHistory()) do
        if m.id == id then return m, i end
    end
    return nil
end

local function KDA(r) return (Num(r.kills) + Num(r.assists) * 0.5) / math.max(1, Num(r.deaths)) end
DB.KDA = KDA

local SORT_VALUE = {
    newest = function(r) return Num(r.at) end,
    score = function(r) return Num(r.score) end,
    kills = function(r) return Num(r.kills) end,
    kda = KDA,
    damage = function(r) return Num(r.damage) end,
    healing = function(r) return Num(r.healing) end,
    medals = function(r) return Num(r.medalCount) end,
}

-- filter: one of DB.FILTERS. `ref` is the record whose map / class "This map" and
-- "This class" compare against.
function DB:Query(filter, sort, ref)
    local out = {}
    for _, r in ipairs(self.records) do
        local keep = true
        if filter == "won" then keep = r.result == "won"
        elseif filter == "lost" then keep = r.result == "lost"
        elseif filter == "map" then keep = ref ~= nil and r.map == ref.map
        elseif filter == "class" then keep = ref ~= nil and r.classId == ref.classId end
        if keep then out[#out + 1] = r end
    end
    local value = SORT_VALUE[sort] or SORT_VALUE.newest
    table.sort(out, function(a, b)
        local va, vb = value(a), value(b)
        if va ~= vb then return va > vb end
        return Num(a.at) > Num(b.at)
    end)
    return out
end

-- Lifetime numbers over a list of records.
function DB:Aggregate(list)
    local a = { matches = #list, won = 0, lost = 0, kills = 0, deaths = 0, assists = 0, damage = 0, healing = 0,
                medals = 0, seconds = 0, maps = {}, classes = {}, mvps = 0 }
    for _, r in ipairs(list) do
        if r.result == "won" then a.won = a.won + 1 elseif r.result == "lost" then a.lost = a.lost + 1 end
        a.kills = a.kills + Num(r.kills)
        a.deaths = a.deaths + Num(r.deaths)
        a.assists = a.assists + Num(r.assists)
        a.damage = a.damage + Num(r.damage)
        a.healing = a.healing + Num(r.healing)
        a.medals = a.medals + Num(r.medalCount)
        a.seconds = a.seconds + Num(r.duration)
        if r.mvp and r.mvp.isYou then a.mvps = a.mvps + 1 end
        local m = a.maps[r.map] or { map = r.map, played = 0, won = 0 }
        m.played, m.won = m.played + 1, m.won + (r.result == "won" and 1 or 0)
        a.maps[r.map] = m
        if r.className then
            local c = a.classes[r.className] or { className = r.className, icon = r.classIcon, played = 0, won = 0 }
            c.played, c.won = c.played + 1, c.won + (r.result == "won" and 1 or 0)
            a.classes[r.className] = c
        end
        if not a.bestDamage or Num(r.damage) > Num(a.bestDamage.damage) then a.bestDamage = r end
        if not a.bestKills or Num(r.kills) > Num(a.bestKills.kills) then a.bestKills = r end
        if not a.bestHealing or Num(r.healing) > Num(a.bestHealing.healing) then a.bestHealing = r end
    end
    local decided = a.won + a.lost
    a.winRate = decided > 0 and a.won / decided * 100 or nil
    a.kd = a.kills / math.max(1, a.deaths)
    local fav
    for _, m in pairs(a.maps) do if not fav or m.played > fav.played then fav = m end end
    a.favoriteMap = fav
    -- current streak from the newest match back
    local newest = self:Query("all", "newest")
    local streak, kind = 0, nil
    for _, r in ipairs(newest) do
        if r.result ~= "won" and r.result ~= "lost" then break end
        if kind == nil then kind = r.result end
        if r.result ~= kind then break end
        streak = streak + 1
    end
    a.streak, a.streakKind = streak, kind
    return a
end

---------------------------------------------------------------------------
-- Player index: everyone you've shared a battleground with, across matches.
-- Keyed by @account (character name when the account is hidden). Each match is
-- applied once (sv.db.applied), so re-finalizing never double counts.
---------------------------------------------------------------------------
DB.PLAYER_FILTERS = { "all", "allies", "foes", "nemesis", "you" }
DB.PLAYER_FILTER_LABELS = { all = "Everyone", allies = "Teammates", foes = "Opponents", nemesis = "Killed you", you = "You" }
DB.PLAYER_SORTS = { "seen", "recent", "kills", "damage", "healing", "killedYou", "name" }
DB.PLAYER_SORT_LABELS = {
    seen = "Most seen", recent = "Last seen", kills = "Kills", damage = "Damage", healing = "Healing",
    killedYou = "Killed you", name = "Name",
}

local function PlayerKey(p)
    if p.displayName and p.displayName ~= "" then return p.displayName end
    return p.characterName or "?"
end

-- ability name -> total damage (a number; older saves hold { name, icon, damage })
local function AbilityDamage(v) return type(v) == "table" and Num(v.damage) or Num(v) end

local function TopInto(map, list, icons)
    for _, a in ipairs(list or {}) do
        if a.name and a.name ~= "" then
            map[a.name] = AbilityDamage(map[a.name]) + Num(a.damage)
            if a.icon and a.icon ~= "" and not icons[a.name] then icons[a.name] = a.icon end
        end
    end
end

function DB:AddPlayers(match, rec)
    if not match.id or self.applied[match.id] then return end
    self.applied[match.id] = true
    local won = match.result == "won"
    local lost = match.result == "lost"
    for _, p in pairs(match.players or {}) do
        local key = PlayerKey(p)
        local e = self.players[key]
        if not e then
            e = { key = key, account = p.displayName, firstSeen = match.startedAt, matches = 0,
                  withMatches = 0, withWon = 0, againstMatches = 0, againstWon = 0,
                  kills = 0, deaths = 0, assists = 0, damage = 0, healing = 0, score = 0, medals = 0, flags = 0,
                  killedYou = 0, killedByYou = 0, damageToYou = 0, damageFromYou = 0, healedYou = 0, healedByYou = 0,
                  bestScore = 0, classes = {}, characters = {}, maps = {}, abilities = {} }
            self.players[key] = e
        end
        e.isYou = p.isLocal or e.isYou
        if p.characterName and p.characterName ~= "" then e.name = p.characterName end
        e.name = e.name or key
        e.characters[e.name or "?"] = true
        e.matches = e.matches + 1
        e.lastSeen, e.lastMap, e.lastMatchId = match.startedAt, match.name, match.id
        local sameTeam = p.team == match.localTeam
        if not p.isLocal then
            if sameTeam then
                e.withMatches = e.withMatches + 1
                if won then e.withWon = e.withWon + 1 end
            else
                e.againstMatches = e.againstMatches + 1
                if won then e.againstWon = e.againstWon + 1 end
            end
        end
        local sc = p.scores or {}
        e.kills = e.kills + Num(sc.KILL)
        e.deaths = e.deaths + Num(sc.DEATH)
        e.assists = e.assists + Num(sc.ASSISTS)
        e.damage = e.damage + Num(sc.DAMAGE_DONE)
        e.healing = e.healing + Num(sc.HEALING_DONE)
        e.score = e.score + Num(sc.SCORE)
        e.flags = e.flags + Num(sc.FLAG_CAPTURED)
        e.medals = e.medals + Num(p.medalCount)
        if Num(sc.SCORE) > e.bestScore then e.bestScore, e.bestScoreMap = Num(sc.SCORE), match.name end
        if p.className then
            -- class name -> matches (a number; older saves hold a table)
            local c = e.classes[p.className]
            e.classes[p.className] = (type(c) == "table" and Num(c.matches) or Num(c)) + 1
            if p.classIcon then self.classIcons[p.className] = p.classIcon end
            e.lastClass, e.lastClassIcon = p.className, p.classIcon
        end
        e.maps[match.name or "?"] = (e.maps[match.name or "?"] or 0) + 1
        local v = p.vs or {}
        e.killedYou = e.killedYou + Num(v.killedYou)
        e.killedByYou = e.killedByYou + Num(v.killedByYou)
        e.damageToYou = e.damageToYou + Num(v.damageToYou)
        e.damageFromYou = e.damageFromYou + Num(v.damageFromYou)
        e.healedYou = e.healedYou + Num(v.healedYou)
        e.healedByYou = e.healedByYou + Num(v.healedByYou)
        TopInto(e.abilities, p.fight and p.fight.topAbilities, self.icons)
        -- keep the ability map small: top 8
        local list = {}
        for name, v in pairs(e.abilities) do list[#list + 1] = { name = name, damage = AbilityDamage(v) } end
        if #list > 8 then
            table.sort(list, function(a, b) return a.damage > b.damage end)
            e.abilities = {}
            for i = 1, 8 do e.abilities[list[i].name] = list[i].damage end
        end
        self:StorePlayer(key, e)
    end
    -- cap the index, dropping the players seen longest ago
    self:TrimPlayers()
end

function DB:GetPlayer(key) return self.players[key] end

local PLAYER_SORT_VALUE = {
    seen = function(e) return e.matches end,
    recent = function(e) return Num(e.lastSeen) end,
    kills = function(e) return e.kills end,
    damage = function(e) return e.damage end,
    healing = function(e) return e.healing end,
    killedYou = function(e) return e.killedYou end,
}

function DB:QueryPlayers(filter, sort)
    local out = {}
    for _, e in pairs(self.players) do
        local keep = true
        if filter == "allies" then keep = e.withMatches > 0
        elseif filter == "foes" then keep = e.againstMatches > 0
        elseif filter == "nemesis" then keep = e.killedYou > 0
        elseif filter == "you" then keep = e.isYou == true end
        if keep then out[#out + 1] = e end
    end
    if sort == "name" then
        table.sort(out, function(a, b) return (a.name or a.key):lower() < (b.name or b.key):lower() end)
    else
        local value = PLAYER_SORT_VALUE[sort] or PLAYER_SORT_VALUE.seen
        table.sort(out, function(a, b)
            local va, vb = value(a), value(b)
            if va ~= vb then return va > vb end
            return Num(a.lastSeen) > Num(b.lastSeen)
        end)
    end
    return out
end

-- Derived numbers for the player card.
function DB:PlayerSummary(e)
    local n = math.max(1, e.matches)
    local abilities = {}
    for name, v in pairs(e.abilities) do
        local icon = type(v) == "table" and v.icon or nil
        abilities[#abilities + 1] = { name = name, damage = AbilityDamage(v), icon = icon or self.icons[name] }
    end
    table.sort(abilities, function(a, b) return a.damage > b.damage end)
    local classes = {}
    for name, c in pairs(e.classes) do
        if type(c) == "table" then
            classes[#classes + 1] = { className = c.className or name, icon = c.icon or self.classIcons[name], matches = Num(c.matches) }
        else
            classes[#classes + 1] = { className = name, icon = self.classIcons[name], matches = Num(c) }
        end
    end
    table.sort(classes, function(a, b) return a.matches > b.matches end)
    local maps = {}
    for m, c in pairs(e.maps) do maps[#maps + 1] = { map = m, count = c } end
    table.sort(maps, function(a, b) return a.count > b.count end)
    local characters = {}
    for c in pairs(e.characters) do characters[#characters + 1] = c end
    table.sort(characters)
    return {
        perMatch = { kills = e.kills / n, deaths = e.deaths / n, assists = e.assists / n,
                     damage = e.damage / n, healing = e.healing / n, score = e.score / n },
        kd = e.kills / math.max(1, e.deaths),
        abilities = abilities, classes = classes, maps = maps, characters = characters,
        relation = e.isYou and "you"
            or (e.withMatches > 0 and e.againstMatches > 0 and "both")
            or (e.withMatches > 0 and "ally") or "foe",
    }
end
ScoreboardRemastered.Mark("Data/MatchDB.lua")
