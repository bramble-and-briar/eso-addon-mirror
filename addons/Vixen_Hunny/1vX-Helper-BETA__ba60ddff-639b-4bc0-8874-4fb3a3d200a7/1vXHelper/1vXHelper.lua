-- 1vX Helper - core
OneVXHelper = OneVXHelper or {}
local addon = OneVXHelper

addon.name        = "1vXHelper"
addon.displayName = "|cFF33331vX|r Helper"
addon.version     = "1.0.0"
addon.unlocked    = false   -- runtime only: UI drag mode

addon.defaults = {
    burst = {
        enabled        = true,
        mode           = "absolute", -- "absolute" | "percent"
        absThreshold   = 15000,      -- damage taken inside the window
        pctThreshold   = 50,         -- % of max health taken inside the window
        window         = 1.0,        -- seconds (burst window)
        alertDuration  = 2.0,        -- seconds the flashing KITE text stays up
        graceDuration  = 2.0,        -- seconds after the alert where it can't retrigger
        extendOnRepeat = true,       -- re-hitting the threshold during the alert extends it
        countDots      = true,
        countBlocked   = true,
        countShielded  = true,
        pvpOnly        = false,      -- only run in Cyrodiil / Imperial City / Battlegrounds
        alertText      = "KITE NOW!",
        alertSize      = 54,
        showGraceText  = true,
        showMeter      = true,
        playSound      = true,
        sound          = "DUEL_START",
        updateRate     = 100,        -- ms between burst timer ticks while active
    },
    pins = {
        enabled = true,
        kite    = true,
        safe    = true,
        choke   = true,
        size    = 28,
        colors  = {             -- per pin type, used on the map, blips, compass, tracker, gamepad
            kite  = { r = 0.2, g = 1,    b = 0.3, a = 1 },
            safe  = { r = 0.3, g = 0.72, b = 1,   a = 1 },
            choke = { r = 1,   g = 0.55, b = 0.1, a = 1 },
        },
        data    = {},  -- [mapId] = { {type, x, y, zoneId, wx, wy, wz, note, t}, ... }
    },
    tracker = {
        enabled        = true,
        kite           = true,
        safe           = true,
        choke          = true,
        maxRange       = 400,  -- meters
        chokeWarn      = true,
        chokeWarnRange = 30,   -- meters
        flipDirection  = false,
        updateRate     = 250,   -- ms between tracker updates
        skipWhenStill  = true,  -- skip updates while you're not moving or turning
    },
    blips = {                 -- 3D markers floating over pins in the world
        enabled      = true,
        kite         = true,   -- these three also filter the compass pins
        safe         = true,
        choke        = true,
        maxRange     = 300,    -- meters
        size         = 1.0,    -- meters (at <= 25m)
        keepReadable = true,   -- grow with distance so far blips stay visible
        throughWalls = true,
        updateRate   = 0,      -- ms, 0 = every frame
    },
    compass = {
        enabled  = true,
        maxRange = 500,        -- meters
        fov      = 108,        -- degrees the compass bar covers (calibrate in settings)
        size     = 22,
    },
    lowHealth = {
        enabled   = false,
        threshold = 35,
    },
    combatTimer = {
        enabled = false,
    },
    gamepad = {
        menuEntry = true,  -- "1vX Map Pins" entry above Inventory in the gamepad main menu
    },
    ui = {
        positions = {},
    },
}

function addon.Print(msg)
    local text = "|cFF33331vX|r: " .. tostring(msg)
    if CHAT_ROUTER and CHAT_ROUTER.AddSystemMessage then
        CHAT_ROUTER:AddSystemMessage(text)
    else
        d(text)
    end
end

function addon.Now()
    return GetGameTimeMilliseconds()
end

function addon.InPvPZone()
    if IsPlayerInAvAWorld and IsPlayerInAvAWorld() then return true end
    if IsActiveWorldBattleground and IsActiveWorldBattleground() then return true end
    return false
end

