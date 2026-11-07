-- ConsoleMetrics_LibFights.lua
-- Optional bridge to the LibFights library (LibFights/ folder in this repo).
--
-- LibFights logs nothing until Start_Logging() is called. When the library is
-- installed, ConsoleMetrics can start it automatically (option
-- libFightsAutoStart) and shows its fight metrics and model predictions in a
-- "LibFights" panel in both the console and PC viewers. ConsoleMetrics' own
-- combat tracking is unchanged; LibFights runs alongside it.
--
-- Every entry point checks IsAvailable(), so the addon behaves exactly as
-- before when LibFights is not installed.

local CM = ConsoleMetrics
local Util = ConsoleMetrics.Util
local NumberText = Util.NumberText
local ShortNumber = Util.ShortNumber

local Bridge = {}
ConsoleMetrics.LibFightsBridge = Bridge

local TOP_ABILITY_ROWS = 5
local TARGET_ESTIMATE_ROWS = 3

local function LF()
    return LibFights
end

function Bridge.IsAvailable()
    local lib = LF()
    return type(lib) == "table" and type(lib.Logger) == "table" and type(lib.Logger.Start) == "function"
end

function Bridge.IsReady()
    return Bridge.IsAvailable() and LF().initialized == true
end

function Bridge.IsLogging()
    return Bridge.IsAvailable() and LF().Logger.IsLogging() == true
end

local function Pct(fraction, decimals)
    return string.format("%." .. tostring(decimals or 1) .. "f%%", (tonumber(fraction) or 0) * 100)
end

local function Duration(ms)
    local totalSec = (tonumber(ms) or 0) / 1000
    local minutes = math.floor(totalSec / 60)
    return string.format("%d:%04.1f", minutes, totalSec - minutes * 60)
end

---------------------------------------------------------------------------
-- Logging control
---------------------------------------------------------------------------
-- Performance Mode trims what LibFights records so the two loggers together
-- stay within the console memory/CPU budget.
local function BuildLoggingOptions(self)
    if self.saved and self.saved.performanceMode then
        return {
            rawEvents = false,
            trackTargetEffects = false,
            statSampleMs = 2000,
        }
    end
    return nil
end

function ConsoleMetrics:StartLibFightsLogging()
    if not Bridge.IsAvailable() then
        return false, "LibFights is not installed"
    end
    if not Bridge.IsReady() then
        return false, "LibFights has not finished loading"
    end
    if Bridge.IsLogging() then
        return false, "LibFights is already logging"
    end
    local ok, reason = LF().Logger.Start(BuildLoggingOptions(self))
    if ok then
        self.libFightsStartedByCM = true
        self.libFightsRev = (self.libFightsRev or 0) + 1
    end
    return ok, reason
end

function ConsoleMetrics:StopLibFightsLogging()
    if not Bridge.IsAvailable() then
        return false, "LibFights is not installed"
    end
    local ok, reason = LF().Logger.Stop()
    self.libFightsStartedByCM = false
    self.libFightsRev = (self.libFightsRev or 0) + 1
    return ok, reason
end

-- Restart so a Performance Mode change takes effect. Only restarts a session
-- ConsoleMetrics started itself, never one another addon owns.
function ConsoleMetrics:RestartLibFightsLogging()
    if not self.libFightsStartedByCM or not Bridge.IsLogging() then
        return
    end
    LF().Logger.Stop()
    self.libFightsStartedByCM = false
    self:StartLibFightsLogging()
end

function ConsoleMetrics:SetLibFightsAutoStart(enabled)
    if not self.saved then
        return
    end
    self.saved.libFightsAutoStart = enabled == true
    if enabled then
        if not Bridge.IsLogging() then
            self:StartLibFightsLogging()
        end
    elseif self.libFightsStartedByCM then
        self:StopLibFightsLogging()
    end
end

