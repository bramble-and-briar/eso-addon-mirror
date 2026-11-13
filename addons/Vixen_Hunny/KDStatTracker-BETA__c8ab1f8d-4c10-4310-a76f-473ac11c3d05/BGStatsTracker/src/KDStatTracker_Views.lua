-- KDStatTracker_Views.lua
-- Platform-neutral page models. Both the PC window and the console dialog
-- render the same data, so stats only have to be assembled in one place.
--
-- page = {
--   key, title,
--   cards    = { { label, value, color, small } x4 },
--   sections = { { title, rows = { { label, value, color, tooltip } }, empty } },
-- }

local KDST = KDStatTracker
local C = KDST.COLORS
local Views = {}
KDST.Views = Views

local LIST_LIMIT = 15

local function Row(label, value, color, tooltip)
    return { label = label, value = value ~= nil and tostring(value) or "", color = color, tooltip = tooltip }
end

local function Card(label, value, color, small)
    return { label = label, value = tostring(value), color = color, small = small }
end

local function KDValue(k, d)
    return string.format("%s / %s", KDST.Color(C.kill, k or 0), KDST.Color(C.death, d or 0))
end

local function CountMatchesFor(charName)
    local n = 0
    for _, m in ipairs(KDST.data.matchHistory) do
        if m.characterName == charName then n = n + 1 end
    end
    return n
end

