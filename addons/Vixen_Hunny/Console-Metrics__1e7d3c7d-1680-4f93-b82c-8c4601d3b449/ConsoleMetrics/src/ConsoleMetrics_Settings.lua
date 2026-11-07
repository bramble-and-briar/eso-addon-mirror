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
    { key = "libFightsAutoStart",          kind = "boolean" },
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
    local changed = (self.saved.performanceMode == true) ~= (enabled == true)
    self.saved.performanceMode = enabled == true
    if enabled then
        self:ApplyConsolePerformancePreset()
    end
    if changed then
        -- LibFights reads its options at Start_Logging(), so restart it to apply the preset.
        self:RestartLibFightsLogging()
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
-- Settings menu (LibAddonMenu-2.0 / LibHarvensAddonSettings)
---------------------------------------------------------------------------
-- The menu is described once as a list of controls and then rendered with
-- whichever settings library is available:
--   PC:      LibAddonMenu-2.0 when installed, otherwise LibHarvensAddonSettings
--   Console: LibHarvensAddonSettings (LibAddonMenu-2.0 is keyboard-only)
-- Only one library is used, so the addon never appears twice in the menu.
--
-- Control fields: kind ("section"|"checkbox"|"slider"|"button"), label,
-- tooltip, get, set, default, disabled (function), min, max, step,
-- buttonText, onClick.
local SETTINGS_PANEL_NAME = "Console Metrics"
local LAM_PANEL_ID = "ConsoleMetricsSettingsPanel"

