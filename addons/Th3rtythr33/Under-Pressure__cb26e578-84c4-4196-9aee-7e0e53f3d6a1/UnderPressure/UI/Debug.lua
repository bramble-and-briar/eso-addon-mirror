-- =============================================================================
-- Under Pressure -- UI/Debug.lua
-- =============================================================================
-- Optional debug overlay. Toggled from the settings panel (Debug > Show
-- debug overlay; also /updebug through 0.3.3). Shows LIVE values only:
--   * health, combat state, dead state (engine's isDead, not just the UI's)
--   * adjusted pressure DPS, burst multiplier, risk bonus
--   * attacker count, silence state and count, plague state and time left
--   * current TTD, candidate state, published state, active debuff count
--   * last 8 events, with abilityType / statusEffectType for each effect --
--     the only way to verify silence detection on console hardware
--
-- Feature-detect results deliberately live in the API audit (Settings > Debug
-- > Print, to chat) instead. They are fixed for the session, so repainting
-- them here at 5 Hz consumed space in a fixed-size overlay to say the same
-- thing every frame.
-- =============================================================================

UP = UP or {}
UP.Debug = UP.Debug or {}

local LOG_MAX = 8
local logBuffer = {}
local header, body, root

local function fmtNum(n)
    if n == math.huge then return "inf" end
    if not n then return "-" end
    return ("%.1f"):format(n)
end

-- Mirrors the overlay's hidden state. Maintained by SetVisible/Toggle so the
-- hot path can check a boolean instead of calling into the control.
local visible = false

-- Newest entries are appended at the end; Refresh reads backwards to display
-- newest-first. Dropping from the front is O(LOG_MAX) = 8, i.e. nothing.
local function trimLog()
    while #logBuffer > LOG_MAX do table.remove(logBuffer, 1) end
end

-- Event logging is skipped entirely while the overlay is hidden.
--
-- This runs on EVERY incoming combat event. Formatting a string and churning
-- an 8-entry buffer for output nobody is looking at was pure waste on the
-- busiest path in the addon -- and the overlay is off in normal play. The
-- cost is that toggling it on starts with an empty history rather than the
-- last 8 events, which is the right trade for a live tuning tool.
function UP.Debug.LogDamage(amount, abilityId)
    if not visible then return end
    logBuffer[#logBuffer + 1] = ("damage   dmg=%-6d ability=%-7s"):format(
        amount or 0, tostring(abilityId or "-"))
    trimLog()
end

-- abilityType and statusEffectType are logged because they are the ONLY way to
-- answer, on hardware, which of the two silence signals the console runtime
-- actually populates -- the same role abilityId plays for verifying the
-- classifier's ability-ID table. A debuff showing "aT=- sT=-" means neither
-- field arrived and silence detection cannot work at all.
function UP.Debug.LogEffect(category, abilityId, abilityType, statusEffectType)
    if not visible then return end
    logBuffer[#logBuffer + 1] = ("effect  cat=%-11s ab=%-7s aT=%-4s sT=%-4s"):format(
        tostring(category), tostring(abilityId or "-"),
        tostring(abilityType or "-"), tostring(statusEffectType or "-"))
    trimLog()
end

-- Separate from LogEffect so a detected silence is unmissable in the buffer,
-- and so it is recorded even when the effect is otherwise unclassified.
function UP.Debug.LogSilence(abilityId, changeType, abilityType, statusEffectType)
    if not visible then return end
    local faded = (type(EFFECT_RESULT_FADED) == "number") and EFFECT_RESULT_FADED or 2
    logBuffer[#logBuffer + 1] = ("SILENCE %-6s ab=%-7s aT=%-4s sT=%-4s"):format(
        (changeType == faded) and "faded" or "on",
        tostring(abilityId or "-"),
        tostring(abilityType or "-"), tostring(statusEffectType or "-"))
    trimLog()
end

-- Plaguebreak attribution evidence (0.4.1): an effect applied to us or a
-- friendly event landing on us while a plague is active. Logged by kind so a
-- player can see, on hardware, what an ally's Purge actually looks like from
-- the victim's side -- the one question the design could not answer offline.
function UP.Debug.LogPlagueEvidence(kind, sourceName, sourceType, abilityName, abilityId)
    if not visible then return end
    logBuffer[#logBuffer + 1] = ("plague %-7s from=%s(%s) ab=%s id=%s"):format(
        tostring(kind), tostring(sourceName or "-"), tostring(sourceType or "-"),
        tostring(abilityName or "-"), tostring(abilityId or "-"))
    trimLog()
end

