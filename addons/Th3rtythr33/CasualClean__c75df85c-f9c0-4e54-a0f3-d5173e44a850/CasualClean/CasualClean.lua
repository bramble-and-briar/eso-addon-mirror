-- Shared namespace. Created here because this file is first in the manifest;
-- UI/MagStamArcs.lua, UI/QuestTracker.lua and Settings.lua hang their modules off it. All of
-- them are parsed before EVENT_ADD_ON_LOADED fires, so OnAddOnLoaded below
-- can call into them unconditionally.
CasualClean = CasualClean or {}
local CC = CasualClean

local ADDON_NAME = "CasualClean"

local COMPANION_TAG = "companion"
local HIDE_FRAME_REASON = "CasualCleanHideCompanionFrame"

-- Same map-pin texture ZOS uses for an active companion on the world map
-- (MAP_PIN_TYPE_ACTIVE_COMPANION in esoui/ingame/map/mappin.lua) -- already
-- reused/recolored this way by other shipped addons (e.g. OdySupportIcons).
local MARKER_TEXTURE = "EsoUI/Art/MapPins/activeCompanion_pin.dds"
-- Gamepad button-prompt up-arrow glyph (scrolltemplates_gamepad.xml) -- a
-- plain single-color icon, safe to tint and rotate to any angle.
local ARROW_TEXTURE = "EsoUI/Art/Buttons/Gamepad/gp_upArrow.dds"
-- Plain "X" glyph from the gamepad dyeing UI (dyeing_common_gamepad.xml's
-- disabled-dye-slot overlay) -- tintable there via a color attribute, and
-- already reused by at least one published addon the same way. Left at
-- its natural white tint here (not recolored) so it reads clearly over
-- the marker's own red-on-death color rather than blending into it.
local DEATH_X_TEXTURE = "EsoUI/Art/Dye/Gamepad/gp_Disabled_X.dds"

local MARKER_SIZE = 32
local ARROW_SIZE = 20
local DEATH_X_SIZE = 40
local EDGE_MARGIN = 48 -- px kept clear of the true screen edge when clamped
-- Raw world units added above the companion's feet-origin position.
-- **Measured in live play 2026-08-08**, replacing the original unmeasured
-- guess of 150. This is the base value, used for any companion without an
-- override -- companions are not all the same height (Zerith-var is notably
-- taller), so per-companion overrides keyed by def id sit on top of it.
local DEFAULT_HEAD_OFFSET_Y = 240
-- Sanity bounds on the tuning knob: wide enough that neither end is a real
-- constraint, narrow enough that a typo can't fling the marker somewhere
-- that looks identical to "the addon broke".
local HEAD_OFFSET_MIN = -500
local HEAD_OFFSET_MAX = 2000
local POLL_MS = 33 -- ~30Hz; a smaller per-tick delta makes the same smoothing look smoother
local NEAR_CLIP = 1 -- forward depth below this is behind the camera
-- Same EMA smoothing pattern DoesThisThingGoAnyFaster/AreYouSlow already
-- use for their own per-poll noisy readings -- here it absorbs both
-- camera micro-motion (movement bob/sway) and companion animation
-- position noise, since it's applied to the camera-space values both
-- feed into, before the on-screen/off-screen branch reads them.
-- **Settled by live play 2026-08-08 at 0.75**, after a measured sample showed
-- the raw projection signal carries no meaningful noise (per-tick step
-- deviation ~1.3%) while the previous 0.12 cost ~50px of trailing lag when
-- moving. The history is worth keeping: 0.35 -> 0.12 chased a camera-shake /
-- animation-noise hypothesis that the data did not support, and the fix
-- turned out to be smoothing far LESS, not more. 0.75 still damps a one-off
-- outlier by three quarters while tracking essentially without lag.
local DEFAULT_SMOOTHING_ALPHA = 0.75
-- 1.0 is a legitimate setting (no smoothing at all -- the marker tracks the
-- raw signal exactly); the low end is bounded well above 0 since alpha=0
-- would freeze the marker permanently at its first sample.
local SMOOTHING_ALPHA_MIN = 0.01
local SMOOTHING_ALPHA_MAX = 1.0
-- Hysteresis band around the on-screen/off-screen boundary: without this,
-- residual noise right at the exact edge can flip `onScreen` back and
-- forth every tick, which snaps the marker between two entirely different
-- coordinate systems (true projected position vs. edge-clamped position)
-- -- a much larger, more jarring jump than ordinary smoothing noise.
local ON_SCREEN_HYSTERESIS = 24 -- px

-- Health-based marker color: green at 100%, yellow at HEALTH_MID_PERCENT,
-- red at HEALTH_LOW_PERCENT and below. Between the two thresholds it's a
-- straight gradient; only one of R/G actually moves in each half (green
-- {0,1,0} -> yellow {1,1,0} only raises R, yellow -> red {1,0,0} only
-- lowers G), so no separate lerp helper is needed.
local HEALTH_MID_PERCENT = 0.6
local HEALTH_LOW_PERCENT = 0.01

-- Companion-pin settings (1.6.6). The pin master switch is a hard off: the
-- 30 Hz poll is unregistered, not merely drawing nothing. Hiding the default
-- companion unit frame is its own choice because some players want the pin
-- AND the frame's health bar.
local DEFAULT_COMPANION_MARKER = true
local DEFAULT_HIDE_COMPANION_FRAME = true

