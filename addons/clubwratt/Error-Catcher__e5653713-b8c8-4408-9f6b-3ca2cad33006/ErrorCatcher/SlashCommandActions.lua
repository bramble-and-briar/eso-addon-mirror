-- SlashCommandActions.lua: /ec
local SlashCommandActions = {}

local Log = ErrorCatcher.LogUtils

local USAGE = "/ec status | mem (memory now) | order (the load order) | scan (list every untrusted game function again) | save on|off (priority saves) | export"

local function PrintStatus()
    local state = ErrorCatcher.state
    local counters = state.counters
    Log.Chat("v%s: trust check %s; this UI load: %d errors with a trace, %d dialogs, %d hooks by add-ons, %d untrusted buttons; scan %s",
        ErrorCatcher.version, state.trustApi and "on" or "unavailable",
        counters.errors, counters.dialogs, counters.hooks, counters.untrustedButtons,
        state.scan.done and "done" or (state.scan.running and "running" or "not run yet"))
end

local function PrintMemory()
    Log.Chat("%s", ErrorCatcher.MemoryActions.Describe("/ec mem") or "the game gives no add-on pool figure here")
    Log.Chat("%s; priority saves %s", ErrorCatcher.SessionActions.SaveCounts(),
        ErrorCatcher.state.savedVars.prioritySave == false and "off" or "on")
end

---@param argument string "on" or "off"
local function SetPrioritySave(argument)
    if argument ~= "on" and argument ~= "off" then
        Log.Chat(USAGE)
        return
    end
    ErrorCatcher.SessionActions.SetPrioritySave(argument == "on")
    Log.Chat("priority saves %s", argument)
end

---@param args string Raw command arguments
function SlashCommandActions.HandleCommand(args)
    local command, argument = ErrorCatcher.SlashCommandUtils.ParseCommand(args)
    if command == "" or command == "status" then
        PrintStatus()
    elseif command == "mem" or command == "memory" then
        PrintMemory()
    elseif command == "order" then
        for _, line in ipairs(ErrorCatcher.LoadActions.DescribeOrder()) do
            Log.Chat("%s", line)
        end
    elseif command == "save" then
        SetPrioritySave(argument)
    elseif command == "scan" then
        Log.Chat(ErrorCatcher.ScanActions.Start(true) and "scan started; the result is in the log" or "a scan is already running")
    elseif command == "export" then
        Log.Export()
    else
        Log.Chat(USAGE)
    end
end

ErrorCatcher.SlashCommandActions = SlashCommandActions
