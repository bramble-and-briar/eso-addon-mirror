-- KDStatTracker_Core.lua
-- Namespace, constants, helpers, saved data (with migration from v2.0) and the
-- stat-recording API. Everything UI-related listens to the "StatsChanged"
-- callback instead of being called directly from the tracking code.

KDStatTracker = KDStatTracker or {}
local KDST = KDStatTracker

KDST.name        = "KDStatTracker"
KDST.displayName = "KD Stat Tracker"
KDST.version     = "3.0.0"
KDST.author      = "Vixen Hunny"

KDST.SCHEMA            = 2      -- saved-data layout version (v2.0 data is schema 0/1)
KDST.MAX_MATCH_HISTORY = 50
KDST.KILL_DEDUPE_MS    = 1500   -- ignore repeat killing blows on the same unit
KDST.DEATH_LINK_MS     = 4000   -- how old a killing blow may be and still explain a death

KDST.callbacks = ZO_CallbackObject:New()
KDST.ui = {}

-------------------------------------------------------------------------------
-- Colours
-------------------------------------------------------------------------------
KDST.COLORS = {
    accent = ZO_ColorDef:New("C5A86E"),
    kill   = ZO_ColorDef:New("7CD67F"),
    death  = ZO_ColorDef:New("E06A5F"),
    ratio  = ZO_ColorDef:New("6EC3E6"),
    gold   = ZO_ColorDef:New("FFD45C"),
    muted  = ZO_ColorDef:New("8F8F8F"),
    text   = ZO_ColorDef:New("E8E4DA"),
}

-------------------------------------------------------------------------------
-- Announcer tables
-------------------------------------------------------------------------------
KDST.MULTI_KILLS = {
    [2] = "Double Kill",
    [3] = "Triple Kill",
    [4] = "Quadra Kill",
    [5] = "Penta Kill",
}
KDST.MULTI_KILL_MAX_NAME = "Massacre"   -- 6+

KDST.STREAKS = {
    [3]  = { name = "Killing Spree", color = "7CD67F" },
    [5]  = { name = "Rampage",       color = "6EC3E6" },
    [7]  = { name = "Dominating",    color = "B58CFF" },
    [10] = { name = "Unstoppable",   color = "FF9A3D" },
    [15] = { name = "Godlike",       color = "FF4FC1" },
    [20] = { name = "Legendary",     color = "FFD45C" },
}

-- Fallback names if the client string table has no entry for a game type.
KDST.MATCH_TYPE_FALLBACK = {
    [1] = "Deathmatch", [2] = "Domination", [3] = "Chaosball",
    [4] = "Capture the Relic", [5] = "King of the Hill",
    [6] = "Murderball", [7] = "Crazy King",
}

-------------------------------------------------------------------------------
-- Defaults
-------------------------------------------------------------------------------
KDST.dataDefaults = {
    schema       = 0,
    totalKills   = 0,
    totalDeaths  = 0,
    characters   = {},
    matchHistory = {},
    matchCounter = 0,
    duels = {
        totalDuels   = 0,
        wins         = 0,
        losses       = 0,
        perCharStats = {},
    },
}

KDST.settingDefaults = {
    -- HUD
    showHUD          = true,
    lockHUD          = false,
    hudPvPOnly       = false,
    hudShowDetails   = true,
    hudShowCharacter = false,   -- false = session numbers, true = character lifetime
    x                = 40,
    y                = 260,
    scale            = 1.0,
    fontSize         = 18,
    fontColor        = "E8E4DA",
    -- Announcer
    showBanners      = true,
    playSounds       = true,
    chatKills        = false,
    showMatchSummary = true,
    multiKillWindow  = 6,
    -- Tracking
    trackOnlyPvP     = true,
    playersOnly      = true,
}