local abs, atan2, sin, cos, min, huge = math.abs, math.atan2, math.sin, math.cos, math.min, math.huge

local marker, arrow, deathX, cameraHelper, hudWindow
local uiW, uiH
local smoothedDepth, smoothedRight, smoothedUp
local wasOnScreen = false
-- Seeded with the default rather than left nil so ComputeProjection is safe
-- to call at any point, including before EVENT_ADD_ON_LOADED has built
-- savedVars. Read fresh every poll tick, so writing it takes effect on the
-- very next frame with no /reloadui.
local savedVars
local headOffsetY = DEFAULT_HEAD_OFFSET_Y
local smoothingAlpha = DEFAULT_SMOOTHING_ALPHA
-- Def id of whatever companion is currently out, 0 for none. Resolved from
-- GetActiveCompanionDefId() whenever state is refreshed rather than read per
-- tick, so ComputeCameraSpace keeps using a plain number.
local activeCompanionDefId = 0

-- Companions are not all the same height, so the base offset can be overridden
-- per companion. Keyed by def id rather than by name: locale-independent, and
-- it needs no hardcoded table of companions, so it covers any ZOS adds later.
local function EffectiveHeadOffset()
    local overrides = savedVars and savedVars.companionOffsets
    local override = overrides and activeCompanionDefId ~= 0 and overrides[activeCompanionDefId]
    return override or (savedVars and savedVars.headOffsetY) or DEFAULT_HEAD_OFFSET_Y
end

local function RefreshCompanionIdentity()
    activeCompanionDefId = GetActiveCompanionDefId() or 0
    headOffsetY = EffectiveHeadOffset()
end

local function CurrentCompanionLabel()
    if activeCompanionDefId == 0 then
        return nil
    end
    local name = GetCompanionName(activeCompanionDefId)
    if name and name ~= "" then
        return name
    end
    return "companion " .. activeCompanionDefId
end