-- Unconditional, unlike the per-event loggers: this is for rare one-off
-- diagnostics (currently only a font-apply failure), not hot-path traffic.
function UP.Debug.Log(msg)
    if type(msg) ~= "string" then msg = tostring(msg) end
    logBuffer[#logBuffer + 1] = msg
    trimLog()
end

function UP.Debug.Init()
    root   = UP_DebugRoot
    if not root then return false end
    header = root:GetNamedChild("Header")
    body   = root:GetNamedChild("Body")
    visible = not root:IsHidden()
    local sv = UP.sv or {}
    UP.Debug.ApplyFontSize(sv.debug_font_size)
    return true
end

function UP.Debug.SetVisible(show)
    visible = show == true
    if root then root:SetHidden(not visible) end
end

function UP.Debug.Toggle()
    if not root then return end
    UP.Debug.SetVisible(root:IsHidden())
end

-- Repainted every tick by main loop
function UP.Debug.Refresh()
    if not visible or not root then return end
    if not (UP.Engine and UP.Engine.Snapshot) then return end
    local s = UP.Engine.Snapshot()

    -- Feature-detect results are NOT shown here any more. They are static for
    -- the session, so repainting them at 5 Hz was wasted space in a fixed-size
    -- overlay. The API audit button (Settings > Debug) prints them to chat.

    header:SetText(("UP debug | TTD %s s | %s"):format(
        fmtNum(s.ttd), tostring(s.publishedState)))

    local effectCount = 0
    for _ in pairs(s.activeEffects or {}) do effectCount = effectCount + 1 end

    local lines = {
        ("hp=%d / %d   inCombat=%s  dead=%s"):format(
            s.health or 0, s.maxHealth or 0, tostring(s.inCombat and true or false),
            tostring(s.isDead and true or false)),
        ("pressureDPS=%s  burstMul=%s  riskBonus=%s"):format(
            fmtNum(s.pressureDps), fmtNum(s.burstMul), fmtNum(s.riskBonus)),
        -- The "+PREVIEW" marker matters: without it a ring on screen beside
        -- "silenced=no" looks like a detection bug rather than the Preview
        -- button.
        ("attackers=%d  silenced=%s%s"):format(
            s.attackerCount or 0,
            (UP.Silence and UP.Silence.IsActive and UP.Silence.IsActive())
                and ("YES x" .. tostring(UP.Silence.Count())) or "no",
            (UP.SilenceRing and UP.SilenceRing.IsPreviewActive and UP.SilenceRing.IsPreviewActive())
                and "  +PREVIEW" or ""),
        -- Plaguebreak (0.4.0). "+PREVIEW" for the same reason as the silence
        -- line: a tint beside "plague=no" must be explained.
        ("plague=%s%s"):format(
            (UP.Plague and UP.Plague.IsActive and UP.Plague.IsActive())
                and ("YES %.1fs left"):format((UP.Plague.RemainingMs(GetGameTimeMilliseconds()) or 0) / 1000)
                or "no",
            (UP.PlagueTint and UP.PlagueTint.IsPreviewActive and UP.PlagueTint.IsPreviewActive())
                and "  +PREVIEW" or ""),
        ("dmgEvts=%d  activeDebuffs=%d  cand=%s"):format(
            s.damageEventCount or 0, effectCount, tostring(s.candidateState)),
        "--- recent events ---",
    }
    -- Backwards: the buffer appends newest-last, the display wants newest-first.
    for i = #logBuffer, 1, -1 do
        lines[#lines + 1] = logBuffer[i]
    end
    body:SetText(table.concat(lines, "\n"))
end

-- =============================================================================
-- Overlay text size (Settings > Debug > Debug text size)
-- =============================================================================
-- Was the /upfont <size> slash command through 0.3.3, which was never
-- persisted; 0.4.0 made it a slider stored in sv.debug_font_size and applied
-- here at Init and on every slider step.
--
-- The requested size is snapped to the nearest font that actually exists in
-- the gamepad fontdefs, so the on-screen size moves in steps. Through 0.2.7
-- this built $(MEDIUM_FONT)/$(BOLD_FONT) descriptors, which are keyboard-only
-- constants and are the reason the size never changed on console. See
-- UI/Fonts.lua.
-- =============================================================================
UP.Debug.DEFAULT_FONT_SIZE = 27

function UP.Debug.ApplyFontSize(sizePx)
    if not root then return end
    local requested = tonumber(sizePx) or UP.Debug.DEFAULT_FONT_SIZE
    if requested < UP.Fonts.MIN_SIZE then requested = UP.Fonts.MIN_SIZE end
    if requested > UP.Fonts.MAX_SIZE then requested = UP.Fonts.MAX_SIZE end
    -- Header sits one rung up the ladder from the body rather than a fixed
    -- +8px, since the ladder is not evenly spaced.
    UP.Fonts.Apply(body,   requested,     false)
    UP.Fonts.Apply(header, requested + 6, true)
end
