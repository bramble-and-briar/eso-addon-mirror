--[[
    Mark state, timer text, warning colour/sound, and tracking of the
    player-side Warmask effect (the single source of truth).
]]

local ADDON = "WeylandHuntsmansWarmaskTracker"
local HMK = _G[ADDON]
local EM = EVENT_MANAGER
local WARMASK_PLAYER_EFFECT_ABILITY_ID = HMK.WARMASK_PLAYER_EFFECT_ABILITY_ID
local ui = HMK.ui
local NowSec, PlayWarnSound = HMK.NowSec, HMK.PlayWarnSound
local ApplyViewStyle, ApplyViewColors, ApplyPosition = HMK.ApplyViewStyle, HMK.ApplyViewColors, HMK.ApplyPosition

-- true while the HUD element should be forced visible and draggable in move mode (/hmark)
local function Editing()
    return HMK.unlocked
end

local state = {
    active  = false,
    endTime = 0,
}

local TICK_NAME = ADDON .. "_Tick"
local SyncPlayerWarmaskEffect   -- defined below (needs the buff-list helpers)
local TICKS_PER_SYNC = 10        -- tick = 100 ms, so the buff list is re-checked once per second
local tickCount = 0

local function FormatTimer(remaining)
    if remaining < 0 then remaining = 0 end
    if HMK.sv.mark.tenths and remaining <= 5 then
        return string.format("%.1f", remaining)
    end
    -- Floor to whole seconds remaining instead of rounding up. The tiny epsilon
    -- also prevents an exact 60.0-second event timestamp from flashing "60".
    return tostring(math.max(0, math.floor(remaining - 0.001)))
end

local function UpdateMarkVisibility()
    local m = ui.mark
    if not m then return end
    -- The marker is visible while the player's Warmask effect is active.
    -- Move mode also forces visibility so the icon can be positioned.
    local show = HMK.unlocked or state.active
    m.content:SetHidden(not show)
    m.frame:SetHidden(not HMK.unlocked)
    m.hint:SetHidden(not HMK.unlocked)
end

local function UpdateTimerText()
    local m = ui.mark
    local cfg = HMK.sv.mark
    if cfg.timerMode == "hidden" then
        m.timer:SetHidden(true)
        return
    end
    m.timer:SetHidden(false)
    if state.active then
        m.timer:SetText(FormatTimer(state.endTime - NowSec()))
    elseif Editing() then
        m.timer:SetText("59")
    else
        m.timer:SetText("")
    end
end

local warnShown = false   -- warning colour currently applied
local soundDone = false   -- one-shot mode: the sound already played for this application of the mark
local lastSoundAt = nil   -- repeat mode: when the sound last played

-- Warning sound. Starts when the remaining time drops to the warning limit and
--   * repeat mode: plays every soundInterval seconds until the mark is refreshed (time goes back above the limit) or ends;
--   * one-shot mode: plays once and re-arms when the mark is refreshed.
local function CheckWarnSound(remaining)
    local cfg = HMK.sv.mark
    if remaining > cfg.warnSeconds then
        soundDone, lastSoundAt = false, nil
        return
    end
    if not cfg.soundEnabled then return end
    local now = NowSec()
    local interval = cfg.soundInterval or 0
    if interval > 0 then
        if not lastSoundAt or now - lastSoundAt >= interval then
            lastSoundAt = now
            PlayWarnSound(cfg.sound)
        end
    elseif not soundDone then
        soundDone = true
        PlayWarnSound(cfg.sound)
    end
end

local function ApplyMarkColors()
    local m, cfg = ui.mark, HMK.sv.mark
    if not m then return end
    local warn = false
    if cfg.warnEnabled and state.active then
        warn = (state.endTime - NowSec()) <= cfg.warnSeconds
    end
    warnShown = warn
    ApplyViewColors(m.view, cfg, warn)
end

local function ApplyMarkStyle()
    local m, cfg = ui.mark, HMK.sv.mark
    if not m then return end

    m:SetDimensions(cfg.size, cfg.size)
    ApplyPosition(m, cfg)

    ApplyViewStyle(m.view, cfg, 1)
    ApplyMarkColors()

    UpdateTimerText()
    UpdateMarkVisibility()
    if HMK.RefreshPanelWidgets then HMK.RefreshPanelWidgets() end