-- Dungeons, Trials, Battlegrounds, and Cyrodiil each have their own native
-- query rather than one unified "instance type" function -- ESO calls
-- Trials "Raids" internally (confirmed via ZO_Death_IsRaidReviveAllowed's
-- use of IsPlayerInRaid for the Trial life/revive system). All four are
-- live player-state queries (not tied to whatever map the player merely has
-- open), and all four are established idioms already used by widely-run
-- addons (LuiExtended, CombatMetrics, Baertram's tools, among others).
--
-- Cyrodiil and Battlegrounds always disable the companion features (both are
-- inherently multiplayer PvP content). Dungeons and Trials only disable them
-- while actually grouped (IsUnitGrouped("player")) -- solo play in either
-- (e.g. soloing a normal dungeon, or a Trial undertaken alone) leaves them
-- running per explicit request.
--
-- SCOPE NOTE (changed 2026-08-08): this governs the COMPANION features only.
-- It used to be addon-wide, but the Mag/Stam Arcs were explicitly exempted --
-- they run everywhere, grouped or not. Do not reintroduce a call to this from
-- UI/MagStamArcs.lua.
local function IsInRestrictedContent()
    if IsActiveWorldBattleground() or IsInCyrodiil() then
        return true
    end
    return IsUnitGrouped("player") and (IsUnitInDungeon("player") or IsPlayerInRaid())
end

-- Still exposed for the /casualclean diagnostic output, which reports the
-- current restricted state. No longer consulted by the arcs.
CC.IsInRestrictedContent = IsInRestrictedContent

local function TryHideCompanionFrame()
    local frame = ZO_UnitFrames_GetUnitFrame(COMPANION_TAG)
    if frame then
        frame:SetHiddenForReason(HIDE_FRAME_REASON, true)
        return true
    end
    return false
end

-- ZOS creates the companion unit frame object in its own handler for the
-- same event we listen for; if ours runs first in the same tick,
-- GetUnitFrame can still be nil, so retry briefly rather than give up.
-- Both settings have to agree before the frame is hidden; a disabled pin
-- leaves the frame alone regardless of the hide-frame choice.
local function CompanionFrameShouldBeHidden()
    if not savedVars then
        return DEFAULT_COMPANION_MARKER and DEFAULT_HIDE_COMPANION_FRAME
    end
    return savedVars.companionMarker ~= false and savedVars.hideCompanionFrame ~= false
end

local function HideCompanionFrameWithRetry(attemptsLeft)
    -- Re-checked on every retry: a pending retry must not re-hide a frame the
    -- player un-hid in the settings a moment ago.
    if not CompanionFrameShouldBeHidden() then
        return
    end
    if TryHideCompanionFrame() or attemptsLeft <= 0 then
        return
    end
    zo_callLater(function() HideCompanionFrameWithRetry(attemptsLeft - 1) end, 250)
end

local function ShowCompanionFrame()
    local frame = ZO_UnitFrames_GetUnitFrame(COMPANION_TAG)
    if frame then
        frame:SetHiddenForReason(HIDE_FRAME_REASON, false)
    end
end

local function HideMarkers()
    marker:SetHidden(true)
    arrow:SetHidden(true)
    deathX:SetHidden(true)
end

-- Returns r, g, b, isDead. isDead is reported separately from the color
-- (rather than folded into a single "red" case) because a dead companion
-- also needs the X overlay shown, not just a color change.
local function GetCompanionHealthColor()
    if IsUnitDead(COMPANION_TAG) then
        return 1, 0, 0, true
    end

    local current, _, effectiveMax = GetUnitPower(COMPANION_TAG, COMBAT_MECHANIC_FLAGS_HEALTH)
    local percent = (effectiveMax > 0) and (current / effectiveMax) or 0
    if percent > 1 then percent = 1 end

    if percent > HEALTH_MID_PERCENT then
        local r = (1 - percent) / (1 - HEALTH_MID_PERCENT)
        return r, 1, 0, false
    elseif percent > HEALTH_LOW_PERCENT then
        local g = (percent - HEALTH_LOW_PERCENT) / (HEALTH_MID_PERCENT - HEALTH_LOW_PERCENT)
        return 1, g, 0, false
    else
        return 1, 0, 0, false
    end
end

-- Pure function of the current camera + companion position: no smoothed
-- state is read or written here. Split out from ComputeProjection so the
-- diagnostics can sample the raw signal WITHOUT advancing the EMA -- the
-- 2026-08-08 sample was taken with a sampler that did advance it, which is
-- why its observed lag came in below what the alpha/poll-rate model
-- predicts: every logged sample was itself pulling `smoothed` toward `raw`.
local function ComputeCameraSpace()
    local _, wx, wy, wz = GetUnitRawWorldPosition(COMPANION_TAG)
    wy = wy + headOffsetY

    Set3DRenderSpaceToCurrentCamera(cameraHelper:GetName())
    local camX, camY, camZ = GuiRender3DPositionToWorldPosition(cameraHelper:Get3DRenderSpaceOrigin())
    local fx, fy, fz = cameraHelper:Get3DRenderSpaceForward()
    local rx, ry, rz = cameraHelper:Get3DRenderSpaceRight()
    local ux, uy, uz = cameraHelper:Get3DRenderSpaceUp()

    local dx, dy, dz = wx - camX, wy - camY, wz - camZ
    return fx * dx + fy * dy + fz * dz,
           rx * dx + ry * dy + rz * dz,
           ux * dx + uy * dy + uz * dz
end

-- Shared by UpdateMarker and the /casualclean diagnostic command so both
-- always agree on how the companion's position maps to the screen.
local function ComputeProjection()
    local rawDepth, rawRight, rawUp = ComputeCameraSpace()

    -- First sample after a reset (companion just appeared, polling just
    -- started) snaps straight to the raw value -- otherwise the marker
    -- would visibly glide in from wherever the stale smoothed state was.
    smoothedDepth = smoothedDepth and (smoothedDepth + smoothingAlpha * (rawDepth - smoothedDepth)) or rawDepth
    smoothedRight = smoothedRight and (smoothedRight + smoothingAlpha * (rawRight - smoothedRight)) or rawRight
    smoothedUp = smoothedUp and (smoothedUp + smoothingAlpha * (rawUp - smoothedUp)) or rawUp
    local depth, right, up = smoothedDepth, smoothedRight, smoothedUp

    local onScreen, screenX, screenY = false, 0, 0
    if depth >= NEAR_CLIP then
        local frustumW, frustumH = GetWorldDimensionsOfViewFrustumAtDepth(depth)
        screenX = right * (uiW / frustumW)
        screenY = -up * (uiH / frustumH)
        -- Threshold shifts depending on the current state (hysteresis):
        -- once on-screen, it takes crossing past the boundary by
        -- ON_SCREEN_HYSTERESIS px to switch to off-screen, and vice versa,
        -- so noise sitting right at the edge can't flap the mode every tick.
        local marginX = wasOnScreen and (uiW / 2 + ON_SCREEN_HYSTERESIS) or (uiW / 2 - ON_SCREEN_HYSTERESIS)
        local marginY = wasOnScreen and (uiH / 2 + ON_SCREEN_HYSTERESIS) or (uiH / 2 - ON_SCREEN_HYSTERESIS)
        onScreen = abs(screenX) <= marginX and abs(screenY) <= marginY
    end
    wasOnScreen = onScreen

    return depth, right, up, onScreen, screenX, screenY, rawDepth, rawRight, rawUp
end

-- deathX always sits exactly on top of the marker's current position
-- (whichever branch placed it), regardless of on-screen vs. edge-clamped.
local function PositionDeathX(x, y, isDead)
    if not isDead then
        deathX:SetHidden(true)
        return
    end
    deathX:ClearAnchors()
    deathX:SetAnchor(CENTER, GuiRoot, CENTER, x, y)
    deathX:SetHidden(false)
end

local function UpdateMarker()
    if not DoesUnitExist(COMPANION_TAG) then
        HideMarkers()
        return
    end

    local r, g, b, isDead = GetCompanionHealthColor()
    marker:SetColor(r, g, b, 1)
    arrow:SetColor(r, g, b, 1)

    local depth, right, up, onScreen, screenX, screenY = ComputeProjection()

    if onScreen then
        marker:ClearAnchors()
        marker:SetAnchor(CENTER, GuiRoot, CENTER, screenX, screenY)
        marker:SetHidden(false)
        arrow:SetHidden(true)
        PositionDeathX(screenX, screenY, isDead)
        return
    end

    -- Off-screen (behind the camera, or simply outside the FOV cone):
    -- horizontal bearing relative to straight-ahead, valid in both cases.
    local theta = atan2(right, depth)
    local dirX, dirY = sin(theta), -cos(theta)
    local halfW, halfH = uiW / 2 - EDGE_MARGIN, uiH / 2 - EDGE_MARGIN
    local scaleX = (dirX ~= 0) and (halfW / abs(dirX)) or huge
    local scaleY = (dirY ~= 0) and (halfH / abs(dirY)) or huge
    local t = min(scaleX, scaleY)
    local edgeX, edgeY = dirX * t, dirY * t

    marker:ClearAnchors()
    marker:SetAnchor(CENTER, GuiRoot, CENTER, edgeX, edgeY)
    marker:SetHidden(false)
    PositionDeathX(edgeX, edgeY, isDead)

    arrow:ClearAnchors()
    arrow:SetAnchor(CENTER, GuiRoot, CENTER, edgeX + dirX * (MARKER_SIZE * 0.6), edgeY + dirY * (MARKER_SIZE * 0.6))
    -- Negated: SetTextureRotation turns the opposite way to the bearing
    -- convention theta is measured in (clockwise from straight-ahead), so
    -- an un-negated theta points the arrow at the mirror image of the
    -- companion's actual direction. Confirmed in live play 2026-08-08 --
    -- the sign here is the only place that flips: dirX/dirY above still
    -- use the un-negated theta, and the edge-clamped position they produce
    -- is correct as-is.
    arrow:SetTextureRotation(-theta, 0.5, 0.5)
    arrow:SetHidden(false)
end

local function StartPolling()
    -- Discard any smoothed state from a previous polling session so the
    -- first sample snaps to the companion's actual current position
    -- instead of smoothing in from wherever tracking last left off.
    smoothedDepth, smoothedRight, smoothedUp = nil, nil, nil
    wasOnScreen = false
    EVENT_MANAGER:RegisterForUpdate("CasualCleanPoll", POLL_MS, UpdateMarker)
end

local function StopPolling()
    EVENT_MANAGER:UnregisterForUpdate("CasualCleanPoll")
    HideMarkers()
end

local function CreateControls()
    -- Dedicated top-level window rather than parenting marker/arrow
    -- directly to GuiRoot -- matching how the published addon Breadcrumbs
    -- (the source this whole positioning technique is based on) sets up
    -- its own equivalent marker controls. A bare GuiRoot child with no
    -- explicit draw layer/tier has no guaranteed place in the compositing
    -- order; on console there's no error surfaced if that leaves it
    -- rendered but never actually visible, so this isn't worth leaving to
    -- an unconfirmed default.
    hudWindow = WINDOW_MANAGER:CreateTopLevelWindow("CasualCleanWindow")
    hudWindow:SetAnchorFill(GuiRoot)
    hudWindow:SetMouseEnabled(false)
    hudWindow:SetMovable(false)
    hudWindow:SetDrawLayer(DL_BACKGROUND)
    hudWindow:SetDrawTier(DT_LOW)
    hudWindow:SetDrawLevel(0)

    -- Colors for marker/arrow are set dynamically every poll from the
    -- companion's current health (GetCompanionHealthColor), not fixed here.
    marker = WINDOW_MANAGER:CreateControl("CasualCleanMarker", hudWindow, CT_TEXTURE)
    marker:SetTexture(MARKER_TEXTURE)
    marker:SetDimensions(MARKER_SIZE, MARKER_SIZE)
    marker:SetDrawLevel(50)
    marker:SetHidden(true)

    arrow = WINDOW_MANAGER:CreateControl("CasualCleanArrow", hudWindow, CT_TEXTURE)
    arrow:SetTexture(ARROW_TEXTURE)
    arrow:SetDimensions(ARROW_SIZE, ARROW_SIZE)
    arrow:SetDrawLevel(50)
    arrow:SetHidden(true)

    -- Drawn above the marker (higher draw level, same parent/tier) so the
    -- X reads as an overlay on top of the pin rather than being obscured
    -- by it.
    deathX = WINDOW_MANAGER:CreateControl("CasualCleanDeathX", hudWindow, CT_TEXTURE)
    deathX:SetTexture(DEATH_X_TEXTURE)
    deathX:SetDimensions(DEATH_X_SIZE, DEATH_X_SIZE)
    deathX:SetDrawLevel(60)
    deathX:SetHidden(true)

    -- Camera-basis helper: not itself visible, only queried for its
    -- Get3DRenderSpace*() vectors -- but anchor-filled to GuiRoot to match
    -- Breadcrumbs' equivalent control exactly, in case that's load-bearing
    -- for Set3DRenderSpaceToCurrentCamera rather than incidental.
    cameraHelper = WINDOW_MANAGER:CreateControl("CasualCleanCameraHelper", GuiRoot, CT_CONTROL)
    cameraHelper:SetAnchorFill(GuiRoot)
    cameraHelper:Create3DRenderSpace()
    cameraHelper:SetHidden(true)

    -- Hidden automatically outside HUD/HUD_UI scenes (menus, dialogues,
    -- map) -- applied to the shared window so marker/arrow inherit it
    -- through the normal parent-hidden chain, rather than tracking two
    -- separate fragments that could fall out of sync with each other.
    local fragment = ZO_SimpleSceneFragment:New(hudWindow)
    HUD_SCENE:AddFragment(fragment)
    HUD_UI_SCENE:AddFragment(fragment)

    uiW, uiH = GuiRoot:GetDimensions()
end

-- Single source of truth for whether the addon should be doing anything at
-- all right now, re-run from every event that could change either half of
-- that answer (companion summoned/dismissed, or entering/leaving
-- restricted content). Re-checking here rather than trusting each event's
-- own "did I just enter a dungeon" framing keeps the two conditions
-- (companion active, content restricted) from drifting out of sync.
local function RefreshState()
    -- Which companion is out decides the effective head offset, so resolve it
    -- here rather than per tick -- every event that can change the companion
    -- already routes through this function.
    RefreshCompanionIdentity()

    -- The arcs no longer share the restricted-content rule, but they are
    -- still refreshed from here: EVENT_PLAYER_ACTIVATED is how they recover
    -- after a loading screen, and re-asserting the default-bar hiding is
    -- cheap and idempotent.
    if CC.MagStamArcs then
        CC.MagStamArcs.Refresh()
    end
    -- Same idea for the quest tracker: Refresh is idempotent, and re-asserting
    -- the scene membership and hidden reason after a loading screen is cheap.
    if CC.QuestTracker then
        CC.QuestTracker.Refresh()
    end

    -- Master switch first: off means no poll, no hidden frame, whatever the
    -- content. Then the restricted-content rule, then the companion itself.
    if (savedVars and savedVars.companionMarker == false) or IsInRestrictedContent() then
        StopPolling()
        ShowCompanionFrame()
        return
    end

    if DoesUnitExist(COMPANION_TAG) then
        if CompanionFrameShouldBeHidden() then
            HideCompanionFrameWithRetry(4)
        else
            ShowCompanionFrame()
        end
        StartPolling()
    else
        StopPolling()
    end
end

-- Settings-panel surface for the companion features. Setters write the saved
-- variable and re-run RefreshState, which is the single place that turns
-- those values into polling and frame visibility.
CC.Companion = {
    DEFAULT_MARKER = DEFAULT_COMPANION_MARKER,
    DEFAULT_HIDE_FRAME = DEFAULT_HIDE_COMPANION_FRAME,
}

function CC.Companion.GetEnabled()
    if savedVars and savedVars.companionMarker ~= nil then
        return savedVars.companionMarker
    end
    return DEFAULT_COMPANION_MARKER
end

function CC.Companion.SetEnabled(value)
    if savedVars then
        savedVars.companionMarker = value and true or false
    end
    RefreshState()
end

function CC.Companion.GetHideFrame()
    if savedVars and savedVars.hideCompanionFrame ~= nil then
        return savedVars.hideCompanionFrame
    end
    return DEFAULT_HIDE_COMPANION_FRAME
end

function CC.Companion.SetHideFrame(value)
    if savedVars then
        savedVars.hideCompanionFrame = value and true or false
    end
    RefreshState()
end

local function OnAddOnLoaded(eventCode, addonName)
    if addonName ~= ADDON_NAME then
        return
    end
    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)

    -- Account-wide rather than per-character: this tracks companion model
    -- height, which doesn't vary by who you're playing. Must be constructed
    -- in this handler specifically or nothing actually persists (documented
    -- in ZOS's own zo_savedvars.lua).
    savedVars = ZO_SavedVars:NewAccountWide("CasualCleanVars", 1, nil, {
        headOffsetY = DEFAULT_HEAD_OFFSET_Y,
        smoothingAlpha = DEFAULT_SMOOTHING_ALPHA,
        -- Per-companion overrides keyed by GetActiveCompanionDefId(). Starts
        -- empty and fills in as companions are tuned, so no hardcoded table
        -- of companion heights is needed and future companions are covered.
        companionOffsets = {},
        fillDirection = CC.MagStamArcs.DEFAULT_FILL_DIRECTION,
        arcOffsetX = CC.MagStamArcs.DEFAULT_ARC_OFFSET_X,
        arcHeight = CC.MagStamArcs.DEFAULT_ARC_HEIGHT,
        hideDefaultBars = CC.MagStamArcs.DEFAULT_HIDE_DEFAULT_BARS,
        -- One flag per HUD tracker group (quest, Golden Pursuit); the module
        -- owns the list, so new groups need no change here.
        questTrackerInMenu = CC.QuestTracker.DEFAULTS.questTrackerInMenu,
        pursuitTrackerInMenu = CC.QuestTracker.DEFAULTS.pursuitTrackerInMenu,
        trackerPeek = CC.QuestTracker.DEFAULTS.trackerPeek,
        trackerPeekSeconds = CC.QuestTracker.DEFAULTS.trackerPeekSeconds,
        -- 1.6.6 master switches and the companion-frame choice. All default
        -- to the pre-1.6.6 behaviour so an upgrade changes nothing.
        arcsEnabled = CC.MagStamArcs.DEFAULT_ENABLED,
        companionMarker = DEFAULT_COMPANION_MARKER,
        hideCompanionFrame = DEFAULT_HIDE_COMPANION_FRAME,
    })
    headOffsetY = savedVars.headOffsetY
    smoothingAlpha = savedVars.smoothingAlpha
    CC.sv = savedVars

    CreateControls()

    -- Order matters: the arcs build their controls and read defaults, then
    -- the settings panel binds getters/setters to them.
    CC.MagStamArcs.Init()
    CC.QuestTracker.Init()
    CC.Settings.Init()

    EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ACTIVE_COMPANION_STATE_CHANGED, RefreshState)
    -- EVENT_ACTIVE_COMPANION_STATE_CHANGED doesn't fire retroactively for a
    -- companion already active before this addon loaded/reloaded, and
    -- restricted-content status can likewise change without either of
    -- those specific events -- EVENT_PLAYER_ACTIVATED (post-load-screen)
    -- and EVENT_ZONE_CHANGED (sub-zone transitions without a load screen)
    -- between them cover dungeon/trial/battleground/Cyrodiil entry and exit.
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_PLAYER_ACTIVATED, RefreshState)
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ZONE_CHANGED, RefreshState)
    -- Since Dungeon/Trial restriction now depends on group status too, not
    -- just location, a group forming or breaking up mid-dungeon needs to
    -- re-evaluate state on its own -- neither event above fires for that.
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_GROUP_MEMBER_JOINED, RefreshState)
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_GROUP_MEMBER_LEFT, RefreshState)
    -- Swapping directly from one companion to another needs the effective
    -- head offset re-resolved even if the active-companion STATE never leaves
    -- "active". This event is named for exactly that transition and carries
    -- the companionId, so it is the reliable signal rather than an inference
    -- from the state-changed event's newState/oldState pair.
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_COMPANION_ACTIVATED, RefreshState)
end

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, OnAddOnLoaded)

