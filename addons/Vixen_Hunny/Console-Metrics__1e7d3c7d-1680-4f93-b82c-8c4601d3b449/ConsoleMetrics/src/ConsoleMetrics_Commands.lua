-- ConsoleMetrics_Commands.lua
-- /cm and /consolemetrics slash commands. Commands are looked up in a table by
-- their first word; the remainder of the line is passed to the handler with
-- original casing (for names) and lower-cased (for keywords).

local CM = ConsoleMetrics
local Util = ConsoleMetrics.Util
local Clamp = Util.Clamp
local NumberText = Util.NumberText
local TrimText = Util.TrimText
local UnitName = Util.UnitName


local HELP_LINES = {
    "Commands:",
    "/cm view - Open the Console Metrics dialog.",
    "/cm close - Close the dialog immediately.",
    "/cm prev - View the previous fight in history.",
    "/cm next - View the next fight in history.",
    "/cm clear - Clear live fight data and all history.",
    "/cm savefight [name] - Save the currently viewed fight to a persistent slot.",
    "/cm loadfight <name> - Load one saved fight by name into history.",
    "/cm loadfightexact <name> - Load one saved fight by exact name only.",
    "/cm loadsaves - Load all saved fight slots into session fight history.",
    "/cm share [fight|build|skills|sustain|all] - Pre-fill chat with stats or your build.",
    "/cm linkbuild - Pre-fill chat with a compact build summary to share.",
    "/cm autoclear on|off - Jump back to the live view when a new fight starts.",
    "/cm autohide on|off - Toggle dialog auto close after combat.",
    "/cm perf on|off|status - Toggle the console performance preset.",
    "/cm debug on|off - Toggle diagnostic chat output (fight start/end lines).",
    "/cm debugbuild - Print build snapshot debug details.",
    "/cm dumpcpslottables - Dump confirmed Champion slottable skill IDs.",
    "/cm dumpsets - Dump all game item sets (API) and session-observed ability IDs.",
    "/cm trace on|off - Enable or disable live event/resource trace output.",
    "/cm trace mode summary|all|in|out - Choose trace scope.",
    "/cm trace target off|reticle|<name> - Restrict trace to one target.",
    "/cm trace focus on|off - Skip non-target combat processing during trace.",
    "/cm trace samples on|off - Toggle non-target sample skipping in focus mode.",
    "/cm trace min <value> - Ignore per-event trace lines below this value.",
    "/cm trace cap <lines/sec> - Limit trace print spam per second.",
    "/cm trace summary <seconds> - Set the trace summary period.",
    "/cm trace status - Print current trace mode and limits.",
    "WARNING: Trace logging is expensive on console. Keep it short and disable with /cm trace off after debugging.",
    "/cm importpct - Import custom set rules from PvPCooldownTracker.",
    "/cm addset <label>|<scene>|<abilityId>|<abilityName> - Add a custom set matcher.",
    "/cm clearsets - Remove all custom set rules.",
    "/cm inject - Retry Journal menu/keybind integration.",
    "/cm reset - Reset addon options to defaults (keeps saved fights and set rules).",
}

function ConsoleMetrics:PrintHelp()
    for i = 1, #HELP_LINES do
        self:Print(HELP_LINES[i])
    end
end

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------
local function WarnIfTracing(self)
    if self.saved.ioTraceEnabled then
        self:Print("WARNING: Live trace output is heavy and can degrade console performance/stability. Use only for short debugging windows.")
    end
end

-- Returns true/false for on/off style words, nil when unrecognized.
local function ParseOnOff(text)
    if text == "on" or text == "true" or text == "1" or text == "enable" or text == "enabled" then
        return true
    end
    if text == "off" or text == "false" or text == "0" or text == "disable" or text == "disabled" then
        return false
    end
    return nil
end

local function OpenAfterLoad(self, ok, message)
    self:Print(message)
    if ok then
        self.dialogPanel = "main"
        self:OpenFightViewDialog(false)
    end
end

local function StepCommand(self, step)
    if self:StepFightView(step) then
        self:OpenFightViewDialog(false)
    else
        self:Print("No fight history available yet.")
    end
end

local function ParseIntegerArg(self, text, usage)
    local value = tonumber(text)
    if not value then
        self:Print(usage)
        return nil
    end
    return math.floor(value + 0.5)
end

