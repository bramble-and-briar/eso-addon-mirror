-- Main.lua: entry point; places the hooks at file scope, then waits for the saved variables and the world
local State = ErrorCatcher.State
local Log = ErrorCatcher.LogUtils
local GameUtils = ErrorCatcher.GameUtils

-- The scan waits this long after the player is in the world. The first seconds there are when every add-on
-- does its work on arrival and the pool is at its highest (2026-11-24: 66 to 88 MB in six seconds); the scan
-- neither adds to that peak nor has its own cost mixed up with it.
local SCAN_DELAY_MS = 20000
-- The game's add-on list is read early: its lines say who is enabled, which a crash soon after should not lose.
local ADDON_LIST_DELAY_MS = 1500

-- File scope so "/ec" answers even if a later step fails.
SLASH_COMMANDS["/ec"] = function(args)
    ErrorCatcher.SlashCommandActions.HandleCommand(args)
end
SLASH_COMMANDS["/errorcatcher"] = SLASH_COMMANDS["/ec"]

---What the game says of a few known functions: a closure of this add-on has to read untrusted and the
---game's own trusted, or the trust lines of this log mean nothing.
---@param label string
local function LogTrustProbe(label)
    local function Trust(fn)
        return type(fn) == "function" and tostring(GameUtils.IsTrusted(fn)) or "missing"
    end
    Log.Line("trust %s: own closure=%s ZO_Dialogs_ShowDialog=%s ZO_KeybindStrip.AddKeybindButtonGroup=%s ZO_PreHook=%s",
        label, Trust(function() end), Trust(ZO_Dialogs_ShowDialog),
        Trust(type(ZO_KeybindStrip) == "table" and ZO_KeybindStrip.AddKeybindButtonGroup or nil), Trust(ZO_PreHook))
end

---Place every hook now, while the add-ons after this one have yet to load: a hook they place is then seen.
local function InstallAtFileScope()
    local state = State.Create()
    ErrorCatcher.state = state
    state.trustApi = GameUtils.DetectTrustApi()
    ErrorCatcher.MemoryActions.Begin()

    Log.Line("v%s loading: trust check %s, stack traces %s, SecurePostHook %s",
        ErrorCatcher.version, state.trustApi and "on" or "unavailable",
        GameUtils.HasTraceback() and "on" or "unavailable", type(SecurePostHook) == "function" and "on" or "missing")
    LogTrustProbe("before hooks")
    -- A followed function that reads untrusted already was wrapped by an add-on that loaded before this one.
    -- Its wrapper ends up inside this add-on's own hook, where no stack trace taken by that hook shows it.
    if GameUtils.IsTrusted(ZO_Dialogs_ShowDialog) == false then
        state.wrappedBeforeLoad.ZO_Dialogs_ShowDialog = true
    end

    local installed = {}
    for _, name in ipairs(ErrorCatcher.HookActions.Install()) do
        installed[#installed + 1] = name
    end
    for _, name in ipairs(ErrorCatcher.ButtonActions.Install()) do
        installed[#installed + 1] = name
    end
    for _, name in ipairs(ErrorCatcher.SessionActions.Install()) do
        installed[#installed + 1] = name
    end
    ErrorCatcher.ErrorActions.Register()
    Log.Line("watching: %s", #installed > 0 and table.concat(installed, ", ") or "nothing (no hook could be placed)")
    LogTrustProbe("after hooks")
end

local function OnAddOnLoaded()
    local state = ErrorCatcher.state
    state.savedVars = ZO_SavedVars:NewAccountWide(
        ErrorCatcher.savedVarsName,
        ErrorCatcher.savedVarsVersion,
        nil,
        state.savedVars
    )
    -- The lines so far are held until the library has loaded, which as a rule comes after this add-on.
    Log.TryFlush()
    -- Each in a guard of its own: one that fails leaves the others their turn.
    GameUtils.Guard("Session.Start", ErrorCatcher.SessionActions.Start)()
    GameUtils.Guard("Memory.Start", ErrorCatcher.MemoryActions.Start)()
    GameUtils.Guard("Session.Register", ErrorCatcher.SessionActions.Register)(ErrorCatcher.MemoryActions.Note)
    ErrorCatcher.LoadActions.StartWatch()
    -- In a step of its own: should the game refuse the call in a way pcall cannot catch, nothing else is lost.
    zo_callLater(GameUtils.Guard("Session.RequestSave", ErrorCatcher.SessionActions.RequestSave), 0)
end

local function OnPlayerActivated()
    -- Once per UI load: a zone change activates the player again.
    EVENT_MANAGER:UnregisterForEvent(ErrorCatcher.name, EVENT_PLAYER_ACTIVATED)
    -- Every add-on has loaded by now, the library too if it is there at all.
    EVENT_MANAGER:UnregisterForEvent(ErrorCatcher.name, EVENT_ADD_ON_LOADED)
    Log.Flush()
    -- The game's add-on list is read in a step of its own, ahead of the scan that words it.
    zo_callLater(GameUtils.Guard("Load.ReadEnabled", ErrorCatcher.LoadActions.ReadEnabled), ADDON_LIST_DELAY_MS)
    -- What the add-on manager says beyond the list (saved variables on disk, add-ons the game disabled), in a
    -- step after it for the same reason.
    zo_callLater(GameUtils.Guard("Load.WriteOrder", ErrorCatcher.LoadActions.WriteOrder), ADDON_LIST_DELAY_MS + 250)
    zo_callLater(GameUtils.Guard("Session.ReadAddOns", ErrorCatcher.SessionActions.ReadAddOns), ADDON_LIST_DELAY_MS + 500)
    zo_callLater(GameUtils.Guard("Scan.Start", function()
        ErrorCatcher.ScanActions.Start(false)
    end), SCAN_DELAY_MS)
end

InstallAtFileScope()

-- This add-on's own load event attaches its saved variables; every later one is an add-on loading after it.
local ownLoaded = false
local onOtherLoaded = GameUtils.Guard("Load.OnOtherLoaded", ErrorCatcher.LoadActions.OnOtherLoaded)
local onOtherLoadedMemory = GameUtils.Guard("Memory.OnOtherLoaded", ErrorCatcher.MemoryActions.OnOtherLoaded)
EVENT_MANAGER:RegisterForEvent(ErrorCatcher.name, EVENT_ADD_ON_LOADED, function(_eventId, addonName)
    if addonName == ErrorCatcher.name then
        ownLoaded = true
        OnAddOnLoaded()
    elseif ownLoaded then
        -- The memory first: the check below reads the game and would count to this add-on's figure.
        onOtherLoadedMemory(addonName)
        onOtherLoaded(addonName)
        -- The library's own handler of its load event runs after this one, so the held lines go out at the
        -- next load event, or a frame after the library's, whichever comes first.
        Log.TryFlush()
        if addonName == "LibConsoleLogger" then
            zo_callLater(Log.TryFlush, 0)
        end
    end
end)
EVENT_MANAGER:RegisterForEvent(ErrorCatcher.name, EVENT_PLAYER_ACTIVATED, OnPlayerActivated)