-------------------------------------------------------------------------------
-- Generic helpers
-------------------------------------------------------------------------------
function KDST.IsGamepadUI()
    if type(IsConsoleUI) == "function" and IsConsoleUI() then
        return true
    end
    return type(IsInGamepadPreferredMode) == "function" and IsInGamepadPreferredMode() == true
end

function KDST.IsConsole()
    return type(IsConsoleUI) == "function" and IsConsoleUI() == true
end

function KDST.Print(msg)
    if CHAT_ROUTER and CHAT_ROUTER.AddSystemMessage then
        CHAT_ROUTER:AddSystemMessage(KDST.COLORS.accent:Colorize("[KD] ") .. tostring(msg))
    else
        d("[KD] " .. tostring(msg))
    end
end

function KDST.Color(color, text)
    if type(color) == "string" then
        return string.format("|c%s%s|r", color, tostring(text))
    end
    return color:Colorize(tostring(text))
end

function KDST.Ratio(kills, deaths)
    kills, deaths = kills or 0, deaths or 0
    if deaths == 0 then
        return string.format("%.2f", kills)
    end
    return string.format("%.2f", kills / deaths)
end

function KDST.Percent(part, whole)
    if not whole or whole == 0 then return "0%" end
    return string.format("%d%%", zo_round(((part or 0) / whole) * 100))
end

function KDST.FormatDuration(seconds)
    seconds = math.max(0, math.floor(seconds or 0))
    local h = math.floor(seconds / 3600)
    local m = math.floor((seconds % 3600) / 60)
    local s = seconds % 60
    if h > 0 then
        return string.format("%d:%02d:%02d", h, m, s)
    end
    return string.format("%d:%02d", m, s)
end

function KDST.FormatDate(timestamp)
    if not timestamp or timestamp == 0 then return "" end
    if type(GetDateStringFromTimestamp) == "function" then
        return GetDateStringFromTimestamp(timestamp)
    end
    return ""
end

function KDST.CleanName(raw)
    if raw == nil or raw == "" then return "Unknown" end
    return zo_strformat("<<1>>", raw)
end

function KDST.AbilityName(abilityId, rawName)
    if rawName and rawName ~= "" then
        return zo_strformat("<<1>>", rawName)
    end
    if abilityId and abilityId > 0 then
        local name = GetAbilityName(abilityId)
        if name and name ~= "" then
            return zo_strformat("<<1>>", name)
        end
    end
    return "Unknown"
end

-- Player character names in combat events carry a "^Mx" / "^Fx" grammar suffix.
function KDST.LooksLikePlayer(rawName)
    return type(rawName) == "string" and string.find(rawName, "%^[MmFf]x") ~= nil
end

function KDST.ValidHex(hex, fallback)
    if type(hex) == "string" and hex:match("^%x%x%x%x%x%x$") then
        return hex
    end
    return fallback or "FFFFFF"
end

