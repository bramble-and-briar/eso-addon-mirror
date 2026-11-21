-- KDStatTracker_ESQL.lua
-- Optional LibESQL integration. When LibESQL is installed, every stat this
-- add-on records becomes an SQL table (kd_*), a few helper SQL functions are
-- registered, and other add-ons can call KDST.Query. Without LibESQL this file does nothing.
--
--   SELECT * FROM kd_characters ORDER BY kd DESC
--   SELECT ability_name, kills FROM kd_kill_sources WHERE character = ? ORDER BY kills DESC LIMIT 10
--   SELECT match_type_name, COUNT(*), SUM(kills), SUM(deaths) FROM kd_matches GROUP BY 1
--   DELETE FROM kd_matches WHERE abandoned
--
-- All tables are live (read straight from the saved data on every query).
-- DELETE is supported where it makes sense and keeps totals consistent.

local KDST = KDStatTracker

local ESQLX = {}
KDST.ESQL = ESQLX

local PREFIX = "kd_"

local function Lib() return LibESQL end

function KDST.HasLibESQL()
    local L = Lib()
    return type(L) == "table" and type(L.RegisterTable) == "function" and type(L.Query) == "function"
end

-------------------------------------------------------------------------------
-- Helpers
-------------------------------------------------------------------------------
local function Tick() Lib().Tick() end

local function KDNumber(k, d)
    k, d = k or 0, d or 0
    if d == 0 then return k end
    return zo_roundToNearest(k / d, 0.01)
end

local function Pct(part, whole)
    if not whole or whole == 0 then return 0 end
    return zo_roundToNearest((part or 0) / whole * 100, 0.1)
end

local function Count(entry)
    if type(entry) == "table" then return entry.count or 0 end
    return tonumber(entry) or 0
end

-- Writes from SQL can delete many rows in one statement; tell the UI once.
local function NotifyChanged()
    EVENT_MANAGER:UnregisterForUpdate("KDStatTracker_ESQLChanged")
    EVENT_MANAGER:RegisterForUpdate("KDStatTracker_ESQLChanged", 0, function()
        EVENT_MANAGER:UnregisterForUpdate("KDStatTracker_ESQLChanged")
        KDST.callbacks:FireCallbacks("StatsChanged", "esql")
    end)
end

local function Characters()
    return KDST.data.characters or {}
end

-------------------------------------------------------------------------------
-- Table definitions
-------------------------------------------------------------------------------
local TABLES = {}

TABLES[#TABLES + 1] = {
    name = PREFIX .. "summary",
    desc = "KD Stat Tracker: account-wide totals (one row)",
    columns = {
        { "total_kills",  "int",  "Kills on every character" },
        { "total_deaths", "int",  "Deaths on every character" },
        { "kd",           "num",  "Account K/D ratio" },
        { "characters",   "int",  "Characters with recorded stats" },
        { "matches",      "int",  "Battlegrounds in the saved history" },
        { "total_duels",  "int",  "Duels on every character" },
        { "duel_wins",    "int",  "Duels won" },
        { "duel_losses",  "int",  "Duels lost" },
        { "duel_win_pct", "num",  "Duel win percentage" },
    },
    build = function(rows)
        local data, duels, n = KDST.data, KDST.data.duels or {}, 0
        for _ in pairs(Characters()) do n = n + 1 end
        rows[1] = {
            total_kills = data.totalKills or 0, total_deaths = data.totalDeaths or 0,
            kd = KDNumber(data.totalKills, data.totalDeaths), characters = n,
            matches = #(data.matchHistory or {}),
            total_duels = duels.totalDuels or 0, duel_wins = duels.wins or 0, duel_losses = duels.losses or 0,
            duel_win_pct = Pct(duels.wins, duels.totalDuels),
        }
    end,
}

