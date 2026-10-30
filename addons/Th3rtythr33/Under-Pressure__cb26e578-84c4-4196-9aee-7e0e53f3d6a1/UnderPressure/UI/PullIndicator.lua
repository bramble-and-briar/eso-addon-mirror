-- =============================================================================
-- Under Pressure -- UI/PullIndicator.lua (0.4.2)
-- =============================================================================
-- Draws the pull warning while Engine/PullTracker says a pull is incoming, in
-- up to three ways, each with its own switch:
--
--   * CORNERS (default on):  the pull icon in all four screen corners, flashing
--   * CENTRE  (default off): one pull icon to the right of the reticle, pulsing
--   * BORDERS (default off): sharp-edged orange bars down the left and right
--                            screen edges, flashing
--
-- All of it is behind the single "Pull detection" switch (sv.pull_detect,
-- default OFF): with that off the tracker never fires, so nothing here is ever
-- asked to draw. The display switches only decide what a warning looks like.
--
-- Owns drawing only; the tracker calls SetActive() on transitions. Visibility
-- per display: HUD scene showing (never over a menu), that display's switch,
-- and a live warning or the preview. The preview is this module's own
-- deadline (the pull tracker has no preview state to borrow), honours each
-- display's switch, bypasses the HUD gate because the button lives in the
-- menu, and shows the corner icons if every display is off so the button
-- never silently does nothing. The preview works with Pull detection OFF so
-- you can see what you would get before switching it on.
-- =============================================================================

UP = UP or {}
UP.PullIndicator = {}

local iconRoot, iconPulse, pulseTimeline
local cornersRoot, cornersTimeline
local bordersRoot, bordersTimeline

local active = false
local activeSet = nil

local PREVIEW_DURATION_MS = 10000
local previewUntilMs = 0

local function sv()
    return UP.sv or {}
end

function UP.PullIndicator.CornersEnabled() return sv().pull_icon_corners ~= false end   -- default on
function UP.PullIndicator.CenterEnabled()  return sv().pull_icon_center == true end     -- default off
function UP.PullIndicator.BordersEnabled() return sv().pull_border == true end          -- default off

local function previewActive()
    return previewUntilMs > 0 and GetGameTimeMilliseconds() < previewUntilMs
end

function UP.PullIndicator.IsPreviewActive() return previewActive() end
function UP.PullIndicator.PreviewDurationMs() return PREVIEW_DURATION_MS end

local function hudShown()
    if UP.UI and UP.UI.IsHudShown then return UP.UI.IsHudShown() end
    return true
end

-- Returns (showCorners, showCentre, showBorders).
local function wanted()
    local forced = previewActive()
    if not (active or forced) then return false, false, false end
    if not forced and not hudShown() then return false, false, false end
    local corners  = UP.PullIndicator.CornersEnabled()
    local center   = UP.PullIndicator.CenterEnabled()
    local borders  = UP.PullIndicator.BordersEnabled()
    if forced and not corners and not center and not borders then
        corners = true
    end
    return corners, center, borders
end

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

function UP.PullIndicator.UpdateVisibility()
    local corners, center, borders = wanted()
    drive(cornersRoot, cornersTimeline, corners, function()
        if cornersRoot and cornersRoot.SetAlpha then cornersRoot:SetAlpha(1) end
    end)
    drive(iconRoot, pulseTimeline, center, function()
        if iconPulse and iconPulse.SetAlpha then iconPulse:SetAlpha(0) end
    end)
    drive(bordersRoot, bordersTimeline, borders, function()
        if bordersRoot and bordersRoot.SetAlpha then bordersRoot:SetAlpha(1) end
    end)
end

-- Called by Engine/PullTracker on a transition. `setKey` names the set for the
-- debug overlay; every set uses the same colour-matched visuals today.
function UP.PullIndicator.SetActive(isActive, setKey)
    active = isActive == true
    activeSet = active and setKey or nil
    UP.PullIndicator.UpdateVisibility()
end

function UP.PullIndicator.ActiveSet() return activeSet end

-- For the debug overlay and the harness.
function UP.PullIndicator.IsShowing()
    local c = cornersRoot and not cornersRoot:IsHidden() or false
    local s = iconRoot and not iconRoot:IsHidden() or false
    local b = bordersRoot and not bordersRoot:IsHidden() or false
    return c, s, b
end

-- ---------------------------------------------------------------------------
-- Preview (Settings > Pull Indicator > Preview): same contract as the ring's.
-- ---------------------------------------------------------------------------
function UP.PullIndicator.RunPreview()
    if not (iconRoot or cornersRoot or bordersRoot) then return false end
    previewUntilMs = GetGameTimeMilliseconds() + PREVIEW_DURATION_MS
    UP.PullIndicator.UpdateVisibility()
    zo_callLater(function()
        if GetGameTimeMilliseconds() >= previewUntilMs then
            previewUntilMs = 0
        end
        UP.PullIndicator.UpdateVisibility()
    end, PREVIEW_DURATION_MS + 50)
    return true
end

-- ---------------------------------------------------------------------------
-- Init: each display disables itself if its control is missing, like the ring
-- ---------------------------------------------------------------------------
local function timelineFor(virtualName, target, what)
    if not (target and ANIMATION_MANAGER) then return nil end
    local ok, timeline = pcall(ANIMATION_MANAGER.CreateTimelineFromVirtual,
                               ANIMATION_MANAGER, virtualName, target)
    if ok then return timeline end
    UP.Note(("Pull %s animation unavailable; it will be static."):format(what))
    return nil
end

function UP.PullIndicator.Init()
    iconRoot    = UP_PullIconRoot
    cornersRoot = UP_PullCornersRoot
    bordersRoot = UP_PullBordersRoot
    if not (iconRoot or cornersRoot or bordersRoot) then
        UP.Note("Pull indicator controls missing; pull warnings disabled.")
        return false
    end

    if iconRoot then
        iconPulse = iconRoot:GetNamedChild("Pulse")
        if iconPulse then iconPulse:SetAlpha(0) end
        pulseTimeline = timelineFor("UP_PullIconPulse", iconPulse, "centre icon pulse")
        iconRoot:SetHidden(true)
    else
        UP.Note("Centre pull icon control missing; that display is disabled.")
    end

    if cornersRoot then
        cornersTimeline = timelineFor("UP_PullFlash", cornersRoot, "corner icon flash")
        cornersRoot:SetAlpha(1)
        cornersRoot:SetHidden(true)
    else
        UP.Note("Corner pull icon control missing; that display is disabled.")
    end

    if bordersRoot then
        bordersTimeline = timelineFor("UP_PullFlash", bordersRoot, "side border flash")
        bordersRoot:SetAlpha(1)
        bordersRoot:SetHidden(true)
    else
        UP.Note("Pull side border control missing; that display is disabled.")
    end
    return true
end