-- Sorts a { key = count } or { key = { count = n, [nameField] = ... } } table.
function KDST.SortedCounts(tbl, nameField)
    local list = {}
    for key, value in pairs(tbl or {}) do
        if type(value) == "table" then
            list[#list + 1] = {
                key   = key,
                name  = (nameField and value[nameField]) or tostring(key),
                count = value.count or 0,
                data  = value,
            }
        elseif type(value) == "number" then
            list[#list + 1] = { key = key, name = tostring(key), count = value }
        end
    end
    table.sort(list, function(a, b)
        if a.count == b.count then return a.name < b.name end
        return a.count > b.count
    end)
    return list
end

function KDST.IsInPvPArea()
    return IsActiveWorldBattleground() or IsPlayerInAvAWorld()
end

function KDST.ShouldTrack()
    return (not KDST.settings.trackOnlyPvP) or KDST.IsInPvPArea()
end

-------------------------------------------------------------------------------
-- Match type name (API changed shape over the years, so be defensive)
-------------------------------------------------------------------------------
function KDST.GetMatchTypeName(gameType)
    if not gameType or gameType == 0 then return "Battleground" end
    local name = GetString("SI_BATTLEGROUNDGAMETYPE", gameType)
    if name and name ~= "" then return name end
    return KDST.MATCH_TYPE_FALLBACK[gameType] or "Battleground"
end

-------------------------------------------------------------------------------
-- Character data
-------------------------------------------------------------------------------
local function NewCharData()
    return {
        kills        = 0,
        deaths       = 0,
        bestStreak   = 0,
        killSources  = {},   -- [abilityId] = { count, abilityName, lastVictim }
        deathSources = {},   -- [abilityId] = { count, abilityName, lastKiller }
        victims      = {},   -- [playerName] = count
        killers      = {},   -- [playerName] = count
    }
end

function KDST.GetCharData(charName)
    charName = charName or KDST.charName
    local chars = KDST.data.characters
    local char = chars[charName]
    if not char then
        char = NewCharData()
        chars[charName] = char
    else
        for key, value in pairs(NewCharData()) do
            if char[key] == nil then char[key] = value end
        end
    end
    return char
end

function KDST.GetDuelData(charName)
    charName = charName or KDST.charName
    local duels = KDST.data.duels
    local char = duels.perCharStats[charName]
    if not char then
        char = { duels = 0, wins = 0, losses = 0, charactersFaced = {} }
        duels.perCharStats[charName] = char
    end
    char.charactersFaced = char.charactersFaced or {}
    return char
end

-------------------------------------------------------------------------------
-- Session / match state (not saved)
-------------------------------------------------------------------------------
function KDST.NewSession()
    KDST.session = {
        kills        = 0,
        deaths       = 0,
        streak       = 0,
        bestStreak   = 0,
        multiCount   = 0,
        lastKillMs   = 0,
        startTime    = GetTimeStamp(),
    }
end

KDST.match = nil   -- { number, bgId, gameType, name, kills, deaths, startTime, character }

-------------------------------------------------------------------------------
-- Migration from v2.0 (killSources/deathSources keyed by character at root)
-------------------------------------------------------------------------------
local function MigrateSources(old, field, lastField, charKey)
    for charName, abilities in pairs(old or {}) do
        if type(abilities) == "table" then
            local char = KDST.GetCharData(charName)
            for abilityId, info in pairs(abilities) do
                if type(info) == "table" then
                    local id = tonumber(abilityId) or abilityId
                    local entry = char[field][id] or { count = 0 }
                    entry.count = (entry.count or 0) + (info.count or 0)
                    entry.abilityName = info.abilityName or entry.abilityName or "Unknown"
                    local last = info[lastField]
                    if last and last ~= "N/A" then entry[lastField] = last end
                    char[field][id] = entry
                    char[charKey] = char[charKey] + (info.count or 0)
                end
            end
        end
    end
end

function KDST.MigrateData()
    local data = KDST.data
    if (data.schema or 0) >= KDST.SCHEMA then return end

    MigrateSources(data.killSources, "killSources", "lastVictim", "kills")
    MigrateSources(data.deathSources, "deathSources", "lastKiller", "deaths")
    data.killSources  = nil
    data.deathSources = nil
    data.perCharKDA   = nil
    data.schema = KDST.SCHEMA
end

function KDST.MigrateSettings()
    local s = KDST.settings
    if s.showKD ~= nil then
        s.showHUD = s.showKD
        s.showKD = nil
    end
    s.scale     = zo_clamp(tonumber(s.scale) or 1, 0.5, 2.5)
    s.fontSize  = zo_clamp(tonumber(s.fontSize) or 18, 12, 40)
    s.fontColor = KDST.ValidHex(s.fontColor, KDST.settingDefaults.fontColor)
end

-------------------------------------------------------------------------------
-- Recording
-------------------------------------------------------------------------------
local function Bump(tbl, key, abilityName, lastField, lastValue)
    local entry = tbl[key]
    if not entry then
        entry = { count = 0 }
        tbl[key] = entry
    end
    entry.count = (entry.count or 0) + 1
    entry.abilityName = abilityName or entry.abilityName or "Unknown"
    entry[lastField] = lastValue
end

local function FireChanged(reason)
    KDST.callbacks:FireCallbacks("StatsChanged", reason)
end

function KDST.RecordKill(abilityId, abilityName, victim)
    local session, char, data = KDST.session, KDST.GetCharData(), KDST.data
    abilityId = abilityId or 0

    data.totalKills = (data.totalKills or 0) + 1
    char.kills = char.kills + 1
    session.kills = session.kills + 1
    if KDST.match then KDST.match.kills = KDST.match.kills + 1 end

    Bump(char.killSources, abilityId, abilityName, "lastVictim", victim)
    if victim and victim ~= "Unknown" then
        char.victims[victim] = (char.victims[victim] or 0) + 1
    end

    -- Streak (until death)
    session.streak = session.streak + 1
    session.bestStreak = math.max(session.bestStreak, session.streak)
    char.bestStreak = math.max(char.bestStreak or 0, session.streak)

    -- Multi-kill (kills within N seconds of each other)
    local now = GetGameTimeMilliseconds()
    local window = (KDST.settings.multiKillWindow or 6) * 1000
    if session.lastKillMs > 0 and (now - session.lastKillMs) <= window then
        session.multiCount = session.multiCount + 1
    else
        session.multiCount = 1
    end
    session.lastKillMs = now

    if KDST.settings.chatKills then
        KDST.Print(string.format("Killed %s with %s", KDST.Color(KDST.COLORS.kill, victim or "Unknown"), abilityName or "Unknown"))
    end

    KDST.callbacks:FireCallbacks("Kill", session.streak, session.multiCount, victim, abilityName)
    FireChanged("kill")
end

function KDST.RecordDeath(abilityId, abilityName, killer)
    local session, char, data = KDST.session, KDST.GetCharData(), KDST.data
    abilityId = abilityId or 0

    data.totalDeaths = (data.totalDeaths or 0) + 1
    char.deaths = char.deaths + 1
    session.deaths = session.deaths + 1
    if KDST.match then KDST.match.deaths = KDST.match.deaths + 1 end

    Bump(char.deathSources, abilityId, abilityName, "lastKiller", killer)
    if killer and killer ~= "Unknown" then
        char.killers[killer] = (char.killers[killer] or 0) + 1
    end

    local endedStreak = session.streak
    session.streak = 0
    session.multiCount = 0
    session.lastKillMs = 0

    if KDST.settings.chatKills then
        KDST.Print(string.format("Killed by %s (%s)", KDST.Color(KDST.COLORS.death, killer or "Unknown"), abilityName or "Unknown"))
    end

    KDST.callbacks:FireCallbacks("Death", endedStreak, killer, abilityName)
    FireChanged("death")
end

function KDST.RecordDuel(won, opponentDisplayName)
    local duels = KDST.data.duels
    local char = KDST.GetDuelData()
    opponentDisplayName = opponentDisplayName or "Unknown"
    local faced = char.charactersFaced[opponentDisplayName] or { wins = 0, losses = 0 }
    char.charactersFaced[opponentDisplayName] = faced

    duels.totalDuels = (duels.totalDuels or 0) + 1
    char.duels = (char.duels or 0) + 1
    if won then
        duels.wins = (duels.wins or 0) + 1
        char.wins = (char.wins or 0) + 1
        faced.wins = (faced.wins or 0) + 1
    else
        duels.losses = (duels.losses or 0) + 1
        char.losses = (char.losses or 0) + 1
        faced.losses = (faced.losses or 0) + 1
    end
    KDST.callbacks:FireCallbacks("Duel", won, opponentDisplayName)
    FireChanged("duel")
end

-------------------------------------------------------------------------------
-- Matches
-------------------------------------------------------------------------------
function KDST.StartMatch()
    if KDST.match then return end
    local bgId = GetCurrentBattlegroundId and GetCurrentBattlegroundId() or 0
    local gameType, name = 0, nil
    if bgId and bgId ~= 0 then
        local ok, gt = pcall(GetBattlegroundGameType, bgId)
        if ok and type(gt) == "number" then gameType = gt end
        local okName, bgName = pcall(GetBattlegroundName, bgId)
        if okName and type(bgName) == "string" and bgName ~= "" then name = zo_strformat("<<1>>", bgName) end
    end

    KDST.data.matchCounter = (KDST.data.matchCounter or 0) + 1
    KDST.match = {
        number    = KDST.data.matchCounter,
        bgId      = bgId,
        gameType  = gameType,
        name      = name,
        kills     = 0,
        deaths    = 0,
        startTime = GetTimeStamp(),
        character = KDST.charName,
    }
    KDST.callbacks:FireCallbacks("MatchStarted", KDST.match)
    FireChanged("match")
end

function KDST.EndMatch(abandoned)
    local match = KDST.match
    if not match then return end
    KDST.match = nil

    local entry = {
        matchId       = match.number,
        bgId          = match.bgId,
        matchType     = match.gameType,
        name          = match.name,
        kills         = match.kills,
        deaths        = match.deaths,
        characterName = match.character,
        duration      = GetTimeStamp() - match.startTime,
        timestamp     = GetTimeStamp(),
        abandoned     = abandoned or nil,
    }
    local history = KDST.data.matchHistory
    history[#history + 1] = entry
    while #history > KDST.MAX_MATCH_HISTORY do
        table.remove(history, 1)
    end

    KDST.callbacks:FireCallbacks("MatchEnded", entry)
    FireChanged("match")
end

-------------------------------------------------------------------------------
-- Reset
-------------------------------------------------------------------------------
KDST.RESET_SCOPES = {
    session   = { title = "Reset Session",   text = "Reset the stats for this play session?" },
    character = { title = "Reset Character", text = "Reset ALL saved kill, death, match and duel stats for <<1>>?\n\nThis cannot be undone." },
    all       = { title = "Reset Everything", text = "Reset ALL saved stats for EVERY character on this account?\n\nThis cannot be undone." },
}

function KDST.ResetStats(scope)
    if scope == "session" then
        KDST.NewSession()
    elseif scope == "character" then
        local char = KDST.GetCharData()
        KDST.data.totalKills  = math.max(0, (KDST.data.totalKills or 0) - char.kills)
        KDST.data.totalDeaths = math.max(0, (KDST.data.totalDeaths or 0) - char.deaths)
        KDST.data.characters[KDST.charName] = nil

        local duels = KDST.data.duels
        local duelChar = duels.perCharStats[KDST.charName]
        if duelChar then
            duels.totalDuels = math.max(0, (duels.totalDuels or 0) - (duelChar.duels or 0))
            duels.wins       = math.max(0, (duels.wins or 0) - (duelChar.wins or 0))
            duels.losses     = math.max(0, (duels.losses or 0) - (duelChar.losses or 0))
            duels.perCharStats[KDST.charName] = nil
        end

        local history, kept = KDST.data.matchHistory, {}
        for i = 1, #history do
            if history[i].characterName ~= KDST.charName then kept[#kept + 1] = history[i] end
        end
        KDST.data.matchHistory = kept
        KDST.NewSession()
    elseif scope == "all" then
        local data = KDST.data
        data.totalKills, data.totalDeaths = 0, 0
        data.characters   = {}
        data.matchHistory = {}
        data.matchCounter = 0
        data.duels = { totalDuels = 0, wins = 0, losses = 0, perCharStats = {} }
        KDST.NewSession()
    else
        return
    end
    KDST.Print((KDST.RESET_SCOPES[scope].title) .. " complete.")
    FireChanged("reset")
end
