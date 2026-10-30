DungeonScores = DungeonScores or {}

-- Addon bootstrap, the five-command slash surface, event registration, and pulse scheduling.

local DS = DungeonScores
local EM = EVENT_MANAGER
local Diagnostics = DS.Diagnostics
local Settings = DS.Settings
local History = DS.History
local defaults = DS.DEFAULTS

function DS:HandleSlashCommand(argument)
    local command = zo_strlower((argument or ""):match("^%s*(.-)%s*$"))

    if command == "" then
        History:Toggle()
    elseif command == "settings" then
        Settings:Open()
    elseif command == "reset" then
        -- An explicit reset is the only in-instance override for a terminal
        -- session boundary such as explicit finalization or leaving the local group.
        self.saved.frozenSessionZoneId = nil
        self.pendingFrozenZoneCheck = false
        self.sessionTrackingSuppressed = false
        self.groupResetSessionClosedZoneId = nil
        self.normalDifficultyObservedForZoneId = nil
        self.pendingDifficultyResetZoneId = nil
        self:NewRun(true, "manual-reset")
        self:Chat(GetString(SI_DUNGEON_SCORES_CHAT_RUN_RESET))
    elseif command == "freeze" then
        self:HandleManualFreeze()
    elseif command == "finalize" or command == "finish" then
        -- /ds finish remains an alias for the one-button freeze-and-finalize path.
        self:HandleManualFinalize()
    elseif command == "report" then
        Diagnostics:ShowReport()
    else
        self:Chat(GetString(SI_DUNGEON_SCORES_CHAT_COMMANDS))
    end
end

-- A completed dungeon can be followed by a new Activity Finder match for the
-- same zoneId. Queue status is retained only as an in-memory transition hint:
-- it never authorizes a fresh run until the client actually zones into a new
-- in-progress LFG activity. In particular, a /reloadui in the old dungeon is
-- not evidence of a new instance.
function DS:OnActivityFinderStatusUpdate(status)
    if status == ACTIVITY_FINDER_STATUS_QUEUED then
        local run = self.run
        local frozenZone = self.saved and self.saved.frozenSessionZoneId
        local currentZoneId, _, _, inDungeon = self:GetCurrentZoneInfo()
        local activeSameInstance = run and run.startedAtMs and not run.finalized
            and not run.completionAchieved and inDungeon
            and tonumber(run.zoneId) == tonumber(currentZoneId)
        -- Activity Finder can queue a replacement group member while the current
        -- dungeon is still in progress. That queue must not turn the next
        -- respawn/loading screen into a fresh run of the same instance.
        if activeSameInstance then
            self.pendingNewFinderInstance = nil
        elseif frozenZone ~= nil or (run and run.startedAtMs and not run.finalized) then
            self.pendingNewFinderInstance = true
        end
    elseif status == ACTIVITY_FINDER_STATUS_NONE
        or status == ACTIVITY_FINDER_STATUS_COMPLETE then
        -- Canceled/closed matchmaking cannot be reused as evidence of a new
        -- instance on a later, unrelated activation.
        self.pendingNewFinderInstance = nil
    end
end

-- A grouped Veteran -> Normal change outside a scored dungeon closes the
-- *previous* instance immediately. Both completed and unfinished active
-- scoring sessions settle locally, without fabricating completion.
-- Normal -> Veteran still arms a fresh-run hint, and the subsequent eligible
-- dungeon arrival must validate it before a new run is allocated.
function DS:OnGroupVeteranDifficultyChanged(isVeteranDifficulty)
    if type(isVeteranDifficulty) ~= "boolean" or IsUnitInDungeon("player") then
        return
    end

    local exitedZoneId = tonumber(self.lastExitedScoredDungeonZoneId)
    if not exitedZoneId then
        -- A group leader can flip difficulty immediately after porting out,
        -- before PLAYER_ACTIVATED reports the outside zone. The client being
        -- outside plus the previously observed scored zone is sufficient to
        -- record that departure; do not lose the reset to event ordering.
        local previousZoneId = tonumber(self.activeScoredDungeonZoneId)
        if previousZoneId and type(self.Data.ZONES[previousZoneId]) == "table" then
            exitedZoneId = previousZoneId
            self.lastExitedScoredDungeonZoneId = exitedZoneId
            self.activeScoredDungeonZoneId = nil
        end
    end
    if not exitedZoneId then
        return
    end
    if isVeteranDifficulty == false then
        self.normalDifficultyObservedForZoneId = exitedZoneId
        self.pendingDifficultyResetZoneId = nil
        self:EndRunForGroupDifficultyReset(exitedZoneId)
        -- The old run is already closed. Hold a session-local gate until ESO
        -- confirms an eligible new arrival; do not persist a frozen-zone gate
        -- that could strand the player if they /reloadui between the flips.
        self.groupResetSessionClosedZoneId = exitedZoneId
        self.sessionTrackingSuppressed = true
    elseif self.normalDifficultyObservedForZoneId == exitedZoneId then
        self.normalDifficultyObservedForZoneId = nil
        self.pendingDifficultyResetZoneId = exitedZoneId
    end
