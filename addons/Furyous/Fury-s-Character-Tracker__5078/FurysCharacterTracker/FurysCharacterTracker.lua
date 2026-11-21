-- Fury's Character Tracker: namespace, saved variables, events and slash commands.
--
--   Data/Lines.lua   the skill lines tracked, grouped, with their max ranks
--   Core/Scan.lua    reads the character you are logged in on
--   Core/Roster.lua  the stored roster: characters, manual fields, totals, export rows
--   UI/              the board (/fct) and the brag card (/fct brag)

FuryCT = FuryCT or {}
local CT = FuryCT

CT.name = "FurysCharacterTracker"
CT.displayName = "Fury's Character Tracker"
CT.version = "1.2.0"

CT.defaults = {
    characters = {},   -- [character name] = everything read from that character (see Core/Scan.lua)
    manual = {},       -- [character name] = { role =, dpsGear =, roleGear =, plannedRace = } picked by you
    order = {},        -- character names in board order
    hidden = {},       -- [character name] = true: deleted characters you removed from the board
    exportRows = {},   -- "FCT|..." lines for ExportToExcel.ps1, rebuilt after every scan
    exportRequestedAt = 0,  -- set by the Export button; AutoExport.ps1 writes the CSV when it sees a new one
    exportPending = false,
    window = nil,
    lastView = "overview",
    sort = {},         -- [view id] = { col =, desc = } column the board is sorted by
}

ZO_CreateStringId("SI_BINDING_NAME_FURYCT_WINDOW", "Open the character board")
ZO_CreateStringId("SI_BINDING_NAME_FURYCT_BRAG", "Show the brag card")
ZO_CreateStringId("SI_BINDING_NAME_FURYCT_TIMERS", "Show research timers")

local function OnAddOnLoaded(_, addonName)
    if addonName ~= CT.name then return end
    EVENT_MANAGER:UnregisterForEvent(CT.name, EVENT_ADD_ON_LOADED)

    -- Account-wide, split per megaserver: NA and EU are different rosters.
    CT.sv = ZO_SavedVars:NewAccountWide("FuryCT_SV", 1, nil, CT.defaults, GetWorldName())
    CT.home = { world = GetWorldName(), account = GetDisplayName() }
    CT.view = CT.home

    CT.Roster:Initialize()
    CT.Window:Initialize()
    CT.Settings:Build()
    CT.RegisterSlashCommands()
end

