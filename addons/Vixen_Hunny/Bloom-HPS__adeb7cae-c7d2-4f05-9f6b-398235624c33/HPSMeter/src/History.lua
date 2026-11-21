-- ============================================================================
-- Bloom HPS - History
-- Battleground totals and the saved fight / battleground history.
--
--   * While you are in a battleground, every fight that ends is added to that
--     battleground's totals, and the meter shows those totals.
--   * When the battleground finishes (or you leave it), its totals are saved
--     and the meter is reset for the next one.
--   * Every fight and every battleground is saved in LibESQL tables:
--       bloomhps_fights   one row per fight
--       bloomhps_bgs      one row per battleground
--     They stay after /reloadui and logging out, and can be searched with
--     /bloomhps fights <text> and /bloomhps bg <text> (SQL LIKE), or queried
--     directly in the ESQL window, e.g. SELECT * FROM bloomhps_bgs.
--
-- LibESQL is optional: without it battleground totals and the reset still
-- work, only nothing is saved.
-- ============================================================================

local M = HPSMeterUI
local History = {}
M.History = History

local format, floor, max, min = string.format, math.floor, math.max, math.min

local FIGHTS, BGS = "bloomhps_fights", "bloomhps_bgs"
local SEARCH_LIMIT = 10
local PRUNE_EVERY = 25 -- check the fight table size every N saved fights

-- columns both tables share, filled from a stats table by StatsColumns
local STAT_COLUMNS = {
    "date TEXT", "character TEXT", "zone TEXT", "battleground TEXT",
    "duration REAL", "fights INT",
    "hps REAL", "hpm REAL", "raw_hps REAL",
    "heal_total REAL", "heal_personal REAL", "heal_group REAL",
    "crit_heal REAL", "crit_hps REAL", "crit_heal_pct REAL", "crit_rate REAL",
    "shield_total REAL", "sps REAL", "shield_group REAL",
    "mitigated REAL", "mps REAL", "mitigated_pct REAL",
}