local function LogProjectionSample(label)
    if not (hudWindow and DoesUnitExist(COMPANION_TAG)) then
        d("CasualClean: no companion active, nothing to sample")
        return
    end
    local depth, right, up, onScreen, screenX, screenY, rawDepth, rawRight, rawUp = ComputeProjection()
    d(string.format(
        "CasualClean %s: raw(d=%.0f r=%.0f u=%.0f) smoothed(d=%.0f r=%.0f u=%.0f) onScreen=%s x=%.0f y=%.0f",
        label, rawDepth, rawRight, rawUp, depth, right, up, tostring(onScreen), screenX, screenY
    ))
end

local OFFSET_USAGE = "CasualClean: usage -- /casualclean offset <value|+N|-N> | base <value> | clear | reset"

-- Writes to the ACTIVE COMPANION's override, or to the shared base if
-- `toBase` is set or nobody is out. Tuning while a companion is summoned is
-- therefore always about that companion, which is the common case -- the base
-- only moves when asked for explicitly.
local function SetHeadOffset(value, toBase)
    if value < HEAD_OFFSET_MIN then value = HEAD_OFFSET_MIN end
    if value > HEAD_OFFSET_MAX then value = HEAD_OFFSET_MAX end

    local target
    if toBase or activeCompanionDefId == 0 then
        if savedVars then savedVars.headOffsetY = value end
        target = "base"
    else
        if savedVars then savedVars.companionOffsets[activeCompanionDefId] = value end
        target = CurrentCompanionLabel()
    end

    headOffsetY = EffectiveHeadOffset()
    -- Drop only the vertical smoothed component, so the marker snaps to the
    -- new height on the next tick instead of easing into it -- makes A/B
    -- comparing two offsets crisp. depth/right aren't affected by this
    -- setting at all, so they keep their smoothed state and the marker
    -- doesn't jump sideways.
    smoothedUp = nil
    d(string.format("CasualClean: set %s offset = %.0f; effective now %.0f", target, value, headOffsetY))
