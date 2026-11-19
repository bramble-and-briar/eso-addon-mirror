-- Bootstrap: saved variables, events, slash commands, keybind entry points.
local SBR = ScoreboardRemastered

local DEFAULTS = {
    autoShowWithScoreboard = true,
    attach = "over",       -- over | right | left | below | free (see UI/Window.lua)
    scale = 1,
    groupByTeam = true,
    hideEmptyColumns = true,
    showFightColumns = true,
    showVsColumns = false, -- you-vs-them columns in the PC table (always in the details pane)
    useLibFights = true,   -- use LibFights when installed
    lfSaveFights = false,  -- let LibFights also save battleground fights to its own SavedVariables
    trackCombat = true,    -- combat ledger: fight stats for every player on the scoreboard
    chatSummary = true,
    maxHistory = 20,       -- full scoreboards kept (10 on console); older matches stay as records
    gamepadOpenKey = "right_stick", -- button added to the native gamepad scoreboard
    replaceNativeScoreboard = true, -- our table instead of the native in-game scoreboard (UI/Replace.lua)
    consoleLayout = "table", -- gamepad scoreboard: "table" (the PC table) or "list" (native list screen)
    maxRecords = 500,      -- match database records (150 on console)
    maxPlayers = 1000,     -- player index entries (400 on console)
    inventoryButton = true, -- "Battleground records" in the inventory
    inventoryKey = "right_stick", -- gamepad inventory button
    debug = false,
    autoReport = true,     -- open the battle report when you leave a finished battleground
    showLauncher = true,   -- PC: the draggable records button on the HUD
    launcherPos = nil,
    showLoadTiming = false, -- always print the load report (it prints by itself when slow)
    history = {},
}

local function On(eventName, handler)
    local event = _G[eventName]
    if event == nil then
        SBR.Debug("event %s not available on this client", eventName)
        return
    end
    EVENT_MANAGER:RegisterForEvent(SBR.name .. "_" .. eventName, event, handler)
end

local function RegisterEvents()
    On("EVENT_PLAYER_ACTIVATED", function()
        local M = SBR.Mark
        -- the time from our setup to here is the game loading the world and the
        -- other add-ons, not ours: it gets its own line in the report
        M("waiting: game and other add-ons")
        SBR.Hook:Install() -- catch anything created after addon load
        SBR.Replace:Install()
        M("activated: scoreboard hooks")
        SBR.MatchLog:StartBackgroundCompaction()
        SBR.InventoryHook:Install()
        SBR.LibFights:Init()
        M("activated: inventory, LibFights")
        SBR.MatchLog:OnPlayerActivated()
        SBR.ReportUI:OnPlayerActivated()
        SBR.Launcher:Install()
        M("activated: match log")
        SBR.FinishLoadProfile()
        -- the settings panel is built a moment after login, not during the load
        if not SBR.settingsCreated then
            SBR.settingsCreated = true
            zo_callLater(function() SBR.Settings:Create() end, 1500)
        end
    end)
    On("EVENT_BATTLEGROUND_STATE_CHANGED", function(_, previousState, currentState)
        SBR.MatchLog:OnStateChanged(previousState, currentState)
    end)
    On("EVENT_BATTLEGROUND_SCOREBOARD_UPDATED", function() SBR.MatchLog:RequestSnapshot() end)
    On("EVENT_BATTLEGROUND_KILL", function(_, ...) SBR.MatchLog:OnKill(...) end)
    On("EVENT_MEDAL_AWARDED", function(_, medalId, name, icon, value) SBR.MatchLog:OnMedal(medalId, name, icon, value) end)
end

local HELP = {
    "/sbr - toggle the panel",
    "/sbr export - CSV of the viewed match",
    "/sbr kills - kill feed of the viewed match",
    "/sbr history [n] - list saved matches, or open match n",
    "/sbr live - back to the live/last match",
    "/sbr db - battleground records (matches and players)",
    "/sbr players - battleground records, players tab",
    "/sbr reset - reset panel position",
    "/sbr attach over|right|left|below|free",
    "/sbr clear - delete saved history",
    "/sbr status - LibFights state and score types",
    "/sbr load - how long the last loads took (CPU budget)",
    "/sbr report - battle report of the last match",
    "/sbr hooks - which native scoreboard parts were hooked",
    "/sbr debug - toggle debug output",
}