local function Columns(...)
    local cols = { ... }
    for _, c in ipairs(STAT_COLUMNS) do cols[#cols + 1] = c end
    return cols
end

local ready = false -- LibESQL loaded and both tables exist

-- The fight that was running when a battleground finished is counted into
-- that battleground straight away; when it ends later it must not be added
-- to the next one. fight -> { id, name } of the battleground it went into.
local counted = setmetatable({}, { __mode = "k" })

-- ---------------------------------------------------------------------------
-- helpers
-- ---------------------------------------------------------------------------

local function R(x) return floor((x or 0) * 10 + 0.5) / 10 end

local function Try(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b = pcall(fn, ...)
    if ok then return a, b end
    return nil
end

local function InBattleground()
    return Try(IsActiveWorldBattleground) == true
end

local function DateText(ts)
    if ready then
        local text = LibESQL.Scalar("SELECT FROM_UNIXTIME(?)", { ts })
        if text then return text end
    end
    return tostring(ts)
end

local function Duration(secs)
    secs = floor(secs or 0)
    return format("%d:%02d", floor(secs / 60), secs % 60)
end

local function StatsColumns(stats, row)
    row.duration = R(stats.duration)
    row.fights = stats.fights or 0
    row.hps, row.hpm, row.raw_hps = R(stats.hps), R(stats.hpm), R(stats.rawHps)
    row.heal_total, row.heal_personal, row.heal_group = R(stats.healTotal), R(stats.healPersonal), R(stats.healGroup)
    row.crit_heal, row.crit_hps = R(stats.critHeal), R(stats.critHps)
    row.crit_heal_pct, row.crit_rate = R(stats.critHealPct), R(stats.critHealRate)
    row.shield_total, row.sps = R(stats.shieldTotal), R(stats.sps)
    row.shield_group = stats.groupMode and R(stats.shieldGroup) or nil
    row.mitigated, row.mps, row.mitigated_pct = R(stats.mitigated), R(stats.mps), R(stats.mitigatedPct)
    return row
end

local function Saving()
    return ready and M.saved.saveHistory
end

-- ---------------------------------------------------------------------------
-- battleground info from the game
-- ---------------------------------------------------------------------------

local function BattlegroundInfo()
    local bgId = Try(GetCurrentBattlegroundId) or 0
    local roundIndex = Try(GetCurrentBattlegroundRoundIndex)
    local name = bgId ~= 0 and Try(GetBattlegroundName, bgId) or nil
    if not name or name == "" then name = zo_strformat("<<1>>", GetUnitZone("player")) end

    local gameType = Try(GetCurrentBattlegroundGameType, roundIndex)
        or (bgId ~= 0 and Try(GetBattlegroundGameType, bgId, roundIndex))
    local gameTypeText = gameType and Try(GetString, "SI_BATTLEGROUNDGAMETYPE", gameType) or nil
    if gameTypeText == "" then gameTypeText = nil end

    return bgId, zo_strformat("<<1>>", name), gameTypeText
end

-- Result of the round that just ended, as text.
local function ResultText()
    local roundIndex = Try(GetCurrentBattlegroundRoundIndex)
    local result = Try(GetCurrentBattlegroundRoundResult, roundIndex)
    if result == nil then return "Unknown" end
    if result == BATTLEGROUND_RESULT_WIN then return "Win" end
    if result == BATTLEGROUND_RESULT_LOSS then return "Loss" end
    if result == BATTLEGROUND_RESULT_TIE then return "Tie" end
    return "Unknown"
end

-- ---------------------------------------------------------------------------
-- saving
-- ---------------------------------------------------------------------------

local function NextId(counterKey)
    M.saved[counterKey] = (M.saved[counterKey] or 0) + 1
    return M.saved[counterKey]
end

local function Insert(tableName, row)
    local ok, err = LibESQL.Insert(tableName, row)
    if not ok then M.Print("Could not save history: " .. tostring(err)) end
    return ok
end

-- Keeps the fight table under LibESQL's row limit by dropping the oldest.
local function PruneFights(lastId)
    if lastId % PRUNE_EVERY ~= 0 then return end
    local keep = min(M.saved.historyMaxFights or 3000, (LibESQL.USER_TABLE_MAX_ROWS or 5000) - PRUNE_EVERY * 2)
    if lastId > keep then
        LibESQL.Delete(FIGHTS, "id <= ?", { lastId - keep })
    end
end

local function SaveFight(fight, snapshot, bg)
    if not Saving() then return end
    local stats = M.Data.FromSums(snapshot)
    local id = NextId("lastFightId")
    local now = GetTimeStamp()
    local row = StatsColumns(stats, {
        id = id,
        bg_id = bg and bg.id or nil,
        battleground = bg and bg.name or nil,
        started_at = fight.startTimestamp or now,
        ended_at = now,
        date = DateText(fight.startTimestamp or now),
        character = fight.character or zo_strformat("<<1>>", GetUnitName("player")),
        zone = fight.zoneName or zo_strformat("<<1>>", GetUnitZone("player")),
    })
    if Insert(FIGHTS, row) then PruneFights(id) end
end

local function SaveBattleground(bg, stats, result)
    if not Saving() then return false end
    return Insert(BGS, StatsColumns(stats, {
        id = bg.id,
        started_at = bg.startedAt,
        ended_at = GetTimeStamp(),
        date = DateText(bg.startedAt),
        character = bg.character,
        zone = bg.zone,
        battleground = bg.name,
        game_type = bg.gameType,
        result = result,
    })) and true or false
end

-- ---------------------------------------------------------------------------
-- battleground tracking
-- ---------------------------------------------------------------------------

-- The battleground in progress lives in the saved variables, so its totals
-- survive /reloadui in the middle of a match.
local function CurrentBg() return M.saved.currentBg end

local function BeginBattleground()
    if CurrentBg() then return CurrentBg() end
    -- after the match ends you stay in the zone for a bit; that is not a new match
    if Try(GetCurrentBattlegroundState) == BATTLEGROUND_STATE_FINISHED then return nil end
    local bgId, name, gameType = BattlegroundInfo()
    local bg = {
        id = NextId("lastBgId"),
        bgId = bgId,
        name = name,
        gameType = gameType,
        startedAt = GetTimeStamp(),
        zone = zo_strformat("<<1>>", GetUnitZone("player")),
        character = zo_strformat("<<1>>", GetUnitName("player")),
        sums = M.Data.NewSums(),
    }
    M.saved.currentBg = bg
    M.UI.Refresh()
    return bg
end

local function FinishBattleground(result)
    local bg = CurrentBg()
    if not bg then return end
    M.saved.currentBg = nil

    -- a fight still running at the end counts towards this battleground
    local current = M.Data.GetCurrentFight()
    if current and not counted[current] then
        M.Data.AddSums(bg.sums, M.Data.Snapshot(current))
        counted[current] = { id = bg.id, name = bg.name }
    end

    local stats = M.Data.FromSums(bg.sums)
    local saved = false
    if bg.sums.fights > 0 then
        saved = SaveBattleground(bg, stats, result)
        M.Print(format("%s finished (%s): HPS %s | Healing %s | Crit %.0f%% | Shield %s | %d fights, %s%s",
            bg.name, result, M.FormatShortNumber(stats.hps), M.FormatShortNumber(stats.healTotal),
            stats.critHealPct, M.FormatShortNumber(stats.shieldTotal), stats.fights,
            Duration(stats.duration), saved and format(". Saved as #%d", bg.id) or ""))
    end

    -- reset the meter for the next battleground
    M.Data.ClearDisplay()
    M.UI.Refresh()
end

-- Meter numbers for the battleground in progress: its finished fights plus
-- the one running now. nil when not in a battleground (or the option is off).
function History.GetBattlegroundStats()
    local bg = CurrentBg()
    if not bg or not M.saved.bgTotals or not InBattleground() then return nil end

    local sums = M.Data.AddSums(M.Data.NewSums(), bg.sums)
    local current = M.Data.GetCurrentFight()
    if current and not counted[current] then
        M.Data.AddSums(sums, M.Data.Snapshot(current))
    end

    local stats = M.Data.FromSums(sums)
    stats.scope = "bg"
    stats.bgName = bg.name
    stats.active = current ~= nil
    stats.hasFight = sums.fights > 0
    return stats
end

function History.OnFightEnded(fight)
    if not fight then return end
    local snapshot = M.Data.Snapshot(fight)

    local bg = counted[fight]
    if bg then
        counted[fight] = nil -- already counted into a finished battleground
    elseif InBattleground() then
        bg = BeginBattleground()
        if bg then M.Data.AddSums(bg.sums, snapshot) end
    end

    SaveFight(fight, snapshot, bg)
end

local function OnBattlegroundStateChanged(_, _, state)
    if state == BATTLEGROUND_STATE_FINISHED
        or (BATTLEGROUND_STATE_POSTGAME and state == BATTLEGROUND_STATE_POSTGAME) then
        FinishBattleground(ResultText())
    elseif state == BATTLEGROUND_STATE_PREROUND or state == BATTLEGROUND_STATE_STARTING
        or state == BATTLEGROUND_STATE_RUNNING then
        BeginBattleground()
    end
end

-- Catches leaving a battleground before it finished, and a battleground
-- left over from a crash or a /reloadui into a different match.
local STALE_BG_SECS = 3600

local function OnPlayerActivated()
    local bg = CurrentBg()
    if InBattleground() then
        if bg then
            local bgId = Try(GetCurrentBattlegroundId) or 0
            if bg.bgId ~= bgId or GetTimeStamp() - (bg.startedAt or 0) > STALE_BG_SECS then
                FinishBattleground("Left")
                BeginBattleground()
            end
        else
            BeginBattleground()
        end
    elseif bg then
        FinishBattleground("Left")
    end
end

-- ---------------------------------------------------------------------------
-- LibESQL tables
-- ---------------------------------------------------------------------------

local function SetupTables()
    local ok, err = LibESQL.CreateTable(FIGHTS,
        Columns("id INT PRIMARY KEY", "bg_id INT", "started_at INT", "ended_at INT"), true)
    if ok == nil then M.Print("Could not create " .. FIGHTS .. ": " .. tostring(err)) return end

    ok, err = LibESQL.CreateTable(BGS,
        Columns("id INT PRIMARY KEY", "started_at INT", "ended_at INT", "game_type TEXT", "result TEXT"), true)
    if ok == nil then M.Print("Could not create " .. BGS .. ": " .. tostring(err)) return end

    -- ids keep counting up from what is already saved
    local saved = M.saved
    saved.lastFightId = max(saved.lastFightId or 0, LibESQL.Scalar("SELECT MAX(id) FROM " .. FIGHTS) or 0)
    saved.lastBgId = max(saved.lastBgId or 0, LibESQL.Scalar("SELECT MAX(id) FROM " .. BGS) or 0)
    ready = true
end

function History.IsReady() return ready end

function History.Init()
    if LibESQL then
        if LibESQL.loaded then
            SetupTables()
        elseif LibESQL.RegisterCallback then
            LibESQL.RegisterCallback("Loaded", SetupTables)
        end
    end

    EVENT_MANAGER:RegisterForEvent(M.name .. "_BGState", EVENT_BATTLEGROUND_STATE_CHANGED, OnBattlegroundStateChanged)
    EVENT_MANAGER:RegisterForEvent(M.name .. "_BGActivated", EVENT_PLAYER_ACTIVATED, OnPlayerActivated)
end

-- ---------------------------------------------------------------------------
-- LIKE lookups
-- ---------------------------------------------------------------------------

local FIGHT_SEARCH_COLUMNS = { "zone", "battleground", "date", "character" }
local BG_SEARCH_COLUMNS = { "battleground", "game_type", "result", "zone", "date", "character" }

-- "col1 LIKE ? ESCAPE '\' OR col2 LIKE ? ESCAPE '\' ..." and its params
local function LikeWhere(columns, text)
    local pattern = "%" .. LibESQL.Escape(text or "") .. "%"
    local parts, params = {}, {}
    for i, col in ipairs(columns) do
        parts[i] = col .. " LIKE ? ESCAPE '\\'"
        params[i] = pattern
    end
    return table.concat(parts, " OR "), params
end

-- Returns rows (newest first), the number of matches, or nil, errorText.
local function Search(tableName, columns, text, fields)
    if not ready then return nil, "History needs LibESQL, which is not installed or not loaded." end
    local where, params = LikeWhere(columns, text)
    local total = LibESQL.Scalar(format("SELECT COUNT(*) FROM %s WHERE %s", tableName, where), params) or 0
    local rows, err = LibESQL.Select(format("SELECT %s FROM %s WHERE %s ORDER BY id DESC LIMIT %d",
        fields, tableName, where, SEARCH_LIMIT), params)
    if not rows then return nil, err end
    return rows, total
end

local Fmt = M.FormatShortNumber

local function FightLine(f)
    return format("#%d %s | %s%s | %s | HPS %s | Heal %s | Crit %.0f%% | Shield %s | Mit %s",
        f.id, f.date or "?", f.zone or "?", f.battleground and (" [BG #" .. tostring(f.bg_id) .. "]") or "",
        Duration(f.duration), Fmt(f.hps), Fmt(f.heal_total), f.crit_heal_pct or 0,
        Fmt(f.shield_total), Fmt(f.mitigated))
end

local function BgLine(b)
    return format("#%d %s | %s%s | %s | %d fights, %s | HPS %s | Heal %s | Crit %.0f%% | Shield %s | Mit %s",
        b.id, b.date or "?", b.battleground or "?", b.game_type and (" (" .. b.game_type .. ")") or "",
        b.result or "?", b.fights or 0, Duration(b.duration), Fmt(b.hps), Fmt(b.heal_total),
        b.crit_heal_pct or 0, Fmt(b.shield_total), Fmt(b.mitigated))
end

local FIGHT_FIELDS = "id, bg_id, date, zone, battleground, duration, hps, heal_total, crit_heal_pct, shield_total, mitigated"
local BG_FIELDS = "id, date, battleground, game_type, result, fights, duration, hps, heal_total, crit_heal_pct, shield_total, mitigated"

local function PrintResults(what, text, rows, total, lineFn)
    if not rows then M.Print(total) return end
    local filter = (text and text ~= "") and format(" matching \"%s\"", text) or ""
    if #rows == 0 then M.Print(format("No %s%s.", what, filter)) return end
    M.Print(format("%s%s: newest %d of %d", what, filter, #rows, total))
    for _, row in ipairs(rows) do M.Print("  " .. lineFn(row)) end
end

-- /bloomhps fights <text>: zone, battleground, date or character LIKE %text%
function History.PrintFightSearch(text)
    local rows, total = Search(FIGHTS, FIGHT_SEARCH_COLUMNS, text, FIGHT_FIELDS)
    PrintResults("Fights", text, rows, total, FightLine)
end

-- /bloomhps bg <text>: battleground, mode, result, zone, date or character
-- LIKE %text%.  /bloomhps bg #12 shows battleground 12 and its fights.
function History.PrintBattlegroundSearch(text)
    local id = text and tonumber(text:match("^#(%d+)$"))
    if not id then
        local rows, total = Search(BGS, BG_SEARCH_COLUMNS, text, BG_FIELDS)
        PrintResults("Battlegrounds", text, rows, total, BgLine)
        return
    end

    if not ready then M.Print("History needs LibESQL, which is not installed or not loaded.") return end
    local bgs = LibESQL.Select(format("SELECT %s FROM %s WHERE id = ?", BG_FIELDS, BGS), { id }) or {}
    if #bgs == 0 then M.Print(format("No battleground #%d.", id)) return end
    M.Print(BgLine(bgs[1]))
    local fights = LibESQL.Select(format("SELECT %s FROM %s WHERE bg_id = ? ORDER BY id", FIGHT_FIELDS, FIGHTS), { id }) or {}
    for _, f in ipairs(fights) do M.Print("  " .. FightLine(f)) end
end
