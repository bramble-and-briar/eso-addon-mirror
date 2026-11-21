-- KDStatTracker_Storage.lua
-- Where the saved stats live.
--
-- With LibESQL installed, stats are stored in LibESQL user tables (kdst_*,
-- saved in LibESQL_SV). The first time, the old KDStatTrackerVars data is
-- copied in; KDStatTrackerVars is then left as it was, as a backup.
--
-- The rest of the add-on keeps working on the same KDST.data table as
-- before. This module loads KDST.data from the tables and, after every
-- change (the "StatsChanged" callback), writes back only the rows that
-- differ from what is stored.
--
-- Modes (KDST.Store.mode):
--   "libesql"   - normal: KDST.data is loaded from / saved to kdst_* tables.
--   "pending"   - stats were migrated, but LibESQL isn't loaded this session.
--                 New stats are kept in KDStatTrackerVars.pending and merged
--                 into the tables the next time LibESQL is loaded.
--   "savedvars" - never migrated (no LibESQL), or a write to LibESQL failed
--                 (e.g. the console row limit); KDStatTrackerVars is used
--                 exactly like before.

local KDST = KDStatTracker

local Store = { mode = "savedvars", snap = {}, writing = false }
KDST.Store = Store

local STORE_VERSION = 1
local BULK_THRESHOLD = 20      -- more changed rows than this: rewrite the table
local SYNC_DELAY_MS = 250
local SEP, NILMARK = "\31", "\1"

local function Lib() return LibESQL end

local function DeepCopy(v)
    if type(v) ~= "table" then return v end
    local out = {}
    for k, x in pairs(v) do out[k] = DeepCopy(x) end
    return out
end

local function N(v) return tonumber(v) or 0 end

local function NewChar()
    return { kills = 0, deaths = 0, bestStreak = 0, killSources = {}, deathSources = {}, victims = {}, killers = {} }
end

local function Char(data, name)
    local c = data.characters[name]
    if not c then c = NewChar(); data.characters[name] = c end
    for k, v in pairs(NewChar()) do if c[k] == nil then c[k] = v end end
    return c
end

local function DuelChar(data, name)
    local per = data.duels.perCharStats
    local c = per[name]
    if not c then c = { duels = 0, wins = 0, losses = 0, charactersFaced = {} }; per[name] = c end
    c.charactersFaced = c.charactersFaced or {}
    return c
end

local function NewData()
    local d = DeepCopy(KDST.dataDefaults)
    d.schema = KDST.SCHEMA
    return d
end

local function Normalize(data)
    for k, v in pairs(NewData()) do if data[k] == nil then data[k] = v end end
    data.duels.perCharStats = data.duels.perCharStats or {}
    return data
end

-------------------------------------------------------------------------------
-- Table specs: columns, key columns, data -> rows, rows -> data
-------------------------------------------------------------------------------
local META_FIELDS = {
    schema       = function(d) return d.schema end,
    totalKills   = function(d) return d.totalKills end,
    totalDeaths  = function(d) return d.totalDeaths end,
    matchCounter = function(d) return d.matchCounter end,
    totalDuels   = function(d) return d.duels.totalDuels end,
    duelWins     = function(d) return d.duels.wins end,
    duelLosses   = function(d) return d.duels.losses end,
    storeVersion = function() return STORE_VERSION end,
}

