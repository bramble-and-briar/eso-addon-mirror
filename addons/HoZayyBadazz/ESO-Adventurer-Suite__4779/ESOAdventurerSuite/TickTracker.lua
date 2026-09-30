-- ESO Adventurer Suite
-- Resource Tick Tracker (v0.29.425)
-- Recovery-stat matching informed by the user-supplied Miat reference.
-- Independent Suite implementation; no Miat controls or saved variables required.
-- Event-driven Health/Magicka/Stamina recovery cadence display integrated into
-- the Suite player bars. Advanced mode adds prediction, overcap waste, trusted
-- tick confirmation, delay/resync feedback, recovery-change state, and recent
-- resource-pressure hints without changing the existing bar-fill animation.

local EPC = ESOProgressionCoach
EPC.TickTracker = EPC.TickTracker or {}
local T = EPC.TickTracker
local WM = WINDOW_MANAGER

local PERIOD = 2000
local EXPIRE = 120000
local CONFIRM_WINDOW = 260
local DELAY_GRACE = 425
local PRESSURE_WINDOW = 4000
local CHANGE_BADGE_MS = 3500
local CONFIRM_FLASH_MS = 180

local POWER_TYPES = { POWERTYPE_HEALTH, POWERTYPE_MAGICKA, POWERTYPE_STAMINA }
local WHITE_TEXTURE = "/esoui/art/miscellaneous/white.dds"

local function safe(fn, fallback, ...)
    if type(fn) ~= "function" then return fallback end
    local ok, a, b, c, d = pcall(fn, ...)
    if not ok then return fallback end
    return a, b, c, d
end

local function nowMS()
    if type(GetFrameTimeMilliseconds) == "function" then
        return tonumber((safe(GetFrameTimeMilliseconds, 0))) or 0
    end
    if type(GetGameTimeMilliseconds) == "function" then
        return tonumber((safe(GetGameTimeMilliseconds, 0))) or 0
    end
    return 0
end

local function clamp(v, low, high)
    v = tonumber(v) or low
    if v < low then return low end
    if v > high then return high end
    return v
end

local function round(v)
    v = tonumber(v) or 0
    if v >= 0 then return math.floor(v + 0.5) end
    return math.ceil(v - 0.5)
end

local function sampleFor(self, powerType)
    self.samples = self.samples or {}
    self.samples[powerType] = self.samples[powerType] or { spendEvents = {} }
    local sample = self.samples[powerType]
    sample.spendEvents = sample.spendEvents or {}
    return sample
end

local function trimSpendEvents(sample, at)
    local events = sample.spendEvents or {}
    local cutoff = at - PRESSURE_WINDOW
    local first = 1
    while first <= #events and (events[first].at or 0) < cutoff do first = first + 1 end
    if first > 1 then
        local kept = {}
        for i = first, #events do kept[#kept + 1] = events[i] end
        sample.spendEvents = kept
        events = kept
    end
    return events
end

function T:IsAdvanced()
    return not EPC.saved or (EPC.saved.tickTrackerMode029415 or "ADVANCED") == "ADVANCED"
end

