-- =============================================================================
-- Under Pressure -- UI/PlagueTint.lua (0.4.0)
-- =============================================================================
-- Draws the Plaguebreak screen tint: a smoky green vignette over the whole
-- screen with a slowly breathing haze layer, shown for exactly as long as a
-- Plaguebreak plague is on the player.
--
-- Owns drawing only. Whether the player IS plagued is Engine/PlagueTracker's
-- job, which calls SetActive() on transitions -- the same split as
-- SilenceTracker / SilenceRing.
--
-- VISIBILITY -- three inputs, one owner, same pattern as the other two UI
-- modules:
--   1. the HUD scene must be showing (never tint a menu)
--   2. the plague_tint setting must be on
--   3. the player must actually carry the plague (or the visual test is live)
--
-- Not gated on the Threat Indicator master toggle or combat state, for the
-- reasons given in UI/SilenceRing.lua: it is a separate indicator with its own
-- switch, and a stale combat flag must not be able to hide it.
--
-- STRENGTH is one number, sv.plague_tint_strength, applied as the root's
-- alpha. Child alpha inherits in ESO's control tree, so the vignette and the
-- animated haze scale together and the XML keeps its own relative levels.
-- =============================================================================

UP = UP or {}
UP.PlagueTint = {}

local root, vignette, haze
local hazeTimeline

local plagued = false

local DEFAULT_STRENGTH = 0.6
local MIN_STRENGTH, MAX_STRENGTH = 0.2, 1.0

-- Preview override (Settings > Plague Indicator > Preview): a deadline
-- timestamp, independent of tracker state, for the reasons documented on
-- SilenceRing.RunPreview.
local PREVIEW_DURATION_MS = 10000
local previewUntilMs = 0

local function previewActive()
    return previewUntilMs > 0 and GetGameTimeMilliseconds() < previewUntilMs
end

local function clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

-- ---------------------------------------------------------------------------
-- Visibility
-- ---------------------------------------------------------------------------
local function shouldShow()
    local forced = previewActive()
    if not (plagued or forced) then return false end
    if not forced then
        local sv = UP.sv or {}
        if sv.plague_tint == false then return false end
        -- Shares Indicator.lua's HUD-scene answer; fails open if unavailable.
        -- The preview bypasses it: the button is in the settings menu, so the
        -- HUD is hidden at the moment it is pressed. See SilenceRing.lua.
        if UP.UI and UP.UI.IsHudShown and not UP.UI.IsHudShown() then return false end
    end
    return true
end

function UP.PlagueTint.UpdateVisibility()
    if not root then return end
    local show = shouldShow()
    root:SetHidden(not show)
    if hazeTimeline then
        if show then
            if not hazeTimeline:IsPlaying() then
                pcall(hazeTimeline.PlayFromStart, hazeTimeline)
            end
        else
            pcall(hazeTimeline.Stop, hazeTimeline)
            if haze then haze:SetAlpha(0) end
        end
    end
end

-- Called by Engine/PlagueTracker on a transition.
function UP.PlagueTint.SetActive(isPlagued)
    plagued = isPlagued == true
    UP.PlagueTint.UpdateVisibility()
end

function UP.PlagueTint.IsPreviewActive()
    return previewActive()
end

-- Settings panel hook. Clamped to the slider's own range so a stray saved
-- value cannot black out the screen.
function UP.PlagueTint.ApplyStrength(strength)
    if not root then return end
    local s = clamp(tonumber(strength) or DEFAULT_STRENGTH, MIN_STRENGTH, MAX_STRENGTH)
    root:SetAlpha(s)
end

UP.PlagueTint.DEFAULT_STRENGTH = DEFAULT_STRENGTH
UP.PlagueTint.MIN_STRENGTH     = MIN_STRENGTH
UP.PlagueTint.MAX_STRENGTH     = MAX_STRENGTH

-- ---------------------------------------------------------------------------
-- Preview (Settings > Plague Indicator > Preview)
-- ---------------------------------------------------------------------------
-- Same contract as SilenceRing.RunPreview: extends rather than stacks,
-- tolerates surplus zo_callLater callbacks, +50 ms guards an early callback.
function UP.PlagueTint.RunPreview()
    if not root then return false end
    previewUntilMs = GetGameTimeMilliseconds() + PREVIEW_DURATION_MS
    UP.PlagueTint.UpdateVisibility()
    zo_callLater(function()
        if GetGameTimeMilliseconds() >= previewUntilMs then
            previewUntilMs = 0
        end
        UP.PlagueTint.UpdateVisibility()
    end, PREVIEW_DURATION_MS + 50)
    return true
end

function UP.PlagueTint.PreviewDurationMs()
    return PREVIEW_DURATION_MS
end

-- ---------------------------------------------------------------------------
-- Init
-- ---------------------------------------------------------------------------
-- Not fatal to the add-on if the control is missing: disables itself and
-- records why, like SilenceRing.
function UP.PlagueTint.Init()
    root = UP_PlagueTintRoot
    if not root then
        UP.Note("Plague tint control missing; Plaguebreak tint disabled.")
        return false
    end
    vignette = root:GetNamedChild("Vignette")
    haze     = root:GetNamedChild("Haze")

    if haze then haze:SetAlpha(0) end

    if haze and ANIMATION_MANAGER then
        local ok, timeline = pcall(ANIMATION_MANAGER.CreateTimelineFromVirtual,
                                   ANIMATION_MANAGER, "UP_PlagueHazePulse", haze)
        if ok then
            hazeTimeline = timeline
        else
            UP.Note("Plague haze animation unavailable; tint will be static.")
        end
    end

    local sv = UP.sv or {}
    UP.PlagueTint.ApplyStrength(sv.plague_tint_strength or DEFAULT_STRENGTH)

    root:SetHidden(true)
    return true
end
