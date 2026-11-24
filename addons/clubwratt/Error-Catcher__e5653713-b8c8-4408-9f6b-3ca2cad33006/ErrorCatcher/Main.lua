-- Main.lua: entry point; places the hooks at file scope, then waits for the saved variables and the world
local State = ErrorCatcher.State
local Log = ErrorCatcher.LogUtils
local GameUtils = ErrorCatcher.GameUtils

-- The scan waits this long after the player is in the world, so its one heavy frame is not the first one.
local SCAN_DELAY_MS = 3000

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

    Log.Line("v%s loading: trust check %s, stack traces %s, SecurePostHook %s",
        ErrorCatcher.version, state.trustApi and "on" or "unavailable",
        GameUtils.HasTraceback() and "on" or "unavailable", type(SecurePostHook) == "function" and "on" or "missing")
    LogTrustProbe("before hooks")

    local installed = {}
    for _, name in ipairs(ErrorCatcher.HookActions.Install()) do
        installed[#installed + 1] = name
    end
    for _, name in ipairs(ErrorCatcher.ButtonActions.Install()) do
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
    Log.Flush()
end

local function OnPlayerActivated()
    -- Once per UI load: a zone change activates the player again.
    EVENT_MANAGER:UnregisterForEvent(ErrorCatcher.name, EVENT_PLAYER_ACTIVATED)
    zo_callLater(GameUtils.Guard("Scan.Start", function()
        ErrorCatcher.ScanActions.Start(false)
    end), SCAN_DELAY_MS)
end

InstallAtFileScope()

EVENT_MANAGER:RegisterForEvent(ErrorCatcher.name, EVENT_ADD_ON_LOADED, function(_eventId, addonName)
    if addonName == ErrorCatcher.name then
        EVENT_MANAGER:UnregisterForEvent(ErrorCatcher.name, EVENT_ADD_ON_LOADED)
        OnAddOnLoaded()
    end
end)
EVENT_MANAGER:RegisterForEvent(ErrorCatcher.name, EVENT_PLAYER_ACTIVATED, OnPlayerActivated)