-- Keybinding labels (must exist before Bindings.xml is parsed)
ZO_CreateStringId("SI_BINDING_NAME_ONEVX_ADD_KITE",       "Add Kite Spot Here")
ZO_CreateStringId("SI_BINDING_NAME_ONEVX_ADD_SAFE",       "Add Safe Place Here")
ZO_CreateStringId("SI_BINDING_NAME_ONEVX_ADD_CHOKE",      "Add Choke Point Here")
ZO_CreateStringId("SI_BINDING_NAME_ONEVX_REMOVE_NEAREST", "Remove Nearest Pin")
ZO_CreateStringId("SI_BINDING_NAME_ONEVX_TEST_BURST",     "Test Burst Alert")
ZO_CreateStringId("SI_BINDING_NAME_ONEVX_GAMEPAD_PINS",   "Open 1vX Gamepad Pin Screen")

function addon.SetUnlocked(v)
    addon.unlocked = v and true or false
    addon.UI.ApplyLockAll()
end

local function SlashCommand(args)
    args = zo_strtrim(args or "")
    local cmd, rest = args:match("^(%S*)%s*(.-)$")
    cmd = (cmd or ""):lower()
    if cmd == "kite" or cmd == "safe" or cmd == "choke" then
        addon.Pins.AddAtPlayer(cmd, rest)
    elseif cmd == "remove" then
        addon.Pins.RemoveNearest()
    elseif cmd == "list" then
        addon.Pins.ListCurrentMap()
    elseif cmd == "test" then
        addon.Burst.Test()
    elseif cmd == "unlock" then
        addon.SetUnlocked(true);  addon.Print("UI unlocked - drag elements, then /1vx lock")
    elseif cmd == "lock" then
        addon.SetUnlocked(false); addon.Print("UI locked")
    elseif cmd == "pad" or cmd == "gamepad" then
        addon.Gamepad.Show()
    elseif cmd == "refresh" or cmd == "fix" then
        addon.RefreshUI(); addon.Print("UI refreshed")
    elseif cmd == "settings" then
        addon.OpenSettings()
    else
        addon.Print("Commands: /1vx [kite|safe|choke <note>|remove|list|test|pad|refresh|unlock|lock|settings]")
    end
end

-- Startup errors are collected and printed once chat is available (after login),
-- so testers can copy the exact message.
local startupErrors = {}

local function SafeCall(moduleName, fnName)
    local mod = addon[moduleName]
    local fn = mod and mod[fnName]
    if not fn then
        startupErrors[#startupErrors + 1] = string.format("%s.%s missing (its file failed to load)", moduleName, fnName)
        return false
    end
    local ok, err = pcall(fn)
    if not ok then
        startupErrors[#startupErrors + 1] = string.format("%s.%s: %s", moduleName, fnName, tostring(err))
    end
    return ok
end

local function ReportStartupErrors()
    if #startupErrors == 0 then return end
    addon.Print("|cFF4040Some parts failed to start - please send this to the author:|r")
    for _, e in ipairs(startupErrors) do addon.Print(e) end
    startupErrors = {}
end

local function OnLoaded(_, name)
    if name ~= addon.name then return end
    EVENT_MANAGER:UnregisterForEvent(addon.name, EVENT_ADD_ON_LOADED)

    addon.sv = ZO_SavedVars:NewAccountWide("OneVXHelper_SV", 1, nil, addon.defaults)
    SLASH_COMMANDS["/1vx"] = SlashCommand

    -- Settings panel first, then every module on its own, so one failing
    -- module can never stop the settings page (or the others) from loading.
    SafeCall("Settings", "Init")
    SafeCall("Burst",    "Init")
    SafeCall("Pins",     "Init")
    SafeCall("Tracker",  "Init")
    SafeCall("Blips",    "Init")
    SafeCall("Extras",   "Init")
    SafeCall("Gamepad",  "Init")

    -- After every loading screen (login, zoning, porting to Cyrodiil, /reloadui)
    -- re-apply every module so nothing stays hidden or stuck.
    EVENT_MANAGER:RegisterForEvent(addon.name .. "_Activated", EVENT_PLAYER_ACTIVATED, function()
        addon.RefreshUI()
        ReportStartupErrors()
    end)
end

function addon.RefreshUI()
    SafeCall("Burst",   "Apply")
    SafeCall("Tracker", "Apply")
    SafeCall("Blips",   "Apply")
    SafeCall("Extras",  "Apply")
    SafeCall("UI",      "Refresh")
end

EVENT_MANAGER:RegisterForEvent(addon.name, EVENT_ADD_ON_LOADED, OnLoaded)