function T:Create()
    local player = EPC.UnitFrames and EPC.UnitFrames.playerFrame
    local bars = player and player.epcBars
    if not WM or not bars or not bars.health or not bars.magicka or not bars.stamina then return end
    if self.frame and self.playerHost == player
        and self.healthHost == bars.health and self.magHost == bars.magicka and self.staHost == bars.stamina then return end

    if self.frame then self.frame:SetHidden(true) end
    for _, indicator in pairs(self.indicators or {}) do
        if indicator.progressPieces then
            for _, piece in ipairs(indicator.progressPieces) do piece:SetHidden(true) end
        elseif indicator.progress then
            indicator.progress:SetHidden(true)
        end
        if indicator.marker then indicator.marker:SetHidden(true) end
        if indicator.tickBox then indicator.tickBox:SetHidden(true) end
    end

    local frame = WM:CreateControl(nil, player, CT_CONTROL)
    frame:SetAnchorFill(player)
    frame:SetMouseEnabled(false)
    frame:SetHidden(true)

    local indicatorSerial = 0

    local function makeIndicator(host, r, g, b)
        indicatorSerial = indicatorSerial + 1
        local controlPrefix = "EAS_TickIndicator_" .. tostring(indicatorSerial)
        local fillHost = host.epcFill or host
        local nativeShape = host.epcNative == true
        local progress
        local marker

        -- Readout sidecar.  It is built from the same native ESO attribute-frame
        -- pieces as the resource bars so it reads as an attached part of the frame,
        -- not a floating rectangle.  SLIM and FANCY share the native silhouette;
        -- FANCY is slightly taller/wider and adds an inner resource-colored glow.
        local tickBox = WM:CreateControl(controlPrefix .. "_Box", host, CT_CONTROL)
        tickBox:ClearAnchors()
        tickBox:SetAnchor(RIGHT, host, LEFT, -2, 0)
        tickBox:SetDimensions(54, math.max(18, host:GetHeight() or 23))
        tickBox:SetMouseEnabled(false)
        tickBox:SetDrawLayer(DL_OVERLAY)
        tickBox:SetDrawLevel(40)
        tickBox:SetHidden(true)

        -- Build the readout interior with the SAME split native StatusBars used by
        -- the real player resource bars. This fills the pointed end caps instead of
        -- leaving a rectangular center cavity with empty triangles at both ends.
        local tickBgLeft = WM:CreateControlFromVirtual(controlPrefix .. "_BgLeft", tickBox, "ZO_PlayerAttributeBgLeftArrow_Keyboard_Template")
        tickBgLeft:ClearAnchors()
        tickBgLeft:SetAnchor(LEFT, tickBox, LEFT, 0, 0)

        local tickBgRight = WM:CreateControlFromVirtual(controlPrefix .. "_BgRight", tickBox, "ZO_PlayerAttributeBgRightArrow_Keyboard_Template")
        tickBgRight:ClearAnchors()
        tickBgRight:SetAnchor(RIGHT, tickBox, RIGHT, 0, 0)

        local tickBgCenter = WM:CreateControlFromVirtual(controlPrefix .. "_BgCenter", tickBox, "ZO_PlayerAttributeBgCenter_Keyboard_Template")
        tickBgCenter:ClearAnchors()
        tickBgCenter:SetAnchor(TOPLEFT, tickBgLeft, TOPRIGHT, 0, 0)
        tickBgCenter:SetAnchor(BOTTOMRIGHT, tickBgRight, BOTTOMLEFT, 0, 0)

        local tickFillLeft = WM:CreateControlFromVirtual(controlPrefix .. "_FillLeft", tickBox, "ZO_PlayerAttributeStatusBar_Keyboard_Template")
        tickFillLeft:ClearAnchors()
        tickFillLeft:SetAnchor(LEFT, tickBox, LEFT, 0, 0)
        tickFillLeft:SetAnchor(RIGHT, tickBox, CENTER, 0, 0)
        tickFillLeft:SetBarAlignment(BAR_ALIGNMENT_REVERSE)
        tickFillLeft:SetMinMax(0, 1)
        tickFillLeft:SetValue(1)
        tickFillLeft:SetColor(r * 0.42, g * 0.42, b * 0.42, 0.92)

        local tickFillRight = WM:CreateControlFromVirtual(controlPrefix .. "_FillRight", tickBox, "ZO_PlayerAttributeStatusBar_Keyboard_Template")
        tickFillRight:ClearAnchors()
        tickFillRight:SetAnchor(RIGHT, tickBox, RIGHT, 0, 0)
        tickFillRight:SetAnchor(LEFT, tickBox, CENTER, 0, 0)
        tickFillRight:SetBarAlignment(BAR_ALIGNMENT_NORMAL)
        tickFillRight:SetMinMax(0, 1)
        tickFillRight:SetValue(1)
        tickFillRight:SetColor(r * 0.42, g * 0.42, b * 0.42, 0.92)

        local tickGlossLeft = WM:CreateControlFromVirtual(controlPrefix .. "_GlossLeft", tickBox, "ZO_PlayerAttributeStatusBarGloss_Keyboard_Template")
        tickGlossLeft:ClearAnchors()
        tickGlossLeft:SetAnchor(LEFT, tickBox, LEFT, 0, 0)
        tickGlossLeft:SetAnchor(RIGHT, tickBox, CENTER, 0, 0)
        tickGlossLeft:SetBarAlignment(BAR_ALIGNMENT_REVERSE)
        tickGlossLeft:SetMinMax(0, 1)
        tickGlossLeft:SetValue(1)
        tickGlossLeft:SetColor(r, g, b, 0.10)

        local tickGlossRight = WM:CreateControlFromVirtual(controlPrefix .. "_GlossRight", tickBox, "ZO_PlayerAttributeStatusBarGloss_Keyboard_Template")
        tickGlossRight:ClearAnchors()
        tickGlossRight:SetAnchor(RIGHT, tickBox, RIGHT, 0, 0)
        tickGlossRight:SetAnchor(LEFT, tickBox, CENTER, 0, 0)
        tickGlossRight:SetBarAlignment(BAR_ALIGNMENT_NORMAL)
        tickGlossRight:SetMinMax(0, 1)
        tickGlossRight:SetValue(1)
        tickGlossRight:SetColor(r, g, b, 0.10)

        for _, piece in ipairs({tickBgLeft, tickBgRight, tickBgCenter}) do
            if piece.SetDrawTier then piece:SetDrawTier(DT_HIGH) end
            piece:SetDrawLayer(DL_CONTROLS)
            piece:SetDrawLevel(1)
        end
        for _, piece in ipairs({tickFillLeft, tickFillRight}) do
            if piece.SetDrawTier then piece:SetDrawTier(DT_HIGH) end
            piece:SetDrawLayer(DL_CONTROLS)
            piece:SetDrawLevel(2)
        end
        for _, piece in ipairs({tickGlossLeft, tickGlossRight}) do
            if piece.SetDrawTier then piece:SetDrawTier(DT_HIGH) end
            piece:SetDrawLayer(DL_CONTROLS)
            piece:SetDrawLevel(3)
        end

        local tickFrameLeft = WM:CreateControlFromVirtual(controlPrefix .. "_FrameLeft", tickBox, "ZO_PlayerAttributeFrameLeftArrow_Keyboard_Template")
        tickFrameLeft:ClearAnchors()
        tickFrameLeft:SetAnchor(LEFT, tickBox, LEFT, 0, 0)
        local tickFrameRight = WM:CreateControlFromVirtual(controlPrefix .. "_FrameRight", tickBox, "ZO_PlayerAttributeFrameRightArrow_Keyboard_Template")
        tickFrameRight:ClearAnchors()
        tickFrameRight:SetAnchor(RIGHT, tickBox, RIGHT, 0, 0)
        local tickFrameCenter = WM:CreateControlFromVirtual(controlPrefix .. "_FrameCenter", tickBox, "ZO_PlayerAttributeFrameCenter_Keyboard_Template")
        tickFrameCenter:ClearAnchors()
        tickFrameCenter:SetAnchor(TOPLEFT, tickFrameLeft, TOPRIGHT, 0, 0)
        tickFrameCenter:SetAnchor(BOTTOMRIGHT, tickFrameRight, BOTTOMLEFT, 0, 0)
        for _, piece in ipairs({tickFrameLeft, tickFrameRight, tickFrameCenter}) do
            if piece.SetDrawTier then piece:SetDrawTier(DT_HIGH) end
            piece:SetDrawLayer(DL_OVERLAY)
            piece:SetDrawLevel(100)
        end

        local tickLabel = WM:CreateControl(controlPrefix .. "_Label", tickBox, CT_LABEL)
        tickLabel:SetAnchor(CENTER, tickBox, CENTER, 0, 0)
        tickLabel:SetFont("ZoFontGameSmall")
        tickLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        tickLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        tickLabel:SetColor(r, g, b, 1)
        tickLabel:SetText("2.0s")
        -- Keep the readout above every native frame/fill child. Native ESO
        -- attribute templates can create their own high-tier overlay children, so
        -- a draw level alone is not sufficient. Explicitly promote the label.
        if tickLabel.SetDrawTier then tickLabel:SetDrawTier(DT_HIGH) end
        tickLabel:SetDrawLayer(DL_OVERLAY)
        tickLabel:SetDrawLevel(1000)
        tickLabel:SetHidden(false)

        -- Rectangle sidecar renderer for the Suite's rectangular frame designs.
        -- These controls coexist with the native pointed pieces so switching the
        -- unit-frame design live does not require recreating the tracker.
        local tickRectBack = WM:CreateControl(controlPrefix .. "_RectBack", tickBox, CT_BACKDROP)
        tickRectBack:SetAnchorFill(tickBox)
        tickRectBack:SetCenterColor(0.015, 0.018, 0.024, 0.94)
        tickRectBack:SetEdgeColor(0.24, 0.24, 0.28, 1)
        tickRectBack:SetEdgeTexture(nil, 1, 1, 1)
        tickRectBack:SetDrawLayer(DL_CONTROLS)
        tickRectBack:SetDrawLevel(4)
        tickRectBack:SetHidden(true)

        local tickRectFill = WM:CreateControl(controlPrefix .. "_RectFill", tickBox, CT_BACKDROP)
        tickRectFill:ClearAnchors()
        tickRectFill:SetAnchor(TOPLEFT, tickBox, TOPLEFT, 2, 2)
        tickRectFill:SetAnchor(BOTTOMRIGHT, tickBox, BOTTOMRIGHT, -2, -2)
        tickRectFill:SetCenterColor(r * 0.42, g * 0.42, b * 0.42, 0.92)
        tickRectFill:SetEdgeColor(0, 0, 0, 0)
        tickRectFill:SetDrawLayer(DL_CONTROLS)
        tickRectFill:SetDrawLevel(5)
        tickRectFill:SetHidden(true)

        local tickRectGlow = WM:CreateControl(controlPrefix .. "_RectGlow", tickBox, CT_BACKDROP)
        tickRectGlow:ClearAnchors()
        tickRectGlow:SetAnchor(TOPLEFT, tickBox, TOPLEFT, 3, 3)
        tickRectGlow:SetAnchor(BOTTOMRIGHT, tickBox, BOTTOMRIGHT, -3, -3)
        tickRectGlow:SetCenterColor(r, g, b, 0.08)
        tickRectGlow:SetEdgeColor(0, 0, 0, 0)
        tickRectGlow:SetDrawLayer(DL_CONTROLS)
        tickRectGlow:SetDrawLevel(6)
        tickRectGlow:SetHidden(true)

        -- Rectangular designs get their own inner cavity that mirrors the
        -- visible epcRectFill geometry exactly (2 px inset on every side).
        -- The cavity clips its children when the client exposes SetClipsChildren,
        -- so even a one-frame layout resize cannot let the tick sweep escape.
        local rectClip = WM:CreateControl(controlPrefix .. "_RectClip", host, CT_CONTROL)
        rectClip:ClearAnchors()
        rectClip:SetAnchor(TOPLEFT, host, TOPLEFT, 2, 2)
        rectClip:SetDimensions(math.max(1, (host:GetWidth() or 1) - 4), math.max(1, (host:GetHeight() or 1) - 4))
        rectClip:SetMouseEnabled(false)
        if type(rectClip.SetClipsChildren) == "function" then rectClip:SetClipsChildren(true) end
        if rectClip.SetDrawTier then rectClip:SetDrawTier(DT_MEDIUM) end
        rectClip:SetDrawLayer(DL_CONTROLS)
        rectClip:SetDrawLevel(109)

        -- Use the same texture primitive as UnitFrames.epcRectFill instead of a
        -- backdrop. This keeps the sweep pixel-for-pixel inside the block bar.
        local rectProgress = WM:CreateControl(controlPrefix .. "_RectProgress", rectClip, CT_TEXTURE)
        rectProgress:SetTexture(WHITE_TEXTURE)
        rectProgress:ClearAnchors()
        rectProgress:SetAnchor(TOPLEFT, rectClip, TOPLEFT, 0, 0)
        rectProgress:SetDimensions(1, math.max(1, rectClip:GetHeight()))
        rectProgress:SetColor(r, g, b, 0.28)
        rectProgress:SetMouseEnabled(false)
        if rectProgress.SetDrawTier then rectProgress:SetDrawTier(DT_MEDIUM) end
        rectProgress:SetDrawLayer(DL_CONTROLS)
        rectProgress:SetDrawLevel(110)
        rectProgress:SetHidden(true)

        local rectMarker = WM:CreateControl(controlPrefix .. "_RectMarker", rectClip, CT_TEXTURE)
        rectMarker:SetTexture(WHITE_TEXTURE)
        rectMarker:ClearAnchors()
        rectMarker:SetAnchor(TOPLEFT, rectClip, TOPLEFT, 0, 0)
        rectMarker:SetDimensions(2, math.max(1, rectClip:GetHeight()))
        rectMarker:SetColor(1, 1, 1, 0.90)
        rectMarker:SetMouseEnabled(false)
        if rectMarker.SetDrawTier then rectMarker:SetDrawTier(DT_MEDIUM) end
        rectMarker:SetDrawLayer(DL_CONTROLS)
        rectMarker:SetDrawLevel(111)
        rectMarker:SetHidden(true)

        if nativeShape and host.epcFillLeft and host.epcFillRight then
            local realLeft = host.epcFillLeft
            local realRight = host.epcFillRight

            local progressLeft = WM:CreateControlFromVirtual(controlPrefix .. "_ProgressLeft", host, "ZO_PlayerAttributeStatusBar_Keyboard_Template")
            progressLeft:ClearAnchors()
            progressLeft:SetHeight(math.max(1, realLeft:GetHeight()))
            progressLeft:SetAnchor(LEFT, host, LEFT, 0, 0)
            progressLeft:SetAnchor(RIGHT, host, CENTER, 0, 0)
            progressLeft:SetBarAlignment(BAR_ALIGNMENT_REVERSE)
            progressLeft:SetMinMax(0, 1)
            progressLeft:SetValue(0)
            progressLeft:SetColor(r, g, b, 0.34)
            progressLeft:SetMouseEnabled(false)
            if progressLeft.SetDrawTier then progressLeft:SetDrawTier(DT_MEDIUM) end
            progressLeft:SetDrawLayer(DL_CONTROLS)
            progressLeft:SetDrawLevel(28)
            progressLeft:SetHidden(true)

            local progressRight = WM:CreateControlFromVirtual(controlPrefix .. "_ProgressRight", host, "ZO_PlayerAttributeStatusBar_Keyboard_Template")
            progressRight:ClearAnchors()
            progressRight:SetHeight(math.max(1, realRight:GetHeight()))
            progressRight:SetAnchor(RIGHT, host, RIGHT, 0, 0)
            progressRight:SetAnchor(LEFT, host, CENTER, 0, 0)
            progressRight:SetBarAlignment(BAR_ALIGNMENT_NORMAL)
            progressRight:SetMinMax(0, 1)
            progressRight:SetValue(0)
            progressRight:SetColor(r, g, b, 0.34)
            progressRight:SetMouseEnabled(false)
            if progressRight.SetDrawTier then progressRight:SetDrawTier(DT_MEDIUM) end
            progressRight:SetDrawLayer(DL_CONTROLS)
            progressRight:SetDrawLevel(28)
            progressRight:SetHidden(true)

            return {
                host = host, fillHost = fillHost,
                progress = progressLeft, progressLeft = progressLeft, progressRight = progressRight,
                progressPieces = { progressLeft, progressRight }, marker = nil, nativeShape = true,
                tickBox = tickBox, tickLabel = tickLabel, tickBgLeft = tickBgLeft, tickBgRight = tickBgRight, tickBgCenter = tickBgCenter, tickFillLeft = tickFillLeft, tickFillRight = tickFillRight, tickGlossLeft = tickGlossLeft, tickGlossRight = tickGlossRight,
                tickFrameLeft = tickFrameLeft, tickFrameRight = tickFrameRight, tickFrameCenter = tickFrameCenter,
                tickRectBack = tickRectBack, tickRectFill = tickRectFill, tickRectGlow = tickRectGlow,
                rectClip = rectClip, rectProgress = rectProgress, rectMarker = rectMarker,
                r = r, g = g, b = b,
            }
        else
            progress = WM:CreateControl(nil, fillHost, CT_BACKDROP)
            progress:SetAnchor(TOPLEFT, fillHost, TOPLEFT, 0, 0)
            progress:SetDimensions(1, math.max(1, fillHost:GetHeight()))
            progress:SetCenterColor(r, g, b, 0.28)
            progress:SetEdgeColor(0, 0, 0, 0)
            progress:SetMouseEnabled(false)
            progress:SetDrawLayer(DL_CONTROLS)
            progress:SetDrawLevel(1)
            progress:SetHidden(true)

            marker = WM:CreateControl(nil, fillHost, CT_BACKDROP)
            marker:SetAnchor(TOPLEFT, fillHost, TOPLEFT, 0, 0)
            marker:SetDimensions(2, math.max(1, fillHost:GetHeight()))
            marker:SetCenterColor(1, 1, 1, 0.92)
            marker:SetEdgeColor(0, 0, 0, 0)
            marker:SetMouseEnabled(false)
            marker:SetDrawLayer(DL_CONTROLS)
            marker:SetDrawLevel(2)
            marker:SetHidden(true)
        end

        return {
            host = host, fillHost = fillHost, progress = progress, marker = marker, nativeShape = nativeShape,
            tickBox = tickBox, tickLabel = tickLabel, tickBgLeft = tickBgLeft, tickBgRight = tickBgRight, tickBgCenter = tickBgCenter, tickFillLeft = tickFillLeft, tickFillRight = tickFillRight, tickGlossLeft = tickGlossLeft, tickGlossRight = tickGlossRight,
            tickFrameLeft = tickFrameLeft, tickFrameRight = tickFrameRight, tickFrameCenter = tickFrameCenter,
            tickRectBack = tickRectBack, tickRectFill = tickRectFill, tickRectGlow = tickRectGlow,
            rectClip = rectClip, rectProgress = rectProgress, rectMarker = rectMarker,
            r = r, g = g, b = b,
        }
    end

    self.indicators = {
        [POWERTYPE_HEALTH] = makeIndicator(bars.health, 1.00, 0.30, 0.30),
        [POWERTYPE_MAGICKA] = makeIndicator(bars.magicka, 0.40, 0.72, 1.00),
        [POWERTYPE_STAMINA] = makeIndicator(bars.stamina, 0.45, 1.00, 0.45),
    }
    self.frame, self.playerHost = frame, player
    self.healthHost, self.magHost, self.staHost = bars.health, bars.magicka, bars.stamina

    frame:SetHandler("OnUpdate", function()
        local at = nowMS()
        if not frame:IsHidden() and at - (T.lastDrawAt or -100) >= 33 then
            T.lastDrawAt = at
            T:RefreshText()
        end
    end)
