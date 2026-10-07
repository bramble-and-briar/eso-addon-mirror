-- =============================================================================
-- Under Pressure -- UI/SilenceRing.lua
-- =============================================================================
-- Draws the silence ring: a static ring with a breathing pulse overlay, centred
-- one reticle-height below the crosshair, shown for exactly as long as the
-- player is silenced.
--
-- Owns drawing only. Whether the player IS silenced is Engine/SilenceTracker's
-- job, which calls SetActive() on transitions.
--
-- VISIBILITY -- three inputs, one owner, same pattern as UI/Indicator.lua:
--   1. the HUD scene must be showing (never draw over a menu)
--   2. the silence_ring setting must be on
--   3. the player must actually be silenced
--
-- Deliberately NOT gated on the "Threat Indicator" master toggle, on combat
-- state, or on the always_show override. That toggle's help text promises to
-- hide the Threat Indicator specifically, and this is a different indicator with
-- its own switch. Combat state is not consulted because silence implies combat
-- anyway, and gating on it would risk suppressing the ring if the cached combat
-- flag were ever stale -- a false negative here is worse than a false positive.
-- =============================================================================

UP = UP or {}
UP.SilenceRing = {}

local root, ring, pulse
local pulseTimeline

-- Whether the player is currently silenced, per SilenceTracker.
local silenced = false

-- Preview override (the "Preview" button in Settings > Silence Indicator;
-- /up-visual-test through 0.3.3). A timestamp, deliberately NOT a boolean and
-- deliberately NOT routed through SilenceTracker: the preview must be unable to
-- corrupt real silence state, so it is a second, independent reason for this
-- control to be visible and touches nothing the tracker owns. A real silence
-- arriving mid-preview therefore behaves normally, and outlives the preview if
-- it is still active when the window closes.
local PREVIEW_DURATION_MS = 10000
local previewUntilMs = 0

local function previewActive()
    return previewUntilMs > 0 and GetGameTimeMilliseconds() < previewUntilMs
end

-- ---------------------------------------------------------------------------
-- Visibility
-- ---------------------------------------------------------------------------
local function shouldShow()
    local forced = previewActive()
    if not (silenced or forced) then return false end

    -- The preview bypasses the user's own toggle. The point of the button is
    -- to look at the visual, and a button that silently did nothing because of
    -- an unrelated setting would read as broken.
    if not forced then
        local sv = UP.sv or {}
        if sv.silence_ring == false then return false end
    end

    -- Reuses the HUD-scene state already computed by UI/Indicator.lua rather
    -- than subscribing to HUD_SCENE/HUD_UI_SCENE a second time to recompute the
    -- same boolean. Fails open if that is somehow unavailable: a ring drawn over
    -- a menu is a cosmetic bug, a ring that never appears is a broken feature.
    --
    -- The preview DOES bypass this one (0.4.0; through 0.3.3 it did not). The
    -- button lives in the settings menu, so the HUD scene is hidden at the
    -- exact moment the player presses it, and a preview that only appeared
    -- after backing out of the menu would defeat the point of putting it there.
    -- This is the one sanctioned exception to "never draw over a menu", bounded
    -- to PREVIEW_DURATION_MS and triggered only by the player's own press.
    if not forced then
        if UP.UI and UP.UI.IsHudShown and not UP.UI.IsHudShown() then return false end
    end
    return true
end

function UP.SilenceRing.UpdateVisibility()
    if not root then return end
    local show = shouldShow()
    root:SetHidden(not show)

    -- Only animate a control that is actually on screen. Left running while
    -- hidden it would be pure waste, every frame, forever.
    if pulseTimeline then
        if show then
            if not pulseTimeline:IsPlaying() then
                pcall(pulseTimeline.PlayFromStart, pulseTimeline)
            end
        else
            pcall(pulseTimeline.Stop, pulseTimeline)
            if pulse then pulse:SetAlpha(0) end
        end
    end
end