TABLES[#TABLES + 1] = {
    name = PREFIX .. "session",
    desc = "KD Stat Tracker: this play session and the current match (one row)",
    columns = {
        { "character",     "text", "Character logged in" },
        { "kills",         "int",  "Kills this session" },
        { "deaths",        "int",  "Deaths this session" },
        { "kd",            "num",  "Session K/D ratio" },
        { "streak",        "int",  "Current kill streak" },
        { "best_streak",   "int",  "Best streak this session" },
        { "start_time",    "int",  "Session start (timestamp)" },
        { "duration_s",    "int",  "Seconds since the session started" },
        { "in_match",      "bool", "Whether a battleground is in progress" },
        { "match_kills",   "int",  "Kills in the current match" },
        { "match_deaths",  "int",  "Deaths in the current match" },
        { "in_pvp_area",   "bool", "In a battleground, Cyrodiil or Imperial City" },
    },
    build = function(rows)
        local s, m = KDST.session, KDST.match
        rows[1] = {
            character = KDST.charName, kills = s.kills, deaths = s.deaths, kd = KDNumber(s.kills, s.deaths),
            streak = s.streak, best_streak = s.bestStreak, start_time = s.startTime,
            duration_s = GetTimeStamp() - (s.startTime or GetTimeStamp()),
            in_match = m ~= nil, match_kills = m and m.kills or nil, match_deaths = m and m.deaths or nil,
            in_pvp_area = KDST.IsInPvPArea() == true,
        }
    end,
}

TABLES[#TABLES + 1] = {
    name = PREFIX .. "characters",
    desc = "KD Stat Tracker: lifetime kills / deaths per character",
    key = "character",
    columns = {
        { "character",       "text", "Character name" },
        { "kills",           "int",  "Lifetime kills" },
        { "deaths",          "int",  "Lifetime deaths" },
        { "kd",              "num",  "K/D ratio" },
        { "best_streak",     "int",  "Best kill streak" },
        { "is_current",      "bool", "The character logged in now" },
        { "unique_victims",  "int",  "Different players killed" },
        { "unique_killers",  "int",  "Different players who killed you" },
        { "favorite_ability","text", "Ability with the most kills", function(r)
            local top = KDST.SortedCounts(Characters()[r.character].killSources, "abilityName")[1]
            return top and top.name
        end },
        { "nemesis_ability", "text", "Ability that killed you most", function(r)
            local top = KDST.SortedCounts(Characters()[r.character].deathSources, "abilityName")[1]
            return top and top.name
        end },
    },
    build = function(rows)
        for name, c in pairs(Characters()) do
            Tick()
            local nv, nk = 0, 0
            for _ in pairs(c.victims or {}) do nv = nv + 1 end
            for _ in pairs(c.killers or {}) do nk = nk + 1 end
            rows[#rows + 1] = {
                character = name, kills = c.kills or 0, deaths = c.deaths or 0, kd = KDNumber(c.kills, c.deaths),
                best_streak = c.bestStreak or 0, is_current = name == KDST.charName,
                unique_victims = nv, unique_killers = nk,
            }
        end
    end,
    -- Same effect as "Reset Character" for that character's kill / death stats.
    delete = function(row)
        local c = Characters()[row.character]
        if not c then return end
        local data = KDST.data
        data.totalKills  = math.max(0, (data.totalKills or 0) - (c.kills or 0))
        data.totalDeaths = math.max(0, (data.totalDeaths or 0) - (c.deaths or 0))
        Characters()[row.character] = nil
        NotifyChanged()
    end,
}

-- kd_kill_sources / kd_death_sources share one shape.
local function SourceTable(name, desc, field, countCol, lastField, lastCol, lastDesc, charTotal, accountTotal)
    return {
        name = PREFIX .. name,
        desc = desc,
        columns = {
            { "character",    "text", "Character name" },
            { "ability_id",   "int",  "Ability id (0 = unknown)" },
            { "ability_name", "text", "Ability name" },
            { countCol,       "int",  "Count" },
            { lastCol,        "text", lastDesc },
            { "pct",          "num",  "Share of this character's total, in %" },
        },
        build = function(rows)
            for charName, c in pairs(Characters()) do
                local total = c[charTotal] or 0
                for id, e in pairs(c[field] or {}) do
                    Tick()
                    local n = Count(e)
                    rows[#rows + 1] = {
                        character = charName, ability_id = tonumber(id) or 0,
                        ability_name = type(e) == "table" and e.abilityName or KDST.AbilityName(tonumber(id)),
                        [countCol] = n, [lastCol] = type(e) == "table" and e[lastField] or nil,
                        pct = Pct(n, total), _key = id,
                    }
                end
            end
        end,
        -- Removing an ability also removes its count from the totals.
        delete = function(row)
            local c = Characters()[row.character]
            local e = c and c[field] and c[field][row._key]
            if e == nil then return end
            local n = Count(e)
            c[field][row._key] = nil
            c[charTotal] = math.max(0, (c[charTotal] or 0) - n)
            KDST.data[accountTotal] = math.max(0, (KDST.data[accountTotal] or 0) - n)
            NotifyChanged()
        end,
    }
