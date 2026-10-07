-- =============================================================================
-- Under Pressure -- UI/Indicator.lua
-- =============================================================================
-- Drives the on-screen indicator.
--
-- The indicator is either a single "base" shape (green square, yellow ring,
-- yellow filled circle) or a vertical stack of 1, 2, or 3 same-size red
-- triangles. The base shape and triangle stack are pinned to the BOTTOM of
-- the root, so the column grows UPWARD as more triangles are added while
-- the bottom edge stays fixed on screen.
--
-- Counter: a single attacker count is drawn centered on the bottom indicator
-- tile. NPC/PLR split was removed in 0.2.6 because ESO console runtime does
-- not expose attacker source type.
--
-- Visibility: by default the indicator is hidden when the player is OUT of
-- combat or DEAD. The "Always show indicator" setting overrides both. It is
-- always hidden while a menu is open, which no setting overrides -- see
-- wireSceneVisibility() below.
-- =============================================================================

UP = UP or {}
UP.UI = UP.UI or {}

local TEXTURE_PATH = "UnderPressure/UI/Textures/"

local TILE = 80
local ROOT_WIDTH = TILE

-- Counter size bounds come from the gamepad font ladder in UI/Fonts.lua
-- rather than being hardcoded here, so the slider can never ask for a size
-- outside the range of fonts that actually exist on console.
local MIN_COUNTER_SIZE = UP.Fonts.MIN_SIZE
local MAX_COUNTER_SIZE = UP.Fonts.MAX_SIZE
local DEFAULT_COUNTER_SIZE = 27

local BASE_TEXTURE = {
    green_square   = TEXTURE_PATH .. "green_square.dds",
    yellow_empty   = TEXTURE_PATH .. "yellow_empty.dds",
    yellow_filled  = TEXTURE_PATH .. "yellow_filled.dds",
}

local TRIANGLE_COUNT = {
    green_square   = 0,
    yellow_empty   = 0,
    yellow_filled  = 0,
    red_one        = 1,
    red_two        = 2,
    red_three      = 3,
}

-- Severity ordering lives in the engine (UP.STATE_SEVERITY) because the
-- persistence gate needs it too. Kept as a local alias for brevity.
local STATE_SEVERITY = UP.STATE_SEVERITY

local root, base, tris, counterLabel
local currentState = "green_square"
-- Latest known combat / alive state from the engine + event handlers, used
-- by UpdateVisibility() to decide whether to show the indicator.
local lastInCombat = false
local lastDead     = false
-- Whether the in-world HUD is currently on screen. False while a menu,
-- inventory, map, etc. is up. See wireSceneVisibility().
local lastHudShown = true

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

local function clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

-- ---------------------------------------------------------------------------
-- De-escalation fade for triangles 2 and 3 (0.3.2)
-- ---------------------------------------------------------------------------
-- Triangle 1 (bottom of the stack) keeps the original behaviour: it hides
-- the instant the published state drops below it, no fade -- see applyState.
-- Triangles 2 and 3, the more severe marks, linger instead: a graduated
-- fade from the normal resting alpha down through 75% / 50% / 25% (one 200ms
-- segment each, interpolated smoothly within the segment rather than jumping
-- at the boundary) before finally hiding.
--
-- This is entirely independent of the engine's state_persistence_ms hold.
-- That hold still gates WHEN the published state -- and hence the new
-- triangle count -- changes; this only governs how a triangle that falls out
-- of the new count is removed from the screen once it does.
--
-- Escalating back into a triangle mid-fade needs no special-case code: the
-- cancel branch in applyState below unhides it immediately, and
-- pulseBrighten() (already called from SetState on any escalation) snaps it
-- to full opacity the same way it already does for every other visible mark.
local FADE_NAMESPACE = "UnderPressure_TriFade"
local FADE_TICK_MS   = 50    -- interpolation granularity, not a step size
local FADE_TOTAL_MS  = 600   -- three 200ms segments
local RESTING_ALPHA  = 0.92  -- shared with pulseBrighten / settleFade below

-- Segment boundaries and target alpha, matching the spec exactly: 200ms ->
-- 75%, 400ms -> 50%, 600ms -> 25%, then hidden.
local FADE_SEGMENTS = {
    { untilMs = 200, from = RESTING_ALPHA, to = 0.75 },
    { untilMs = 400, from = 0.75,          to = 0.50 },
    { untilMs = 600, from = 0.50,          to = 0.25 },
}