-- Called by Engine/SilenceTracker on a transition into or out of silence.
function UP.SilenceRing.SetActive(isSilenced)
    silenced = isSilenced == true
    UP.SilenceRing.UpdateVisibility()
end

-- No IsActive() accessor here on purpose. UP.Silence.IsActive() is the single
-- authoritative answer to "is the player silenced"; the local `silenced` above
-- is just this module's cached copy of it, and exposing it would create two
-- sources of truth that could disagree.
--
-- IsPreviewActive is different: the preview override is genuinely this
-- module's own state and lives nowhere else. The debug overlay reads it so that
-- a ring on screen alongside "silenced=no" is explained rather than alarming.
function UP.SilenceRing.IsPreviewActive()
    return previewActive()
end

-- ---------------------------------------------------------------------------
-- Preview (Settings > Silence Indicator > Preview)
-- ---------------------------------------------------------------------------
-- Shows the ring for PREVIEW_DURATION_MS so the art, placement and pulse can be
-- checked without finding something to silence you -- which on console means
-- queueing for PvP or hunting a specific mob, and gives no control over timing.
-- Was the /up-visual-test slash command through 0.3.3; 0.4.0 moved it onto an
-- LHAS button so it is one A-press away from the toggle it previews, and
-- removed every slash command from the add-on.
--
-- Returns false if the control never initialised, so the caller can say so
-- rather than appearing to succeed.
--
-- Re-invoking EXTENDS the window rather than stacking: each call overwrites the
-- deadline, and each schedules its own cleanup. An earlier cleanup firing during
-- an extended window sees the deadline has moved, declines to clear it, and just
-- re-evaluates -- so the ring survives to the new deadline instead of being
-- hidden early by a stale timer. zo_callLater cannot be cancelled, so tolerating
-- surplus callbacks is the design rather than a compromise.
--
-- The +50ms guards the other direction: if the callback ran a hair EARLY,
-- previewActive() would still be true, nothing would clear, and the ring would
-- hang until the next unrelated visibility change.
function UP.SilenceRing.RunPreview()
    if not root then return false end

    previewUntilMs = GetGameTimeMilliseconds() + PREVIEW_DURATION_MS
    UP.SilenceRing.UpdateVisibility()

    zo_callLater(function()
        if GetGameTimeMilliseconds() >= previewUntilMs then
            previewUntilMs = 0
        end
        UP.SilenceRing.UpdateVisibility()
    end, PREVIEW_DURATION_MS + 50)

    return true
end

function UP.SilenceRing.PreviewDurationMs()
    return PREVIEW_DURATION_MS
end

-- ---------------------------------------------------------------------------
-- Init
-- ---------------------------------------------------------------------------
-- Returns true on success. A missing control is not fatal to the addon -- unlike
-- UP.UI.Init, whose failure aborts startup -- so this only disables itself and
-- records why.
function UP.SilenceRing.Init()
    root = UP_SilenceRingRoot
    if not root then
        UP.Note("Silence ring control missing; silence indicator disabled.")
        return false
    end

    ring  = root:GetNamedChild("Ring")
    pulse = root:GetNamedChild("Pulse")

    if ring and ring.SetColor then ring:SetColor(1, 1, 1, 0.95) end
    if pulse then
        if pulse.SetColor then pulse:SetColor(1, 1, 1, 1) end
        pulse:SetAlpha(0)
    end

    -- ANIMATION_MANAGER is an engine-injected global, present before addon files
    -- parse. pcall-guarded regardless: if the timeline cannot be built the ring
    -- should still work as a static shape rather than take the feature down.
    if pulse and ANIMATION_MANAGER then
        local ok, timeline = pcall(ANIMATION_MANAGER.CreateTimelineFromVirtual,
                                   ANIMATION_MANAGER, "UP_SilencePulse", pulse)
        if ok then
            pulseTimeline = timeline
        else
            UP.Note("Silence ring pulse animation unavailable; ring will be static.")
        end
    end

    root:SetHidden(true)
    return true
end