---------------------------------------------------------------------------
-- Trace subcommands
---------------------------------------------------------------------------
local function TraceStatus(self)
    local saved = self.saved
    local targetMode = tostring(saved.ioTraceTargetMode or "off")
    local targetText = "off"
    if targetMode == "reticle" then
        local rawName = type(GetUnitName) == "function" and GetUnitName("reticleover") or ""
        local reticleName = (rawName and rawName ~= "") and UnitName(rawName) or ""
        targetText = reticleName ~= "" and ("reticle:" .. reticleName) or "reticle:(none)"
    elseif targetMode == "name" then
        local name = tostring(saved.ioTraceTargetName or "")
        targetText = name ~= "" and ("name:" .. name) or "name:(empty)"
    end

    local state = self.ioTraceState
    self:Print(string.format(
        "Trace status: enabled=%s mode=%s target=%s focus=%s sampleSkip=%s min=%d cap=%d/s summary=%ds hit[min=%s max=%s n=%d]",
        tostring(saved.ioTraceEnabled == true),
        tostring(saved.ioTraceMode),
        targetText,
        tostring(saved.ioTraceTargetOnlyProcessing == true),
        tostring(saved.ioTraceSkipResourceSampling == true),
        tonumber(saved.ioTraceMinValue) or 0,
        tonumber(saved.ioTraceMaxLinesPerSecond) or 40,
        tonumber(saved.ioTraceSummarySeconds) or 1,
        NumberText(state and state.minHitValue or 0),
        NumberText(state and state.maxHitValue or 0),
        state and state.hitValueSamples or 0
    ))
    WarnIfTracing(self)
end

-- handler(self, arg, argLower); arg keeps original casing.
local TRACE_COMMANDS = {}

TRACE_COMMANDS.status = function(self)
    TraceStatus(self)
end

TRACE_COMMANDS.target = function(self, arg, argLower)
    if argLower == "" then
        self:Print("Usage: /cm trace target off|reticle|<name>")
        return
    end
    if argLower == "off" or argLower == "none" or argLower == "clear" then
        self.saved.ioTraceTargetMode = "off"
        self.saved.ioTraceTargetName = ""
        self:Print("Trace target filter disabled.")
        return
    end
    if argLower == "reticle" or argLower == "current" then
        self.saved.ioTraceTargetMode = "reticle"
        self.saved.ioTraceTargetName = ""
        self:Print("Trace target filter set to reticle target.")
    else
        self.saved.ioTraceTargetMode = "name"
        self.saved.ioTraceTargetName = arg
        self:Print(string.format("Trace target filter set to '%s'.", arg))
    end
    WarnIfTracing(self)
end

TRACE_COMMANDS.mode = function(self, _, argLower)
    self.saved.ioTraceMode = self:NormalizeIoTraceMode(argLower)
    self:Print(string.format("Trace mode set to '%s'.", self.saved.ioTraceMode))
    WarnIfTracing(self)
end

TRACE_COMMANDS.min = function(self, arg)
    local value = ParseIntegerArg(self, arg, "Trace min expects a number. Example: /cm trace min 500")
    if value then
        self.saved.ioTraceMinValue = math.max(0, value)
        self:Print(string.format("Trace minimum value set to %d.", self.saved.ioTraceMinValue))
    end
end

TRACE_COMMANDS.cap = function(self, arg)
    local value = ParseIntegerArg(self, arg, "Trace cap expects a number. Example: /cm trace cap 60")
    if value then
        self.saved.ioTraceMaxLinesPerSecond = Clamp(value, 1, 400)
        self:Print(string.format("Trace line cap set to %d lines/sec.", self.saved.ioTraceMaxLinesPerSecond))
    end
end

TRACE_COMMANDS.summary = function(self, arg)
    local value = ParseIntegerArg(self, arg, "Trace summary expects a number. Example: /cm trace summary 1")
    if value then
        self.saved.ioTraceSummarySeconds = Clamp(value, 1, 10)
        self:Print(string.format("Trace summary period set to %d second(s).", self.saved.ioTraceSummarySeconds))
    end
end

TRACE_COMMANDS.focus = function(self, _, argLower)
    local flag = ParseOnOff(argLower)
    if flag == nil then
        self:Print("Usage: /cm trace focus on|off")
        return
    end
    self.saved.ioTraceTargetOnlyProcessing = flag
    if flag then
        self:Print("Trace focus processing enabled (non-target combat events are skipped).")
        WarnIfTracing(self)
    else
        self:Print("Trace focus processing disabled.")
    end