local function fadeAlphaAt(elapsedMs)
    for _, seg in ipairs(FADE_SEGMENTS) do
        if elapsedMs <= seg.untilMs then
            local segStart = seg.untilMs - 200
            local t = (elapsedMs - segStart) / 200
            if t < 0 then t = 0 elseif t > 1 then t = 1 end
            return seg.from + (seg.to - seg.from) * t
        end
    end
    return 0
end

-- Height must account for a triangle that's technically past the current
-- state's triangle count but still visually lingering in a fade -- shrinking
-- the root early would risk cutting it off mid-animation.
local function updateRootHeight(triCount)
    if not root then return end
    local top = triCount
    if tris[3] and not tris[3]:IsHidden() then top = math.max(top, 3) end
    if tris[2] and not tris[2]:IsHidden() then top = math.max(top, 2) end
    root:SetDimensions(ROOT_WIDTH, (top > 0) and (top * TILE) or TILE)
end

local fadeStartMs = {}  -- [2] / [3] -> GetGameTimeMilliseconds() when started

local function stopFadeIndex(i)
    fadeStartMs[i] = nil
end

local function updateFades()
    local now = GetGameTimeMilliseconds()
    local stillActive = false
    for i = 2, 3 do
        local start = fadeStartMs[i]
        if start then
            local elapsed = now - start
            local t = tris[i]
            if elapsed >= FADE_TOTAL_MS then
                fadeStartMs[i] = nil
                if t then
                    t:SetHidden(true)
                    if t.SetColor then t:SetColor(1, 1, 1, RESTING_ALPHA) end
                end
            else
                stillActive = true
                if t and t.SetColor then t:SetColor(1, 1, 1, fadeAlphaAt(elapsed)) end
            end
        end
    end
    updateRootHeight(TRIANGLE_COUNT[currentState] or 0)
    if not stillActive then
        EVENT_MANAGER:UnregisterForUpdate(FADE_NAMESPACE)
    end
end

local function startFadeIndex(i)
    if fadeStartMs[i] then return end  -- already fading; don't restart it
    fadeStartMs[i] = GetGameTimeMilliseconds()
    EVENT_MANAGER:RegisterForUpdate(FADE_NAMESPACE, FADE_TICK_MS, updateFades)
end

-- ---------------------------------------------------------------------------
-- State application (declared before Init so Init can call it)
-- ---------------------------------------------------------------------------
local function applyState(newState, force)
    if not force and newState == currentState then return end
    local triCount = TRIANGLE_COUNT[newState] or 0
    local baseTex  = BASE_TEXTURE[newState]

    if base then
        if baseTex then
            base:SetTexture(baseTex)
            base:SetHidden(false)
        else
            base:SetHidden(true)
        end
    end

    -- Triangle 1: default behaviour, unchanged -- shows/hides immediately
    -- with the state, no fade.
    local t1 = tris[1]
    if t1 then t1:SetHidden(1 > triCount) end

    -- Triangles 2 and 3: falling out of the new count starts a fade instead
    -- of hiding immediately. Coming back into the count cancels any fade in
    -- progress and shows it immediately (see the block comment above).
    for i = 2, 3 do
        local t = tris[i]
        if t then
            if i <= triCount then
                stopFadeIndex(i)
                t:SetHidden(false)
            elseif not t:IsHidden() and not fadeStartMs[i] then
                startFadeIndex(i)
            end
        end
    end

    updateRootHeight(triCount)
    currentState = newState
end

-- ---------------------------------------------------------------------------
-- Visibility
-- ---------------------------------------------------------------------------
-- Decide whether the indicator should be visible right now.
--   * The in-world HUD must be up -- never draw over a menu or inventory.
--   * The manual hide setting beats everything else.
--   * "Always show" beats the combat/alive requirement.
--   * Otherwise show only when in combat AND alive.
local function shouldShow(sv)
    if not lastHudShown then return false end   -- menus win over everything
    if sv.hidden == true then return false end  -- manual hide is next
    if sv.always_show == true then return true end
    if lastDead then return false end
    if not lastInCombat then return false end
    return true
end

function UP.UI.UpdateVisibility()
    if not root then return end
    local sv = UP.sv or {}
    root:SetHidden(not shouldShow(sv))
end

-- Inputs from the rest of the addon. Each updates the cache and re-evaluates.
function UP.UI.SetInCombat(inCombat)
    lastInCombat = inCombat == true
    UP.UI.UpdateVisibility()
end

function UP.UI.SetDead(isDead)
    lastDead = isDead == true
    UP.UI.UpdateVisibility()
