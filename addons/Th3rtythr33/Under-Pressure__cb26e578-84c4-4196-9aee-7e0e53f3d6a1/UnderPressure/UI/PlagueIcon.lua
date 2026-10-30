-- =============================================================================
-- Under Pressure -- UI/PlagueIcon.lua (0.4.2)
-- =============================================================================
-- Draws the Plague Carrier icon (the biological hazard symbol in green) in two
-- independent ways while a Plaguebreak plague is on the player:
--
--   * CORNERS (default on): the icon in all four corners of the screen,
--     slowly flashing. Hard to miss from any eye position on a TV.
--   * CENTRE  (default off): one icon just below the silence ring's slot,
--     with the breathing pulse overlay the ring uses.
--
-- Owns drawing only. Whether the player IS plagued is Engine/PlagueTracker's
-- job, which calls SetActive() on transitions with the same boolean it gives
-- the tint (active, or held through death until respawn).
--
-- VISIBILITY, per display, same owner pattern as SilenceRing / PlagueTint:
--   1. the HUD scene must be showing (never draw over a menu)
--   2. that display's own switch must be on
--   3. the player must carry the plague (or the Plague Indicator preview is live)
--
-- The preview is the tint's deadline timestamp (UP.PlagueTint.IsPreviewActive);
-- this module does not keep a second one, so one button previews every plague
-- visual together. The preview bypasses the HUD gate (the button is in the
-- menu) but honours each display's switch, so what you preview is what you
-- will get -- with one exception: if every plague visual is switched off, the
-- preview shows the corner icons, so the button never silently does nothing.
-- =============================================================================

UP = UP or {}
UP.PlagueIcon = {}

local iconRoot, iconPulse, pulseTimeline
local cornersRoot, flashTimeline

local plagued = false

local function sv()
    return UP.sv or {}
end

-- Default on. `~= false` so an absent key (a file written before this
-- setting existed) reads as on, which is also what DEFAULT_SAVED says.
function UP.PlagueIcon.CornersEnabled()
    return sv().plague_icon_corners ~= false
end

-- Default off. `== true` so an absent key reads as off.
function UP.PlagueIcon.CenterEnabled()
    return sv().plague_icon_center == true
end

local function previewActive()
    local t = UP.PlagueTint
    return (t and t.IsPreviewActive and t.IsPreviewActive()) == true
end

local function hudShown()
    -- Shares Indicator.lua's HUD-scene answer; fails open if unavailable.
    if UP.UI and UP.UI.IsHudShown then return UP.UI.IsHudShown() end
    return true
end

-- Returns (showCorners, showCentre).
local function wanted()
    local forced = previewActive()
    if not (plagued or forced) then return false, false end
    if not forced and not hudShown() then return false, false end
    local corners, center = UP.PlagueIcon.CornersEnabled(), UP.PlagueIcon.CenterEnabled()
    if forced and not corners and not center and sv().plague_tint ~= true then
        -- Nothing is enabled; the preview still has to show something.
        corners = true
    end
    return corners, center
end

-- Show/hide one display and keep its timeline in step. `onStop` restores the
-- animated alpha so a later show starts from a known state and nothing can be
-- left half-faded behind a hidden control.
local function drive(root, timeline, show, onStop)
    if not root then return end
    root:SetHidden(not show)
    if not timeline then return end
    if show then
        if not timeline:IsPlaying() then
            pcall(timeline.PlayFromStart, timeline)
        end
    else
        pcall(timeline.Stop, timeline)
        if onStop then onStop() end
    end
end

function UP.PlagueIcon.UpdateVisibility()
    local corners, center = wanted()
    drive(cornersRoot, flashTimeline, corners, function()
        if cornersRoot and cornersRoot.SetAlpha then cornersRoot:SetAlpha(1) end
    end)
    drive(iconRoot, pulseTimeline, center, function()
        if iconPulse and iconPulse.SetAlpha then iconPulse:SetAlpha(0) end
    end)
end

-- Called by Engine/PlagueTracker on a transition (same value as the tint's).
function UP.PlagueIcon.SetActive(isPlagued)
    plagued = isPlagued == true
    UP.PlagueIcon.UpdateVisibility()
end

-- For the debug overlay and the harness: what is on screen right now.
function UP.PlagueIcon.IsShowing()
    local c = cornersRoot and not cornersRoot:IsHidden() or false
    local s = iconRoot and not iconRoot:IsHidden() or false
    return c, s
end

-- ---------------------------------------------------------------------------
-- Init
-- ---------------------------------------------------------------------------
-- Not fatal to the add-on if a control is missing: that display disables
-- itself and records why, like SilenceRing and PlagueTint.
function UP.PlagueIcon.Init()
    iconRoot    = UP_PlagueIconRoot
    cornersRoot = UP_PlagueCornersRoot
    if not iconRoot and not cornersRoot then
        UP.Note("Plague icon controls missing; Plague Carrier icons disabled.")
        return false
    end

    if iconRoot then
        iconPulse = iconRoot:GetNamedChild("Pulse")
        if iconPulse then iconPulse:SetAlpha(0) end
        if iconPulse and ANIMATION_MANAGER then
            local ok, timeline = pcall(ANIMATION_MANAGER.CreateTimelineFromVirtual,
                                       ANIMATION_MANAGER, "UP_PlagueIconPulse", iconPulse)
            if ok then pulseTimeline = timeline
            else UP.Note("Plague icon pulse animation unavailable; centre icon will be static.") end
        end
        iconRoot:SetHidden(true)
    else
        UP.Note("Centre plague icon control missing; that display is disabled.")
    end

    if cornersRoot then
        if ANIMATION_MANAGER then
            local ok, timeline = pcall(ANIMATION_MANAGER.CreateTimelineFromVirtual,
                                       ANIMATION_MANAGER, "UP_PlagueCornerFlash", cornersRoot)
            if ok then flashTimeline = timeline
            else UP.Note("Plague corner flash animation unavailable; corner icons will be static.") end
        end
        cornersRoot:SetAlpha(1)
        cornersRoot:SetHidden(true)
    else
        UP.Note("Corner plague icon control missing; that display is disabled.")
    end
    return true
end