local function BuildSettingsControls(self)
    local controls = {}
    local function Add(control)
        controls[#controls + 1] = control
    end

    -- General
    Add({ kind = "section", label = "General" })
    Add({
        kind = "checkbox",
        label = "Auto Clear on Next Fight",
        tooltip = "Switch the fight dialog back to the live view when a new fight starts.",
        get = function() return self.saved.autoClearOnNextFight end,
        set = function(v) self.saved.autoClearOnNextFight = v end,
        default = self.defaults.autoClearOnNextFight,
    })
    Add({
        kind = "slider",
        label = "Max Fight History",
        tooltip = "How many past fights to keep in memory for browsing (5–40).",
        min = 5,
        max = MAX_FIGHT_HISTORY_HARD_CAP,
        step = 1,
        get = function() return tonumber(self.saved.maxFightHistory) or self.defaults.maxFightHistory end,
        set = function(v)
            self.saved.maxFightHistory = Clamp(math.floor(v + 0.5), 5, MAX_FIGHT_HISTORY_HARD_CAP)
            self:EnforceFightHistoryLimit()
        end,
        default = self.defaults.maxFightHistory,
    })

    -- Dialog
    Add({ kind = "section", label = "Fight Dialog" })
    Add({
        kind = "checkbox",
        label = "Dialog Auto Hide",
        tooltip = "Automatically close the fight view dialog after combat ends.",
        get = function() return self.saved.dialogAutoHide end,
        set = function(v) self:SetDialogAutoHide(v) end,
        default = self.defaults.dialogAutoHide,
    })
    Add({
        kind = "slider",
        label = "Auto Hide Delay (seconds)",
        tooltip = "Seconds after combat to wait before auto-closing the dialog (3–120).",
        min = 3,
        max = 120,
        step = 1,
        get = function() return tonumber(self.saved.dialogAutoHideSeconds) or self.defaults.dialogAutoHideSeconds end,
        set = function(v)
            self.saved.dialogAutoHideSeconds = math.max(3, math.min(120, math.floor(v + 0.5)))
        end,
        default = self.defaults.dialogAutoHideSeconds,
        disabled = function() return not self.saved.dialogAutoHide end,
    })
    Add({
        kind = "button",
        label = "Open Fight Viewer",
        tooltip = "Open the Console Metrics fight viewer (same as /cm view).",
        buttonText = "Open",
        onClick = function()
            self.dialogPanel = "main"
            self:OpenFightViewDialog()
        end,
    })

    -- Performance
    Add({ kind = "section", label = "Performance" })
    Add({
        kind = "checkbox",
        label = "Performance Mode",
        tooltip = "Apply Series S / low-end console preset (enables low memory mode, disables ML model and trace).",
        get = function() return self.saved.performanceMode end,
        set = function(v) self:SetPerformanceMode(v) end,
        default = self.defaults.performanceMode,
    })
    Add({
        kind = "checkbox",
        label = "Low Memory Mode",
        tooltip = "Compact fight snapshots to reduce memory usage. Disables some detailed breakdowns.",
        get = function() return self.saved.lowMemoryMode end,
        set = function(v) self:SetLowMemoryMode(v) end,
        default = self.defaults.lowMemoryMode,
    })

    -- ML Model
    Add({ kind = "section", label = "Behavior Model (ML)" })
    Add({
        kind = "checkbox",
        label = "Enable Behavior Model",
        tooltip = "Run the ML-lite resistance and behavior prediction model during combat.",
        get = function() return self.saved.behaviorModelEnabled end,
        set = function(v) self:SetBehaviorModelEnabled(v) end,
        default = self.defaults.behaviorModelEnabled,
    })
    Add({
        kind = "slider",
        label = "Model Refresh (ms)",
        tooltip = "How often the behavior model recalculates during combat (250–5000 ms).",
        min = 250,
        max = 5000,
        step = 250,
        get = function() return tonumber(self.saved.behaviorModelRefreshMs) or self.defaults.behaviorModelRefreshMs end,
        set = function(v)
            self.saved.behaviorModelRefreshMs = math.max(250, math.min(5000, math.floor(v / 250 + 0.5) * 250))
        end,
        default = self.defaults.behaviorModelRefreshMs,
        disabled = function() return not self.saved.behaviorModelEnabled end,
    })

    -- LibFights
    Add({ kind = "section", label = "LibFights" })
    Add({
        kind = "checkbox",
        label = "Start LibFights Logging",
        tooltip = "When the LibFights library is installed, start its logging on load so the LibFights panel has data. Turning this off stops a session Console Metrics started.",
        get = function() return self.saved.libFightsAutoStart end,
        set = function(v) self:SetLibFightsAutoStart(v) end,
        default = self.defaults.libFightsAutoStart,
        disabled = function() return not self.LibFightsBridge.IsAvailable() end,
    })

    -- Actions
    Add({ kind = "section", label = "Actions" })
    Add({
        kind = "button",
        label = "Apply Performance Preset",
        tooltip = "Apply the low-memory / high-performance preset (same as /cm perf on).",
        buttonText = "Apply",
        onClick = function()
            self:SetPerformanceMode(true)
            self:Print("Performance preset applied.")
        end,
    })
    Add({
        kind = "button",
        label = "Clear All Fight Data",
        tooltip = "Wipe current fight and full fight history from memory.",
        buttonText = "Clear",
        isDangerous = true,
        onClick = function()
            self:ResetFightData(false)
            self:Print("Fight data cleared.")
        end,
    })

    -- Set rules
    Add({ kind = "section", label = "Custom Set Rules" })
    Add({
        kind = "button",
        label = "Import PvPCooldownTracker Rules",
        tooltip = "Scans PvPCooldownTracker tables and imports ability-based set rules. Use /cm addset to add rules by hand.",
        buttonText = "Import",
        onClick = function()
            local _, message = self:ImportSetsFromPvPCooldownTracker()
            self:Print(message)
        end,
    })
    Add({
        kind = "button",
        label = "Clear Custom Set Rules",
        tooltip = "Removes all custom set rules added through commands or import.",
        buttonText = "Clear",
        isDangerous = true,
        onClick = function()
            self:ClearCustomSetRules()
            self:Print("Cleared all custom set rules.")
        end,
    })

    return controls
end

-- LibAddonMenu-2.0 renderer ---------------------------------------------
local LAM_TYPES = { section = "header", checkbox = "checkbox", slider = "slider", button = "button" }

local function RegisterLibAddonMenu(self, controls)
    local LAM = LibAddonMenu2
    local panelData = {
        type = "panel",
        name = SETTINGS_PANEL_NAME,
        displayName = SETTINGS_PANEL_NAME,
        author = "Vixen Hunny",
        version = tostring(self.version or ""),
        registerForRefresh = true,
        registerForDefaults = true,
    }
    self.ui.lamPanel = LAM:RegisterAddonPanel(LAM_PANEL_ID, panelData)

    local options = {}
    for i = 1, #controls do
        local c = controls[i]
        local option = {
            type = LAM_TYPES[c.kind],
            name = c.label,
            tooltip = c.tooltip,
            disabled = c.disabled,
        }
        if c.kind == "checkbox" or c.kind == "slider" then
            option.getFunc = c.get
            option.setFunc = c.set
            option.default = c.default
        end
        if c.kind == "slider" then
            option.min = c.min
            option.max = c.max
            option.step = c.step
        elseif c.kind == "button" then
            option.func = c.onClick
            option.isDangerous = c.isDangerous
            option.width = "half"
        end
        options[#options + 1] = option
    end
    LAM:RegisterOptionControls(LAM_PANEL_ID, options)
    return "LibAddonMenu-2.0"
end

-- LibHarvensAddonSettings renderer -------------------------------------
local function RegisterLibHarvens(self, controls)
    local LHAS = LibHarvensAddonSettings
    local panel = LHAS:AddAddon(SETTINGS_PANEL_NAME)
    self.ui.lhasPanel = panel

    local types = {
        section = LHAS.ST_SECTION,
        checkbox = LHAS.ST_CHECKBOX,
        slider = LHAS.ST_SLIDER,
        button = LHAS.ST_BUTTON,
    }
    for i = 1, #controls do
        local c = controls[i]
        local setting = {
            type = types[c.kind],
            label = c.label,
            tooltip = c.tooltip,
            disable = c.disabled,
        }
        if c.kind == "checkbox" or c.kind == "slider" then
            setting.getFunction = c.get
            setting.setFunction = c.set
            setting.default = c.default
        end
        if c.kind == "slider" then
            setting.min = c.min
            setting.max = c.max
            setting.step = c.step
            setting.format = "%d"
        elseif c.kind == "button" then
            setting.buttonText = c.buttonText
            setting.clickHandler = c.onClick
        end
        panel:AddSetting(setting)
    end
    return "LibHarvensAddonSettings"
end

local function HasLibAddonMenu()
    if type(IsConsoleUI) == "function" and IsConsoleUI() then
        return false
    end
    return type(LibAddonMenu2) == "table" and type(LibAddonMenu2.RegisterAddonPanel) == "function"
end

local function HasLibHarvens()
    return type(LibHarvensAddonSettings) == "table" and type(LibHarvensAddonSettings.AddAddon) == "function"
end

function ConsoleMetrics:RegisterSettingsMenu()
    if self.settingsMenuLibrary then
        return self.settingsMenuLibrary
    end

    local renderer
    if HasLibAddonMenu() then
        renderer = RegisterLibAddonMenu
    elseif HasLibHarvens() then
        renderer = RegisterLibHarvens
    else
        return nil
    end

    local ok, result = pcall(renderer, self, BuildSettingsControls(self))
    if not ok then
        self:Print("Settings menu failed to load: " .. tostring(result))
        return nil
    end
    self.settingsMenuLibrary = result
    return result
end

-- Opens the settings panel directly when LibAddonMenu-2.0 is in use.
function ConsoleMetrics:OpenSettingsMenu()
    if self.settingsMenuLibrary == "LibAddonMenu-2.0" and self.ui.lamPanel and type(LibAddonMenu2.OpenToPanel) == "function" then
        LibAddonMenu2:OpenToPanel(self.ui.lamPanel)
        return true
    end
    if self.settingsMenuLibrary == "LibHarvensAddonSettings" then
        self:Print("Open Settings > Addons > Console Metrics.")
        return true
    end
    self:Print("No settings menu library installed. Install LibAddonMenu-2.0 (PC) or LibHarvensAddonSettings.")
    return false
end