end

-- ---------------------------------------------------------------------------
-- Hide while menus are open
-- ---------------------------------------------------------------------------
-- The sibling addon AreYouSlow solves this with a ZO_SimpleSceneFragment on
-- HUD_SCENE / HUD_UI_SCENE, which is the idiomatic approach. It is NOT used
-- here: a fragment calls SetHidden on the control itself, and this control
-- already has an owner for its hidden state (UpdateVisibility, driven by
-- combat/alive/settings). Two independent writers of the same property fight
-- -- the fragment would show the indicator on leaving a menu even when we
-- want it hidden for being out of combat.
--
-- Instead we subscribe to the same scenes and fold "is the HUD up" in as one
-- more input to the single decision function. One owner, no conflict.
--
-- HUD_SCENE and HUD_UI_SCENE are defined in esoui/ingame/scenes/hudscene.lua
-- (not keyboard/gamepad split, so console-safe). ZO_Scene fires "StateChange"
-- with (oldState, newState) and exposes IsShowing(); both verified in
-- esoui/libraries/zo_scene/zo_scene.lua at API 101050.
-- Built once. These are engine globals present before addon files parse, and
-- rebuilding the list per callback allocated a table on every menu open and
-- close.
local HUD_SCENES = { HUD_SCENE, HUD_UI_SCENE }

-- The silence ring and the plague tint need the same "is the HUD up" answer.
-- They read this rather than registering their own callbacks on the same two
-- scenes to recompute the identical boolean.
function UP.UI.IsHudShown()
    return lastHudShown
end

local function refreshHudShown()
    local shown = false
    for _, scene in ipairs(HUD_SCENES) do
        if scene and scene.IsShowing then
            local ok, isShowing = pcall(scene.IsShowing, scene)
            if ok and isShowing then shown = true end
        end
    end
    lastHudShown = shown
    UP.UI.UpdateVisibility()
    -- One subscription, three consumers.
    if UP.SilenceRing and UP.SilenceRing.UpdateVisibility then
        UP.SilenceRing.UpdateVisibility()
    end
    if UP.PlagueTint and UP.PlagueTint.UpdateVisibility then
        UP.PlagueTint.UpdateVisibility()
    end
end

local function wireSceneVisibility()
    local wired = false
    for _, scene in ipairs(HUD_SCENES) do
        if scene and scene.RegisterCallback then
            local ok = pcall(scene.RegisterCallback, scene, "StateChange", refreshHudShown)
            if ok then wired = true end
        end
    end
    if wired then
        refreshHudShown()
    else
        -- Scenes unavailable for any reason: fail open rather than leaving the
        -- indicator permanently hidden.
        lastHudShown = true
    end
end

-- ---------------------------------------------------------------------------
-- Init
-- ---------------------------------------------------------------------------
function UP.UI.Init()
    root = UP_IndicatorRoot
    if not root then
        UP.Note("FATAL: indicator root control missing. UI did not initialise.")
        return false
    end
    base = root:GetNamedChild("Base")
    tris = {
        root:GetNamedChild("Tri1"),
        root:GetNamedChild("Tri2"),
        root:GetNamedChild("Tri3"),
    }
    counterLabel = root:GetNamedChild("Counter")

    if base and base.SetColor then base:SetColor(1, 1, 1, RESTING_ALPHA) end
    for _, t in ipairs(tris) do
        if t then
            if t.SetColor then t:SetColor(1, 1, 1, RESTING_ALPHA) end
            t:SetHidden(true)
        end
    end
    if counterLabel then
        if counterLabel.SetColor then counterLabel:SetColor(1, 1, 1, 0.95) end
        counterLabel:SetText("0")
        counterLabel:SetHidden(true)
    end

    local sv = UP.sv or {}
    local x = sv.offset_x or 0
    local y = sv.offset_y or -140
    local scale = sv.scale or 1.0
    root:ClearAnchors()
    root:SetAnchor(BOTTOM, GuiRoot, CENTER, x, y)
    root:SetScale(scale)

    UP.UI.ApplyCounterFontSize(sv.counter_font_size or DEFAULT_COUNTER_SIZE)

    applyState("green_square", true)

    -- Seed alive state from the API if available; combat state will arrive
    -- via EVENT_PLAYER_COMBAT_STATE shortly after load.
    if type(IsUnitDead) == "function" then
        local ok, dead = pcall(IsUnitDead, "player")
        if ok then lastDead = dead == true end
    end

    -- Subscribe to HUD scene changes and seed lastHudShown. This calls
    -- UpdateVisibility itself, so no separate call is needed afterwards.
    wireSceneVisibility()
    return true