end

local function SetSmoothingAlpha(value)
    if value < SMOOTHING_ALPHA_MIN then value = SMOOTHING_ALPHA_MIN end
    if value > SMOOTHING_ALPHA_MAX then value = SMOOTHING_ALPHA_MAX end
    smoothingAlpha = value
    if savedVars then
        savedVars.smoothingAlpha = value
    end
    -- Clear all three channels, not just one: alpha changes the character of
    -- the whole filter, so carrying over state converged under the old value
    -- would make the first second after the change misrepresent the new one.
    smoothedDepth, smoothedRight, smoothedUp = nil, nil, nil
    d(string.format("CasualClean: smoothingAlpha = %.2f (default %.2f; 1.00 = no smoothing)",
        smoothingAlpha, DEFAULT_SMOOTHING_ALPHA))
end

local function HandleAlphaCommand(rest)
    if rest == "" then
        d(string.format(
            "CasualClean: smoothingAlpha = %.2f (default %.2f) -- usage: /casualclean alpha <0.01-1.0|reset>",
            smoothingAlpha, DEFAULT_SMOOTHING_ALPHA
        ))
        return
    end
    if rest == "reset" then
        SetSmoothingAlpha(DEFAULT_SMOOTHING_ALPHA)
        return
    end
    local value = tonumber(rest)
    if not value then
        d("CasualClean: usage -- /casualclean alpha <0.01-1.0|reset>")
        return
    end
    SetSmoothingAlpha(value)