-------------------------------------------------------------------------------
-- Overview
-------------------------------------------------------------------------------
local function BuildOverview()
    local s, char, data = KDST.session, KDST.GetCharData(), KDST.data
    local page = { key = "overview", title = "Overview" }

    page.cards = {
        Card("Kills",       char.kills,  C.kill),
        Card("Deaths",      char.deaths, C.death),
        Card("K/D Ratio",   KDST.Ratio(char.kills, char.deaths), C.ratio),
        Card("Best Streak", char.bestStreak or 0, C.gold),
    }

    local sections = {}
    sections[#sections + 1] = {
        title = "This Session",
        rows = {
            Row("Kills / Deaths", KDValue(s.kills, s.deaths)),
            Row("K/D Ratio", KDST.Ratio(s.kills, s.deaths), C.ratio),
            Row("Current Streak", s.streak, s.streak >= 3 and C.gold or nil),
            Row("Best Streak", s.bestStreak),
            Row("Session Length", KDST.FormatDuration(GetTimeStamp() - s.startTime)),
        },
    }

    if KDST.match then
        local m = KDST.match
        sections[#sections + 1] = {
            title = "Current Match",
            rows = {
                Row("Mode", KDST.GetMatchTypeName(m.gameType) .. (m.name and (" - " .. m.name) or "")),
                Row("Kills / Deaths", KDValue(m.kills, m.deaths)),
                Row("K/D Ratio", KDST.Ratio(m.kills, m.deaths), C.ratio),
                Row("Time", KDST.FormatDuration(GetTimeStamp() - m.startTime)),
            },
        }
    end

    local duel = KDST.GetDuelData()
    sections[#sections + 1] = {
        title = zo_strformat("<<1>>", KDST.charName),
        rows = {
            Row("Kills / Deaths", KDValue(char.kills, char.deaths)),
            Row("Battlegrounds Logged", CountMatchesFor(KDST.charName)),
            Row("Duel Record", string.format("%s W  /  %s L", KDST.Color(C.kill, duel.wins or 0), KDST.Color(C.death, duel.losses or 0))),
        },
    }

    local charCount = 0
    for _ in pairs(data.characters) do charCount = charCount + 1 end
    sections[#sections + 1] = {
        title = "Account - All Characters",
        rows = {
            Row("Kills / Deaths", KDValue(data.totalKills, data.totalDeaths)),
            Row("K/D Ratio", KDST.Ratio(data.totalKills, data.totalDeaths), C.ratio),
            Row("Characters Tracked", charCount),
        },
    }

    local chars = {}
    for name, c in pairs(data.characters) do
        chars[#chars + 1] = { name = name, kills = c.kills or 0, deaths = c.deaths or 0 }
    end
    table.sort(chars, function(a, b) return a.kills > b.kills end)
    local charRows = {}
    for i = 1, math.min(#chars, LIST_LIMIT) do
        local c = chars[i]
        local label = c.name == KDST.charName and (c.name .. "  " .. KDST.Color(C.accent, "(you)")) or c.name
        charRows[#charRows + 1] = Row(label, string.format("%s   %s", KDValue(c.kills, c.deaths), KDST.Color(C.ratio, KDST.Ratio(c.kills, c.deaths))))
    end
    sections[#sections + 1] = { title = "Characters", rows = charRows, empty = "No characters tracked yet." }

    page.sections = sections
    return page
end

-------------------------------------------------------------------------------
-- Battlegrounds
-------------------------------------------------------------------------------
local function BuildBattlegrounds()
    local history = KDST.data.matchHistory
    local page = { key = "battlegrounds", title = "Battlegrounds" }

    local kills, deaths, n = 0, 0, #history
    local byType = {}
    for _, m in ipairs(history) do
        kills, deaths = kills + (m.kills or 0), deaths + (m.deaths or 0)
        local typeName = KDST.GetMatchTypeName(m.matchType)
        local t = byType[typeName] or { count = 0, kills = 0, deaths = 0 }
        t.count, t.kills, t.deaths = t.count + 1, t.kills + (m.kills or 0), t.deaths + (m.deaths or 0)
        byType[typeName] = t
    end

    page.cards = {
        Card("Matches",    n, C.accent),
        Card("Avg Kills",  n > 0 and string.format("%.1f", kills / n) or "0", C.kill),
        Card("Avg Deaths", n > 0 and string.format("%.1f", deaths / n) or "0", C.death),
        Card("Match K/D",  KDST.Ratio(kills, deaths), C.ratio),
    }

    local recent = {}
    for i = n, math.max(1, n - LIST_LIMIT + 1), -1 do
        local m = history[i]
        local label = string.format("#%d  %s", m.matchId or i, KDST.GetMatchTypeName(m.matchType))
        if m.name then label = label .. "  " .. KDST.Color(C.muted, m.name) end
        if m.abandoned then label = label .. "  " .. KDST.Color(C.death, "(left)") end
        local value = string.format("%s   %s", KDValue(m.kills, m.deaths), KDST.Color(C.ratio, KDST.Ratio(m.kills, m.deaths)))
        local tip = string.format("%s\n%s\nDuration %s\n%s",
            m.characterName or "?", KDST.GetMatchTypeName(m.matchType),
            KDST.FormatDuration(m.duration or 0), KDST.FormatDate(m.timestamp))
        recent[#recent + 1] = Row(label, value, nil, tip)
    end

    local typeRows = {}
    for _, entry in ipairs(KDST.SortedCounts(byType)) do
        local t = entry.data
        typeRows[#typeRows + 1] = Row(string.format("%s  %s", entry.name, KDST.Color(C.muted, "x" .. t.count)),
            string.format("%s   %s", KDValue(t.kills, t.deaths), KDST.Color(C.ratio, KDST.Ratio(t.kills, t.deaths))))
    end

    page.sections = {
        { title = "Recent Matches", rows = recent, empty = "No battlegrounds recorded yet. Queue up!" },
        { title = "By Game Mode", rows = typeRows, empty = "No battlegrounds recorded yet." },
    }
    return page
end

-------------------------------------------------------------------------------
-- Duels
-------------------------------------------------------------------------------
local function BuildDuels()
    local duel = KDST.GetDuelData()
    local acct = KDST.data.duels
    local page = { key = "duels", title = "Duels" }
    local total = duel.duels or 0

    page.cards = {
        Card("Duels",    total, C.accent),
        Card("Wins",     duel.wins or 0, C.kill),
        Card("Losses",   duel.losses or 0, C.death),
        Card("Win Rate", KDST.Percent(duel.wins, total), C.ratio),
    }

    local opponents = {}
    for name, rec in pairs(duel.charactersFaced) do
        local w, l = rec.wins or 0, rec.losses or 0
        opponents[#opponents + 1] = { name = name, wins = w, losses = l, total = w + l }
    end
    table.sort(opponents, function(a, b)
        if a.total == b.total then return a.name < b.name end
        return a.total > b.total
    end)

    local rows = {}
    for i = 1, math.min(#opponents, 40) do
        local o = opponents[i]
        local color = (o.wins > o.losses and C.kill) or (o.losses > o.wins and C.death) or nil
        rows[#rows + 1] = Row(o.name,
            string.format("%s W  /  %s L   %s", KDST.Color(C.kill, o.wins), KDST.Color(C.death, o.losses), KDST.Color(C.muted, KDST.Percent(o.wins, o.total))),
            color)
    end

    page.sections = {
        {
            title = "Account Record",
            rows = {
                Row("All Characters", string.format("%s W  /  %s L", KDST.Color(C.kill, acct.wins or 0), KDST.Color(C.death, acct.losses or 0))),
                Row("Win Rate", KDST.Percent(acct.wins, acct.totalDuels), C.ratio),
            },
        },
        { title = "Opponents", rows = rows, empty = "No duels yet. Challenge someone!" },
    }
    return page
end

-------------------------------------------------------------------------------
-- Abilities & players
-------------------------------------------------------------------------------
local function TopName(list)
    return list[1] and list[1].name or "-"
end

local function BuildAbilities()
    local char = KDST.GetCharData()
    local page = { key = "abilities", title = "Abilities" }

    local dealt   = KDST.SortedCounts(char.killSources, "abilityName")
    local taken   = KDST.SortedCounts(char.deathSources, "abilityName")
    local victims = KDST.SortedCounts(char.victims)
    local killers = KDST.SortedCounts(char.killers)

    page.cards = {
        Card("Favorite Skill", TopName(dealt),   C.kill,  true),
        Card("Nemesis Skill",  TopName(taken),   C.death, true),
        Card("Top Victim",     TopName(victims), C.gold,  true),
        Card("Top Nemesis",    TopName(killers), C.ratio, true),
    }

    local function AbilityRows(list, lastField, lastLabel)
        local rows = {}
        for i = 1, math.min(#list, LIST_LIMIT) do
            local e = list[i]
            local last = e.data and e.data[lastField]
            rows[#rows + 1] = Row(string.format("%d. %s", i, e.name), "x" .. e.count, nil,
                last and string.format("%s: %s", lastLabel, last) or nil)
        end
        return rows
    end

    local function PlayerRows(list, color)
        local rows = {}
        for i = 1, math.min(#list, LIST_LIMIT) do
            rows[#rows + 1] = Row(string.format("%d. %s", i, list[i].name), KDST.Color(color, "x" .. list[i].count))
        end
        return rows
    end

    page.sections = {
        { title = "Killing Blows Dealt", rows = AbilityRows(dealt, "lastVictim", "Last victim"), empty = "No kills recorded yet." },
        { title = "Killed By",           rows = AbilityRows(taken, "lastKiller", "Last killer"), empty = "No deaths recorded yet." },
        { title = "Most Killed Players", rows = PlayerRows(victims, C.kill),  empty = "No player kills yet." },
        { title = "Nemeses",             rows = PlayerRows(killers, C.death), empty = "Nobody has killed you. Yet." },
    }
    return page
end

-------------------------------------------------------------------------------
-- Registry
-------------------------------------------------------------------------------
Views.PAGES = {
    { key = "overview",      title = "Overview", build = BuildOverview },
    { key = "battlegrounds", title = "Battlegrounds", build = BuildBattlegrounds },
    { key = "duels",         title = "Duels", build = BuildDuels },
    { key = "abilities",     title = "Abilities", build = BuildAbilities },
}

function Views.Build(index)
    local def = Views.PAGES[index] or Views.PAGES[1]
    return def.build()
end

function Views.Count()
    return #Views.PAGES
end

function Views.Wrap(index)
    local n = #Views.PAGES
    return ((index - 1) % n) + 1
end
