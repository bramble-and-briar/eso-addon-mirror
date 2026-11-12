-- ConsoleMetrics_Init.lua
-- Startup, event registration and the periodic update loop.

local CM = ConsoleMetrics
local Util = ConsoleMetrics.Util
local DIALOG_LIVE_REFRESH_MS = Util.DIALOG_LIVE_REFRESH_MS
local METRICS_UPDATE_THROTTLE_MS = Util.METRICS_UPDATE_THROTTLE_MS
local PROTECTION_UPDATE_THROTTLE_MS = Util.PROTECTION_UPDATE_THROTTLE_MS
local UnitName = Util.UnitName

local Fight = ConsoleMetrics.Fight
local NewFight = Fight.NewFight


---------------------------------------------------------------------------
-- Update loop
---------------------------------------------------------------------------
local UPDATE_INTERVAL_MS = 200

-- Panels that are expensive to rebuild get a longer live refresh interval.
local SLOW_REFRESH_PANELS = { overview = true, resources = true, mitigation = true, resistance = true }

local function DialogRefreshIntervalMs(self, panelName)
    local base = DIALOG_LIVE_REFRESH_MS
    -- The console list is rebuilt row by row; refreshing it twice a second
    -- makes it hard to navigate, so it updates at most every 1.5s.
    if not self:IsFightViewDialogShowingPC() then
        base = math.max(base, 1500)
    end
    if self.saved and self.saved.performanceMode then
        if panelName == "main" then
            return math.max(base, 750)
        end
        if SLOW_REFRESH_PANELS[panelName] then
            return math.max(base, 1500)
        end
        return math.max(base, 2000)
    end

    if panelName == "main" then
        return base
    end
    if SLOW_REFRESH_PANELS[panelName] then
        return math.max(base, 1000)
    end
    return math.max(base, 1500)
end

-- Changes whenever the dialog would show different data; static views never refresh.
local function LiveDialogRefreshKey(self)
    local fight = self.fight or {}
    return string.format(
        "%s|%d|%d|%d|%s",
        tostring(self.dialogPanel or "main"),
        self.inCombat and 1 or 0,
        math.floor(tonumber(fight.snapshotRev) or 0),
        self.viewFightIndex or 0,
        self:GetLibFightsRefreshKey()
    )
end

-- Session FPS statistics shown on the gamepad main panel.
function ConsoleMetrics:RecordRuntimeFps()
    if type(GetFramerate) ~= "function" then
        return
    end
    local fps = tonumber(GetFramerate())
    if not fps or fps <= 0 then
        return
    end

    local stats = self.fpsRuntime
    if not stats then
        stats = { samples = 0, total = 0, min = nil, bins = {} }
        self.fpsRuntime = stats
    end
    stats.samples = (stats.samples or 0) + 1
    stats.total = (stats.total or 0) + fps
    if stats.min == nil or fps < stats.min then
        stats.min = fps
    end
    local key = math.max(0, math.min(120, math.floor(fps + 0.5))) + 1
    stats.bins[key] = (stats.bins[key] or 0) + 1
end