end

TRACE_COMMANDS.samples = function(self, _, argLower)
    local flag = ParseOnOff(argLower)
    if flag == nil then
        self:Print("Usage: /cm trace samples on|off")
        return
    end
    -- "samples off" means: skip resource samples outside the focus window.
    self.saved.ioTraceSkipResourceSampling = not flag
    if flag then
        self:Print("Trace focus sampling reduction disabled.")
    else
        self:Print("Trace focus sampling reduction enabled (non-target windows skip samples).")
        WarnIfTracing(self)
    end
end

local function TraceCommand(self, rest, restLower)
    if restLower == "" then
        TraceStatus(self)
        return
    end

    local sub, arg = string.match(rest, "^(%S+)%s*(.*)$")
    local subLower = string.lower(sub)
    local handler = TRACE_COMMANDS[subLower]
    if handler then
        arg = TrimText(arg)
        handler(self, arg, string.lower(arg))
        return
    end

    local flag = ParseOnOff(subLower)
    if flag == true then
        self.saved.ioTraceEnabled = true
        self:ResetIoTraceState(GetFrameTimeMilliseconds())
        self:Print("Live trace enabled. Use '/cm trace mode all' for full event lines.")
        WarnIfTracing(self)
    elseif flag == false then
        self.saved.ioTraceEnabled = false
        self:Print("Live trace disabled.")
    else
        self:Print("Unknown trace command. Use /cm help for the trace options.")
    end
end

---------------------------------------------------------------------------
-- Other commands with arguments
---------------------------------------------------------------------------
local function ShareCommand(self, _, restLower)
    if restLower == "" or restLower == "fight" then
        self:ShareFightToChat()
    elseif restLower == "build" then
        self:ShareBuildToChat()
    elseif restLower == "skills" then
        self:ShareTopSkillsToChat()
    elseif restLower == "sustain" or restLower == "resources" then
        self:ShareResourceToChat()
    elseif restLower == "all" or restLower == "snapshot" then
        self:ShareFullSnapshotToChat()
    else
        self:Print("Usage: /cm share [fight|build|skills|sustain|all]")
    end
end

local function ToggleOptionCommand(key, onMessage, offMessage, usage, applyFn)
    return function(self, _, restLower)
        local flag = ParseOnOff(restLower)
        if flag == nil then
            self:Print(usage)
            return
        end
        if applyFn then
            applyFn(self, flag)
        else
            self.saved[key] = flag
        end
        self:Print(flag and onMessage or offMessage)
    end
end

local function PerfCommand(self, _, restLower)
    local flag = ParseOnOff(restLower)
    if flag == true then
        self:SetPerformanceMode(true)
        self:Print("Performance Mode enabled (console preset applied).")
    elseif flag == false then
        self:SetPerformanceMode(false)
        self:Print("Performance Mode disabled.")
    else
        self:Print(string.format(
            "Performance Mode: %s | lowMemory=%s | behaviorModel=%s | trace=%s",
            tostring(self.saved.performanceMode == true),
            tostring(self.saved.lowMemoryMode == true),
            tostring(self.saved.behaviorModelEnabled == true),
            tostring(self.saved.ioTraceEnabled == true)
        ))
    end
end

local function SaveFightCommand(self, rest)
    if rest ~= "" then
        self.saved.saveFightDraftName = rest
    end
    local _, message = self:SaveViewedFight()
    self:Print(message)
end

local function LoadFightCommand(exact)
    return function(self, rest)
        if rest ~= "" then
            self.saved.loadFightDraftName = rest
        end
        local name = self.saved.loadFightDraftName or ""
        local ok, message
        if exact then
            ok, message = self:LoadSavedFightIntoHistoryByExactName(name)
        else
            ok, message = self:LoadSavedFightIntoHistoryByName(name)
        end
        OpenAfterLoad(self, ok, message)
    end
end

local function LoadSavesCommand(self)
    local loaded = self:RestoreSavedFightsIntoHistory()
    if loaded > 0 then
        self:Print(string.format("Loaded %d saved fight(s) into history (showing latest %d max). Use /cm view to browse.", loaded, self.saved.maxFightHistory or self.defaults.maxFightHistory))
        self.dialogPanel = "main"
        self:OpenFightViewDialog(false)
    else
        self:Print("No saved fights to load.")
    end
