-- ===========================================================================
-- ZoomReconciler.lua
-- ---------------------------------------------------------------------------
-- Single owner of "where should the camera converge after an FPV toggle we
-- handle ourselves".
--
-- The addon pre-hooks ToggleGameCameraFirstPerson. In states where the engine
-- would refuse a proper third-person/FPV transition (mounted, werewolf,
-- swimming) -- or when leaving FPV -- BAV takes ownership and drives the camera
-- distance itself. The hard part is that other addons (notably PvpAlerts /
-- Miat's PvP) call ToggleGameCameraFirstPerson() TWICE in one rendered frame to
-- probe the camera, expecting the pair to net to zero visible change.
--
-- The old approach tried to RECOGNISE such a pair by frame timestamp and undo
-- our zoom synchronously on the second call. That heuristic was fragile: it
-- broke differently in Cyrodiil (oscillation), as a werewolf (stuck FPV after a
-- port), and on the world map (forced FPV) -- one bug per state, because the
-- "two calls share a frame" assumption does not hold everywhere.
--
-- Model here: INTENT + COALESCING DEFERRED RECONCILE. We never inspect frame
-- timing. An owned toggle only FLIPS a persistent `desiredZoom` intent relative
-- to its OWN value (FPV <-> third person) and schedules a single next-frame
-- reconcile that writes `desiredZoom` exactly once. A probe pair is two flips,
-- so `desiredZoom` returns to where it started and the one reconcile writes the
-- original value -- net zero, regardless of whether the two probes shared a
-- frame. If the engine rejects the write (a state that owns its own distance),
-- we retry a bounded number of times rather than leaving the camera half-moved.
--
-- Scope is deliberately NARROW: this only engages where BAV already blocks the
-- engine (limited state, or leaving FPV). The normal third-person->FPV path is
-- left as a passthrough so the engine runs its native transition and other
-- addons can still measure the ordinary case -- HandleToggle returns false there
-- and the hook lets the original function run.
--
-- Nothing here touches SavedVariables directly; it routes verified writes
-- through the main file's SetCameraZoom (which owns the write-failure metric)
-- and persistence through QueueSave.
-- ===========================================================================

local addon = BureauOfAcceptableViews
local private = addon.private

addon.ZoomReconciler = addon.ZoomReconciler or {}
local ZoomReconciler = addon.ZoomReconciler

-- Library globals bound to locals once at load.
local EVENT_MANAGER = EVENT_MANAGER
local tonumber       = tonumber

-- ZOOM_FPV is the shared first-person sentinel (camera distance 0.0). Read it
-- from the main file's constant contract so there is a single source of truth.
local ZOOM_FPV = (private.constants and private.constants.ZOOM_FPV) or 0.0

-- Logging resolved lazily so file load order cannot break us (same discipline as
-- FovArbiter / ContextPresets). The guard is a load-order guard only -- all four
-- Log* helpers ARE exported on private by the core file.
--
-- String convention: the toggle narrative below continues the core's own FPV
-- story, so it reuses the core's localized SI_BAV_LOG_* strings. Purely internal
-- mechanics (the write-retry loop) use plain English traces, matching every other
-- module -- they name internals and are only read while chasing a bug. What is
-- NOT allowed is borrowing an unrelated localized string for an internal event,
-- or logging at a lower level than the core does for the same event.
local function LogDebug(...)
    if private.LogDebug then private.LogDebug(...) end
end

local function LogWarn(...)
    if private.LogWarn then private.LogWarn(...) end
end

-- ---------------------------------------------------------------------------
-- Reconcile state
-- ---------------------------------------------------------------------------
-- desiredZoom -- coalesced intent, re-seeded from the live distance whenever
--                no reconcile is pending. Direct writes supersede queued intent.
-- thirdPersonTarget -- exact return distance for a pending probe pair; separate
--                      player toggles still resolve the remembered preference.
-- pending     -- gates the one-shot updater (mirror of ContextPresets coalesce).
-- retries     -- bounded reschedule counter for a rejected write.
local desiredZoom = nil
local thirdPersonTarget = nil
local pending     = false
local retries     = 0

-- Unique to this module; must not collide with the main file's save timer or the
-- other modules' update timers.
local RECONCILE_UPDATE_NAME = "BAV_ZoomReconcile"
-- Uses the same three-failure threshold as the conflict diagnostics: if the
-- engine rejects the write this many times in a row we stop retrying. The
-- matching rejection run is readable through private.GetZoomWriteFailureCount()
-- and is reported by `/bav status`.
local RECONCILE_MAX_RETRIES = 3

local Schedule  -- forward declaration (OnReconcileUpdate reschedules through it)

-- Resolve the third-person distance a "leave FPV" intent should target. Mirrors
-- the expression the old synchronous handler used: prefer the remembered
-- third-person zoom, else the configured limited-state fallback.
local function ResolveThirdPersonTarget()
    local lastZoom = private.GetLastZoom()
    if private.IsValidZoom(lastZoom) and lastZoom > ZOOM_FPV then
        return lastZoom
    end
    return private.GetConfiguredMinMountedZoom()
end

-- Tear down the reconcile timer AND clear the intent. Idempotent. This is the
-- external cancel used on /bav reset and across load screens: a fresh slate
-- where the next owned toggle re-seeds desiredZoom from the live camera.
function ZoomReconciler.Cancel()
    if pending then
        EVENT_MANAGER:UnregisterForUpdate(RECONCILE_UPDATE_NAME)
        pending = false
    end
    desiredZoom = nil
    thirdPersonTarget = nil
    retries = 0
end

-- One-shot updater: the single point that actually writes the camera.
local function OnReconcileUpdate()
    -- Self-tear the timer FIRST, but DO NOT clear desiredZoom here -- unlike the
    -- external Cancel(), this teardown must preserve the intent we are about to
    -- apply (and may need to keep for a retry). Hence the inline unregister
    -- rather than calling Cancel().
    if pending then
        EVENT_MANAGER:UnregisterForUpdate(RECONCILE_UPDATE_NAME)
        pending = false
    end

    if desiredZoom == nil then
        return
    end

    -- The one verified write. SetCameraZoom owns the write-failure metric
    -- (consecutiveZoomWriteFailures), so we just react to its boolean result.
    -- Raise the re-entrancy guard around it so a write that somehow re-triggers
    -- the FPV toggle is passed through by the hook instead of recursing here.
    if private.SetTogglingFPV then private.SetTogglingFPV(true) end
    local ok = private.SetCameraZoom(desiredZoom)
    if private.SetTogglingFPV then private.SetTogglingFPV(false) end
    if ok then
        retries = 0
        if private.NoteViewStateAndCheckOscillation then
            private.NoteViewStateAndCheckOscillation(GetGameTimeMilliseconds())
        end
        private.QueueSave()
    elseif retries < RECONCILE_MAX_RETRIES then
        -- Engine rejected the write (e.g. a state that owns its own distance).
        -- Try again next frame rather than leaving the camera half-applied. WARN,
        -- not DEBUG: the core logs a rejected camera write at WARN, so the same
        -- event must not be quieter just because it came through the reconciler.
        retries = retries + 1
        LogWarn("ZoomReconciler: camera write of %.2f rejected, retry %d/%d",
            desiredZoom, retries, RECONCILE_MAX_RETRIES)
        Schedule()
    else
        -- Give up after a bounded run. This is the visible end of a rejection run
        -- (private.GetZoomWriteFailureCount / `/bav status` report the count).
        LogWarn("ZoomReconciler: giving up on camera write of %.2f after %d retries",
            desiredZoom, RECONCILE_MAX_RETRIES)
        retries = 0
    end
end

-- Arm the next-frame reconcile, unless one is already pending. The pending guard
-- is what collapses a same-frame probe PAIR to a single write: the second
-- toggle's Schedule() is a no-op, so only one reconcile fires for the pair.
Schedule = function()
    if pending then
        return
    end
    pending = true
    EVENT_MANAGER:RegisterForUpdate(RECONCILE_UPDATE_NAME, 0, OnReconcileUpdate)
end

-- Decide ownership for this toggle and, when owned, flip the intent + schedule.
-- Returns true when we took ownership (the hook should block the engine), false
-- to pass through to the engine's native handling (the normal third->FPV case).
function ZoomReconciler.HandleToggle(nativeTransitionPending)
    local zoom, success = private.GetCameraZoom()
    if not success then
        LogWarn("ZoomReconciler: live zoom unavailable; passing toggle to ESO")
        desiredZoom = nil
        thirdPersonTarget = nil
        retries = 0
        return false
    end
    local owned = private.IsZoomLimited() or zoom <= ZOOM_FPV
    if not owned then
        -- Normal third-person -> FPV: let the engine run its native transition.
        -- Other addons' in-frame measurement of this ordinary case keeps working.
        -- Keep our persistent intent aligned with the native transition's expected
        -- destination. Without this, an old third-person desiredZoom survives the
        -- passthrough; the next owned toggle from FPV flips relative to that stale
        -- value and can select FPV again instead of leaving it.
        thirdPersonTarget = zoom
        desiredZoom = ZOOM_FPV
        retries = 0
        LogDebug(SI_BAV_LOG_TOGGLE_PASSING)
        return false
    end

    if not pending then
        desiredZoom = zoom
        if zoom > ZOOM_FPV then
            thirdPersonTarget = zoom
        elseif not nativeTransitionPending or thirdPersonTarget == nil then
            thirdPersonTarget = ResolveThirdPersonTarget()
        end
    end

    -- While pending, flip the intent relative to its OWN value, not the live camera: two
    -- flips (a probe pair) return desiredZoom to its start, so a probe that
    -- never rendered cannot corrupt the result or the remembered third zoom.
    if desiredZoom == nil then
        -- First owned toggle: seed straight to the opposite of the live view.
        desiredZoom = (zoom <= ZOOM_FPV) and ResolveThirdPersonTarget() or ZOOM_FPV
    elseif desiredZoom <= ZOOM_FPV then
        desiredZoom = thirdPersonTarget or ResolveThirdPersonTarget()   -- FPV -> third person
        LogDebug(SI_BAV_LOG_TOGGLE_TO_THIRD, desiredZoom)
    else
        -- third person -> FPV: remember the third-person distance first (only if
        -- it is a "normal" zoom past the threshold), mirroring the old handler.
        -- Skip the remember while a preset (ContextPresets) is actively overriding
        -- distance: desiredZoom would then be the preset's offset framing, not the
        -- player's own preferred zoom, and saving it would pollute lastZoom with a
        -- cinematic distance that resurfaces long after the preset clears.
        local presets = addon.ContextPresets
        local presetOverriding = presets and presets.GetActiveState and presets.GetActiveState() ~= "default"
        if desiredZoom > private.GetConfiguredLastZoomThreshold() and not presetOverriding then
            private.SetLastZoom(desiredZoom)
        end
        desiredZoom = ZOOM_FPV
        LogDebug(SI_BAV_LOG_TOGGLE_TO_FPV, zoom)
    end

    -- NOTE: a probe pair SPLIT across two frames while in a limited state can
    -- produce a single frame of FPV before the next reconcile restores the
    -- third-person intent. That one-frame flicker is strictly better than the
    -- old stuck-FPV bug and only occurs in the owned/limited state.
    Schedule()
    LogDebug(SI_BAV_LOG_TOGGLE_HANDLED)
    return true
end

-- Re-seed the intent to match a distance some OTHER module just wrote directly
-- (e.g. ContextPresets applying a preset's distance via CameraSettings.Set,
-- which bypasses this module entirely). Without this, desiredZoom keeps
-- pointing at whatever the last owned toggle left it at; a same-frame probe
-- pair arriving after that direct write would flip relative to the STALE
-- intent and the deferred reconcile would drag the camera back to it instead
-- of the preset's distance -- the "two systems touch camera distance" flicker.
-- A direct distance write supersedes any queued toggle or retry. The core skips
-- this handoff during the reconciler's own guarded write.
function ZoomReconciler.SyncIntent(zoom)
    zoom = tonumber(zoom)
    if zoom == nil then
        return
    end
    ZoomReconciler.Cancel()
    desiredZoom = zoom
end