local function OnLibFightsReady(self)
    local lib = LF()
    if self.libFightsCallbacksRegistered then
        return
    end
    self.libFightsCallbacksRegistered = true

    local function Bump()
        self.libFightsRev = (self.libFightsRev or 0) + 1
    end
    lib.RegisterCallback(lib.EVENTS.FIGHT_STARTED, function()
        self.libFightsViewOffset = 0
        Bump()
    end)
    lib.RegisterCallback(lib.EVENTS.FIGHT_ENDED, Bump)
    lib.RegisterCallback(lib.EVENTS.LOGGING_STOPPED, function()
        self.libFightsStartedByCM = false
        Bump()
    end)

    if self.saved.libFightsAutoStart and not Bridge.IsLogging() then
        self:StartLibFightsLogging()
    end
end

function ConsoleMetrics:InitLibFightsIntegration()
    self.libFightsRev = 0
    self.libFightsViewOffset = 0
    self.libFightsStartedByCM = false
    if not Bridge.IsAvailable() then
        return
    end

    local lib = LF()
    if lib.initialized then
        OnLibFightsReady(self)
    else
        -- LibFights normally loads first (OptionalDependsOn), but wait for it if not.
        local function OnInit()
            lib.UnregisterCallback(lib.EVENTS.INITIALIZED, OnInit)
            OnLibFightsReady(self)
        end
        lib.RegisterCallback(lib.EVENTS.INITIALIZED, OnInit)
    end
end

-- Changes whenever the LibFights panel would show different data.
function ConsoleMetrics:GetLibFightsRefreshKey()
    if not Bridge.IsAvailable() then
        return "0"
    end
    local current = LF().Logger.GetCurrentFight()
    return string.format("%d|%d|%d", self.libFightsRev or 0, current and 1 or 0, self.libFightsViewOffset or 0)
end