end

function T:IsPreviewActive()
    return self.demoPending == true or (self.demoUntil ~= nil and nowMS() < self.demoUntil)
end

function T:RefreshPlayerVisibility()
    local frames = EPC.UnitFrames
    if frames and frames.RefreshPlayer then frames:RefreshPlayer() end
end

function T:ShouldShow()
    if not EPC.saved or EPC.saved.enabled == false then return false end
    if self.layoutMode then return true end
    if EPC.saved.showTickTracker029382 ~= true then return false end
    if EPC.IsGameplayHudSuppressed and EPC:IsGameplayHudSuppressed() == true then return false end
    return true
end

function T:GetRecovery(powerType)
    local combat = safe(IsUnitInCombat, false, "player") == true
    local stat
    if powerType == POWERTYPE_HEALTH then
        stat = combat and STAT_HEALTH_REGEN_COMBAT or (STAT_HEALTH_REGEN_IDLE or STAT_HEALTH_REGEN_COMBAT)
    elseif powerType == POWERTYPE_MAGICKA then
        stat = combat and STAT_MAGICKA_REGEN_COMBAT or (STAT_MAGICKA_REGEN_IDLE or STAT_MAGICKA_REGEN_COMBAT)
    elseif powerType == POWERTYPE_STAMINA then
        stat = combat and STAT_STAMINA_REGEN_COMBAT or (STAT_STAMINA_REGEN_IDLE or STAT_STAMINA_REGEN_COMBAT)
    end
    if stat == nil then return 0 end
    local value = tonumber((safe(GetPlayerStat, 0, stat, STAT_BONUS_OPTION_APPLY_BONUS))) or 0

    -- Sprinting/blocking can temporarily report zero Stamina/Magicka recovery.
    -- Preserve the last positive amount for cadence prediction until ESO reports
    -- a real positive value again.
    self.lastPositiveRecovery029426 = self.lastPositiveRecovery029426 or {}
    if value > 0 then
        self.lastPositiveRecovery029426[powerType] = value
        return value
    end
    if powerType == POWERTYPE_MAGICKA or powerType == POWERTYPE_STAMINA then
        return tonumber(self.lastPositiveRecovery029426[powerType]) or 0
    end
    return value
