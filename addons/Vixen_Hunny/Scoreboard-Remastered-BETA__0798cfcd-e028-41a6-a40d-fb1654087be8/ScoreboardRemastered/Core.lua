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
    maxHistory = 50,       -- 10 on console (smaller SavedVariables budget)
    gamepadOpenKey = "right_stick", -- button added to the native gamepad scoreboard
    consoleLayout = "table", -- gamepad scoreboard: "table" (the PC table) or "list" (native list screen)
    maxRecords = 500,      -- match database records (150 on console)
    maxPlayers = 2000,     -- player index entries (400 on console)
    inventoryButton = true, -- "Battleground records" in the inventory
    inventoryKey = "right_stick", -- gamepad inventory button
    debug = false,
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
        SBR.Hook:Install() -- catch anything created after addon load
        SBR.InventoryHook:Install()
        SBR.LibFights:Init()
        SBR.MatchLog:OnPlayerActivated()
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
    SBR.sv = ZO_SavedVars:NewAccountWide("ScoreboardRemasteredSV", 1, nil, DEFAULTS)
    SBR.MatchLog:Init(SBR.sv)
    SBR.MatchDB:Init(SBR.sv)
    SBR.Battleground:DiscoverScoreTypes()
    SBR.LibFights:Init()
    SBR.Hook:Install()
    SBR.Window:Create()
    SBR.Gamepad:Init()
    SBR.MatchBrowser:Init()
    SBR.InventoryHook:Install()
    SBR.Settings:Create()
    RegisterEvents()

    if SLASH_COMMANDS then -- not available on console
        SLASH_COMMANDS["/sbr"] = Slash
        SLASH_COMMANDS["/scoreboard"] = Slash
    end
end

EVENT_MANAGER:RegisterForEvent(SBR.name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)

-- Public API for other addons
function SBR.GetCurrentMatch() return SBR.MatchLog:GetCurrent() end
function SBR.GetHistory() return SBR.MatchLog:GetHistory() end