end

TABLES[#TABLES + 1] = SourceTable("kill_sources", "KD Stat Tracker: kills per ability per character",
    "killSources", "kills", "lastVictim", "last_victim", "Last player killed with it", "kills", "totalKills")
TABLES[#TABLES + 1] = SourceTable("death_sources", "KD Stat Tracker: deaths per ability per character",
    "deathSources", "deaths", "lastKiller", "last_killer", "Last player who killed you with it", "deaths", "totalDeaths")

-- kd_victims / kd_killers
local function PlayerTable(name, desc, field, countCol, playerDesc)
    return {
        name = PREFIX .. name,
        desc = desc,
        columns = {
            { "character", "text", "Your character" },
            { "player",    "text", playerDesc },
            { countCol,    "int",  "Count" },
        },
        build = function(rows)
            for charName, c in pairs(Characters()) do
                for player, n in pairs(c[field] or {}) do
                    Tick()
                    rows[#rows + 1] = { character = charName, player = player, [countCol] = Count(n) }
                end
            end
        end,
        delete = function(row)
            local c = Characters()[row.character]
            if c and c[field] then c[field][row.player] = nil; NotifyChanged() end
        end,
    }
end

TABLES[#TABLES + 1] = PlayerTable("victims", "KD Stat Tracker: players you killed", "victims", "kills", "Player killed")
TABLES[#TABLES + 1] = PlayerTable("killers", "KD Stat Tracker: players who killed you", "killers", "deaths", "Player who killed you")

TABLES[#TABLES + 1] = {
    name = PREFIX .. "matches",
    desc = "KD Stat Tracker: battleground match history (last " .. KDST.MAX_MATCH_HISTORY .. ")",
    key = "match_id",
    columns = {
        { "match_id",        "int",  "Match number" },
        { "character",       "text", "Character that played it" },
        { "bg_id",           "int",  "Battleground id" },
        { "match_type",      "int",  "Game type id (BATTLEGROUND_GAME_TYPE_*)" },
        { "match_type_name", "text", "Game type name" },
        { "name",            "text", "Battleground name" },
        { "kills",           "int",  "Kills in the match" },
        { "deaths",          "int",  "Deaths in the match" },
        { "kd",              "num",  "K/D ratio for the match" },
        { "duration_s",      "int",  "Match length in seconds" },
        { "timestamp",       "int",  "When it ended (timestamp)" },
        { "abandoned",       "bool", "Left before the end" },
        { "date",            "text", "End date", function(r) return KDST.FormatDate(r.timestamp) end },
        { "duration",        "text", "Match length (m:ss)", function(r) return KDST.FormatDuration(r.duration_s) end },
    },
    build = function(rows)
        for i, m in ipairs(KDST.data.matchHistory or {}) do
            Tick()
            rows[#rows + 1] = {
                match_id = m.matchId or i, character = m.characterName, bg_id = m.bgId,
                match_type = m.matchType, match_type_name = KDST.GetMatchTypeName(m.matchType), name = m.name,
                kills = m.kills or 0, deaths = m.deaths or 0, kd = KDNumber(m.kills, m.deaths),
                duration_s = m.duration or 0, timestamp = m.timestamp, abandoned = m.abandoned == true,
                _entry = m,
            }
        end
    end,
    -- Removes the match from the history (character totals are not changed).
    delete = function(row)
        local history = KDST.data.matchHistory
        for i = #history, 1, -1 do
            if history[i] == row._entry then table.remove(history, i); NotifyChanged(); return end
        end
    end,
}

TABLES[#TABLES + 1] = {
    name = PREFIX .. "duels",
    desc = "KD Stat Tracker: duel record per character",
    key = "character",
    columns = {
        { "character", "text", "Character name" },
        { "duels",     "int",  "Duels fought" },
        { "wins",      "int",  "Duels won" },
        { "losses",    "int",  "Duels lost" },
        { "win_pct",   "num",  "Win percentage" },
        { "opponents", "int",  "Different opponents faced" },
    },
    build = function(rows)
        for charName, c in pairs((KDST.data.duels or {}).perCharStats or {}) do
            Tick()
            local n = 0
            for _ in pairs(c.charactersFaced or {}) do n = n + 1 end
            rows[#rows + 1] = {
                character = charName, duels = c.duels or 0, wins = c.wins or 0, losses = c.losses or 0,
                win_pct = Pct(c.wins, c.duels), opponents = n,
            }
        end
    end,
    delete = function(row)
        local duels = KDST.data.duels
        local c = duels.perCharStats[row.character]
        if not c then return end
        duels.totalDuels = math.max(0, (duels.totalDuels or 0) - (c.duels or 0))
        duels.wins       = math.max(0, (duels.wins or 0) - (c.wins or 0))
        duels.losses     = math.max(0, (duels.losses or 0) - (c.losses or 0))
        duels.perCharStats[row.character] = nil
        NotifyChanged()
    end,
}

TABLES[#TABLES + 1] = {
    name = PREFIX .. "duel_opponents",
    desc = "KD Stat Tracker: duel record against each opponent",
    columns = {
        { "character", "text", "Your character" },
        { "opponent",  "text", "Opponent @account name" },
        { "wins",      "int",  "Duels won against them" },
        { "losses",    "int",  "Duels lost against them" },
        { "duels",     "int",  "Duels against them" },
        { "win_pct",   "num",  "Win percentage against them" },
    },
    build = function(rows)
        for charName, c in pairs((KDST.data.duels or {}).perCharStats or {}) do
            for opp, rec in pairs(c.charactersFaced or {}) do
                Tick()
                local w, l = rec.wins or 0, rec.losses or 0
                rows[#rows + 1] = {
                    character = charName, opponent = opp, wins = w, losses = l, duels = w + l, win_pct = Pct(w, w + l),
                }
            end
        end
    end,
    -- Removing an opponent also removes those duels from the totals.
    delete = function(row)
        local duels = KDST.data.duels
        local c = duels.perCharStats[row.character]
        local rec = c and c.charactersFaced[row.opponent]
        if not rec then return end
        local w, l = rec.wins or 0, rec.losses or 0
        c.charactersFaced[row.opponent] = nil
        c.wins, c.losses = math.max(0, (c.wins or 0) - w), math.max(0, (c.losses or 0) - l)
        c.duels = math.max(0, (c.duels or 0) - w - l)
        duels.wins, duels.losses = math.max(0, (duels.wins or 0) - w), math.max(0, (duels.losses or 0) - l)
        duels.totalDuels = math.max(0, (duels.totalDuels or 0) - w - l)
        NotifyChanged()
    end,
}

-------------------------------------------------------------------------------
-- SQL functions
-------------------------------------------------------------------------------
local FUNCTIONS = {
    -- KD_RATIO(kills, deaths) -> number, same rule as the HUD (deaths 0 -> kills)
    KD_RATIO = function(k, d) return KDNumber(tonumber(k), tonumber(d)) end,
    -- KD_MATCH_TYPE(gameType) -> "Deathmatch", "Capture the Relic", ...
    KD_MATCH_TYPE = function(t) return KDST.GetMatchTypeName(tonumber(t)) end,
    -- KD_DURATION(seconds) -> "m:ss" / "h:mm:ss"
    KD_DURATION = function(s) return s and KDST.FormatDuration(tonumber(s)) end,
    -- KD_STREAK_NAME(n) -> "Killing Spree", "Rampage", ... for the highest streak tier reached
    KD_STREAK_NAME = function(n)
        n = tonumber(n)
        if not n then return nil end
        local best, name = 0, nil
        for at, def in pairs(KDST.STREAKS) do
            if n >= at and at > best then best, name = at, def.name end
        end
        return name
    end,
}

-------------------------------------------------------------------------------
-- Registration
-------------------------------------------------------------------------------
function ESQLX.Register()
    if ESQLX.registered or not KDST.HasLibESQL() then return false end
    local L = Lib()
    for _, def in ipairs(TABLES) do
        def.live = true
        local ok, err = pcall(L.RegisterTable, def)
        if not ok then KDST.Print("LibESQL: could not register " .. def.name .. ": " .. tostring(err)) end
    end
    if type(L.RegisterFunction) == "function" then
        for name, fn in pairs(FUNCTIONS) do pcall(L.RegisterFunction, name, fn) end
    end
    ESQLX.registered = true
    return true
end

function ESQLX.GetTableNames()
    local out = {}
    for i, def in ipairs(TABLES) do out[i] = def.name end
    return out
end


-------------------------------------------------------------------------------
-- Querying from Lua (for other add-ons): rows as objects, or nil + error text.
-------------------------------------------------------------------------------
function KDST.Query(sql, params)
    if not KDST.HasLibESQL() then return nil, "LibESQL is not installed" end
    return Lib().Select(sql, params)
end