end

function T:SeedSamples()
    self.samples = {}
    -- A zone/player activation can establish a new natural-recovery phase.
    -- Relearn it from the next real recovery pulse instead of carrying stale timing.
    self.sharedLastTick = nil
    for _, power in ipairs(POWER_TYPES) do
        local value, maximum, effective = safe(GetUnitPower, nil, "player", power)
        local sample = sampleFor(self, power)
        sample.lastValue, sample.maximum = value, effective or maximum
        sample.recovery = self:GetRecovery(power)
        sample.lastRecovery = sample.recovery
    end
end

function T:Refresh()
    self:Create()
    local enabled = EPC.saved and EPC.saved.enabled ~= false and EPC.saved.showTickTracker029382 == true
    if self.eventName and enabled ~= self.tracking then
        EPC.Runtime:UnregisterEvent("TickTracker", "Power")
        self.tracking = enabled
        self:SeedSamples()
        if enabled then
            local filters = REGISTER_FILTER_UNIT_TAG and {{REGISTER_FILTER_UNIT_TAG, "player"}} or nil
            EPC.Runtime:RegisterEvent("TickTracker", "Power", EVENT_POWER_UPDATE, function(_, unit, _, power, value, maximum, effective)
                if unit == "player" then T:OnPowerUpdate(power, value, effective or maximum) end
            end, filters)
        end
    end
    if not self.frame then return end
    self.frame:SetHidden(not self:ShouldShow())
    if not self.frame:IsHidden() then self:RefreshText() end
end