end

function DS:RegisterDeathCombatEvents()
    if self.deathCombatEventsRegistered then
        return
    end

    local deathXPName = self.NAME .. "_DiedXP"
    EM:RegisterForEvent(deathXPName, EVENT_COMBAT_EVENT, function(...)
        self:OnDeathCombatEvent(...)
    end)
    EM:AddFilterForEvent(deathXPName, EVENT_COMBAT_EVENT, REGISTER_FILTER_COMBAT_RESULT, ACTION_RESULT_DIED_XP)

    local deathName = self.NAME .. "_Died"
    EM:RegisterForEvent(deathName, EVENT_COMBAT_EVENT, function(...)
        self:OnDeathCombatEvent(...)
    end)
    EM:AddFilterForEvent(deathName, EVENT_COMBAT_EVENT, REGISTER_FILTER_COMBAT_RESULT, ACTION_RESULT_DIED)
    self.deathCombatEventsRegistered = true
end

function DS:RegisterEvents()
    self:RegisterDeathCombatEvents()

    -- Boss health is sampled from the 500 ms active-run pulse rather than ESO's
    -- high-frequency EVENT_POWER_UPDATE stream. Scoring needs state transitions,
    -- not every intermediate health tick.
    EM:RegisterForEvent(self.NAME .. "_Bosses", EVENT_BOSSES_CHANGED, function(_, forceReset)
        self:OnBossesChanged(forceReset)
    end)

    EM:RegisterForEvent(self.NAME .. "_ActivityFinderComplete", EVENT_ACTIVITY_FINDER_ACTIVITY_COMPLETE, function()
        self:OnActivityFinderActivityComplete()
    end)

    if EVENT_ACTIVITY_FINDER_STATUS_UPDATE then
        EM:RegisterForEvent(self.NAME .. "_ActivityFinderStatus", EVENT_ACTIVITY_FINDER_STATUS_UPDATE,
            function(_, status)
                self:OnActivityFinderStatusUpdate(status)
            end)
    end

    -- Group-level changes are an authoritative reset hint for premade groups.
    -- Personal difficulty changes are deliberately ignored: a solo toggle
    -- does not reliably reset a group-dungeon instance.
    if EVENT_GROUP_VETERAN_DIFFICULTY_CHANGED then
        EM:RegisterForEvent(self.NAME .. "_GroupDungeonDifficulty", EVENT_GROUP_VETERAN_DIFFICULTY_CHANGED,
            function(_, isVeteranDifficulty)
                self:OnGroupVeteranDifficultyChanged(isVeteranDifficulty)
            end)
    end

    local bossDeathsName = self.NAME .. "_BossDeathState"
    EM:RegisterForEvent(bossDeathsName, EVENT_UNIT_DEATH_STATE_CHANGED, function(_, unitTag, isDead)
        self:OnBossDeathStateChanged(unitTag, isDead)
    end)
    EM:AddFilterForEvent(bossDeathsName, EVENT_UNIT_DEATH_STATE_CHANGED, REGISTER_FILTER_UNIT_TAG_PREFIX, "boss")

    local groupDeathsName = self.NAME .. "_GroupDeaths"
    EM:RegisterForEvent(groupDeathsName, EVENT_UNIT_DEATH_STATE_CHANGED, function(_, unitTag, isDead)
        self:OnGroupDeathStateChanged(unitTag, isDead)
    end)
    EM:AddFilterForEvent(groupDeathsName, EVENT_UNIT_DEATH_STATE_CHANGED, REGISTER_FILTER_UNIT_TAG_PREFIX, "group")

    local playerDeathName = self.NAME .. "_PlayerDeathState"
    EM:RegisterForEvent(playerDeathName, EVENT_UNIT_DEATH_STATE_CHANGED, function(_, unitTag, isDead)
        self:OnGroupDeathStateChanged(unitTag, isDead)
    end)
    EM:AddFilterForEvent(playerDeathName, EVENT_UNIT_DEATH_STATE_CHANGED, REGISTER_FILTER_UNIT_TAG, "player")

    EM:RegisterForEvent(self.NAME .. "_GroupUpdate", EVENT_GROUP_UPDATE, function()
        self:OnGroupChanged("group-update")
    end)
    for name, eventCode in pairs({
        ActiveCompanionState = EVENT_ACTIVE_COMPANION_STATE_CHANGED,
        CompanionActivated = EVENT_COMPANION_ACTIVATED,
        CompanionDeactivated = EVENT_COMPANION_DEACTIVATED,
    }) do
        if eventCode then
            EM:RegisterForEvent(self.NAME .. "_" .. name, eventCode, function()
                self:ObserveCompanionPresence()
            end)
        end
    end
    EM:RegisterForEvent(self.NAME .. "_GroupJoined", EVENT_GROUP_MEMBER_JOINED, function()
        self:OnGroupChanged("group-member-joined")
    end)
    EM:RegisterForEvent(self.NAME .. "_GroupLeft", EVENT_GROUP_MEMBER_LEFT, function(_, _, reason, isLocalPlayer)
        if isLocalPlayer then
            self:OnLocalPlayerLeftGroup(reason)
        else
            self:OnGroupChanged("group-member-left")
        end
    end)

    EM:RegisterForEvent(self.NAME .. "_CombatState", EVENT_PLAYER_COMBAT_STATE, function(_, inCombat)
        self:OnPlayerCombatState(inCombat)
    end)

    if EVENT_PLAYER_DEACTIVATED then
        EM:RegisterForEvent(self.NAME .. "_Deactivated", EVENT_PLAYER_DEACTIVATED, function()
            self.playerDeactivated = true
            self:ClearPitstopObservationGaps()
            local run = self.run
            if run and not run.finalized and run.startedAtMs
                and run.departureStartedElapsedMs == nil then
                -- Record the pre-loading-screen boundary. The destination
                -- activation decides whether this was an exit or /reloadui.
                run.departureStartedElapsedMs = math.max(
                    0, GetGameTimeMilliseconds() - run.startedAtMs)
                run.departureStartedAtTimeStamp = GetTimeStamp()
            end
            self:InvalidateEligibilityCache()
            self:CancelQueuedBossRefresh()
            self:TouchActiveRunPersistence()
        end)
    end

    EM:RegisterForEvent(self.NAME .. "_Activated", EVENT_PLAYER_ACTIVATED, function(_, initial)
        self:OnPlayerActivated(initial)
    end)
