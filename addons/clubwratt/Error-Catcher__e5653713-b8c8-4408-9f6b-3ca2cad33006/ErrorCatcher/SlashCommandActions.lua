-- SlashCommandActions.lua: /ec
local SlashCommandActions = {}

local Log = ErrorCatcher.LogUtils

local USAGE = "/ec status | scan (list every untrusted game function again) | export"

local function PrintStatus()
    local state = ErrorCatcher.state
    local counters = state.counters
    Log.Chat("v%s: trust check %s; this UI load: %d errors with a trace, %d dialogs, %d hooks by add-ons, %d untrusted buttons; scan %s",
        ErrorCatcher.version, state.trustApi and "on" or "unavailable",
        counters.errors, counters.dialogs, counters.hooks, counters.untrustedButtons,
        state.scan.done and "done" or (state.scan.running and "running" or "not run yet"))
end

---@param args string Raw command arguments
function SlashCommandActions.HandleCommand(args)
    local command = ErrorCatcher.SlashCommandUtils.ParseCommand(args)
    if command == "" or command == "status" then
        PrintStatus()
    elseif command == "scan" then
        Log.Chat(ErrorCatcher.ScanActions.Start(true) and "scan started; the result is in the log" or "a scan is already running")
    elseif command == "export" then
        Log.Export()
    else
        Log.Chat(USAGE)
    end
end

ErrorCatcher.SlashCommandActions = SlashCommandActions
