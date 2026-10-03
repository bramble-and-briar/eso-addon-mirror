-- SnipersFriendGroundTargetActions.lua: Ground-target range / line-of-sight indicator.
--
-- While the player is placing a ground-target ability (Elemental Explosion etc.) the
-- engine evaluates the target point every frame and exposes its verdict through
-- GetGroundTargetingError(): nil = castable here, ACTION_RESULT_TARGET_OUT_OF_RANGE,
-- ACTION_RESULT_TARGET_NOT_IN_VIEW / CANT_SEE_TARGET (line of sight), ... The native
-- reticle only prints that as text. We recolour the dot and show the range next to it,
-- so a bad placement is obvious before the cast is confirmed. Because it is the
-- engine's own verdict it already includes passives and keep / siege-shield range
-- buffs. There is no API for the targeted world point, so distance is not shown as a
-- number; a "range dwell" fade indicates how long the aim has been out of range.

local SnipersFriend = SnipersFriend
local Utils = SnipersFriend.GroundTargetUtils
local ReticleUtils = SnipersFriend.ReticleUtils

local GroundTargetActions = {}

local LABEL_NAME = "SnipersFriendGtLabel"
local LOG_MAX = 40

---@return SnipersFriendGroundTargetSettings
local function Settings() return SnipersFriend.state.savedVars.groundTarget end
---@return SnipersFriendState
local function State() return SnipersFriend.state end

local function Debug(fmt, ...) SnipersFriend.SlashUtils.Debug(fmt, ...) end

-- ---------------------------------------------------------------- label

local function EnsureLabel()
    local state = State()
    if state.gtLabel then return state.gtLabel end
    local dot = state.dotControl
    if not dot then return nil end
    local label = _G[LABEL_NAME] or WINDOW_MANAGER:CreateControl(LABEL_NAME, dot:GetParent(), CT_LABEL)
    label:SetFont("ZoFontGamepad27")
    label:SetDrawLayer(DL_OVERLAY)
    label:SetDrawLevel(2)
    label:SetHidden(true)
    state.gtLabel = label
    return label
end

local function PositionLabel()
    local state = State()
    local label, dot = state.gtLabel, state.dotControl
    if not (label and dot) then return end
    label:ClearAnchors()
    label:SetAnchor(TOP, dot, BOTTOM, 0, Settings().labelOffsetY or 10)
end

-- ---------------------------------------------------------------- ability discovery

---Refresh the list of ground-target abilities on the active bar.
function GroundTargetActions.RefreshAbilities()
    local state = State()
    if not SnipersFriend.CameraUtils.IsCallable("GetAbilityTargetDescription") then
        state.gtAbilities = {}
        return
    end
    local groundLabel = GetString(SI_ABILITY_TOOLTIP_TARGET_TYPE_GROUND)
    local areaLabel = SI_ABILITY_TOOLTIP_TARGET_TYPE_AREA and GetString(SI_ABILITY_TOOLTIP_TARGET_TYPE_AREA) or nil
    state.gtAbilities = Utils.FindGroundAbilities(groundLabel, areaLabel)
    if Settings().debugLog then
        for _, a in ipairs(state.gtAbilities) do
            Debug("ground ability slot %d: %s (%d) range %s m", a.slot, a.name, a.abilityId, a.maxRangeM and string.format("%.0f", a.maxRangeM) or "?")
        end
    end
end

---Best guess at the ability currently being placed: the engine does not tell us which
---slot entered ground-target mode, so we take the most recently USED ground ability,
---falling back to the first one on the bar.
---@return {slot: integer, abilityId: integer, name: string, maxRangeM: number|nil}|nil
function GroundTargetActions.CurrentAbility()
    local state = State()
    local abilities = state.gtAbilities or {}
    if state.gtLastUsedSlot then
        for _, a in ipairs(abilities) do
            if a.slot == state.gtLastUsedSlot then return a end
        end
    end
    return abilities[1]
end

---@param slot integer
function GroundTargetActions.OnAbilityUsed(slot)
    local state = State()
    for _, a in ipairs(state.gtAbilities or {}) do
        if a.slot == slot then
            state.gtLastUsedSlot = slot
            return
        end
    end
end

-- ---------------------------------------------------------------- colouring

---@param gtState SnipersFriendGtState
---@return SnipersFriendRGBA
local function ColorFor(gtState)
    local s = Settings()
    if gtState == "ok" then return s.okColor end
    if gtState == "range" then return s.rangeColor end
    if gtState == "los" then return s.losColor end
    return s.invalidColor