end

function DS:StartPulse()
    if self.pulseActive then
        return
    end

    self.pulseActive = true
    EM:RegisterForUpdate(self.NAME .. "_Pulse", self.PULSE_INTERVAL_MS, function()
        if not self.run or not self.run.startedAtMs or self.run.finalized then
            self:StopPulse()
            return
        end

        -- Loading screens are observation gaps. The original timer anchor remains
        -- monotonic, but boss/death state must not be sampled until activation has
        -- revalidated the dungeon and resumed (or suspended) the run.
        if self.playerDeactivated then
            return
        end

        -- During the short Activity Finder exit-recovery window, poll only the
        -- authoritative completion state. Boss tags and combat emitters now belong
        -- to the destination zone and must not enter the dungeon run.
        if self.run.exitCompletionRecoveryUntilMs then
            self:CheckAutoCompletion("pulse")
            if self.run and not self.run.finalized then
                self:TouchActiveRunPersistence()
            end
            return
        end

        if self.run.zoneExitSuspended == true then
            self:StopPulse()
            return
        end

        self:PruneRoutineDeathDedupe()
        -- Both presence checks need the same zone/dungeon observation. Sample it
        -- once per pulse; their event-triggered calls still sample independently.
        local needsCompanion = self.run.companionObserved ~= true
        local needsPitstop = self.run.pitstopObserved ~= true
            and self.run.completionAchieved ~= true
        if needsCompanion or needsPitstop then
            local observedZoneId = self:GetCurrentZoneInfo()
            local observedInDungeon = IsUnitInDungeon("player") == true
            if needsCompanion then
                self:ObserveCompanionPresence(observedZoneId, observedInDungeon)
            end
            if needsPitstop then
                self:ObservePitstopPresence(observedZoneId, observedInDungeon)
            end
        end
        self:PollBossPowerStates()

        local activeEncounter = self.run.activeBossEncounter
        if activeEncounter and activeEncounter.emptySinceMs then
            self:FinalizeObservedBossEncounter(false)
        end

        self:CheckAutoCompletion("pulse")
        if self.run and not self.run.finalized then
            self:TouchActiveRunPersistence()
        end

        if self.saved and self.saved.settings.showHud then
            local nowMs = GetGameTimeMilliseconds()
            if not self.lastHudPulseAtMs or nowMs - self.lastHudPulseAtMs >= 1000 then
                self.lastHudPulseAtMs = nowMs
                self:RefreshHud()
            end
        end
    end)