end

-- ---------------------------------------------------------------------------
-- Counter
-- ---------------------------------------------------------------------------
-- Set the single attacker count. Hides the label when count is 0 or when
-- show_counter is off.
-- Called 5x/second. Redundant SetText/SetHidden calls are skipped: the count
-- is unchanged on most refreshes, and SetText forces a text-layout pass even
-- when the string is identical.
local lastCounterValue  = nil
local lastCounterHidden = nil

local function setCounterHidden(hidden)
    if lastCounterHidden ~= hidden then
        lastCounterHidden = hidden
        counterLabel:SetHidden(hidden)
    end
end

function UP.UI.SetCounter(count)
    if not counterLabel then return end
    local sv = UP.sv or {}
    if sv.show_counter == false then
        setCounterHidden(true)
        return
    end
    local n = tonumber(count) or 0
    if n == 0 then
        setCounterHidden(true)
        return
    end
    if lastCounterValue ~= n then
        lastCounterValue = n
        counterLabel:SetText(tostring(n))
    end
    setCounterHidden(false)
end

-- Applies the counter font. The requested size is snapped to the nearest
-- font that actually exists in the gamepad fontdefs (see UI/Fonts.lua) and
-- the label is sized from the SNAPPED value, not the requested one, so the
-- box always matches the glyphs it has to hold.
--
-- Evidence says an unresolvable font fails soft (0.2.7 shipped keyboard-only
-- fonts and ran fine for dozens of users; the symptom was wrong sizes, not a
-- crash). UP.Fonts.Apply is pcall-guarded anyway: this runs from UP.UI.Init(),
-- before event registration and before the engine starts, so a throw here
-- WOULD abort init -- and console does not surface Lua errors, so the symptom
-- would be a silently dead addon. Cheap insurance for an unlikely case.
function UP.UI.ApplyCounterFontSize(sizePx)
    if not counterLabel then return end
    local requested = math.floor(clamp(tonumber(sizePx) or DEFAULT_COUNTER_SIZE,
                                       MIN_COUNTER_SIZE, MAX_COUNTER_SIZE))
    local _, snapped = UP.Fonts.Nearest(requested, true)
    UP.Fonts.Apply(counterLabel, requested, true)
    if counterLabel.SetDimensions then
        counterLabel:SetDimensions(math.max(60, snapped * 3), math.floor(snapped * 1.6))
    end
end

-- ---------------------------------------------------------------------------
-- State change with animation
-- ---------------------------------------------------------------------------
-- Triangles 2/3 lingering in a de-escalation fade are deliberately excluded
-- here: they have their own animation loop (updateFades above), and
-- pulseBrighten / settleFade would otherwise fight it for control of the
-- same alpha channel. i <= triCount is sufficient to detect that case --
-- a lingering triangle is, by construction, past the current triangle
-- count (see applyState) even though it isn't hidden yet.
local function eachVisible(fn)
    if base and not base:IsHidden() then fn(base) end
    local triCount = TRIANGLE_COUNT[currentState] or 0
    for i, t in ipairs(tris) do
        if t and i <= triCount and not t:IsHidden() then fn(t) end
    end
end

local function pulseBrighten()
    eachVisible(function(c) c:SetColor(1, 1, 1, 1.0) end)
    zo_callLater(function()
        eachVisible(function(c) c:SetColor(1, 1, 1, RESTING_ALPHA) end)
    end, 180)
end

local function settleFade()
    eachVisible(function(c) c:SetColor(1, 1, 1, 0.70) end)
    zo_callLater(function()
        eachVisible(function(c) c:SetColor(1, 1, 1, RESTING_ALPHA) end)
    end, 220)
end

function UP.UI.SetState(newState)
    if newState == currentState then return end
    if not (BASE_TEXTURE[newState] or TRIANGLE_COUNT[newState]) then return end

    local oldSev = STATE_SEVERITY[currentState] or 0
    local newSev = STATE_SEVERITY[newState] or 0

    applyState(newState, false)

    if newSev > oldSev then
        pulseBrighten()
    elseif newSev < oldSev then
        settleFade()
    end
end

function UP.UI.ApplyAnchor(offsetX, offsetY, scale)
    if not root then return end
    root:ClearAnchors()
    root:SetAnchor(BOTTOM, GuiRoot, CENTER, offsetX or 0, offsetY or -140)
    if scale then root:SetScale(scale) end
end