end

local function OnTick()
    if not state.active then return end
    local remaining = state.endTime - NowSec()
    if remaining <= 0 then
        HMK.ClearMark()
        return
    end
    UpdateTimerText()
    CheckWarnSound(remaining)
    local warn = HMK.sv.mark.warnEnabled and remaining <= HMK.sv.mark.warnSeconds
    if warn ~= warnShown then ApplyMarkColors() end

    -- Safety net that exists only while a mark is shown: once per second compare
    -- with the live buff list (e.g. effect removed without a FADED event).
    tickCount = tickCount + 1
    if tickCount >= TICKS_PER_SYNC then
        tickCount = 0
        SyncPlayerWarmaskEffect()
    end
end

local function SetMark(endTime)
    if type(endTime) ~= "number" or endTime <= NowSec() then
        HMK.ClearMark()
        return
    end

    -- The player-side Warmask effect is the single source of truth. Its expiry
    -- is compared using the same frame-time clock as GetUnitBuffInfo().
    state.active  = true
    state.endTime = endTime
    tickCount = 0
    EM:UnregisterForUpdate(TICK_NAME)
    EM:RegisterForUpdate(TICK_NAME, 100, OnTick)
    CheckWarnSound(endTime - NowSec())
    ApplyMarkColors()
    UpdateTimerText()
    UpdateMarkVisibility()
end

function HMK.ClearMark()
    state.active  = false
    state.endTime = 0
    soundDone, lastSoundAt = false, nil
    EM:UnregisterForUpdate(TICK_NAME)
    if ui.mark then
        ApplyMarkColors()
        UpdateTimerText()
        UpdateMarkVisibility()
    end
end

---------------------------------------------------------------------------
-- Tracking the player-side Warmask effect
---------------------------------------------------------------------------
-- Ability 252050 is the self effect on the player while Mark of Hircine is
-- active. Unlike the target debuff (252048), it has a stable unitTag: "player".
-- We intentionally do not inspect NPCs, target names, reticleover, or unit IDs.
local function PlayerWarmaskEffectExpiry()
    for i = 1, GetNumBuffs("player") do
        local _, _, timeEnding, _, _, _, _, _, _, _, abilityId = GetUnitBuffInfo("player", i)
        if tonumber(abilityId) == WARMASK_PLAYER_EFFECT_ABILITY_ID
            and type(timeEnding) == "number" and timeEnding > NowSec() then
            return timeEnding
        end
    end
    return nil
end

-- Reconcile the HUD against the live player buff list. This also recovers from
-- a missed/reordered event and guarantees that the timer cannot outlive the
-- actual self effect.
SyncPlayerWarmaskEffect = function(eventEndTime)
    local expiry = PlayerWarmaskEffectExpiry()
    if not expiry and type(eventEndTime) == "number" and eventEndTime > NowSec() then
        -- EVENT_EFFECT_CHANGED may arrive before GetUnitBuffInfo reflects GAINED.
        expiry = eventEndTime
    end

    if expiry then
        if not state.active or math.abs(state.endTime - expiry) > 0.05 then
            SetMark(expiry)
        end
    elseif state.active then
        HMK.ClearMark()
    end
end

-- Registration filters this event to the player's 252050 effect, so the
-- handler can process it directly without repeating those checks here.
local function OnPlayerEffectChanged(_, changeType, _, _, _, _, endTime)
    if changeType == EFFECT_RESULT_FADED then
        -- If ESO has already refreshed the same self effect, retain its new expiry.
        local currentExpiry = PlayerWarmaskEffectExpiry()
        if currentExpiry then
            SyncPlayerWarmaskEffect(currentExpiry)
        else
            HMK.ClearMark()
        end
        return
    end

    SyncPlayerWarmaskEffect(endTime)
end

HMK.ApplyMarkStyle = ApplyMarkStyle
HMK.SyncPlayerWarmaskEffect = SyncPlayerWarmaskEffect
HMK.OnPlayerEffectChanged = OnPlayerEffectChanged