local function ListHistory()
    local history = SBR.MatchLog:GetHistory()
    if #history == 0 then
        SBR.Print("No saved matches yet.")
        return
    end
    local first = math.max(1, #history - 14)
    for i = first, #history do
        local m = history[i]
        local me = SBR.MatchLog:FindLocalPlayer(m)
        local s = me and me.scores or {}
        d(string.format("  %d. %s %s - %s (%s) K/D/A %s/%s/%s", i, SBR.FormatTimestamp(m.startedAt),
            m.name or "?", m.result or "?", SBR.FormatDuration(m.duration),
            tostring(s.KILL or "-"), tostring(s.DEATH or "-"), tostring(s.ASSISTS or "-")))
    end
    SBR.Print("/sbr history <n> to open one.")
end

local function Status()
    SBR.Print("fight data: %s; combat ledger %s", SBR.LibFights:StatusText(),
        SBR.FightTracker.active and "running" or (SBR.sv.trackCombat and "standby" or "off"))
    local ledger = SBR.FightTracker.ledger
    if ledger then
        local n = 0
        for _ in pairs(ledger.units) do n = n + 1 end
        SBR.Print("combat ledger: %d players seen this match", n)
    end
    local types = {}
    for _, st in ipairs(SBR.Battleground.scoreTypes or {}) do types[#types + 1] = st.key .. "=" .. st.id end
    SBR.Print("score types: %s", table.concat(types, ", "))
    SBR.Print("in battleground: %s, current match: %s, saved matches: %d",
        tostring(SBR.Battleground:IsInBattleground()), SBR.MatchLog:GetCurrent() and "yes" or "no",
        #SBR.MatchLog:GetHistory())
end

local function Slash(args)
    local cmd, rest = (args or ""):lower():match("^%s*(%S*)%s*(.-)%s*$")
    local W = SBR.Window
    if cmd == "" or cmd == "toggle" then
        W:Toggle()
    elseif cmd == "show" then
        W:Show(true)
    elseif cmd == "hide" then
        W:Hide(true)
    elseif cmd == "report" then
        SBR.ReportUI:Open()
    elseif cmd == "load" then
        local reports = SBR.sv.loadReports or {}
        if #reports == 0 then SBR.Print("no load report yet") end
        for _, r in ipairs(reports) do
            SBR.Print("%s: our files %d ms, setup %d ms, after login %d ms; slowest step %s %d ms; not ours %d ms; slowest add-ons: %s",
                SBR.FormatTimestamp and SBR.FormatTimestamp(r.at) or tostring(r.at), r.ourFilesMs or 0, r.setupMs or 0,
                r.activatedMs or 0, tostring(r.slowest), r.slowestMs or 0, r.outsideMs or 0, r.otherAddons ~= "" and r.otherAddons or "-")
        end
        local last = reports[#reports]
        if last then SBR.Print("steps (ms): %s", last.steps) end
    elseif cmd == "export" then
        SBR.Export:Show(W:GetViewedMatch())
    elseif cmd == "kills" or cmd == "killfeed" then
        SBR.Export:ShowKillFeed(W:GetViewedMatch())
    elseif cmd == "history" then
        local n = tonumber(rest)
        if n then
            W:Show(true)
            W:SetView(n)
        else
            ListHistory()
        end
    elseif cmd == "db" or cmd == "database" or cmd == "records" then
        SBR.MatchBrowser:Open()
    elseif cmd == "players" then
        SBR.MatchBrowser:Open("players")
    elseif cmd == "live" then
        W:Show(true)
        W:SetView(nil)
    elseif cmd == "reset" then
        W:ResetPosition()
    elseif cmd == "attach" and rest ~= "" then
        SBR.sv.attach = rest
        W:ResetPosition()
    elseif cmd == "clear" then
        SBR.MatchLog:ClearHistory()
        SBR.Print("History cleared.")
    elseif cmd == "status" then
        Status()
    elseif cmd == "hooks" then
        SBR.Hook:Report()
        SBR.InventoryHook:Report()
    elseif cmd == "debug" then
        SBR.sv.debug = not SBR.sv.debug
        SBR.Print("debug %s", SBR.sv.debug and "on" or "off")
    else
        for _, line in ipairs(HELP) do d(line) end
    end
end

-- Keybind entry points (Bindings.xml)
function ScoreboardRemastered_Toggle() SBR.Window:Toggle() end
function ScoreboardRemastered_Export() SBR.Export:Show(SBR.Window:GetViewedMatch()) end

local function OnAddOnLoaded(_, addonName)
    if addonName ~= SBR.name then return end
    EVENT_MANAGER:UnregisterForEvent(SBR.name, EVENT_ADD_ON_LOADED)

    if SBR.IsConsole() then
        DEFAULTS.maxHistory = 10
        DEFAULTS.maxRecords = 150
        DEFAULTS.maxPlayers = 400
    end
    local M = SBR.Mark
    M("add-on loaded event")
    SBR.sv = ZO_SavedVars:NewAccountWide("ScoreboardRemasteredSV", 1, nil, DEFAULTS)
    M("setup: saved variables")
    SBR.MatchLog:Init(SBR.sv)
    SBR.MatchDB:Init(SBR.sv)
    M("setup: match log, database")
    SBR.Battleground:DiscoverScoreTypes()
    SBR.LibFights:Init()
    SBR.Hook:Install()
    -- the windows and the settings panel are built later (first open / after
    -- login), not here: load time counts against ESO's CPU budget
    SBR.Gamepad:Init()
    SBR.InventoryHook:Install()
    RegisterEvents()
    M("setup: hooks, events")

    if SLASH_COMMANDS then -- not available on console
        SLASH_COMMANDS["/sbr"] = Slash
        SLASH_COMMANDS["/scoreboard"] = Slash
    end
end

EVENT_MANAGER:RegisterForEvent(SBR.name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)

-- Load report: how long our files, our setup and each add-on's load took. Printed to
-- chat once per load when it's slow (or always with the "Show load timing" setting),
-- and the last 5 are kept in sv.loadReports.
local SLOW_LOAD_MS = 100
function SBR.FinishLoadProfile()
    local p = SBR.loadProfile
    if p.done then return end
    p.done = true
    EVENT_MANAGER:UnregisterForEvent(SBR.name .. "_LoadTimeline", EVENT_ADD_ON_LOADED)
    local lines, last = {}, p.start
    local ours, setup, activated, waiting = 0, 0, 0, 0
    local slowest, slowestMs = nil, -1
    for _, m in ipairs(p.marks) do
        local ms = m[2] - last
        last = m[2]
        -- "add-on loaded event" / "waiting: ..." are time spent outside our code
        local outside = m[1] == "add-on loaded event" or m[1]:find("^waiting") ~= nil
        if outside then
            waiting = waiting + ms
        elseif m[1]:find("^setup") then setup = setup + ms
        elseif m[1]:find("^activated") then activated = activated + ms
        else ours = ours + ms end
        if not outside and ms > slowestMs then slowest, slowestMs = m[1], ms end
        lines[#lines + 1] = string.format("%s %d", m[1], ms)
    end
    -- other add-ons: time between consecutive "add-on loaded" events (their saved
    -- variables and setup, plus file loading for the first one)
    local others, prev = {}, nil
    for _, a in ipairs(p.addons) do
        if prev then others[#others + 1] = { a[1], a[2] - prev } end
        prev = a[2]
    end
    table.sort(others, function(a, b) return a[2] > b[2] end)
    local top = {}
    for i = 1, math.min(3, #others) do top[#top + 1] = string.format("%s %d ms", others[i][1], others[i][2]) end
    local report = {
        at = GetTimeStamp(),
        ourFilesMs = ours, setupMs = setup, activatedMs = activated, outsideMs = waiting,
        slowest = slowest, slowestMs = slowestMs,
        sinceFirstFileMs = last - p.start,
        steps = table.concat(lines, ", "),
        otherAddons = table.concat(top, ", "),
    }
    local sv = SBR.sv
    if sv then
        sv.loadReports = sv.loadReports or {}
        table.insert(sv.loadReports, report)
        while #sv.loadReports > 5 do table.remove(sv.loadReports, 1) end
    end
    local total = ours + setup + activated
    if total >= SLOW_LOAD_MS or (sv and sv.showLoadTiming) then
        SBR.Print("load: our files %d ms, setup %d ms, after login %d ms (slowest: %s %d ms). Not ours: game and other add-ons %d ms. Slowest loads overall: %s",
            ours, setup, activated, tostring(slowest), slowestMs, waiting, #top > 0 and table.concat(top, ", ") or "-")
    end
end

-- Public API for other addons
function SBR.GetCurrentMatch() return SBR.MatchLog:GetCurrent() end
function SBR.GetHistory() return SBR.MatchLog:GetHistory() end
ScoreboardRemastered.Mark("Core.lua")
