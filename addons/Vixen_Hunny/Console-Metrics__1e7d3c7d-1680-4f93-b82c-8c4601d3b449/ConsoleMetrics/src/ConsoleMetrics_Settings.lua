-- ConsoleMetrics_Settings.lua
-- Saved-variable schema (normalization and reset), option setters with side
-- effects, the console performance preset and the LibHarvensAddonSettings menu.

local CM = ConsoleMetrics
local Util = ConsoleMetrics.Util
local Clamp = Util.Clamp
local DeepCopy = Util.DeepCopy
local MAX_FIGHT_HISTORY_HARD_CAP = Util.MAX_FIGHT_HISTORY_HARD_CAP


---------------------------------------------------------------------------
-- Option schema
---------------------------------------------------------------------------
-- Every user option is described once here; Initialize() uses it to repair
-- corrupt or out-of-range saved values and /cm reset uses it to restore
-- defaults. User data (customSetRules, savedFights) is validated separately
-- and is never touched by a reset.
local OPTION_SCHEMA = {
    { key = "autoClearOnNextFight",        kind = "boolean" },
    { key = "maxFightHistory",             kind = "integer", min = 5,    max = MAX_FIGHT_HISTORY_HARD_CAP },
    { key = "performanceMode",             kind = "boolean" },
    { key = "lowMemoryMode",               kind = "boolean" },
    { key = "dialogAutoHide",              kind = "boolean" },
    { key = "dialogAutoHideSeconds",       kind = "integer", min = 3,    max = 120 },
    { key = "closeOnMove",                 kind = "boolean" },
    { key = "debugEnabled",                kind = "boolean" },
    { key = "drSampleAlpha",               kind = "number",  min = 0.05, max = 0.85 },
    { key = "ioTraceEnabled",              kind = "boolean" },
    { key = "ioTraceMode",                 kind = "custom",  normalize = function(self, value) return self:NormalizeIoTraceMode(value) end },
    { key = "ioTraceTargetMode",           kind = "enum",    values = { off = true, name = true, reticle = true } },
    { key = "ioTraceTargetName",           kind = "string" },
    { key = "ioTraceTargetOnlyProcessing", kind = "boolean" },
    { key = "ioTraceSkipResourceSampling", kind = "boolean" },
    { key = "ioTraceTargetGraceMs",        kind = "integer", min = 250,  max = 5000 },
    { key = "ioTraceMaxLinesPerSecond",    kind = "integer", min = 1,    max = 400 },
    { key = "ioTraceMinValue",             kind = "integer", min = 0 },
    { key = "ioTraceSummarySeconds",       kind = "integer", min = 1,    max = 10 },
    { key = "behaviorModelEnabled",        kind = "boolean" },
    { key = "behaviorModelRefreshMs",      kind = "integer", min = 250,  max = 5000 },
    { key = "saveFightDraftName",          kind = "string" },
    { key = "loadFightDraftName",          kind = "string" },
    { key = "maxSavedFights",              kind = "integer", min = 1,    max = 50 },
}

local function NormalizeOption(self, entry, value)
    local default = self.defaults[entry.key]
    local kind = entry.kind

    if kind == "boolean" then
        if value == nil then
            return default
        end
        return value == true
    end

    if kind == "integer" or kind == "number" then
        local number = tonumber(value)
        if number == nil then
            number = default
        end
        if kind == "integer" then
            number = math.floor(number + 0.5)
        end
        if entry.min and number < entry.min then
            number = entry.min
        end
        if entry.max and number > entry.max then
            number = entry.max
        end
        return number
    end

    if kind == "string" then
        if type(value) ~= "string" then
            return default
        end
        return value
    end

    if kind == "enum" then
        local lower = string.lower(tostring(value == nil and default or value))
        if entry.values[lower] then
            return lower
        end
        return default
    end

    if kind == "custom" then
        return entry.normalize(self, value == nil and default or value)
    end

    return value
end

function ConsoleMetrics:NormalizeSavedVariables()
    local saved = self.saved
    for i = 1, #OPTION_SCHEMA do
        local entry = OPTION_SCHEMA[i]
        saved[entry.key] = NormalizeOption(self, entry, saved[entry.key])
    end
    if type(saved.customSetRules) ~= "table" then
        saved.customSetRules = {}
    end
    if type(saved.savedFights) ~= "table" then
        saved.savedFights = {}
    end
end

-- Restores every option to its default. Custom set rules and saved fights are kept.
function ConsoleMetrics:ResetOptions()
    if not self.saved then
        return
    end
    for i = 1, #OPTION_SCHEMA do
        local key = OPTION_SCHEMA[i].key
        self.saved[key] = DeepCopy(self.defaults[key])
    end

    self.dialogPanel = "main"
    self.dialogAutoHideAtMs = nil
    self.lastDialogRefreshKey = nil
    self.ioTraceState = nil
    self.behaviorModelCache = nil
    self.observedAbilityLog = {}
    self.observedAbilityCount = 0
    self.fpsRuntime = { samples = 0, total = 0, min = nil, bins = {} }
    self:EnforceFightHistoryLimit()
