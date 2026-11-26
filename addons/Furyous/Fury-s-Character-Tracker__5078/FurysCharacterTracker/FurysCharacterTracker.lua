-- shared
-- Fury's Character Tracker: the namespace, the saved data and its upgrade steps.
--
-- How the addon is laid out:
--   Data/        text shown on screen, the skill lines, the tabs of the board
--   Core/        helpers, the list of tracked things, the roster, history, the board's rules, the pages
--   Trackers/    ONE FILE PER TRACKED THING: how to read it from the game, which game events make
--                it stale, its board columns, its details lines, its export columns
--   Game/        what only runs in game: reading (Scan), alerts, startup and slash commands
--   UI/          the windows
--
-- A file whose first line is "-- shared" makes no game calls while it loads. The offline viewer
-- (Windows Tools) runs those same files in the browser, so the viewer shows what the board shows
-- without a second copy of the rules.

FurysCharacterTracker = {}
local CT = FurysCharacterTracker

CT.name = "FurysCharacterTracker"
CT.displayName = "Fury's Character Tracker"
CT.version = "1.8.4"
-- The Windows Tools (offline viewer, Excel export) can't ship in the ESOUI zip; this page has the download.
CT.toolsUrl = "https://github.com/AlbertHoffpauir/FurysCharacterTracker#downloads"

-- Saved per account, split per megaserver. Characters are saved under the game's own character ID
-- (it never changes, a name can).
CT.defaults = {
    characters = {},   -- [character id] = everything read from that character (see Trackers/)
    manual = {},       -- [character id] = what only you know: role, gear, planned race, note
    order = {},        -- character ids in your board order
    hidden = {},       -- [character id] = true: characters you took off the board
    history = {},      -- [character id] = one short text per day played (see Core/History.lua)
    exportRows = {},   -- "FCT|..." lines for the Windows Tools, written at logout and when you export
    exportRequestedAt = 0,  -- set by the Export button; AutoExport.ps1 writes the CSV when it sees a new one
    exportPending = false,
    lastView = "overview",
    sort = {},         -- [view id] = { col =, desc = } column the board is sorted by
}

-- True in game, false in the offline viewer.
CT.live = false

-- What a read of a character gathers. Raise it when a new version reads something more: the board
-- then says which characters need one login to fill the new columns (each read stamps c.v).
CT.READ_VERSION = 3

-- Saved data version ------------------------------------------------------------------------
-- Each step runs once, in order, on data saved before it existed. A change to the shape of the
-- saved data is a new step at the end of this list. Steps only look at the data they are given,
-- so they can run on every account in the file, whoever is logged in.
CT.UPGRADES = {
    -- 1: picks renamed and starter rows dropped (pre-1.0 test builds); one alert switch became two (1.2.0 test builds).
    function(data)
        CT.Roster.UpgradeOldPicks(data)
        if data.alertsOff then data.alertResearch, data.alertRiding, data.alertsOff = false, false, nil end
    end,
    -- 2 (1.5.0): characters saved under their character ID instead of their name.
    function(data)
        CT.Roster.UpgradeToIds(data)
    end,
}

function CT.UpgradeProfile(data, isNewInstall)
    for key, value in pairs(CT.defaults) do
        if data[key] == nil and type(value) == "table" then data[key] = {} end
    end
    local from = isNewInstall and #CT.UPGRADES or (data.dataVersion or 0)
    for step = from + 1, #CT.UPGRADES do CT.UPGRADES[step](data) end
    data.dataVersion = #CT.UPGRADES
end

-- Every account and megaserver in the file: the board can show any of them, so all of them have
-- to be in today's shape.
function CT.UpgradeAll()
    for _, accounts in pairs(FuryCT_SV or {}) do
        if type(accounts) == "table" then
            for _, profile in pairs(accounts) do
                local data = type(profile) == "table" and profile["$AccountWide"]
                if type(data) == "table" and (data.dataVersion or 0) < #CT.UPGRADES then CT.UpgradeProfile(data) end
            end
        end
    end
end

-- Other accounts and megaservers -----------------------------------------------------------
-- Every account that plays on this PC saves into the same file, so the board can show any of them.
-- What you see for another account is what it saved the last time it logged out.
-- CT.home = the account you are logged in on (in the viewer: nobody). CT.view = the one on the board.

function CT.IsHome() return CT.live and CT.view == CT.home end

local function Profile(entry)
    local world = FuryCT_SV and FuryCT_SV[entry.world]
    return world and world[entry.account] and world[entry.account]["$AccountWide"]
end

-- The saved data of the account being viewed (yours, unless you picked another one).
function CT.Data()
    if CT.IsHome() then return CT.sv end
    local data = CT.view and Profile(CT.view)
    if not data then
        CT.view = CT.home or CT.Accounts()[1]
        return CT.sv or (CT.view and Profile(CT.view)) or CT.defaults
    end
    return data
end

-- Every account and megaserver with characters in the file: yours first, then A to Z.
function CT.Accounts()
    local list = {}
    for world, accounts in pairs(FuryCT_SV or {}) do
        if type(accounts) == "table" then
            for account, profile in pairs(accounts) do
                local data = type(profile) == "table" and profile["$AccountWide"]
                if type(data) == "table" and type(data.characters) == "table" and next(data.characters) then
                    local isHome = CT.home and world == CT.home.world and account == CT.home.account
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

-- "@Furyous · NA"
function CT.ViewLabel(entry)
    entry = entry or CT.view
    return string.format("%s  ·  %s", entry.account, (entry.world:gsub(" Megaserver", "")))
end

-- Windows that want to redraw when the account on the board changes add themselves here.
CT.viewListeners = {}
function CT.SetView(entry)
    CT.view = entry
    for _, listener in ipairs(CT.viewListeners) do listener() end
end