end

local function AddSetCommand(self, rest)
    if rest == "" then
        self:Print("Usage: /cm addset <label>|<scene>|<abilityId>|<abilityName>")
        return
    end
    local label, scene, abilityIdText, abilityName = string.match(rest, "([^|]*)|?([^|]*)|?([^|]*)|?(.*)")
    local _, message = self:AddCustomSetRule(label, scene, tonumber(TrimText(abilityIdText)), abilityName)
    self:Print(message)
end

---------------------------------------------------------------------------
-- Command table
---------------------------------------------------------------------------
local COMMANDS = {}

local function Register(handler, ...)
    for i = 1, select("#", ...) do
        COMMANDS[select(i, ...)] = handler
    end
end

Register(function(self) self:PrintHelp() end, "", "help", "options")
Register(function(self) self:RefreshJournalIntegration(true) end, "inject", "journal")
Register(function(self)
    self.dialogPanel = "main"
    self:OpenFightViewDialog()
end, "view", "menu")
Register(function(self) self:CloseFightViewDialog(false, "slash") end, "close")
Register(function(self) StepCommand(self, 1) end, "next")
Register(function(self) StepCommand(self, -1) end, "prev")
Register(function(self)
    self:ResetFightData(false)
    self:Print("Fight history and live fight data cleared")
end, "clear")

Register(ToggleOptionCommand("autoClearOnNextFight",
    "Auto clear on next fight enabled (dialog returns to the live view when a fight starts)",
    "Auto clear on next fight disabled",
    "Usage: /cm autoclear on|off"), "autoclear")
Register(ToggleOptionCommand("dialogAutoHide",
    "Dialog auto hide enabled", "Dialog auto hide disabled", "Usage: /cm autohide on|off",
    function(self, flag) self:SetDialogAutoHide(flag) end), "autohide")
Register(ToggleOptionCommand("debugEnabled",
    "Debug output enabled", "Debug output disabled", "Usage: /cm debug on|off"), "debug")
Register(PerfCommand, "perf")

Register(function(self) self:DumpGameSets() end, "dumpsets", "logsets")
Register(function(self) self:PrintBuildSnapshotDebug("slash") end, "debugbuild", "builddebug")
Register(function(self) self:DumpChampionSlottables() end, "dumpcpslottables", "dumpcpstars", "logcpslottables")
Register(TraceCommand, "trace")

Register(ShareCommand, "share")
Register(function(self) self:ShareBuildToChat() end, "linkbuild", "buildlink", "chatbuild")
Register(function(self) self:ShareFightToChat() end, "sharefight")
Register(function(self) self:ShareTopSkillsToChat() end, "shareskills", "sharesklls", "topskills")
Register(function(self) self:ShareResourceToChat() end, "sharesustain", "shareresources")
Register(function(self) self:ShareFullSnapshotToChat() end, "shareall", "snapshot")

Register(function(self)
    local _, message = self:ImportSetsFromPvPCooldownTracker()
    self:Print(message)
end, "importpct", "syncpct")
Register(AddSetCommand, "addset")
Register(function(self)
    self:ClearCustomSetRules()
    self:Print("Cleared all custom set rules.")
end, "clearsets")

Register(SaveFightCommand, "savefight")
Register(LoadFightCommand(false), "loadfight")
Register(LoadFightCommand(true), "loadfightexact", "loadfightstrict")
Register(LoadSavesCommand, "loadsaves")

Register(function(self)
    self:Print("The on-screen HUD panel is not available. Use /cm view for the dialog.")
end, "toggle", "lock", "unlock")
Register(function(self)
    self:ResetOptions()
    self:Print("Options reset to defaults (custom set rules and saved fights were kept).")
end, "reset")

function ConsoleMetrics:HandleSlash(rawInput)
    local text = TrimText(rawInput)
    local command, rest = string.match(text, "^(%S+)%s*(.*)$")
    command = string.lower(command or "")
    rest = TrimText(rest or "")

    local handler = COMMANDS[command]
    if not handler then
        self:Print("Unknown command. Use /cm help")
        return
    end
    handler(self, rest, string.lower(rest))
end