---------------------------------------------------------------------------
-- Fight selection
---------------------------------------------------------------------------
-- Offset 0 is the running fight (or the most recent one); 1 is the one before.
local function FightList()
    local logger = LF().Logger
    local list = {}
    local fights = logger.GetFights() or {}
    for i = 1, #fights do
        list[#list + 1] = fights[i]
    end
    local current = logger.GetCurrentFight()
    if current then
        list[#list + 1] = current
    end
    return list
end

function ConsoleMetrics:GetLibFightsViewedFight()
    if not Bridge.IsAvailable() then
        return nil, 0, 0
    end
    local list = FightList()
    local count = #list
    if count == 0 then
        return nil, 0, 0
    end
    local offset = math.max(0, math.min(count - 1, self.libFightsViewOffset or 0))
    self.libFightsViewOffset = offset
    local index = count - offset
    return list[index], index, count
end

function ConsoleMetrics:StepLibFightsView(step)
    if not Bridge.IsAvailable() then
        return
    end
    local count = #FightList()
    local offset = (self.libFightsViewOffset or 0) - (tonumber(step) or 0)
    self.libFightsViewOffset = math.max(0, math.min(math.max(0, count - 1), offset))
    self.libFightsRev = (self.libFightsRev or 0) + 1
end

---------------------------------------------------------------------------
-- Panel rows (shared by the console and PC viewers)
---------------------------------------------------------------------------
-- Returns a list of rows:
--   { section = "Heading", tooltip = "..." }
--   { label = "Name", value = "Text", tooltip = "..." }
local function Section(rows, text, tooltip)
    rows[#rows + 1] = { section = text, tooltip = tooltip }
end

local function Stat(rows, label, value, tooltip)
    rows[#rows + 1] = { label = label, value = value, tooltip = tooltip }
end

local function AddFightRows(rows, fight, index, count)
    local s = fight:GetSummary()
    Section(rows, string.format("Fight %d/%d: %s%s", index, count, tostring(s.title or "?"), s.isActive and " (live)" or ""),
        "LibFights fight record. Use Previous/Next LibFights Fight to browse.")
    Stat(rows, "Duration", string.format("%s (active %.1fs)", Duration(s.durationMs), s.activeSec or 0),
        "Fight length, and time from your first to last outgoing hit")
    Stat(rows, "DPS", string.format("%s (active %s, boss %s)", ShortNumber(s.dps), ShortNumber(s.activeDPS), ShortNumber(s.bossDPS)),
        "Damage per second over the fight, over your active time, and against bosses only")
    Stat(rows, "Damage", NumberText(s.damage), string.format("DoT share %s, overkill %s", Pct(s.dotShare), NumberText(s.overkill)))
    Stat(rows, "HPS", string.format("%s (raw %s, overheal %s)", ShortNumber(s.hps), ShortNumber(s.rawHPS), Pct(s.overhealPct)),
        "Effective and raw healing per second")
    Stat(rows, "DTPS", string.format("%s (taken %s)", ShortNumber(s.dtps), NumberText(s.damageTaken)), "Damage taken per second")
    Stat(rows, "Mitigated", string.format("%s (MPS %s, %s)", NumberText(s.mitigated), ShortNumber(s.mps), Pct(s.mitigationPct)),
        string.format("Shield %s exact; block ~%s, armor ~%s, avoid ~%s estimated",
            NumberText(s.mitigatedShield), NumberText(s.mitigatedBlockEst), NumberText(s.mitigatedArmorEst), NumberText(s.mitigatedAvoidEst)))
    Stat(rows, "Crit", string.format("%s (%d/%d hits)", Pct(s.critRate), s.crits or 0, s.hits or 0), "Outgoing critical strike rate")
    Stat(rows, "Max Hit", string.format("%s (%s)", NumberText(s.maxHit), tostring(s.maxHitAbility or "-")), "Largest single outgoing hit")
    Stat(rows, "APM", string.format("%.1f (LA %d, HA %d, weaves %d / %s)", s.apm or 0, s.lightAttacks or 0, s.heavyAttacks or 0, s.weaves or 0, Pct(s.weaveRatio)),
        "Actions per minute, light/heavy attacks and light-attack weaves")
    Stat(rows, "Bars", string.format("front %s / back %s (%d swaps)", Pct(s.frontBarPct, 0), Pct(s.backBarPct, 0), s.barSwaps or 0),
        "Time spent on each weapon bar")
    Stat(rows, "Procs / Deaths", string.format("%d procs, %d deaths, %d KBs", s.procActivations or 0, s.deaths or 0, s.killingBlows or 0),
        "Proc activations, your deaths and killing blows")

    local abilities = fight:GetAbilityBreakdown("damageOut", "total", TOP_ABILITY_ROWS) or {}
    Section(rows, "LibFights Top Damage", "Your top damage abilities in this fight")
    if #abilities == 0 then
        Stat(rows, "No damage yet", "", "No outgoing damage recorded")
    end
    for i = 1, #abilities do
        local a = abilities[i]
        Stat(rows, string.format("%d) %s", i, tostring(a.name or a.id)),
            string.format("%s (%s, %s/s)", NumberText(a.total), Pct(a.pct), ShortNumber(a.dps)),
            string.format("Hits %d | crit %s | avg %s | max %s", a.hits or 0, Pct(a.critRate, 0), NumberText(a.avg), NumberText(a.max)))
    end
end

local function AddModelRows(rows, fight)
    local models = LF().Models
    if type(models) ~= "table" or type(models.GetReport) ~= "function" then
        return
    end
    local report = models.GetReport()
    Section(rows, "LibFights Predictions",
        "Statistical estimates. Hit a target dummy to calibrate the resistance model. Each line shows its sample count.")

    local crit = report.crit or {}
    Stat(rows, "Crit Chance", string.format("%s +/- %s (%d hits)", Pct(crit.critChance), Pct(crit.critChanceStd), crit.samples or 0),
        "Observed crit chance (Beta posterior)")
    Stat(rows, "Crit Damage", crit.critDamagePct and string.format("+%.1f%%", crit.critDamagePct) or "need more data",
        "Mean crit hit divided by mean non-crit hit of the same abilities")

    local inc = report.incoming or {}
    Stat(rows, "Your DR", string.format("%.1f%% (armor %.1f%% + other %.1f%%)", inc.totalDRPct or 0, inc.armorMitigationPct or 0, inc.otherDRPct or 0),
        string.format("Incoming damage reduction (%d samples)", inc.samples or 0))

    local targets = report.targets or {}
    local shown = 0
    for i = 1, #targets do
        if shown >= TARGET_ESTIMATE_ROWS then
            break
        end
        local t = targets[i]
        if (t.samples or 0) > 0 then
            shown = shown + 1
            Stat(rows, tostring(t.name),
                string.format("~%s res, DR %.1f%%", NumberText(t.predictedResistance), t.predictedDRPct or 0),
                string.format("+/- %s | missing pen %s | %s (%d samples)",
                    NumberText(t.predictedResistanceStd), NumberText(t.missingPenetration), tostring(t.status or ""), t.samples))
        elseif (t.relativeSamples or 0) > 0 then
            shown = shown + 1
            Stat(rows, tostring(t.name), string.format("takes %s of avg damage", Pct(t.relativeDamageTaken or 1, 0)),
                string.format("Relative estimate (%d samples). Hit a dummy to calibrate.", t.relativeSamples))
        end
    end
    if shown == 0 then
        Stat(rows, "Targets", "no samples yet", "Target resistance estimates appear after a few hits")
    end

    local ttk = report.ttk or {}
    for i = 1, #ttk do
        local k = ttk[i]
        if k.secondsRemaining then
            Stat(rows, string.format("TTK %s", tostring(k.name or k.unitTag)),
                string.format("%.0fs (%s hp)", k.secondsRemaining, Pct(k.healthFraction, 0)), "Predicted time to kill from boss health trend")
        end
    end

    if fight and fight:IsActive() and type(models.PredictFightOutcome) == "function" then
        local outcome = models.PredictFightOutcome(fight)
        if outcome and outcome.predictedFinalDPS then
            Stat(rows, "Predicted Final DPS", ShortNumber(outcome.predictedFinalDPS),
                string.format("Predicted fight length %.0fs", outcome.predictedDurationSec or 0))
        end
    end
    if report.dpsForecast then
        Stat(rows, "DPS Forecast (5s)", ShortNumber(report.dpsForecast), "Holt-smoothed DPS forecast")
    end
end

function ConsoleMetrics:BuildLibFightsRows()
    local rows = {}
    if not Bridge.IsAvailable() then
        Section(rows, "LibFights", "Optional library")
        Stat(rows, "Status", "not installed",
            "Install the LibFights folder next to ConsoleMetrics in your AddOns directory to enable this panel")
        return rows
    end

    local lib = LF()
    Section(rows, string.format("LibFights %s", tostring(lib.version or "")), "Fight data from the LibFights library")
    local status = Bridge.IsLogging() and "logging" or "stopped"
    if Bridge.IsLogging() and not self.libFightsStartedByCM then
        status = "logging (started outside Console Metrics)"
    end
    Stat(rows, "Status", status, "LibFights records nothing until logging is started")
    Stat(rows, "Fights", tostring(#FightList()), "Fights LibFights holds in memory this session")

    local fight, index, count = self:GetLibFightsViewedFight()
    if fight then
        AddFightRows(rows, fight, index, count)
    else
        Section(rows, "No LibFights fight yet")
        Stat(rows, "Hint", Bridge.IsLogging() and "start a fight" or "start logging first",
            "Fights appear here once LibFights is logging and you enter combat")
    end
    AddModelRows(rows, fight)
    return rows
end

---------------------------------------------------------------------------
-- Chat output
---------------------------------------------------------------------------
function ConsoleMetrics:PrintLibFightsLines(kind)
    if not Bridge.IsAvailable() then
        self:Print("LibFights is not installed.")
        return
    end
    local lib = LF()
    local report = lib.Report
    if type(report) ~= "table" then
        self:Print("LibFights report module is unavailable.")
        return
    end
    if kind == "models" then
        lib.PrintLines(report.ModelLines())
        return
    end
    local fight = self:GetLibFightsViewedFight()
    if not fight then
        self:Print("No LibFights fight yet.")
        return
    end
    if kind == "all" then
        lib.PrintLines(report.AllFightLines(fight))
    else
        lib.PrintLines(report.FightSummaryLines(fight))
    end
end