function ConsoleMetrics:OnUpdate()
    local nowMs = GetFrameTimeMilliseconds()
    self:RecordRuntimeFps()
    -- Console dialog: a moved cursor counts as input (pauses refresh / auto-hide).
    self:TrackConsoleDialogInput()
    local dialogShowing = self:IsFightViewDialogShowing()

    -- Console dialog left the screen without going through Back / Close
    -- (another menu opened, the screen was dismissed): just tidy up. Back is
    -- handled inside the dialog (ConsoleGoBack), so nothing is re-opened here;
    -- re-showing the screen from this loop is what used to break the view.
    if self.wasFightViewDialogShowing and not dialogShowing and self.ui.fightViewDialog and not self.isClosingFightViewDialog then
        self:CloseFightViewDialog(true, "cancel")
        dialogShowing = false
    end

    if self.dialogAutoHideAtMs and self.saved.dialogAutoHide and not self.inCombat and nowMs >= self.dialogAutoHideAtMs then
        if self:IsFightViewDialogInUse() then
            -- The player is reading or using the window: push the timer back.
            self:ArmDialogAutoHide()
        else
            self:CloseFightViewDialog(true, "autohide")
            dialogShowing = false
        end
    end

    if self.inCombat then
        local performanceMode = self.saved and self.saved.performanceMode == true
        local protectionThrottleMs = performanceMode and math.max(PROTECTION_UPDATE_THROTTLE_MS, 750) or PROTECTION_UPDATE_THROTTLE_MS
        local metricsThrottleMs = performanceMode and math.max(METRICS_UPDATE_THROTTLE_MS, 400) or METRICS_UPDATE_THROTTLE_MS

        self:SampleFightResources(nowMs, false)
        if nowMs >= (self.lastProtectionUpdateMs or 0) + protectionThrottleMs then
            self:UpdateProtectionInference(nowMs)
            self.lastProtectionUpdateMs = nowMs
        end
        if nowMs >= (self.lastMetricsUpdateMs or 0) + metricsThrottleMs then
            self:UpdateFightPeaks(nowMs)
            self.lastMetricsUpdateMs = nowMs
        end
    end

    if dialogShowing then
        if not self.dialogRefreshAtMs or nowMs >= self.dialogRefreshAtMs then
            local refreshKey = LiveDialogRefreshKey(self)
            -- Never rebuild under the cursor while the player is clicking, typing or scrolling.
            if self.lastDialogRefreshKey ~= refreshKey and not self:IsFightViewDialogEditing() and not self:IsFightViewDialogBusy() then
                self:RefreshFightViewDialog()
                self.lastDialogRefreshKey = refreshKey
            end
            self.dialogRefreshAtMs = nowMs + DialogRefreshIntervalMs(self, tostring(self.dialogPanel or "main"))
        end
    else
        self.dialogRefreshAtMs = nil
        self.lastDialogRefreshKey = nil
    end

    self.wasFightViewDialogShowing = dialogShowing
    self:EmitIoTraceHeartbeat(nowMs)
end

---------------------------------------------------------------------------
-- Initialization
---------------------------------------------------------------------------
function ConsoleMetrics:Initialize()
    self.saved = ZO_SavedVars:NewAccountWide("ConsoleMetricsSavedVars", 1, nil, self.defaults)
    self:NormalizeSavedVariables()
    if self.saved.performanceMode then
        self:ApplyConsolePerformancePreset()
    end
    self:InvalidateTrackedSetMatchCache()
    self:ResetLikelySetProcCache()

    self.playerName = UnitName(GetUnitName("player"))
    self.fightHistory = {}
    -- Restore persisted saved fights into session history so they're browsable immediately.
    self:RestoreSavedFightsIntoHistory()
    self.viewFightIndex = #self.fightHistory
    self.dialogPanel = "main"
    self.dialogAutoHideAtMs = nil
    self.lastDialogRefreshKey = nil
    self.wasFightViewDialogShowing = false
    self.isClosingFightViewDialog = false
    self.ioTraceState = nil
    self.observedAbilityLog = {}
    self.observedAbilityCount = 0
    self.fpsRuntime = { samples = 0, total = 0, min = nil, bins = {} }
    self.fight = NewFight(GetFrameTimeMilliseconds())

    self:InitLibFightsIntegration()
    self:RegisterSettingsMenu()
    self:RegisterJournalIntegrationHooks()

    EVENT_MANAGER:RegisterForEvent(self.name, EVENT_PLAYER_COMBAT_STATE, function(...)
        self:OnCombatState(...)
    end)

    EVENT_MANAGER:RegisterForEvent(self.name, EVENT_COMBAT_EVENT, function(...)
        self:OnCombatEvent(...)
    end)

    EVENT_MANAGER:RegisterForUpdate(self.name .. "Update", UPDATE_INTERVAL_MS, function()
        self:OnUpdate()
    end)

    SLASH_COMMANDS["/cm"] = function(args)
        self:HandleSlash(args)
    end
    SLASH_COMMANDS["/consolemetrics"] = function(args)
        self:HandleSlash(args)
    end

    self:Print("Loaded. Use /cm view to open the fight dialog, /cm help for commands.")
end

local function OnAddonLoaded(_, addonName)
    if addonName ~= ConsoleMetrics.name then
        return
    end

    EVENT_MANAGER:UnregisterForEvent(ConsoleMetrics.name, EVENT_ADD_ON_LOADED)
    ConsoleMetrics:Initialize()
end

EVENT_MANAGER:RegisterForEvent(ConsoleMetrics.name, EVENT_ADD_ON_LOADED, OnAddonLoaded)