end

local function HandleOffsetCommand(rest)
    if rest == "" then
        local base = (savedVars and savedVars.headOffsetY) or DEFAULT_HEAD_OFFSET_Y
        d(string.format("CasualClean: effective offset %.0f -- base %.0f (default %.0f)",
            headOffsetY, base, DEFAULT_HEAD_OFFSET_Y))
        local who = CurrentCompanionLabel()
        if who then
            local override = savedVars and savedVars.companionOffsets[activeCompanionDefId]
            d(string.format("  active: %s (defId %d)%s", who, activeCompanionDefId,
                override and string.format(" -- override %.0f", override) or " -- no override, using base"))
        else
            d("  active: none -- changes would apply to the base")
        end
        d(OFFSET_USAGE)
        return
    end

    if rest == "reset" then
        if savedVars then
            savedVars.headOffsetY = DEFAULT_HEAD_OFFSET_Y
            savedVars.companionOffsets = {}
        end
        headOffsetY = EffectiveHeadOffset()
        smoothedUp = nil
        d(string.format("CasualClean: reset to base %.0f, all per-companion overrides cleared", headOffsetY))
        return
    end

    if rest == "clear" then
        if activeCompanionDefId == 0 then
            d("CasualClean: no companion active, no override to clear")
            return
        end
        local who = CurrentCompanionLabel()
        if savedVars then savedVars.companionOffsets[activeCompanionDefId] = nil end
        headOffsetY = EffectiveHeadOffset()
        smoothedUp = nil
        d(string.format("CasualClean: cleared %s override, now using base %.0f", who, headOffsetY))
        return
    end

    local sub, tail = string.match(rest, "^(%S*)%s*(.-)$")
    if sub == "base" then
        local value = tonumber(tail)
        if not value then
            d(OFFSET_USAGE)
            return
        end
        SetHeadOffset(value, true)
        return
    end

    -- A leading +/- is a relative nudge, which is what repeated tuning
    -- actually wants ("a bit higher, a bit higher still") -- a bare number is
    -- absolute. The sign has to be read off the string before conversion,
    -- not inferred from the result: tonumber("+10") is just 10, so a
    -- result-based check couldn't tell "+10" from "10".
    local sign = string.sub(rest, 1, 1)
    local value = tonumber(rest)
    if not value then
        d(OFFSET_USAGE)
        return
    end

    if sign == "+" or sign == "-" then
        SetHeadOffset(headOffsetY + value, false)
    else
        SetHeadOffset(value, false)
    end