function T:IsRecoverySizedGain(delta, recovery)
    if recovery <= 0 or delta <= 0 then return false end
    -- Recovery values can be rounded by ESO and capped gains can be slightly
    -- smaller. Keep the tolerance narrow enough that ordinary heals/restores
    -- do not casually establish a recovery phase.
    local tolerance = math.max(2, recovery * 0.025)
    return math.abs(delta - recovery) <= tolerance
end

function T:ConfirmTick(power, sample, at, delta)
    sample.lastTick = at
    sample.lastConfirm = at
    sample.nextExpected = at + PERIOD
    sample.gain = delta
    sample.candidate = nil
    sample.delayed = false
    sample.missed = 0
    sample.confidence = math.min(3, (sample.confidence or 0) + 1)

    -- Natural stamina/magicka recovery shares the same two-second combat rhythm
    -- for the purpose of the tracker. Remember that phase globally so a resource
    -- can keep counting while its own regeneration is suppressed by sprinting or
    -- blocking. The next real matching recovery pulse automatically re-syncs it.
    if power == POWERTYPE_MAGICKA or power == POWERTYPE_STAMINA then
        self.sharedLastTick = at
    end

    local indicator = self.indicators and self.indicators[power]
    if indicator then indicator.flashUntil = at + CONFIRM_FLASH_MS end
end