local function OnPlayerActivated()
    -- Every zone change fires this; one full read per login or /reloadui is plenty,
    -- the events in Scan:Start catch progress made after that.
    EVENT_MANAGER:UnregisterForEvent(CT.name, EVENT_PLAYER_ACTIVATED)
    CT.Scan:Start()
    if CT.sv.loginNotice ~= false then CT.Research:LoginNotice() end
    CT.Alerts:Start()
    if CT.sv.openAtLogin then CT.Window:Show() end
    if CT.sv.exportPending then
        CT.sv.exportPending = false
        CT.Util.Print("Exported %d characters. With Auto Export on, ESO Characters.csv is in Documents\\Elder Scrolls Online in a few seconds.", #CT.sv.exportRows - 1)
    end
end

-- Windows: the one you open or click comes to the front.
-- Each raise puts the window one draw level above the last one raised.
local topLevel = 10
function CT.Raise(control)
    topLevel = topLevel + 1
    control:SetDrawLevel(topLevel)
    if control.BringWindowToTop then control:BringWindowToTop() end
end

-- Other accounts and megaservers -----------------------------------------------------------
-- Every account that plays on this PC saves into the same file, so the board can show any of them.
-- What you see for another account is what it saved the last time it logged out.

function CT.IsHome() return CT.view == CT.home end

-- The saved data of the account being viewed (yours, unless you picked another one).
function CT.Data()
    if CT.IsHome() then return CT.sv end
    local world = FuryCT_SV and FuryCT_SV[CT.view.world]
    local data = world and world[CT.view.account] and world[CT.view.account]["$AccountWide"]
    if not data then CT.view = CT.home; return CT.sv end
    data.characters, data.order = data.characters or {}, data.order or {}
    data.hidden, data.manual = data.hidden or {}, data.manual or {}
    return data
end

-- Every account and megaserver with characters in the file: yours first, then A to Z.
function CT.Accounts()
    local list = {}
    for world, accounts in pairs(FuryCT_SV or {}) do
        if type(accounts) == "table" then
            for account, profile in pairs(accounts) do
                local data = type(profile) == "table" and profile["$AccountWide"]
                if data and next(data.characters or {}) then
                    local isHome = world == CT.home.world and account == CT.home.account
                    list[#list + 1] = isHome and CT.home or { world = world, account = account }
                end
            end
        end
    end
    table.sort(list, function(a, b)
        if (a == CT.home) ~= (b == CT.home) then return a == CT.home end
        if a.account ~= b.account then return a.account < b.account end
        return a.world < b.world
    end)
    return list
end

function CT.SetView(entry)
    CT.view = entry
    CT.Window:Refresh()
    if not FuryCTBrag:IsHidden() then CT.Brag:Refresh() end
    CT.Timers:RefreshIfShown()
end

-- "@Furyous · NA"
function CT.ViewLabel(entry)
    entry = entry or CT.view
    return string.format("%s  ·  %s", entry.account, (entry.world:gsub(" Megaserver", "")))
end

-- Export button: the game only writes SavedVariables on a reload or logout, so save and reload in one go.
-- AutoExport.ps1 (turned on with "Turn On Auto Export.cmd") sees the new request and writes the CSV.
function CT.RequestExport()
    CT.Roster:BuildExportRows()
    CT.sv.exportRequestedAt = GetTimeStamp()
    CT.sv.exportPending = true
    ReloadUI("ingame")
end

function CT.RegisterSlashCommands()
    local U = CT.Util
    SLASH_COMMANDS["/fct"] = function(arg)
        arg = zo_strlower(zo_strtrim(arg or ""))
        if arg == "" or arg == "show" then
            CT.Window:Toggle()
        elseif CT.Window:HasView(arg) then
            CT.Window:Show(arg)
        elseif arg == "brag" then
            CT.Brag:Toggle()
        elseif arg == "todo" or arg:match("^todo %d+$") then
            CT.Roster:PrintToDo(tonumber(arg:match("%d+")) or 7)
        elseif arg == "scan" then
            CT.Scan:Run()
            U.Print("Updated %s.", CT.Scan.CurrentName())
        elseif arg == "export" then
            CT.RequestExport()
        elseif arg == "settings" then
            CT.Settings:Open()
        elseif arg == "alerts on" or arg == "alerts off" then
            CT.Alerts:Set(arg == "alerts on")
        elseif arg == "research" then
            CT.Research:Print()
        elseif arg == "timers" then
            CT.Timers:Toggle()
        elseif arg == "ids" then
            CT.Scan:PrintIds()
        else
            U.Print("%s v%s", CT.displayName, CT.version)
            U.Print("/fct  open the board (also on a key: Controls > Fury's Character Tracker)")
            U.Print("/fct overview, weapons, armor, guilds, world, crafting, traits, collections, sets  open a view")
            U.Print("/fct brag  the brag card: your best numbers on one screen, for a screenshot")
            U.Print("/fct timers  research timers window: what each character is researching and time left")
            U.Print("/fct research  research slots and timers in chat")
            U.Print("/fct settings  open the settings page (or the gear on the board)")
            U.Print("/fct alerts on | off  chat line when research or a riding lesson is ready on any character (on by default)")
            U.Print("/fct todo  characters never read, or not read in 7 days (/fct todo 30 for 30 days)")
            U.Print("/fct scan  read this character again now")
            U.Print("/fct export  export to Excel (reloads the UI; Auto Export writes the CSV)")
        end
    end
end

EVENT_MANAGER:RegisterForEvent(CT.name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
EVENT_MANAGER:RegisterForEvent(CT.name, EVENT_PLAYER_ACTIVATED, OnPlayerActivated)