end

-- Burst sampler. The "/casualclean [count]" sampler logs ~200ms apart, which
-- is far too coarse to answer the question that actually matters now: does
-- GetUnitRawWorldPosition update every tick, or does it step at a lower
-- network tick rate while the engine interpolates the companion's rendered
-- body smoothly? A 5Hz sampler aliases a 10Hz staircase into a perfectly
-- clean-looking ramp -- which is exactly what the 2026-08-08 sample showed,
-- so that sample cannot distinguish the two cases. This one samples at the
-- real poll rate and reports how often the raw value didn't change at all
-- between ticks, which tells the two apart directly. Buffered rather than
-- logged live: 30 chat writes at 30Hz would both flood the window and
-- perturb the thing being measured.
local BURST_MAX = 60
local burstD, burstR, burstU = {}, {}, {}
local burstCount, burstTarget = 0, 0

local function ReportBurst()
    EVENT_MANAGER:UnregisterForUpdate("CasualCleanBurst")
    if burstCount < 2 then
        d("CasualClean burst: too few samples to report")
        return
    end

    local held, sumStep, maxStep, minStep = 0, 0, 0, huge
    local dr, du, dd = {}, {}, {}
    for i = 2, burstCount do
        local sd = burstD[i] - burstD[i - 1]
        local sr = burstR[i] - burstR[i - 1]
        local su = burstU[i] - burstU[i - 1]
        -- All three identical means the raw world position and the camera
        -- both failed to advance this tick -- i.e. a held step, not motion.
        if sd == 0 and sr == 0 and su == 0 then
            held = held + 1
        end
        local step = abs(sr)
        sumStep = sumStep + step
        if step > maxStep then maxStep = step end
        if step < minStep then minStep = step end
        dd[#dd + 1] = string.format("%.0f", sd)
        dr[#dr + 1] = string.format("%.0f", sr)
        du[#du + 1] = string.format("%.0f", su)
    end

    local steps = burstCount - 1
    local meanStep = sumStep / steps
    -- max/mean of the per-tick step is the load-bearing number here, not
    -- `held`. `held` only fires when the CAMERA is static too -- if the
    -- player is turning, camera-space values shift every tick even while the
    -- unit's own position is stepping, and held reads 0 despite a real
    -- staircase (verified against simulated data both ways). The ratio
    -- survives that: it stays ~1.0 for a genuinely per-tick signal, and rises
    -- to roughly the number of ticks per update when the source is stepped.
    local stepRatio = (meanStep > 0) and (maxStep / meanStep) or 0
    d(string.format("CasualClean burst: %d ticks @%dms -- held=%d/%d (%.0f%%, only meaningful if standing still)",
        burstCount, POLL_MS, held, steps, held / steps * 100))
    d(string.format("  |dRight| per tick: min=%.0f mean=%.1f max=%.0f -- max/mean=%.1f (~1 = smooth, >=2 = stepped)",
        minStep, meanStep, maxStep, stepRatio))
    d("  dDepth: " .. table.concat(dd, " "))
    d("  dRight: " .. table.concat(dr, " "))
    d("  dUp:    " .. table.concat(du, " "))
end

local function BurstTick()
    if not DoesUnitExist(COMPANION_TAG) then
        EVENT_MANAGER:UnregisterForUpdate("CasualCleanBurst")
        d("CasualClean burst: companion gone, aborted")
        return
    end
    burstCount = burstCount + 1
    -- ComputeCameraSpace, not ComputeProjection: sampling must not advance
    -- the EMA, or the diagnostic changes the marker it is measuring.
    burstD[burstCount], burstR[burstCount], burstU[burstCount] = ComputeCameraSpace()
    if burstCount >= burstTarget then
        ReportBurst()
    end
end

local function HandleBurstCommand(rest)
    if not (hudWindow and DoesUnitExist(COMPANION_TAG)) then
        d("CasualClean: no companion active, nothing to sample")
        return
    end
    local n = tonumber(rest) or 30
    if n < 2 then n = 2 end
    if n > BURST_MAX then n = BURST_MAX end
    burstCount, burstTarget = 0, n
    EVENT_MANAGER:RegisterForUpdate("CasualCleanBurst", POLL_MS, BurstTick)
    d(string.format("CasualClean: sampling %d ticks at %dms, keep moving...", n, POLL_MS))
end

-- Console never surfaces Lua errors to the player, so "it's not working" /
-- "still jittery" reports otherwise come with nothing to go on. Jitter is
-- a pattern across several samples, not a single snapshot, so
-- "/casualclean [count]" (default 1, max 20) logs that many samples
-- ~200ms apart -- comparing raw vs. smoothed columns across them shows
-- both how noisy the raw signal actually is and whether smoothing is
-- visibly damping it.
--
-- "/casualclean offset [value|+N|-N|reset]" live-tunes the marker's height
-- above the companion. Tuning scaffold rather than a shipped setting: once
-- the right height is known, DEFAULT_HEAD_OFFSET_Y should become that value
-- and this subcommand can retire (same spirit as APIAUDITS.md's retired
-- probes -- it exists to answer an open question, not forever).
SLASH_COMMANDS["/casualclean"] = function(args)
    local cmd, rest = string.match(args or "", "^%s*(%S*)%s*(.-)%s*$")

    if cmd == "offset" then
        HandleOffsetCommand(rest)
        return
    elseif cmd == "alpha" then
        HandleAlphaCommand(rest)
        return
    elseif cmd == "burst" then
        HandleBurstCommand(rest)
        return
    elseif cmd == "tracker" then
        -- Whether the first-party globals resolved, which hidden reasons are
        -- set, and which scenes the tracker fragments currently belong to.
        -- This is the only window into the feature on console.
        for _, line in ipairs(CC.QuestTracker.GetReport()) do
            d("  " .. line)
        end
        return
    elseif cmd == "arcs" then
        -- Reports both gradient stops for each power type. Which of START/END
        -- reads better as a solid arc fill is a visual question that can't be
        -- settled from source; this settles it in one look instead of a
        -- guess-and-upload round.
        -- No `restricted=` here on purpose: the Mag/Stam Arcs ignore
        -- restricted content entirely, so reporting it alongside them would
        -- imply a relationship that no longer exists. It is still in the main
        -- /casualclean status line, where it governs the companion features.
        d(string.format("CasualClean arcs: direction=%s offsetX=%.0f height=%.0f hideDefaultBars=%s",
            CC.MagStamArcs.GetFillDirectionName(), savedVars and savedVars.arcOffsetX or -1,
            savedVars and savedVars.arcHeight or -1,
            tostring(savedVars and savedVars.hideDefaultBars)))
        for _, line in ipairs(CC.MagStamArcs.GetColorReport()) do
            d("  " .. line)
        end
        return
    end

    d(string.format(
        "CasualClean: companion=%s restricted=%s windowHidden=%s markerHidden=%s offset=%.0f alpha=%.2f pin=%s hideFrame=%s arcs=%s",
        tostring(DoesUnitExist(COMPANION_TAG)),
        tostring(IsInRestrictedContent()),
        tostring(hudWindow and hudWindow:IsHidden()),
        tostring(marker and marker:IsHidden()),
        headOffsetY,
        smoothingAlpha,
        tostring(CC.Companion.GetEnabled()),
        tostring(CC.Companion.GetHideFrame()),
        tostring(CC.MagStamArcs.GetEnabled())
    ))

    if DoesUnitExist(COMPANION_TAG) then
        local r, g, b, isDead = GetCompanionHealthColor()
        d(string.format("CasualClean: dead=%s color=(%.2f, %.2f, %.2f) who=%s defId=%d",
            tostring(isDead), r, g, b, CurrentCompanionLabel() or "?", activeCompanionDefId))
    end

    local count = tonumber(args) or 1
    if count < 1 then count = 1 end
    if count > 20 then count = 20 end
    for i = 1, count do
        zo_callLater(function() LogProjectionSample(i .. "/" .. count) end, (i - 1) * 200)
    end
end