function T:OnPowerUpdate(power, value, maximum)
    if not self.tracking or (power ~= POWERTYPE_HEALTH and power ~= POWERTYPE_MAGICKA and power ~= POWERTYPE_STAMINA) then return end
    local sample = sampleFor(self, power)
    local previous, oldMax = sample.lastValue, sample.maximum
    sample.lastValue, sample.maximum = value, maximum
    if not previous or (oldMax and oldMax ~= maximum) then
        sample.lastTick, sample.candidate, sample.nextExpected = nil, nil, nil
        sample.confidence, sample.delayed = 0, false
        sample.spendEvents = {}
        return
    end

    local delta = value - previous
    local at = nowMS()

    if delta < 0 then
        local events = trimSpendEvents(sample, at)
        events[#events + 1] = { at = at, amount = -delta }
        return
    end
    if delta <= 0 then return end

    local recovery = self:GetRecovery(power)
    sample.recovery = recovery
    if recovery <= 0 then return end

    -- Full-value confirmation is intentionally conservative. At cap, a natural
    -- recovery pulse may be truncated or absent, so we predict overcap waste in
    -- the UI but do not use that ambiguous gain to establish the cadence.
    if value >= maximum or not self:IsRecoverySizedGain(delta, recovery) then return end

    -- Once a cadence is trusted, accept a matching gain close to any expected
    -- 2-second cycle. This immediately resynchronizes after a delayed/suppressed
    -- interval without letting a random same-sized restore shift the phase.
    if sample.lastTick and (sample.confidence or 0) >= 1 then
        local age = at - sample.lastTick
        if age > 0 and age < EXPIRE + PERIOD then
            local cycles = math.max(1, math.floor(age / PERIOD + 0.5))
            if math.abs(age - cycles * PERIOD) <= CONFIRM_WINDOW then
                self:ConfirmTick(power, sample, at, delta)
                return
            end
        end
    end

    -- Health still requires two matching pulses because heals/HoTs frequently
    -- resemble Health Recovery. Magicka/Stamina can start a provisional cadence
    -- from the first exact recovery-sized pulse so PvP timing becomes useful
    -- immediately; the next natural pulse confirms/resynchronizes it.
    if power == POWERTYPE_MAGICKA or power == POWERTYPE_STAMINA then
        sample.lastTick = at
        sample.nextExpected = at + PERIOD
        sample.gain = delta
        sample.candidate = at
        sample.delayed = false
        sample.confidence = math.max(0, tonumber(sample.confidence) or 0)
        self.sharedLastTick = at
        return
    end

    if sample.candidate then
        local candidateAge = at - sample.candidate
        if math.abs(candidateAge - PERIOD) <= CONFIRM_WINDOW then
            self:ConfirmTick(power, sample, at, delta)
            return
        end
        if candidateAge > PERIOD + CONFIRM_WINDOW then sample.candidate = nil end
    end
    sample.candidate = at
end

function T:DisplayState(power, at)
    if self.layoutMode then return 0.55, true end
    if self.demoUntil and at < self.demoUntil then
        return ((at - self.demoStart) % PERIOD) / PERIOD, true
    end

    local sample = sampleFor(self, power)
    -- The tracker only matters while this resource is missing. When full, hide
    -- the sweep but keep the remembered phase so spending resource later can show
    -- the correct countdown immediately instead of waiting for another tick.
    if sample.maximum and sample.maximum > 0 and sample.lastValue >= sample.maximum then return 0, false end
    if (sample.recovery or 0) <= 0 then return 0, false end

    -- If this resource's own recovery is suppressed (sprint/block), continue from
    -- the most recently observed natural stamina/magicka tick. Missing a pulse does
    -- NOT reset or hide the bar; releasing sprint/block near the end of the sweep
    -- lets the player catch the upcoming two-second recovery tick.
    local phaseTick = tonumber(sample.lastTick) or tonumber(self.sharedLastTick)
    local age = phaseTick and (at - phaseTick) or nil
    if not age or age < 0 or age >= EXPIRE then return 0, false end
    return (age % PERIOD) / PERIOD, true
end

function T:GetPressureLevel(sample, at)
    if not self:IsAdvanced() or EPC.saved.tickTrackerPressure029415 == false then return 0 end
    local events = trimSpendEvents(sample, at)
    local spent = 0
    for _, event in ipairs(events) do spent = spent + (tonumber(event.amount) or 0) end
    local recovery = tonumber(sample.recovery) or 0
    if recovery <= 0 or spent <= 0 then return 0 end
    -- Pressure is visual-only now. Keep the intelligence, but never append
    -- debug-like symbols or letters to the countdown readout.
    if spent > recovery * 2.20 then return 2 end
    if spent > recovery * 1.20 then return 1 end
    return 0
end

function T:UpdateRecoveryState(sample, recovery, at)
    local prior = tonumber(sample.lastRecovery)
    recovery = tonumber(recovery) or 0
    if prior ~= nil and math.abs(recovery - prior) >= math.max(2, math.abs(prior) * 0.02) then
        sample.recoveryDirection = recovery > prior and 1 or -1
        sample.recoveryChangedUntil = at + CHANGE_BADGE_MS
    end
    sample.lastRecovery = recovery
    sample.recovery = recovery
end

function T:UpdateDelayState(sample, at)
    -- A missing natural recovery pulse is normal while sprinting/blocking in PvP.
    -- Do not replace the useful countdown with SYNC just because a scheduled pulse
    -- produced no resource gain. The cadence keeps running and the next matching
    -- recovery event re-synchronizes it automatically.
    sample.delayed = false
end

function T:BuildAdvancedText(power, sample, phase, at)
    local remaining = math.max(0, (1 - clamp(phase, 0, 1)) * (PERIOD / 1000))
    local recovery = math.max(0, round(sample.recovery or 0))
    local current = tonumber(sample.lastValue) or 0
    local maximum = tonumber(sample.maximum) or 0
    local room = math.max(0, maximum - current)
    local predicted = math.min(recovery, round(room))
    local waste = math.max(0, recovery - predicted)

    if sample.delayed then
        return "SYNC"
    end

    -- Keep the live readout human-readable. Advanced intelligence is conveyed
    -- by visual state (pulse/flash/tint), not debug-style suffix characters.
    if EPC.saved.tickTrackerWaste029415 ~= false and waste > 0 then
        return string.format("%.1fs +%d WASTE", remaining, predicted)
    end
    return string.format("%.1fs +%d", remaining, predicted)
end

local function EAS_TickFrameDesign029422()
    local design = EPC.saved and tostring(EPC.saved.unitFrameVisualStyle or "ESO_CLASSIC") or "ESO_CLASSIC"
    if design == "CLEAN_MINIMAL" then return "COMPACT_STACK" end
    if design == "DARK_GOLD" or design == "ARCANE_BLUE" or design == "HIGH_CONTRAST"
        or design == "SPLIT_RESOURCES" or design == "WIDE_PLATE" or design == "TACTICAL_GRID" then
        return "CENTER_CORE"
    end
    return design
end

local function EAS_IsRectTickDesign029422(design)
    return design == "RECT_STACK" or design == "TRIPLE_BLOCKS" or design == "SIDE_METERS"
        or design == "CENTER_CORE" or design == "SLIM_LINES"
end

local function EAS_TickAttachmentProfile029422(design, powerType, advanced, fancy, host)
    local hostH = math.max(12, math.floor((host and host:GetHeight() or 20) + 0.5))
    local hostW = math.max(30, math.floor((host and host:GetWidth() or 100) + 0.5))
    local p = { shape = "POINTED", anchor = "LEFT", gap = 2, h = hostH }

    if design == "ESO_CLASSIC" then
        p.w = advanced and (fancy and 124 or 108) or (fancy and 62 or 50)
        p.h = fancy and math.max(23, math.floor(hostH * 1.16 + 0.5)) or hostH
    elseif design == "COMPACT_STACK" then
        p.w = advanced and (fancy and 112 or 98) or (fancy and 58 or 48)
        p.h = fancy and math.max(21, math.floor(hostH * 1.10 + 0.5)) or hostH
    elseif design == "RECT_STACK" then
        p.shape, p.anchor = "RECT", "LEFT"
        p.w = advanced and (fancy and 116 or 102) or (fancy and 58 or 48)
        p.h = fancy and math.max(20, hostH + 2) or math.max(18, hostH)
    elseif design == "TRIPLE_BLOCKS" then
        p.shape = "RECT"
        -- Spread the three readouts around the horizontal three-block group while
        -- keeping the entire top edge clear for the player buff row.
        if powerType == POWERTYPE_HEALTH then p.anchor = "LEFT"
        elseif powerType == POWERTYPE_MAGICKA then p.anchor = "BOTTOM"
        else p.anchor = "RIGHT" end
        p.w = advanced and math.min(math.max(82, math.floor(hostW * 0.76)), fancy and 116 or 102) or 48
        p.h = fancy and 22 or 20
    elseif design == "SIDE_METERS" then
        p.shape = "RECT"
        p.anchor = powerType == POWERTYPE_HEALTH and "LEFT" or "RIGHT"
        p.w = advanced and (powerType == POWERTYPE_HEALTH and (fancy and 116 or 102) or (fancy and 104 or 92)) or 48
        p.h = powerType == POWERTYPE_HEALTH and math.max(20, hostH) or (fancy and 20 or 18)
    elseif design == "CENTER_CORE" then
        p.shape, p.anchor = "RECT", "LEFT"
        p.w = advanced and (fancy and 112 or 98) or 48
        p.h = powerType == POWERTYPE_HEALTH and math.max(20, hostH) or (fancy and 20 or 18)
    elseif design == "SLIM_LINES" then
        p.shape, p.anchor = "RECT", "RIGHT"
        p.w = advanced and (fancy and 104 or 92) or 46
        p.h = fancy and 20 or 18
    end
    return p
end

local function EAS_ApplyTickAnchor029422(box, host, profile)
    box:ClearAnchors()
    local gap = profile.gap or 2
    if profile.anchor == "RIGHT" then
        box:SetAnchor(LEFT, host, RIGHT, gap, 0)
    elseif profile.anchor == "TOP" then
        box:SetAnchor(BOTTOM, host, TOP, 0, -gap)
    elseif profile.anchor == "BOTTOM" then
        box:SetAnchor(TOP, host, BOTTOM, 0, gap)
    else
        box:SetAnchor(RIGHT, host, LEFT, -gap, 0)
    end
end

local function EAS_SetTickSidecarShape029422(indicator, profile)
    local pointed = profile.shape == "POINTED"
    for _, piece in ipairs({indicator.tickBgLeft, indicator.tickBgRight, indicator.tickBgCenter,
        indicator.tickFillLeft, indicator.tickFillRight, indicator.tickGlossLeft, indicator.tickGlossRight,
        indicator.tickFrameLeft, indicator.tickFrameRight, indicator.tickFrameCenter}) do
        if piece then piece:SetHidden(not pointed) end
    end
    for _, piece in ipairs({indicator.tickRectBack, indicator.tickRectFill, indicator.tickRectGlow}) do
        if piece then piece:SetHidden(pointed) end
    end
end

function T:RefreshText()
    if not self.frame or self.frame:IsHidden() then return end
    local at = nowMS()
    if self.demoPending and self.playerHost and not self.playerHost:IsHidden()
        and not (EPC.IsGameplayHudSuppressed and EPC:IsGameplayHudSuppressed()) then
        self.demoPending = nil
        self.demoStart, self.demoUntil = at, at + 10000
        local expires = self.demoUntil
        zo_callLater(function()
            if T.demoUntil == expires then
                T.demoUntil = nil
                T:RefreshPlayerVisibility()
                T:Refresh()
            end
        end, 10000)
    end

    if not self.lastStatsAt or at - self.lastStatsAt >= 250 then
        for _, power in ipairs(POWER_TYPES) do
            local sample = sampleFor(self, power)
            self:UpdateRecoveryState(sample, self:GetRecovery(power), at)
            self:UpdateDelayState(sample, at)
        end
        self.lastStatsAt = at
    end

    for _, power in ipairs(POWER_TYPES) do
        local indicator = self.indicators and self.indicators[power]
        if indicator then
            local sample = sampleFor(self, power)
            local phase, active = self:DisplayState(power, at)
            local host = indicator.host
            local fillHost = indicator.fillHost or (host and host.epcFill) or host
            local innerWidth = fillHost and math.max(0, fillHost:GetWidth()) or 0
            local innerHeight = fillHost and math.max(1, fillHost:GetHeight()) or 1
            local visible = active and phase > 0 and host and fillHost and not host:IsHidden()

            local design = EAS_TickFrameDesign029422()
            local rectDesign = EAS_IsRectTickDesign029422(design)
            if indicator.progressPieces then
                for _, piece in ipairs(indicator.progressPieces) do piece:SetHidden(rectDesign or not visible) end
            elseif indicator.progress then
                indicator.progress:SetHidden(rectDesign or not visible)
            end
            if indicator.marker then indicator.marker:SetHidden(rectDesign or not visible) end
            if indicator.rectProgress then indicator.rectProgress:SetHidden((not rectDesign) or not visible) end
            if indicator.rectMarker then indicator.rectMarker:SetHidden((not rectDesign) or not visible) end

            if indicator.tickBox then
                local readoutStyle = (EPC.saved and EPC.saved.tickTrackerReadoutStyle029417) or "SLIM"
                local showReadout = visible and readoutStyle ~= "OFF"
                indicator.tickBox:SetHidden(not showReadout)
                if showReadout then
                    local design = EAS_TickFrameDesign029422()
                    local advanced = self:IsAdvanced()
                    local fancy = readoutStyle == "FANCY"
                    local profile = EAS_TickAttachmentProfile029422(design, power, advanced, fancy, host)
                    EAS_ApplyTickAnchor029422(indicator.tickBox, host, profile)
                    indicator.tickBox:SetDimensions(profile.w, profile.h)
                    EAS_SetTickSidecarShape029422(indicator, profile)

                    if profile.shape == "POINTED" then
                        local capW = math.max(8, math.floor(13 * (profile.h / 23) + 0.5))
                        if indicator.tickFrameLeft then indicator.tickFrameLeft:SetDimensions(capW, profile.h) end
                        if indicator.tickFrameRight then indicator.tickFrameRight:SetDimensions(capW, profile.h) end
                        if indicator.tickBgLeft then indicator.tickBgLeft:SetDimensions(capW, profile.h) end
                        if indicator.tickBgRight then indicator.tickBgRight:SetDimensions(capW, profile.h) end
                        local fillH = math.max(6, math.floor(17 * (profile.h / 23) + 0.5))
                        for _, fillPiece in ipairs({indicator.tickFillLeft, indicator.tickFillRight, indicator.tickGlossLeft, indicator.tickGlossRight}) do
                            if fillPiece then fillPiece:SetHeight(fillH) end
                        end
                    end

                    local flashing = indicator.flashUntil and at < indicator.flashUntil
                    local recoveryChanged = sample.recoveryChangedUntil and at < sample.recoveryChangedUntil
                    local pressureLevel = advanced and self:GetPressureLevel(sample, at) or 0

                    local fr, fg, fb, fa = indicator.r * 0.42, indicator.g * 0.42, indicator.b * 0.42, 0.92
                    local gr, gg, gb, ga = indicator.r, indicator.g, indicator.b, fancy and 0.16 or 0.09
                    if flashing and EPC.saved.tickTrackerConfirm029415 ~= false then
                        fr, fg, fb, fa = 0.80, 0.80, 0.80, 0.98
                        gr, gg, gb, ga = 1, 1, 1, 0.48
                    elseif recoveryChanged then
                        local pulse = 0.28 + (0.18 * ((math.sin(at / 85) + 1) * 0.5))
                        fr, fg, fb, fa = indicator.r * 0.52, indicator.g * 0.52, indicator.b * 0.52, 0.96
                        gr, gg, gb, ga = 1, 1, 1, pulse
                    elseif pressureLevel > 0 then
                        fr, fg, fb, fa = indicator.r * 0.50, indicator.g * 0.50, indicator.b * 0.50, 0.96
                        ga = pressureLevel == 2 and 0.28 or 0.19
                    end

                    if profile.shape == "POINTED" then
                        for _, fillPiece in ipairs({indicator.tickFillLeft, indicator.tickFillRight}) do
                            if fillPiece then fillPiece:SetColor(fr, fg, fb, fa) end
                        end
                        for _, glossPiece in ipairs({indicator.tickGlossLeft, indicator.tickGlossRight}) do
                            if glossPiece then glossPiece:SetColor(gr, gg, gb, ga) end
                        end
                    else
                        if indicator.tickRectFill then indicator.tickRectFill:SetCenterColor(fr, fg, fb, fa) end
                        if indicator.tickRectGlow then indicator.tickRectGlow:SetCenterColor(gr, gg, gb, ga) end
                        if indicator.tickRectBack then
                            indicator.tickRectBack:SetEdgeColor(indicator.r * 0.75, indicator.g * 0.75, indicator.b * 0.75, fancy and 0.95 or 0.76)
                        end
                    end

                    local textInset = profile.shape == "POINTED" and math.max(6, math.floor(13 * (profile.h / 23) * 0.55 + 0.5)) or 5
                    if indicator.tickLabel then
                        local readoutText
                        if advanced then
                            readoutText = self:BuildAdvancedText(power, sample, phase, at)
                        else
                            local remaining = math.max(0, (1 - clamp(phase, 0, 1)) * (PERIOD / 1000))
                            readoutText = string.format("%.1fs", remaining)
                        end

                        indicator.tickLabel:SetText(readoutText)

                        -- Advanced strings such as "1.9s +1388 WASTE" are wider
                        -- than several of the visual-design presets. Size the
                        -- sidecar to the *actual rendered text* so the final E in
                        -- WASTE (and large recovery values) can never be clipped.
                        -- Keep the design profile as the minimum width so normal
                        -- Basic readouts retain their compact appearance.
                        local measuredTextW = 0
                        if indicator.tickLabel.GetTextWidth then
                            measuredTextW = tonumber(indicator.tickLabel:GetTextWidth()) or 0
                        end
                        local requiredW = math.ceil(measuredTextW + (textInset * 2) + 6)
                        local finalW = math.max(profile.w, requiredW)
                        if finalW ~= profile.w then
                            profile.w = finalW
                            indicator.tickBox:SetDimensions(profile.w, profile.h)
                            EAS_SetTickSidecarShape029422(indicator, profile)
                        end
                        indicator.tickLabel:SetDimensions(math.max(1, profile.w - (textInset * 2)), profile.h)
                    end
                else
                    EAS_SetTickSidecarShape029422(indicator, {shape = "RECT"})
                    if indicator.tickRectBack then indicator.tickRectBack:SetHidden(true) end
                    if indicator.tickRectFill then indicator.tickRectFill:SetHidden(true) end
                    if indicator.tickRectGlow then indicator.tickRectGlow:SetHidden(true) end
                end
            end

            if visible then
                if rectDesign and indicator.rectProgress then
                    -- Match the exact visible rectangle used by UnitFrames.lua:
                    -- TOPLEFT +2,+2; BOTTOMLEFT +2,-2; width = bar width - 4.
                    local innerW = math.max(1, math.floor((host:GetWidth() or 1) - 4 + 0.5))
                    local innerH = math.max(1, math.floor((host:GetHeight() or 1) - 4 + 0.5))
                    if indicator.rectClip then
                        indicator.rectClip:ClearAnchors()
                        indicator.rectClip:SetAnchor(TOPLEFT, host, TOPLEFT, 2, 2)
                        indicator.rectClip:SetDimensions(innerW, innerH)
                    end
                    local width = math.max(1, math.min(innerW, math.floor(innerW * clamp(phase, 0, 1) + 0.5)))
                    indicator.rectProgress:ClearAnchors()
                    indicator.rectProgress:SetAnchor(TOPLEFT, indicator.rectClip or host, TOPLEFT, 0, 0)
                    indicator.rectProgress:SetDimensions(width, innerH)
                    if indicator.rectMarker then
                        local markerW = math.min(2, innerW)
                        local markerX = math.max(0, math.min(innerW - markerW, width - markerW))
                        indicator.rectMarker:ClearAnchors()
                        indicator.rectMarker:SetAnchor(TOPLEFT, indicator.rectClip or host, TOPLEFT, markerX, 0)
                        indicator.rectMarker:SetDimensions(markerW, innerH)
                    end
                elseif indicator.nativeShape and indicator.progressLeft and indicator.progressRight then
                    local value = clamp(phase, 0, 1)
                    local leftHeight = host.epcFillLeft and math.max(1, host.epcFillLeft:GetHeight()) or innerHeight
                    local rightHeight = host.epcFillRight and math.max(1, host.epcFillRight:GetHeight()) or innerHeight
                    indicator.progressLeft:SetHeight(leftHeight)
                    indicator.progressRight:SetHeight(rightHeight)
                    indicator.progressLeft:SetMinMax(0, 1)
                    indicator.progressRight:SetMinMax(0, 1)
                    indicator.progressLeft:SetValue(value)
                    indicator.progressRight:SetValue(value)
                else
                    local width = math.max(1, math.min(innerWidth, innerWidth * phase))
                    indicator.progress:ClearAnchors()
                    indicator.progress:SetAnchor(TOPLEFT, fillHost, TOPLEFT, 0, 0)
                    indicator.progress:SetDimensions(width, innerHeight)

                    if indicator.marker then
                        local markerWidth = math.min(2, math.max(1, innerWidth))
                        local markerX = math.max(0, math.min(innerWidth - markerWidth, width - markerWidth))
                        indicator.marker:ClearAnchors()
                        indicator.marker:SetAnchor(TOPLEFT, fillHost, TOPLEFT, markerX, 0)
                        indicator.marker:SetDimensions(markerWidth, innerHeight)
                    end
                end
            end
        end
    end
end

function T:SetLayoutMode(active)
    self.layoutMode = active == true
    self:Refresh()
end

function T:Reveal(test)
    if not EPC.saved then return end
    EPC.saved.showTickTracker029382 = true
    self.demoPending = test == true
    self.demoStart, self.demoUntil = nil, nil
    self:RefreshPlayerVisibility()
    self:Refresh()
    if EPC.Print then
        if EPC.saved.enabled == false then
            EPC:Print("Enable ESO Adventurer Suite in its settings to display the resource tracker.")
        elseif not self.playerHost or self.playerHost:IsHidden() then
            EPC:Print("Resource ticks enabled. Show the Suite player frame to see them; they follow its visibility.")
        else
            EPC:Print(test and "Resource ticks: ten-second DEMO queued. Close menus to see the integrated Health/Magicka/Stamina ticks and advanced readouts."
                or "Resource ticks enabled inside your player bars. /easticks test previews the indicators.")
        end
    end
end

function T:Initialize()
    if self.initialized then return end
    self.layoutMode = false
    if EPC.saved and not EPC.saved.tickTrackerVisible029404 then
        EPC.saved.showTickTracker029382 = true
        EPC.saved.tickTrackerVisible029404 = true
    end
    if EPC.saved then
        if EPC.saved.tickTrackerMode029415 == nil then EPC.saved.tickTrackerMode029415 = "ADVANCED" end
        if EPC.saved.tickTrackerWaste029415 == nil then EPC.saved.tickTrackerWaste029415 = true end
        if EPC.saved.tickTrackerConfirm029415 == nil then EPC.saved.tickTrackerConfirm029415 = true end
        if EPC.saved.tickTrackerPressure029415 == nil then EPC.saved.tickTrackerPressure029415 = true end
        if EPC.saved.tickTrackerResync029415 == nil then EPC.saved.tickTrackerResync029415 = true end
    end
    self:Create()
    local prefix = (EPC.name or "ESOAdventurerSuite") .. "_TickTracker029382"
    self.eventName = prefix .. "_Power"
    EPC.Runtime:RegisterEvent("TickTracker", "Combat", EVENT_PLAYER_COMBAT_STATE, function()
        T.lastStatsAt = nil
        T:Refresh()
    end)
    EPC.Runtime:RegisterEvent("TickTracker", "Activated", EVENT_PLAYER_ACTIVATED, function()
        T:SeedSamples()
        T.lastStatsAt = nil
        T:Refresh()
    end)
    EVENT_MANAGER:UnregisterForUpdate(prefix .. "_Countdown")
    self:Refresh()
    SLASH_COMMANDS["/easticks"] = function(argument)
        local action = string.lower(tostring(argument or "")):match("^%s*(.-)%s*$")
        if action == "off" then
            EPC.saved.showTickTracker029382 = false
            T.demoPending, T.demoUntil = nil, nil
            T:RefreshPlayerVisibility()
            T:Refresh()
        elseif action == "basic" then
            EPC.saved.tickTrackerMode029415 = "BASIC"
            T:Reveal(false)
            if EPC.Print then EPC:Print("Resource ticks switched to Basic readouts.") end
        elseif action == "advanced" then
            EPC.saved.tickTrackerMode029415 = "ADVANCED"
            T:Reveal(false)
            if EPC.Print then EPC:Print("Resource ticks switched to Advanced readouts.") end
        elseif action == "" or action == "show" or action == "test" then
            T:Reveal(action == "test")
        elseif EPC.Print then
            EPC:Print("Resource ticks: /easticks, /easticks test, /easticks basic, /easticks advanced, /easticks off.")
        end
    end
    self.initialized = true
end

-- Sprint/block recovery persistence is owned directly by GetRecovery.\n