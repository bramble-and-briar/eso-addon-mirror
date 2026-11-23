-- Gold Digger: start-up and saved data. Who can use it is decided in Access.lua.

ESOC_GoldDigger = ESOC_GoldDigger or {}
local GP = ESOC_GoldDigger

GP.NAME = "ESOCGoldDigger"

local DEFAULTS = {
    account = { done = {} },
    characters = {},
    items = {},
    listings = {},
    tour = {},
    checks = {},
    book = {},
    kioskPlaces = {},
    stock = {},
    listed = {},
    strikes = {},
    eventLog = {},
    saleCursors = {},
    members = {},
    memberInfo = {},
    options = {
        showOnLogin = true,
        showAtTrader = true,
        includeTome = false,
        side = "left",
        height = 0,
        sellZone = "Deshaan",
        maxAgeDays = 3,
        maxPrice = 0,
        budget = 0,
        choosePrice = false,
        scanOnOpen = false,
        minListValue = 5000,
        minProfit = 1000,
    },
}

GP.unlocked = false

-- Daily reset differs by server, so the hour can be changed in settings.
local function defaultResetHour()
    local world = string.lower(GetWorldName() or "")
    return string.find(world, "eu", 1, true) and 3 or 10
end

function GP.ResetHour()
    return GP.sv.options.resetHour or defaultResetHour()
end

-- A day number that rolls over at the daily reset.
function GP.Today()
    return math.floor((GetTimeStamp() - GP.ResetHour() * 3600) / 86400)
end

function GP.RefreshLock()
    local wasUnlocked = GP.unlocked
    GP.unlocked = GP.Access.IsAllowed()
    if wasUnlocked ~= GP.unlocked and GP.Interface then GP.Interface.Refresh() end
    return GP.unlocked
end

function GP.Alert(text)
    pcall(ZO_Alert, UI_ALERT_CATEGORY_ALERT, nil, "Gold Digger: " .. text)
end

local firstActivation = false

local function onPlayerActivated()
    -- Runs at every loading screen, so an expired code locks without needing a relog
    GP.RefreshLock()
    if firstActivation then return end
    firstActivation = true
    if GP.unlocked then
        pcall(GP.Selling.Refresh)
        GP.Scanner.Prune()
        GP.Jobs.Start("sales", function(tick) GP.Scanner.ReadSales(tick) end)
    end
    GP.Interface.ShowLogin()
end

local function onLoaded(_, addonName)
    if addonName ~= GP.NAME then return end
    EVENT_MANAGER:UnregisterForEvent(GP.NAME, EVENT_ADD_ON_LOADED)
    GP.sv = ZO_SavedVars:NewAccountWide("ESOCGoldDigger_SV", 1, nil, DEFAULTS)
    -- Replaced in 0.4.1: traders now scan only when you ask
    GP.sv.options.autoScan, GP.sv.options.newestFirst = nil, nil
    GP.Events.ClearParked()
    local charId = GetCurrentCharacterId()
    GP.sv.characters[charId] = GP.sv.characters[charId] or { done = {} }
    GP.character = GP.sv.characters[charId]

    GP.Access.Install()
    GP.Scanner.Install()
    GP.Interface.Install()
    GP.Stockpile.InstallActions()
    EVENT_MANAGER:RegisterForEvent(GP.NAME, EVENT_PLAYER_ACTIVATED, onPlayerActivated)
end

EVENT_MANAGER:RegisterForEvent(GP.NAME, EVENT_ADD_ON_LOADED, onLoaded)