end

local function ApplyVisual()
    local state = State()
    local dot, label = state.dotControl, state.gtLabel
    if not dot then return end
    local gtState = state.gtState
    local s = Settings()

    if gtState == "idle" or not s.enabled then
        if label then label:SetHidden(true) end
        state.gtOverriding = false
        SnipersFriend.ReticleActions.RefreshColor()
        return
    end

    state.gtOverriding = true
    local c = ColorFor(gtState)
    local r, g, b, a = c.r, c.g, c.b, c.a
    if gtState == "range" and s.dwellFade then
        -- fade from the OK colour to the range colour over dwellMs so brief clips at
        -- the edge look different from aiming well past max range
        local t = (GetFrameTimeMilliseconds() - (state.gtStateSince or 0)) / math.max(1, s.dwellMs)
        r, g, b, a = Utils.Lerp(s.okColor, s.rangeColor, t)
    end
    dot:SetColor(r, g, b, a)

    if s.showLabel and label then
        local ability = GroundTargetActions.CurrentAbility()
        local parts = {}
        if ability and ability.maxRangeM then parts[#parts + 1] = string.format("%.0f m", ability.maxRangeM) end
        if gtState == "range" then parts[#parts + 1] = s.rangeText
        elseif gtState == "los" then parts[#parts + 1] = s.losText
        elseif gtState == "invalid" then parts[#parts + 1] = s.invalidText
        elseif gtState == "other" and state.gtLastError then parts[#parts + 1] = zo_strformat(GetString("SI_ACTIONRESULT", state.gtLastError)) end
        label:SetText(table.concat(parts, "  "))
        label:SetColor(r, g, b, 1)
        label:SetHidden(#parts == 0)
    elseif label then
        label:SetHidden(true)
    end
end

-- ---------------------------------------------------------------- per-frame

---Called from the reticle OnUpdate post-hook (every frame while the HUD is up).
function GroundTargetActions.OnUpdate()
    local state = State()
    if not Settings().enabled or not state.gtReady then return end

    -- Only react while a ground-target ability is slotted: the engine also flags
    -- "ground targeting" for a frame during ordinary casts, which made the dot flicker.
    local targeting = #(state.gtAbilities or {}) > 0 and IsPlayerGroundTargeting()
    local newState, err = "idle", nil
    if targeting then
        err = GetGroundTargetingError()
        newState = Utils.Classify(err)
    end

    if newState ~= state.gtState or err ~= state.gtLastError then
        if Settings().debugLog and newState ~= "idle" then
            local log = state.gtLog
            log[#log + 1] = string.format("%s err=%s", newState, tostring(err))
            if #log > LOG_MAX then table.remove(log, 1) end
        end
        state.gtState = newState
        state.gtLastError = err
        state.gtStateSince = GetFrameTimeMilliseconds()
        ApplyVisual()
    elseif newState == "range" and Settings().dwellFade then
        ApplyVisual() -- animate the fade
    end
end

function GroundTargetActions.Refresh()
    PositionLabel()
    ApplyVisual()
end

---@return boolean
function GroundTargetActions.Initialize()
    local state = State()
    local CU = SnipersFriend.CameraUtils
    if not (CU.IsCallable("IsPlayerGroundTargeting") and CU.IsCallable("GetGroundTargetingError")) then
        Debug("ground targeting API not available here")
        state.gtReady = false
        return false
    end
    EnsureLabel()
    PositionLabel()
    GroundTargetActions.RefreshAbilities()
    state.gtState = "idle"
    state.gtReady = true
    return true
end

---@return string[]
function GroundTargetActions.StatusLines()
    local state = State()
    local lines = {}
    lines[#lines + 1] = string.format("ground-target indicator: %s (%s)", Settings().enabled and "on" or "off", state.gtReady and "ready" or "unavailable")
    for _, a in ipairs(state.gtAbilities or {}) do
        lines[#lines + 1] = string.format("  slot %d: %s  [%s] range %s m%s", a.slot, a.name, a.targetType or "?",
            a.maxRangeM and string.format("%.0f", a.maxRangeM) or "?", a.slot == state.gtLastUsedSlot and "  (last used)" or "")
    end
    if #(state.gtAbilities or {}) == 0 then lines[#lines + 1] = "  no ground-target abilities on this bar" end
    lines[#lines + 1] = string.format("  state now: %s err=%s", tostring(state.gtState), tostring(state.gtLastError))
    return lines
end

SnipersFriend.GroundTargetActions = GroundTargetActions