end

---------------------------------------------------------------------------
-- Option setters with side effects (shared by menu, dialogs and slash commands)
---------------------------------------------------------------------------
function ConsoleMetrics:SetDialogAutoHide(enabled)
    if not self.saved then
        return
    end
    self.saved.dialogAutoHide = enabled == true
    if enabled then
        self:ArmDialogAutoHide()
    else
        self.dialogAutoHideAtMs = nil
    end
end

function ConsoleMetrics:SetLowMemoryMode(enabled)
    if not self.saved then
        return
    end
    self.saved.lowMemoryMode = enabled == true
    if enabled then
        self:ApplyLowMemoryModeToHistory()
    end
    self:EnforceFightHistoryLimit()
end

function ConsoleMetrics:SetPerformanceMode(enabled)
    if not self.saved then
        return
    end
    self.saved.performanceMode = enabled == true
    if enabled then
        self:ApplyConsolePerformancePreset()
    end
end

function ConsoleMetrics:SetBehaviorModelEnabled(enabled)
    if not self.saved then
        return
    end
    self.saved.behaviorModelEnabled = enabled == true
    self.behaviorModelCache = nil
end

function ConsoleMetrics:ClearCustomSetRules()
    if not self.saved then
        return
    end
    self.saved.customSetRules = {}
    self:InvalidateTrackedSetMatchCache()
    self:ResetLikelySetProcCache()
end

---------------------------------------------------------------------------
-- Console performance preset
---------------------------------------------------------------------------
function ConsoleMetrics:ApplyConsolePerformancePreset()
    if not self.saved then
        return
    end

    self.saved.lowMemoryMode = true
    self.saved.behaviorModelEnabled = false
    self.behaviorModelCache = nil
    self.saved.ioTraceEnabled = false
    self.saved.ioTraceMode = "summary"
    self.saved.ioTraceTargetOnlyProcessing = true
    self.saved.ioTraceSkipResourceSampling = true
    self.saved.ioTraceMaxLinesPerSecond = math.max(1, math.min(400, math.min(tonumber(self.saved.ioTraceMaxLinesPerSecond) or 40, 20)))
    self.saved.ioTraceSummarySeconds = math.max(1, math.min(10, tonumber(self.saved.ioTraceSummarySeconds) or 1))

    if self.fightHistory and #self.fightHistory > 0 then
        self:ApplyLowMemoryModeToHistory()
    end
    self:EnforceFightHistoryLimit()
end

