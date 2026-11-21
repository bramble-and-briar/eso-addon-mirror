-- KDStatTracker_Commands.lua
-- Slash commands (all v2.0 commands are kept) and keybinding names.

local KDST = KDStatTracker
local C = KDST.COLORS

ZO_CreateStringId("SI_BINDING_NAME_KDSTATTRACKER_TOGGLE_DIALOG", "Toggle Stats Window")
ZO_CreateStringId("SI_BINDING_NAME_KDSTATTRACKER_TOGGLE_HUD", "Toggle HUD Tracker")

function KDST.ToggleHUD()
    local s = KDST.settings
    s.showHUD = not s.showHUD
    KDST.HUD:UpdateVisibility()
    KDST.Print("HUD tracker " .. (s.showHUD and KDST.Color(C.kill, "shown") or KDST.Color(C.death, "hidden")))
end

local function KD(k, d)
    return string.format("%s / %s  (K/D %s)", KDST.Color(C.kill, k or 0), KDST.Color(C.death, d or 0), KDST.Color(C.ratio, KDST.Ratio(k, d)))
end

local function Trim(text)
    return (text or ""):match("^%s*(.-)%s*$")
end

local function PrintTop(title, tbl, nameField, lastField, lastLabel, limit)
    local list = KDST.SortedCounts(tbl, nameField)
    if #list == 0 then
        KDST.Print(title .. ": nothing recorded yet.")
        return
    end
    KDST.Print(title .. ":")
    for i = 1, math.min(#list, limit or 10) do
        local e = list[i]
        local last = lastField and e.data and e.data[lastField]
        d(string.format("  %d. %s  x%d%s", i, e.name, e.count, last and string.format("  (%s: %s)", lastLabel, last) or ""))
    end
end

-------------------------------------------------------------------------------
-- Lookup: one search over players, duel opponents, abilities and characters.
-- Case-insensitive, matches any part of the name, totals summed over every
-- character. Returns { players, opponents, abilities, characters }, each a
-- list sorted by most activity first.
-------------------------------------------------------------------------------
local LOOKUP_LIMIT = 5

local function Matches(name, term)
    return type(name) == "string" and zo_strlower(name):find(term, 1, true) ~= nil
end

local function Num(v)
    if type(v) == "table" then return v.count or 0 end
    return tonumber(v) or 0
end

local function SortedValues(map, total)
    local list = {}
    for _, v in pairs(map) do list[#list + 1] = v end
    table.sort(list, function(a, b)
        local ta, tb = total(a), total(b)
        if ta == tb then return a.name < b.name end
        return ta > tb
    end)
    return list
end

-- Duel opponents through LibESQL: LIKE over kd_duel_opponents, summed over
-- every character. The typed text matches anywhere in the name, and % and _
-- are always literal (see KDST.LikePattern). Returns nil when LibESQL is
-- missing or the query fails, so the caller falls back to the Lua search.
local DUEL_LIKE_SQL = [[
SELECT opponent, SUM(wins) AS wins, SUM(losses) AS losses, SUM(duels) AS duels
FROM kd_duel_opponents
WHERE opponent LIKE ?
GROUP BY opponent
ORDER BY 4 DESC, 1]]

-- Escaping typed % and _. LibESQL's LIKE has no ESCAPE clause, so a literal
-- % or _ can't be written in the pattern. Instead each one becomes _ (exactly
-- one character, which still matches the real % or _), and the rows that
-- come back are checked with a plain substring match, which drops anything
-- the _ let through by accident ("a_b" must not match "axb"). Search text
-- can never change the meaning of the query, and it's bound with ?, so no
-- input can cause an SQL syntax error.
--
-- Every search string goes through KDST.EscapeSearch first:
--   * ESO markup (|c colours, |H links, |t textures, |r) is removed, so a
--     pasted link searches by its visible text;
--   * control characters (newlines, tabs, NUL) are removed;
--   * the result is trimmed and capped at MAX_SEARCH_LEN bytes (never
--     cutting a UTF-8 character in half).
-- The SQL text itself is always a fixed constant and the search value is
-- only ever bound as a ? parameter, never concatenated into the query, so
-- quotes, semicolons, "--" or keywords in the input are just text to match.
local MAX_SEARCH_LEN = 64

function KDST.EscapeSearch(term)
    term = tostring(term or "")
    term = term:gsub("|H.-|h(.-)|h", "%1")       -- links -> their text
    term = term:gsub("|t.-|t", "")                -- textures
    term = term:gsub("|c%x%x%x%x%x%x", "")        -- colour start
    term = term:gsub("|r", "")                    -- colour end
    term = term:gsub("%c", "")                    -- control characters
    term = Trim(term)
    if #term > MAX_SEARCH_LEN then
        term = term:sub(1, MAX_SEARCH_LEN)
        -- drop a trailing partial UTF-8 sequence
        term = term:gsub("[\192-\255][\128-\191]*$", "")
    end
    return term
end

-- LIKE pattern for a search: escaped text, % and _ made literal, wrapped
-- so it matches anywhere in the name.
function KDST.LikePattern(term)
    local escaped = KDST.EscapeSearch(term):gsub("[%%_]", "_")
    return "%" .. escaped .. "%"
end
KDST.DuelLikePattern = KDST.LikePattern

-- The exact, case-insensitive substring check that goes with LikePattern.
function KDST.LikeMatches(name, term)
    return Matches(name, zo_strlower(KDST.EscapeSearch(term)))
end

-- For any code that ever has to put a value inside SQL text: an escaped
-- SQL string literal ('it''s'). Prefer ? parameters; this is the fallback.
function KDST.SQLLiteral(value)
    if KDST.HasLibESQL and KDST.HasLibESQL() and type(LibESQL.Quote) == "function" then
        return LibESQL.Quote(value)
    end
    if value == nil then return "NULL" end
    if type(value) == "number" then return tostring(value) end
    return "'" .. tostring(value):gsub("'", "''") .. "'"
end

local function NeedsRecheck(term)
    return term:find("[%%_]") ~= nil
end

local function UseESQL()
    return KDST.HasLibESQL and KDST.HasLibESQL() and KDST.ESQL and KDST.ESQL.registered
end

function KDST.LookupDuelOpponents(term)
    term = KDST.EscapeSearch(term)
    if not UseESQL() then return nil end
    local rows = KDST.Query(DUEL_LIKE_SQL, { KDST.LikePattern(term) })
    if not rows then return nil end
    local recheck = NeedsRecheck(term)
    local list = {}
    for _, r in ipairs(rows) do
        if not recheck or KDST.LikeMatches(r.opponent, term) then
            list[#list + 1] = { name = r.opponent, wins = r.wins or 0, losses = r.losses or 0 }
        end
    end
    return list
end

-- Victims (players you killed) with the same LIKE rules. Each entry also
-- carries how often that player killed you, from kd_killers.
local VICTIM_LIKE_SQL = [[
SELECT player, SUM(kills) AS kills
FROM kd_victims
WHERE player LIKE ?
GROUP BY player]]

local KILLER_LIKE_SQL = [[
SELECT player, SUM(deaths) AS deaths
FROM kd_killers
WHERE player LIKE ?
GROUP BY player]]

local function SortVictims(list)
    table.sort(list, function(a, b)
        if a.kills == b.kills then return zo_strlower(a.name) < zo_strlower(b.name) end
        return a.kills > b.kills
    end)
    return list
end

-- Returns a list of { name, kills, deaths }, most killed first.
function KDST.LookupVictims(term)
    term = KDST.EscapeSearch(term)
    if UseESQL() then
        local pattern = KDST.LikePattern(term)
        local victims = KDST.Query(VICTIM_LIKE_SQL, { pattern })
        local killers = victims and KDST.Query(KILLER_LIKE_SQL, { pattern })
        if victims and killers then
            local deathsBy = {}
            for _, r in ipairs(killers) do deathsBy[r.player] = r.deaths or 0 end
            local recheck = NeedsRecheck(term)
            local list = {}
            for _, r in ipairs(victims) do
                if (r.kills or 0) > 0 and (not recheck or KDST.LikeMatches(r.player, term)) then
                    list[#list + 1] = { name = r.player, kills = r.kills, deaths = deathsBy[r.player] or 0 }
                end
            end
            return SortVictims(list)
        end
    end
    -- Lua fallback: substring match (empty term = everyone).
    local lowered, byName = zo_strlower(term), {}
    for _, c in pairs(KDST.data.characters or {}) do
        for player, n in pairs(c.victims or {}) do
            if Matches(player, lowered) then
                local e = byName[player] or { name = player, kills = 0, deaths = 0 }
                e.kills = e.kills + Num(n)
                byName[player] = e
            end
        end
    end
    for _, c in pairs(KDST.data.characters or {}) do
        for player, n in pairs(c.killers or {}) do
            if byName[player] then byName[player].deaths = byName[player].deaths + Num(n) end
        end
    end
    local list = {}
    for _, e in pairs(byName) do list[#list + 1] = e end
    return SortVictims(list)
end

function KDST.VictimText(e)
    return string.format("%s  -  %s kills / %s deaths  (K/D %s)", e.name,
        KDST.Color(C.kill, e.kills), KDST.Color(C.death, e.deaths), KDST.Color(C.ratio, KDST.Ratio(e.kills, e.deaths)))
end

function KDST.Lookup(term)
    term = zo_strlower(KDST.EscapeSearch(term))
    local players, opponents, abilities, characters = {}, {}, {}, {}
    if term == "" then return { players = {}, opponents = {}, abilities = {}, characters = {} } end

    local function Entry(map, name, init)
        local e = map[name]
        if not e then e = init; e.name = name; map[name] = e end
        return e
    end

    for charName, c in pairs(KDST.data.characters or {}) do
        if Matches(charName, term) then
            characters[charName] = { name = charName, kills = c.kills or 0, deaths = c.deaths or 0, bestStreak = c.bestStreak or 0 }
        end
        for player, n in pairs(c.victims or {}) do
            if Matches(player, term) then
                local e = Entry(players, player, { kills = 0, deaths = 0 })
                e.kills = e.kills + Num(n)
            end
        end
        for player, n in pairs(c.killers or {}) do
            if Matches(player, term) then
                local e = Entry(players, player, { kills = 0, deaths = 0 })
                e.deaths = e.deaths + Num(n)
            end
        end
        -- Abilities are grouped by name (ranks / morph variants have different ids).
        for id, e in pairs(c.killSources or {}) do
            local name = type(e) == "table" and e.abilityName or KDST.AbilityName(tonumber(id))
            if Matches(name, term) then
                local a = Entry(abilities, name, { kills = 0, deaths = 0 })
                a.kills = a.kills + Num(e)
            end
        end
        for id, e in pairs(c.deathSources or {}) do
            local name = type(e) == "table" and e.abilityName or KDST.AbilityName(tonumber(id))
            if Matches(name, term) then
                local a = Entry(abilities, name, { kills = 0, deaths = 0 })
                a.deaths = a.deaths + Num(e)
            end
        end
    end

    local opponentList = KDST.LookupDuelOpponents(term)
    if not opponentList then
        for _, c in pairs((KDST.data.duels or {}).perCharStats or {}) do
            for opp, rec in pairs(c.charactersFaced or {}) do
                if Matches(opp, term) then
                    local e = Entry(opponents, opp, { wins = 0, losses = 0 })
                    e.wins, e.losses = e.wins + (rec.wins or 0), e.losses + (rec.losses or 0)
                end
            end
        end
        opponentList = SortedValues(opponents, function(e) return e.wins + e.losses end)
    end

    local function KDTotal(e) return e.kills + e.deaths end
    return {
        players    = SortedValues(players, KDTotal),
        opponents  = opponentList,
        abilities  = SortedValues(abilities, KDTotal),
        characters = SortedValues(characters, KDTotal),
    }
end

local function PrintSection(title, list, format)
    if #list == 0 then return 0 end
    d(KDST.Color(C.accent, string.format("  %s (%d)", title, #list)))
    for i = 1, math.min(#list, LOOKUP_LIMIT) do d("    " .. format(list[i])) end
    if #list > LOOKUP_LIMIT then d(KDST.Color(C.muted, string.format("    ...and %d more, be more specific", #list - LOOKUP_LIMIT))) end
    return #list
end

function KDST.PrintLookup(term)
    term = KDST.EscapeSearch(term)
    if term == "" then
        KDST.Print("Usage: /kdlookup <name>  -  search players, duel opponents, abilities and your characters")
        return
    end
    local r = KDST.Lookup(term)
    KDST.Print(string.format("Lookup \"%s\":", term))
    local found = 0
    found = found + PrintSection("Players", r.players, function(e)
        return string.format("%s  -  you killed %s, killed you %s  (K/D %s)", e.name,
            KDST.Color(C.kill, e.kills), KDST.Color(C.death, e.deaths), KDST.Color(C.ratio, KDST.Ratio(e.kills, e.deaths)))
    end)
    found = found + PrintSection("Duel opponents", r.opponents, KDST.DuelOpponentText)
    found = found + PrintSection("Abilities", r.abilities, function(e)
        return string.format("%s  -  %s kills with it, %s deaths to it", e.name, KDST.Color(C.kill, e.kills), KDST.Color(C.death, e.deaths))
    end)
    found = found + PrintSection("Your characters", r.characters, function(e)
        return string.format("%s  -  %s  |  best streak %d", e.name, KD(e.kills, e.deaths), e.bestStreak)
    end)
    if found == 0 then d("  Nothing recorded matching \"" .. term .. "\".") end
end

local COMMANDS = {
    { "/kdstats",    "Open the stats window",                    function(arg) KDST.ToggleStatsDialog(tonumber(arg)) end },
    { "/kd",         "Show session + character K/D",             function()
        local s, c = KDST.session, KDST.GetCharData()
        KDST.Print(string.format("Session: %s", KD(s.kills, s.deaths)))
        KDST.Print(string.format("%s: %s  |  best streak %d", KDST.charName, KD(c.kills, c.deaths), c.bestStreak or 0))
    end },
    { "/kdhud",      "Show / hide the HUD tracker",              function() KDST.ToggleHUD() end },
    { "/kdlookup",   "Look up a player, opponent or ability",     function(arg) KDST.PrintLookup(arg) end },
    { "/kdreset",    "Reset stats: session | character | all",   function(arg)
        arg = Trim(arg):lower()
        if arg == "" then arg = "session" end
        if KDST.RESET_SCOPES[arg] then
            KDST.ShowResetDialog(arg)
        else
            KDST.Print("Usage: /kdreset session | character | all")
        end
    end },
    { "/bgstats",    "Show the last 10 battlegrounds",           function()
        local history = KDST.data.matchHistory
        if #history == 0 then KDST.Print("No battleground matches recorded.") return end
        KDST.Print("Last battlegrounds:")
        for i = #history, math.max(1, #history - 9), -1 do
            local m = history[i]
            d(string.format("  #%d %s: %s", m.matchId or i, KDST.GetMatchTypeName(m.matchType), KD(m.kills, m.deaths)))
        end
    end },
    { "/duelstats",  "Show duel record for this character",      function()
        local c = KDST.GetDuelData()
        KDST.Print(string.format("Duels for %s: %d total, %s wins, %s losses (%s)", KDST.charName, c.duels or 0,
            KDST.Color(C.kill, c.wins or 0), KDST.Color(C.death, c.losses or 0), KDST.Percent(c.wins, c.duels)))
    end },
    { "/duels",      "Overall duel record vs. a player: /duels [part of @Name]", function(arg)
        arg = KDST.EscapeSearch(arg)
        local function Record(w, l)
            return string.format("%s W / %s L  (W/L %s, %s)", KDST.Color(C.kill, w), KDST.Color(C.death, l),
                KDST.Color(C.ratio, KDST.Ratio(w, l)), KDST.Percent(w, w + l))
        end

        if arg == "" then
            -- Account-wide record, then your most-dueled opponents.
            local duels = KDST.data.duels or {}
            KDST.Print("Overall duels (all characters): " .. Record(duels.wins or 0, duels.losses or 0))
            local list = KDST.LookupDuelOpponents("@") or KDST.Lookup("@").opponents
            if #list == 0 then d("  No duels recorded yet.") return end
            PrintSection("Most dueled", list, KDST.DuelOpponentText)
            return
        end

        -- Same matching as /kdlookup; wins / losses are summed over every character.
        local list = KDST.LookupDuelOpponents(arg) or KDST.Lookup(arg).opponents
        if #list == 0 then
            KDST.Print("No duels against anyone matching \"" .. arg .. "\".")
            return
        end
        -- An exact name (with or without the @) wins over partial matches.
        local wanted = zo_strlower(arg:sub(1, 1) == "@" and arg or ("@" .. arg))
        for _, e in ipairs(list) do
            if zo_strlower(e.name) == wanted then list = { e }; break end
        end
        if #list == 1 then
            local e = list[1]
            KDST.Print(string.format("Overall vs %s (all characters): %s  -  %d duels", e.name, Record(e.wins, e.losses), e.wins + e.losses))
            return
        end
        local w, l = 0, 0
        for _, e in ipairs(list) do w, l = w + e.wins, l + e.losses end
        KDST.Print(string.format("Overall vs %d players matching \"%s\": %s", #list, arg, Record(w, l)))
        PrintSection("Players", list, KDST.DuelOpponentText)
    end },
    { "/kdstorage",  "Where stats are saved (LibESQL or SavedVariables); /kdstorage retry", function(arg)
        KDST.Store.PrintStatus(arg)
    end },
    { "/duellookup", "Open the duel lookup dialog (gamepad / console)", function(arg)
        if not KDST.OpenDuelLookup(arg) then SLASH_COMMANDS["/duels"](arg) end
    end },
    { "/victims",    "Players you've killed: /victims [part of name]", function(arg)
        arg = KDST.EscapeSearch(arg)
        local list = KDST.LookupVictims(arg)
        if #list == 0 then
            KDST.Print(arg ~= "" and ("You haven't killed anyone matching \"" .. arg .. "\".") or "No player kills recorded yet.")
            return
        end
        -- An exact name wins over partial matches.
        local wanted = zo_strlower(arg)
        for _, e in ipairs(list) do
            if zo_strlower(e.name) == wanted then list = { e }; break end
        end
        if #list == 1 then
            local e = list[1]
            KDST.Print(string.format("Vs %s (all characters): %s kills / %s deaths  (K/D %s)", e.name,
                KDST.Color(C.kill, e.kills), KDST.Color(C.death, e.deaths), KDST.Color(C.ratio, KDST.Ratio(e.kills, e.deaths))))
            return
        end
        local k, dd = 0, 0
        for _, e in ipairs(list) do k, dd = k + e.kills, dd + e.deaths end
        KDST.Print(string.format("%d victims%s: %s kills / %s deaths  (K/D %s)", #list,
            arg ~= "" and (" matching \"" .. arg .. "\"") or "",
            KDST.Color(C.kill, k), KDST.Color(C.death, dd), KDST.Color(C.ratio, KDST.Ratio(k, dd))))
        PrintSection(arg ~= "" and "Victims" or "Most killed", list, KDST.VictimText)
    end },
    { "/victimlookup", "Open the victim lookup dialog (gamepad / console)", function(arg)
        if not KDST.OpenVictimLookup(arg) then SLASH_COMMANDS["/victims"](arg) end
    end },
    { "/killstats",  "Kills per ability",                        function()
        PrintTop("Kills by ability", KDST.GetCharData().killSources, "abilityName", "lastVictim", "last victim", 25)
    end },
    { "/deathstats", "Deaths per ability",                       function()
        PrintTop("Deaths by ability", KDST.GetCharData().deathSources, "abilityName", "lastKiller", "last killer", 25)
    end },
    { "/mostkills",  "Your top killing ability",                 function()
        PrintTop("Top killing ability", KDST.GetCharData().killSources, "abilityName", "lastVictim", "last victim", 1)
    end },
    { "/mostdeaths", "The ability that kills you most",          function()
        PrintTop("Top nemesis ability", KDST.GetCharData().deathSources, "abilityName", "lastKiller", "last killer", 1)
    end },
}

function KDST.RegisterSlashCommands()
    for _, cmd in ipairs(COMMANDS) do
        SLASH_COMMANDS[cmd[1]] = cmd[3]
    end
    SLASH_COMMANDS["/kdhelp"] = function()
        KDST.Print(KDST.displayName .. " " .. KDST.version .. " commands:")
        for _, cmd in ipairs(COMMANDS) do
            d(string.format("  %s  -  %s", KDST.Color(C.accent, cmd[1]), cmd[2]))
        end
        d(string.format("  %s  -  %s", KDST.Color(C.accent, "/kdsettings"), "Open settings"))
    end
    if not SLASH_COMMANDS["/kdsettings"] then
        SLASH_COMMANDS["/kdsettings"] = function() KDST.OpenSettings() end
    end
end