end

function DS:StopPulse()
    if not self.pulseActive then
        return
    end

    EM:UnregisterForUpdate(self.NAME .. "_Pulse")
    self.pulseActive = false
end

function DS:Initialize()
    self.saved = ZO_SavedVars:NewAccountWide(self.SV_NAME, self.SV_VERSION, nil, defaults, GetWorldName(), nil)
    self:PurgeLegacyReferenceData()
    self:UpgradePendingStandardPublicationPayloads()
    self:InitializeScoreHistoryState()
    self:InitializeRunIdentityState()

    Diagnostics:Initialize(self.saved)
    History:Initialize(self.saved)
    Settings:Initialize(self.saved)

    self:CreateHud()
    self:RegisterEvents()
    SLASH_COMMANDS["/ds"] = function(argument)
        self:HandleSlashCommand(argument)
    end

    local savedRun = self.saved and self.saved.activeRun or nil
    if self.saved and self.saved.frozenSessionZoneId then
        -- Finalization or local group departure is terminal for the current
        -- dungeon instance. Defer zone validation until PLAYER_ACTIVATED so
        -- /reloadui cannot silently start another score in that same instance.
        self.pendingFrozenZoneCheck = true
        self.sessionTrackingSuppressed = true
        self.run = nil
        self:RemoveOpenSettlementForRun(savedRun)
        self.saved.activeRun = nil
    elseif type(savedRun) == "table" and not savedRun.finalized then
        -- Zone APIs can be transient during EVENT_ADD_ON_LOADED after /reloadui.
        -- Validate the same-version persisted run only after PLAYER_ACTIVATED.
        self.pendingActiveRunRestore = true
        self.run = nil
    else
        self:NewRun(false, "addon-initialize")
    end

end

function DS:ToggleBrowserFromKeybind()
    if self.History and self.History.Toggle then
        self.History:Toggle()
    end
end

function DS:FreezeScoreFromKeybind()
    if self.HandleManualFreeze then
        self:HandleManualFreeze()
    end
end

function DS:FinalizeScoreFromKeybind()
    if self.HandleManualFinalize then
        self:HandleManualFinalize()
    end
end

local function OnAddOnLoaded(_, addonName)
    if addonName ~= DS.NAME then
        return
    end

    EM:UnregisterForEvent(DS.NAME, EVENT_ADD_ON_LOADED)
    DS:Initialize()
end

EM:RegisterForEvent(DS.NAME, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
