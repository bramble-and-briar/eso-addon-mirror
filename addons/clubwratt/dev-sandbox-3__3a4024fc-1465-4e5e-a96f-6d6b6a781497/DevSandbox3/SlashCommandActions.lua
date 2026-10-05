local SlashCommandActions = {}

local LogUtils = DevSandbox3.LogUtils
local NodeUtils = DevSandbox3.NodeUtils

local function HandleList()
    local nodes = DevSandbox3.state.savedVars.nodes
    local now = GetTimeStamp()
    LogUtils.Log("%d saved war torte spawn(s)", #nodes)
    for index, node in ipairs(nodes) do
        LogUtils.Log("  %d. %s  (%.4f, %.4f)", index, NodeUtils.DescribeNode(node, now), node.gx, node.gy)
    end
end

local function HandleMark()
    local node, isNew = DevSandbox3.NodeActions.RecordAtPlayer("Manual mark", false)
    if node then
        LogUtils.Log("%s node marked at your position (%d total)", isNew and "New" or "Existing", #DevSandbox3.state.savedVars.nodes)
    else
        LogUtils.Log("Could not resolve your position (LibGPS not ready?)")
    end
end

local function HandleClear()
    DevSandbox3.NodeActions.ClearAll()
    LogUtils.Log("All saved spawns cleared")
end

local function HandleDebug()
    local savedVars = DevSandbox3.state.savedVars
    savedVars.debug = not savedVars.debug
    LogUtils.Log("Debug logging %s", savedVars.debug and "ON (reticle names will be logged)" or "OFF")
end

---@param remaining string
local function HandleMatch(remaining)
    local savedVars = DevSandbox3.state.savedVars
    local arg = string.lower(remaining or "")
    if arg == "" then
        LogUtils.Log("Built-in patterns: %s", table.concat(NodeUtils.MATCH_PATTERNS, ", "))
        LogUtils.Log("Extra test patterns: %s", #savedVars.extraPatterns > 0 and table.concat(savedVars.extraPatterns, ", ") or "(none)")
    elseif arg == "clear" then
        savedVars.extraPatterns = {}
        LogUtils.Log("Extra test patterns cleared")
    else
        table.insert(savedVars.extraPatterns, arg)
        local promoted = DevSandbox3.NodeActions.PromoteMatchingCandidates()
        LogUtils.Log("Added test pattern '%s' - nodes whose name contains it will now be recorded (%d candidate(s) promoted)", arg, promoted)
    end
end

---@param remaining string
local function HandleIgnore(remaining)
    local savedVars = DevSandbox3.state.savedVars
    local arg = string.lower(remaining or "")
    if arg == "" then
        local names = {}
        for name in pairs(savedVars.ignoredNames) do names[#names + 1] = name end
        table.sort(names)
        LogUtils.Log("Ignored node names: %s", #names > 0 and table.concat(names, ", ") or "(none)")
        LogUtils.Log("Unrecognized-node recording is %s (/ds3 unknown to toggle)", savedVars.recordUnknown and "ON" or "OFF")
    elseif arg == "clear" then
        savedVars.ignoredNames = {}
        LogUtils.Log("Ignored node names cleared")
    else
        savedVars.ignoredNames[arg] = true
        local removed = DevSandbox3.NodeActions.RemoveCandidatesNamed(arg)
        LogUtils.Log("'%s' is now treated as an ordinary material (%d candidate pin(s) removed)", arg, removed)
    end
end

local function HandleUnknown()
    local savedVars = DevSandbox3.state.savedVars
    savedVars.recordUnknown = not savedVars.recordUnknown
    LogUtils.Log("Recording of unrecognized harvest nodes %s", savedVars.recordUnknown and "ON" or "OFF")
end

local function HandleLooted()
    local looted = DevSandbox3.state.savedVars.lootedSlots
    LogUtils.Log("%d looted recipe(s) attributed to expected slots", #looted)
    local now = GetTimeStamp()
    for i, entry in ipairs(looted) do
        LogUtils.Log("  %d. %s slot %s, %s", i, entry.typeName, entry.index and (entry.dist .. "m away") or "(none nearby)", NodeUtils.FormatAge(now - entry.at))
    end
end

local function HandleHelp()
    LogUtils.Log("/ds3 list | mark | clear | refresh | debug | scan | match [<text>|clear] | ignore [<name>|clear] | unknown")
    LogUtils.Log("/ds3 slots (status) | empties (nearest missing slots) | clearempties | looted (which slot each recipe was on)")
    LogUtils.Log("/ds3 dismiss | alert (preview) | coverage | resetcoverage | probe  - or use the addon settings menu")
    LogUtils.Log("/ds3 quiet (turn every chat/alert option off) | clearall (spawns + empties + alert) | markers (3D/compass status)")
end

---@param args string Raw command arguments
function SlashCommandActions.HandleCommand(args)
    local command, remaining = DevSandbox3.SlashCommandUtils.ParseCommand(args)

    if command == "list" then
        HandleList()
    elseif command == "mark" then
        HandleMark()
    elseif command == "clear" then
        HandleClear()
    elseif command == "refresh" then
        DevSandbox3.PinActions.RefreshPins()
        LogUtils.Log("Pins refreshed")
    elseif command == "debug" then
        HandleDebug()
    elseif command == "scan" then
        DevSandbox3.CompassActions.Scan()
    elseif command == "match" then
        HandleMatch(remaining)
    elseif command == "ignore" then
        HandleIgnore(remaining)
    elseif command == "unknown" then
        HandleUnknown()
    elseif command == "probe" then
        local s = DevSandbox3.state.savedVars.settings
        s.probeAllTypes = not s.probeAllTypes
        LogUtils.Log("Probing all compass pin types %s", s.probeAllTypes and "ON (noisy, testing)" or "OFF")
    elseif command == "slots" then
        DevSandbox3.SlotActions.Status()
    elseif command == "empties" then
        DevSandbox3.SlotActions.ListEmpties()
    elseif command == "clearempties" then
        DevSandbox3.SlotActions.ClearEmpties()
    elseif command == "clearall" then
        DevSandbox3.SlotActions.ClearEmpties()
        HandleClear()
        DevSandbox3.AlertActions.Dismiss()
    elseif command == "quiet" then
        local s = DevSandbox3.state.savedVars.settings
        s.logEmptySlots, s.alertOnEmptySlots, s.probeAllTypes = false, false, false
        DevSandbox3.state.savedVars.debug, DevSandbox3.state.savedVars.recordUnknown = false, false
        LogUtils.Log("Quiet: chat lines, big alerts, probing, debug and candidate recording all OFF")
    elseif command == "markers" then
        LogUtils.Log(DevSandbox3.WorldMarkerActions.Status())
    elseif command == "looted" then
        HandleLooted()
    elseif command == "dismiss" then
        DevSandbox3.AlertActions.Dismiss()
    elseif command == "alert" then
        DevSandbox3.AlertActions.Test()
    elseif command == "coverage" then
        LogUtils.Log("Covered cells: %d (tracking %s, drawing %s)", DevSandbox3.CoverageActions.CountCoveredCells(), DevSandbox3.state.savedVars.settings.trackCoverage and "ON" or "OFF", DevSandbox3.state.savedVars.settings.showCoverage and "ON" or "OFF")
    elseif command == "resetcoverage" then
        DevSandbox3.CoverageActions.ResetCoverage()
    else
        HandleHelp()
    end
end

DevSandbox3.SlashCommandActions = SlashCommandActions