---------------------------------------------------------------------------
-- Settings menu (LibHarvensAddonSettings)
---------------------------------------------------------------------------
function ConsoleMetrics:RegisterSettingsMenu()
    if not LibHarvensAddonSettings then
        return
    end

    local panel = LibHarvensAddonSettings:AddAddon("Console Metrics")

    -- General
    panel:AddSetting({
        type = LibHarvensAddonSettings.ST_SECTION,
        label = "General",
    })
    panel:AddSetting({
        type = LibHarvensAddonSettings.ST_CHECKBOX,
        label = "Auto Clear on Next Fight",
        tooltip = "Switch the fight dialog back to the live view when a new fight starts.",
        getFunction = function() return self.saved.autoClearOnNextFight end,
        setFunction = function(v) self.saved.autoClearOnNextFight = v end,
        default = self.defaults.autoClearOnNextFight,
    })
    panel:AddSetting({
        type = LibHarvensAddonSettings.ST_SLIDER,
        label = "Max Fight History",
        tooltip = "How many past fights to keep in memory for browsing (5–40).",
        min = 5,
        max = MAX_FIGHT_HISTORY_HARD_CAP,
        step = 1,
        format = "%d",
        getFunction = function() return tonumber(self.saved.maxFightHistory) or self.defaults.maxFightHistory end,
        setFunction = function(v)
            self.saved.maxFightHistory = Clamp(math.floor(v + 0.5), 5, MAX_FIGHT_HISTORY_HARD_CAP)
            self:EnforceFightHistoryLimit()
        end,
        default = self.defaults.maxFightHistory,
    })

    -- Dialog
    panel:AddSetting({
        type = LibHarvensAddonSettings.ST_SECTION,
        label = "Fight Dialog",
    })
    panel:AddSetting({
        type = LibHarvensAddonSettings.ST_CHECKBOX,
        label = "Dialog Auto Hide",
        tooltip = "Automatically close the fight view dialog after combat ends.",
        getFunction = function() return self.saved.dialogAutoHide end,
        setFunction = function(v) self:SetDialogAutoHide(v) end,
        default = self.defaults.dialogAutoHide,
    })
    panel:AddSetting({
        type = LibHarvensAddonSettings.ST_SLIDER,
        label = "Auto Hide Delay (seconds)",
        tooltip = "Seconds after combat to wait before auto-closing the dialog (3–120).",
        min = 3,
        max = 120,
        step = 1,
        format = "%d",
        getFunction = function() return tonumber(self.saved.dialogAutoHideSeconds) or self.defaults.dialogAutoHideSeconds end,
        setFunction = function(v)
            self.saved.dialogAutoHideSeconds = math.max(3, math.min(120, math.floor(v + 0.5)))
        end,
        default = self.defaults.dialogAutoHideSeconds,
        disable = function() return not self.saved.dialogAutoHide end,
    })

    -- Performance
    panel:AddSetting({
        type = LibHarvensAddonSettings.ST_SECTION,
        label = "Performance",
    })
    panel:AddSetting({
        type = LibHarvensAddonSettings.ST_CHECKBOX,
        label = "Performance Mode",
        tooltip = "Apply Series S / low-end console preset (enables low memory mode, disables ML model and trace).",
        getFunction = function() return self.saved.performanceMode end,
        setFunction = function(v) self:SetPerformanceMode(v) end,
        default = self.defaults.performanceMode,
    })
    panel:AddSetting({
        type = LibHarvensAddonSettings.ST_CHECKBOX,
        label = "Low Memory Mode",
        tooltip = "Compact fight snapshots to reduce memory usage. Disables some detailed breakdowns.",
        getFunction = function() return self.saved.lowMemoryMode end,
        setFunction = function(v) self:SetLowMemoryMode(v) end,
        default = self.defaults.lowMemoryMode,
    })

    -- ML Model
    panel:AddSetting({
        type = LibHarvensAddonSettings.ST_SECTION,
        label = "Behavior Model (ML)",
    })
    panel:AddSetting({
        type = LibHarvensAddonSettings.ST_CHECKBOX,
        label = "Enable Behavior Model",
        tooltip = "Run the ML-lite resistance and behavior prediction model during combat.",
        getFunction = function() return self.saved.behaviorModelEnabled end,
        setFunction = function(v) self:SetBehaviorModelEnabled(v) end,
        default = self.defaults.behaviorModelEnabled,
    })
    panel:AddSetting({
        type = LibHarvensAddonSettings.ST_SLIDER,
        label = "Model Refresh (ms)",
        tooltip = "How often the behavior model recalculates during combat (250–5000 ms).",
        min = 250,
        max = 5000,
        step = 250,
        format = "%d",
        getFunction = function() return tonumber(self.saved.behaviorModelRefreshMs) or self.defaults.behaviorModelRefreshMs end,
        setFunction = function(v)
            self.saved.behaviorModelRefreshMs = math.max(250, math.min(5000, math.floor(v / 250 + 0.5) * 250))
        end,
        default = self.defaults.behaviorModelRefreshMs,
        disable = function() return not self.saved.behaviorModelEnabled end,
    })

    -- Actions
    panel:AddSetting({
        type = LibHarvensAddonSettings.ST_SECTION,
        label = "Actions",
    })
    panel:AddSetting({
        type = LibHarvensAddonSettings.ST_BUTTON,
        label = "Apply Performance Preset",
        tooltip = "Apply the low-memory / high-performance preset (same as /cm perf on).",
        buttonText = "Apply",
        clickHandler = function()
            self.saved.performanceMode = true
            self:ApplyConsolePerformancePreset()
            self:Print("Performance preset applied.")
        end,
    })
    panel:AddSetting({
        type = LibHarvensAddonSettings.ST_BUTTON,
        label = "Clear All Fight Data",
        tooltip = "Wipe current fight and full fight history from memory.",
        buttonText = "Clear",
        clickHandler = function()
            self:ResetFightData(false)
            self:Print("Fight data cleared.")
        end,
    })

    -- Set rules
    panel:AddSetting({
        type = LibHarvensAddonSettings.ST_SECTION,
        label = "Custom Set Rules",
    })
    panel:AddSetting({
        type = LibHarvensAddonSettings.ST_BUTTON,
        label = "Import PvPCooldownTracker Rules",
        tooltip = "Scans PvPCooldownTracker tables and imports ability-based set rules. Use /cm addset to add rules by hand.",
        buttonText = "Import",
        clickHandler = function()
            local _, message = self:ImportSetsFromPvPCooldownTracker()
            self:Print(message)
        end,
    })
    panel:AddSetting({
        type = LibHarvensAddonSettings.ST_BUTTON,
        label = "Clear Custom Set Rules",
        tooltip = "Removes all custom set rules added through commands or import.",
        buttonText = "Clear",
        clickHandler = function()
            self:ClearCustomSetRules()
            self:Print("Cleared all custom set rules.")
        end,
    })
end