local SPECS = {
    {
        name = "kdst_meta",
        desc = "KD Stat Tracker storage: account totals and counters",
        columns = { { "key", "text" }, { "value", "int" } },
        keys = { "key" },
        rows = function(d, out)
            for key, get in pairs(META_FIELDS) do out[#out + 1] = { key = key, value = N(get(d)) } end
        end,
        apply = function(d, rows)
            local m = {}
            for _, r in ipairs(rows) do m[r.key] = N(r.value) end
            d.schema = m.schema or KDST.SCHEMA
            d.totalKills, d.totalDeaths, d.matchCounter = m.totalKills or 0, m.totalDeaths or 0, m.matchCounter or 0
            d.duels.totalDuels, d.duels.wins, d.duels.losses = m.totalDuels or 0, m.duelWins or 0, m.duelLosses or 0
        end,
    },
    {
        name = "kdst_characters",
        desc = "KD Stat Tracker storage: per-character kills / deaths",
        columns = { { "character", "text" }, { "kills", "int" }, { "deaths", "int" }, { "best_streak", "int" } },
        keys = { "character" },
        rows = function(d, out)
            for name, c in pairs(d.characters) do
                out[#out + 1] = { character = name, kills = N(c.kills), deaths = N(c.deaths), best_streak = N(c.bestStreak) }
            end
        end,
        apply = function(d, rows)
            for _, r in ipairs(rows) do
                local c = Char(d, r.character)
                c.kills, c.deaths, c.bestStreak = N(r.kills), N(r.deaths), N(r.best_streak)
            end
        end,
    },
    {
        name = "kdst_sources",
        desc = "KD Stat Tracker storage: kills / deaths per ability",
        columns = { { "character", "text" }, { "kind", "text" }, { "ability_id", "int" },
                    { "ability_name", "text" }, { "count", "int" }, { "last_player", "text" } },
        keys = { "character", "kind", "ability_id" },
        rows = function(d, out)
            for name, c in pairs(d.characters) do
                for id, e in pairs(c.killSources or {}) do
                    out[#out + 1] = { character = name, kind = "kill", ability_id = N(id), ability_name = e.abilityName,
                                      count = N(e.count), last_player = e.lastVictim }
                end
                for id, e in pairs(c.deathSources or {}) do
                    out[#out + 1] = { character = name, kind = "death", ability_id = N(id), ability_name = e.abilityName,
                                      count = N(e.count), last_player = e.lastKiller }
                end
            end
        end,
        apply = function(d, rows)
            for _, r in ipairs(rows) do
                local c = Char(d, r.character)
                local id = N(r.ability_id)
                if r.kind == "kill" then
                    c.killSources[id] = { count = N(r.count), abilityName = r.ability_name, lastVictim = r.last_player }
                elseif r.kind == "death" then
                    c.deathSources[id] = { count = N(r.count), abilityName = r.ability_name, lastKiller = r.last_player }
                end
            end
        end,
    },
    {
        name = "kdst_players",
        desc = "KD Stat Tracker storage: players you killed / who killed you",
        columns = { { "character", "text" }, { "kind", "text" }, { "player", "text" }, { "count", "int" } },
        keys = { "character", "kind", "player" },
        rows = function(d, out)
            for name, c in pairs(d.characters) do
                for p, n in pairs(c.victims or {}) do out[#out + 1] = { character = name, kind = "victim", player = p, count = N(n) } end
                for p, n in pairs(c.killers or {}) do out[#out + 1] = { character = name, kind = "killer", player = p, count = N(n) } end
            end
        end,
        apply = function(d, rows)
            for _, r in ipairs(rows) do
                local c = Char(d, r.character)
                if r.kind == "victim" then c.victims[r.player] = N(r.count)
                elseif r.kind == "killer" then c.killers[r.player] = N(r.count) end
            end
        end,
    },
    {
        name = "kdst_matches",
        desc = "KD Stat Tracker storage: battleground history",
        columns = { { "seq", "int" }, { "match_id", "int" }, { "character", "text" }, { "bg_id", "int" },
                    { "match_type", "int" }, { "name", "text" }, { "kills", "int" }, { "deaths", "int" },
                    { "duration", "int" }, { "timestamp", "int" }, { "abandoned", "bool" } },
        keys = { "seq" },
        rows = function(d, out)
            for i, m in ipairs(d.matchHistory) do
                out[#out + 1] = { seq = i, match_id = m.matchId, character = m.characterName, bg_id = m.bgId,
                                  match_type = m.matchType, name = m.name, kills = N(m.kills), deaths = N(m.deaths),
                                  duration = N(m.duration), timestamp = m.timestamp, abandoned = m.abandoned == true }
            end
        end,
        apply = function(d, rows)
            table.sort(rows, function(a, b) return N(a.seq) < N(b.seq) end)
            d.matchHistory = {}
            for i, r in ipairs(rows) do
                d.matchHistory[i] = { matchId = r.match_id, characterName = r.character, bgId = r.bg_id,
                                      matchType = r.match_type, name = r.name, kills = N(r.kills), deaths = N(r.deaths),
                                      duration = N(r.duration), timestamp = r.timestamp, abandoned = r.abandoned or nil }
            end
        end,
    },
    {
        name = "kdst_duels",
        desc = "KD Stat Tracker storage: duel record per character",
        columns = { { "character", "text" }, { "duels", "int" }, { "wins", "int" }, { "losses", "int" } },
        keys = { "character" },
        rows = function(d, out)
            for name, c in pairs(d.duels.perCharStats) do
                out[#out + 1] = { character = name, duels = N(c.duels), wins = N(c.wins), losses = N(c.losses) }
            end
        end,
        apply = function(d, rows)
            for _, r in ipairs(rows) do
                local c = DuelChar(d, r.character)
                c.duels, c.wins, c.losses = N(r.duels), N(r.wins), N(r.losses)
            end
        end,
    },
    {
        name = "kdst_duel_opponents",
        desc = "KD Stat Tracker storage: duel record per opponent",
        columns = { { "character", "text" }, { "opponent", "text" }, { "wins", "int" }, { "losses", "int" } },
        keys = { "character", "opponent" },
        rows = function(d, out)
            for name, c in pairs(d.duels.perCharStats) do
                for opp, rec in pairs(c.charactersFaced or {}) do
                    out[#out + 1] = { character = name, opponent = opp, wins = N(rec.wins), losses = N(rec.losses) }
                end
            end
        end,
        apply = function(d, rows)
            for _, r in ipairs(rows) do
                DuelChar(d, r.character).charactersFaced[r.opponent] = { wins = N(r.wins), losses = N(r.losses) }
            end
        end,
    },
}

local SPEC_BY_NAME = {}
for _, spec in ipairs(SPECS) do
    SPEC_BY_NAME[spec.name] = spec
    local cols, nonKeys, isKey = {}, {}, {}
    for _, k in ipairs(spec.keys) do isKey[k] = true end
    for i, c in ipairs(spec.columns) do
        cols[i] = c[1] .. " " .. c[2]
        if not isKey[c[1]] then nonKeys[#nonKeys + 1] = c[1] end
    end
    spec.createCols, spec.nonKeys = cols, nonKeys
    local where = {}
    for i, k in ipairs(spec.keys) do where[i] = k .. " = ?" end
    spec.where = table.concat(where, " AND ")
end

local function KeyOf(spec, row)
    local parts = {}
    for i, k in ipairs(spec.keys) do
        local v = row[k]
        parts[i] = v == nil and NILMARK or zo_strlower(tostring(v))
    end
    return table.concat(parts, SEP)
end

local function SigOf(spec, row)
    local parts = {}
    for i, c in ipairs(spec.columns) do
        local v = row[c[1]]
        parts[i] = v == nil and NILMARK or tostring(v)
    end
    return table.concat(parts, SEP)
end

local function DesiredRows(spec, data)
    local list = {}
    spec.rows(data, list)
    return list
end

-------------------------------------------------------------------------------
-- LibESQL access
-------------------------------------------------------------------------------
function Store.Available()
    local L = Lib()
    return KDST.HasLibESQL and KDST.HasLibESQL() and L.loaded == true
        and type(L.CreateTable) == "function" and type(L.Insert) == "function"
end

-- Raises with the library's error text when a LibESQL call returned nil.
-- The call goes last so both of its return values reach here.
local function Check(what, ok, err)
    if ok == nil then error(string.format("%s: %s", what, tostring(err)), 0) end
    return ok
end

local function EnsureTables()
    for _, spec in ipairs(SPECS) do
        Check("create " .. spec.name, Lib().CreateTable(spec.name, spec.createCols, true))
    end
end

local function ReadAll()
    local data = NewData()
    for _, spec in ipairs(SPECS) do
        local rows = Check("read " .. spec.name, Lib().Select("SELECT * FROM " .. spec.name))
        spec.apply(data, rows)
    end
    return Normalize(data)
end

local function KeyParams(spec, row)
    local p = { n = #spec.keys }
    for i, k in ipairs(spec.keys) do p[i] = row[k] end
    return p
end

-- snap[table][key] = { sig = row signature, keys = key values as stored }
local function TakeSnapshot(data)
    for _, spec in ipairs(SPECS) do
        local snap = {}
        for _, row in ipairs(DesiredRows(spec, data)) do
            snap[KeyOf(spec, row)] = { sig = SigOf(spec, row), keys = KeyParams(spec, row) }
        end
        Store.snap[spec.name] = snap
    end
end

-- Write one table's changes. full = true rewrites every row.
local function SyncSpec(spec, data, full)
    local L = Lib()
    local desired = DesiredRows(spec, data)
    local old = Store.snap[spec.name] or {}
    local newSnap, inserts, updates, seen = {}, {}, {}, {}
    for _, row in ipairs(desired) do
        local key, sig = KeyOf(spec, row), SigOf(spec, row)
        newSnap[key], seen[key] = { sig = sig, keys = KeyParams(spec, row) }, true
        if old[key] == nil then inserts[#inserts + 1] = row
        elseif old[key].sig ~= sig then updates[#updates + 1] = row end
    end
    local deletes = {}
    for key, entry in pairs(old) do if not seen[key] then deletes[#deletes + 1] = entry.keys end end

    local changed = #inserts + #updates + #deletes
    if changed == 0 and not full then return end

    if full or changed > BULK_THRESHOLD then
        Check("clear " .. spec.name, L.Delete(spec.name))
        if #desired > 0 then Check("insert into " .. spec.name, L.Insert(spec.name, desired)) end
    else
        for _, keyVals in ipairs(deletes) do
            Check("delete from " .. spec.name, L.Delete(spec.name, spec.where, keyVals))
        end
        for _, row in ipairs(updates) do
            local changes = {}
            for _, col in ipairs(spec.nonKeys) do
                local v = row[col]
                if v == nil then changes[col] = L.NULL else changes[col] = v end
            end
            if next(changes) then
                Check("update " .. spec.name, L.Update(spec.name, changes, spec.where, KeyParams(spec, row)))
            end
        end
        if #inserts > 0 then Check("insert into " .. spec.name, L.Insert(spec.name, inserts)) end
    end
    Store.snap[spec.name] = newSnap
end

local function WriteAll(data, full)
    Store.writing = true
    local ok, err = pcall(function()
        for _, spec in ipairs(SPECS) do SyncSpec(spec, data, full) end
    end)
    Store.writing = false
    return ok, err
end

-------------------------------------------------------------------------------
-- Merging (pending stats from a session without LibESQL)
-------------------------------------------------------------------------------
local function HasContent(d)
    if type(d) ~= "table" then return false end
    if N(d.totalKills) + N(d.totalDeaths) > 0 then return true end
    if d.matchHistory and #d.matchHistory > 0 then return true end
    return d.duels and N(d.duels.totalDuels) > 0
end

local function AddSources(into, from)
    for id, e in pairs(from or {}) do
        local t = into[id]
        if not t then into[id] = DeepCopy(e)
        else
            t.count = N(t.count) + N(e.count)
            t.abilityName = e.abilityName or t.abilityName
            t.lastVictim = e.lastVictim or t.lastVictim
            t.lastKiller = e.lastKiller or t.lastKiller
        end
    end
end

local function AddCounts(into, from)
    for k, n in pairs(from or {}) do into[k] = N(into[k]) + N(n) end
end

function Store.Merge(into, from)
    into.totalKills  = N(into.totalKills) + N(from.totalKills)
    into.totalDeaths = N(into.totalDeaths) + N(from.totalDeaths)
    for name, c in pairs(from.characters or {}) do
        local t = Char(into, name)
        t.kills, t.deaths = N(t.kills) + N(c.kills), N(t.deaths) + N(c.deaths)
        t.bestStreak = math.max(N(t.bestStreak), N(c.bestStreak))
        AddSources(t.killSources, c.killSources)
        AddSources(t.deathSources, c.deathSources)
        AddCounts(t.victims, c.victims)
        AddCounts(t.killers, c.killers)
    end
    for _, m in ipairs(from.matchHistory or {}) do
        into.matchCounter = N(into.matchCounter) + 1
        local copy = DeepCopy(m)
        copy.matchId = into.matchCounter
        into.matchHistory[#into.matchHistory + 1] = copy
    end
    while #into.matchHistory > KDST.MAX_MATCH_HISTORY do table.remove(into.matchHistory, 1) end
    local fd = from.duels or {}
    into.duels.totalDuels = N(into.duels.totalDuels) + N(fd.totalDuels)
    into.duels.wins       = N(into.duels.wins) + N(fd.wins)
    into.duels.losses     = N(into.duels.losses) + N(fd.losses)
    for name, c in pairs(fd.perCharStats or {}) do
        local t = DuelChar(into, name)
        t.duels, t.wins, t.losses = N(t.duels) + N(c.duels), N(t.wins) + N(c.wins), N(t.losses) + N(c.losses)
        for opp, rec in pairs(c.charactersFaced or {}) do
            local r = t.charactersFaced[opp] or { wins = 0, losses = 0 }
            r.wins, r.losses = N(r.wins) + N(rec.wins), N(r.losses) + N(rec.losses)
            t.charactersFaced[opp] = r
        end
    end
    return into
end

-------------------------------------------------------------------------------
-- Load / save
-------------------------------------------------------------------------------
-- The legacy (pre-migration) fields of KDStatTrackerVars, as a plain copy.
local function LegacyCopy(sv)
    local d = NewData()
    for k in pairs(KDST.dataDefaults) do d[k] = DeepCopy(sv[k]) end
    d.schema = sv.schema or KDST.SCHEMA
    return Normalize(d)
end

-- Something went wrong writing to LibESQL: keep every stat by going back to
-- KDStatTrackerVars for good (until /kdstorage retry).
function Store.FallBack(reason)
    local sv = KDST.sv
    local current = KDST.data
    for k in pairs(KDST.dataDefaults) do sv[k] = DeepCopy(current[k]) end
    sv.schema = current.schema
    sv.storage, sv.storageFailed = "savedvars", tostring(reason)
    sv.pending = nil
    KDST.data = sv
    Store.mode = "savedvars"
    KDST.Print("Couldn't save stats to LibESQL (" .. tostring(reason) .. "). Saving to KDStatTrackerVars instead; nothing was lost. /kdstorage for details.")
end

function Store.Load()
    local sv = KDST.sv
    KDST.data = sv   -- default: saved variables, exactly like before

    if not Store.Available() then
        if sv.storage == "libesql" then
            sv.pending = Normalize(sv.pending or NewData())
            KDST.data = sv.pending
            Store.mode = "pending"
            zo_callLater(function()
                KDST.Print("LibESQL isn't loaded, but your stats are stored in it. This session's stats are kept aside and will be added to them when LibESQL is back.")
            end, 3000)
        else
            Store.mode = "savedvars"
        end
        return
    end

    if sv.storageFailed then
        Store.mode = "savedvars"
        return
    end

    local ok, err = pcall(EnsureTables)
    if not ok then Store.mode = "savedvars"; sv.storageFailed = tostring(err); return end

    if sv.storage ~= "libesql" then
        -- First run with LibESQL: copy KDStatTrackerVars into the tables.
        local data = LegacyCopy(sv)
        KDST.data = data
        Store.snap = {}
        local wrote, werr = WriteAll(data, true)
        if not wrote then
            KDST.data = sv
            Store.mode = "savedvars"
            sv.storageFailed = tostring(werr)
            KDST.Print("Couldn't move stats to LibESQL (" .. tostring(werr) .. "). Still using KDStatTrackerVars.")
            return
        end
        sv.storage = "libesql"
        sv.migratedAt = GetTimeStamp()
        Store.mode = "libesql"
        zo_callLater(function()
            KDST.Print("Stats moved to LibESQL (tables kdst_*). KDStatTrackerVars is kept unchanged as a backup.")
        end, 3000)
    else
        local okRead, data = pcall(ReadAll)
        if not okRead then
            -- Tables unreadable: leave them alone and keep this session aside.
            sv.pending = Normalize(sv.pending or NewData())
            KDST.data = sv.pending
            Store.mode = "pending"
            KDST.Print("Couldn't read stats from LibESQL (" .. tostring(data) .. "). This session's stats are kept aside and will be added once it can be read.")
            return
        end
        KDST.data = data
        TakeSnapshot(data)
        Store.mode = "libesql"
    end

    -- Stats recorded while LibESQL was off.
    if HasContent(sv.pending) then
        Store.Merge(KDST.data, sv.pending)
        local wrote, werr = WriteAll(KDST.data, false)
        if wrote then
            sv.pending = nil
            zo_callLater(function() KDST.Print("Added the stats recorded while LibESQL was off.") end, 3500)
        else
            Store.FallBack(werr)
        end
    else
        sv.pending = nil
    end
end

function Store.Flush()
    EVENT_MANAGER:UnregisterForUpdate("KDStatTracker_StoreSync")
    if Store.mode ~= "libesql" or not Store.Available() then return end
    local ok, err = WriteAll(KDST.data, false)
    if not ok then Store.FallBack(err) end
end

function Store.ScheduleSync()
    if Store.mode ~= "libesql" then return end
    EVENT_MANAGER:UnregisterForUpdate("KDStatTracker_StoreSync")
    EVENT_MANAGER:RegisterForUpdate("KDStatTracker_StoreSync", SYNC_DELAY_MS, Store.Flush)
end

-- Someone edited a kdst_* table with SQL: reload KDST.data from the tables.
local function OnExternalWrite(tableName)
    if Store.writing or Store.mode ~= "libesql" or not SPEC_BY_NAME[tableName] then return end
    EVENT_MANAGER:UnregisterForUpdate("KDStatTracker_StoreReload")
    EVENT_MANAGER:RegisterForUpdate("KDStatTracker_StoreReload", 0, function()
        EVENT_MANAGER:UnregisterForUpdate("KDStatTracker_StoreReload")
        Store.Flush()   -- our own unsaved changes first
        local ok, data = pcall(ReadAll)
        if not ok then return end
        KDST.data = data
        TakeSnapshot(data)
        KDST.callbacks:FireCallbacks("StatsChanged", "storage")
    end)
end

function Store.Initialize()
    KDST.callbacks:RegisterCallback("StatsChanged", function(reason)
        if reason ~= "storage" then Store.ScheduleSync() end
    end)
    -- Write anything still queued before the UI unloads (reload, logout, zoning).
    EVENT_MANAGER:RegisterForEvent(KDST.name .. "_Store", EVENT_PLAYER_DEACTIVATED, Store.Flush)
    if Store.mode == "libesql" and type(Lib().RegisterCallback) == "function" then
        for _, ev in ipairs({ "RowsInserted", "RowsUpdated", "RowsDeleted" }) do
            Lib().RegisterCallback(ev, OnExternalWrite)
        end
    end
end

-------------------------------------------------------------------------------
-- /kdstorage
-------------------------------------------------------------------------------
local MODE_TEXT = {
    libesql   = "LibESQL (tables kdst_*)",
    pending   = "LibESQL isn't loaded; this session is kept aside until it is",
    savedvars = "KDStatTrackerVars (SavedVariables)",
}

function Store.PrintStatus(arg)
    local sv = KDST.sv
    arg = zo_strlower(zo_strtrim(arg or ""))
    if arg == "retry" then
        sv.storageFailed = nil
        if sv.storage == "savedvars" then sv.storage = nil end
        KDST.Print("LibESQL storage will be tried again after /reloadui.")
        return
    end
    KDST.Print("Stats are stored in: " .. (MODE_TEXT[Store.mode] or Store.mode))
    if sv.migratedAt then d("  Moved to LibESQL: " .. KDST.FormatDate(sv.migratedAt) .. " (KDStatTrackerVars kept as a backup)") end
    if sv.storageFailed then d("  Last LibESQL error: " .. sv.storageFailed .. "  -  /kdstorage retry to try again") end
    if Store.mode == "libesql" then
        for _, spec in ipairs(SPECS) do
            local n = Lib().Scalar("SELECT COUNT(*) FROM " .. spec.name)
            d(string.format("  %s: %d rows", spec.name, N(n)))
        end
        d(string.format("  Row limit per table: %d", N(Lib().USER_TABLE_MAX_ROWS)))
    end
end
