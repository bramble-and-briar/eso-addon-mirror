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

local COMMANDS = {
    { "/kdstats",    "Open the stats window",                    function(arg) KDST.ToggleStatsDialog(tonumber(arg)) end },
    { "/kd",         "Show session + character K/D",             function()
        local s, c = KDST.session, KDST.GetCharData()
        KDST.Print(string.format("Session: %s", KD(s.kills, s.deaths)))
        KDST.Print(string.format("%s: %s  |  best streak %d", KDST.charName, KD(c.kills, c.deaths), c.bestStreak or 0))
    end },
    { "/kdhud",      "Show / hide the HUD tracker",              function() KDST.ToggleHUD() end },
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
    { "/duels",      "Duel record vs. someone: /duels @Name",    function(arg)
        arg = Trim(arg)
        local c = KDST.GetDuelData()
        if arg == "" then
            KDST.Print(string.format("Duels for %s: %s W / %s L", KDST.charName, KDST.Color(C.kill, c.wins or 0), KDST.Color(C.death, c.losses or 0)))
            return
        end
        if arg:sub(1, 1) ~= "@" then arg = "@" .. arg end
        local rec = c.charactersFaced[arg]
        if not rec then
            KDST.Print("No duel data against " .. arg .. ".")
            return
        end
        local total = (rec.wins or 0) + (rec.losses or 0)
        KDST.Print(string.format("Vs %s: %s W / %s L (%s)", arg, KDST.Color(C.kill, rec.wins or 0), KDST.Color(C.death, rec.losses or 0), KDST.Percent(rec.wins, total)))
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
