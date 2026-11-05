-- Arclight Taunt 1.1.2 | Native row and banner progress animations
-- No frame-driven Lua loop: ESO animates cached visible controls directly.
local A = ArclightTaunt
local C, SetHidden, SetColor = A.C, A.SetHidden, A.SetColor
local FOCUS_SECONDS = 0.36
local STRIPE_SECONDS = 0.30
local ENTRY_SECONDS, ENTRY_ALPHA = 0.12, 0.82
local REFLOW_SECONDS, REVEAL_SECONDS = 0.14, 0.08
local GLOSS_SECONDS, GLOSS_FADE_IN, GLOSS_FADE_OUT = .48, .10, .16
local LinearEase = ZO_LinearEase or function(progress) return progress end
local function ReflowEase(progress)
    return 1 - (1 - progress) ^ 3
end

local function StopStripe(row)
    if row.stripeRunning then row.stripeRunning = false; row.stripeTimeline:Stop() end
end
local function StripeWidth(row, now)
    local p = A.Clamp((now - (row.stripeAt or now)) / STRIPE_SECONDS, 0, 1)
    return row.stripeFrom + (row.stripeTo - row.stripeFrom) * p
end
local function AnimateAccent(row, target, now, width, desired, full, high)
    local paused = A.demo and A.demoPausedAt ~= nil
    local reduced = A.saved.reduceAnimations == true
    local reset = row.stripeTarget ~= target or row.stripeWidth ~= width
        or row.stripeHeight ~= row.lastRowHeight or row.stripeFull ~= full
        or row.stripeBarHeight ~= row.barHeight or row.stripeDividerHeight ~= row.contrastHeight
        or row.stripeHigh ~= high or row.stripeMirror ~= A.saved.mirrorTauntList
        or row.stripeTrack ~= A.saved.texturedTrack or row.stripeReduced ~= reduced
    local changed = reset or row.stripeTo ~= desired or row.stripePaused ~= paused
    if not changed then return end
    local current = (reset or reduced) and desired or StripeWidth(row, now)
    local transitionChanged = row.stripeRunning or (not reset and row.stripeTo ~= desired)
    StopStripe(row)
    if transitionChanged then row.stripeRevision = (row.stripeRevision or 0) + 1 end
    row.stripeTarget, row.stripeWidth, row.stripeHeight = target, width, row.lastRowHeight
    row.stripeBarHeight, row.stripeDividerHeight = row.barHeight, row.contrastHeight
    row.stripeFull, row.stripeHigh, row.stripeMirror = full, high, A.saved.mirrorTauntList
    row.stripeTrack, row.stripePaused = A.saved.texturedTrack, paused
    row.stripeReduced = reduced
    if reset or row.stripeTo ~= desired then
        row.stripeFrom, row.stripeTo, row.stripeAt = current, desired, now
    end
    local seconds = math.max(0, STRIPE_SECONDS - (now - row.stripeAt))
    row.accent:SetWidth(current)
    for _, c in ipairs({row.progressRegion, row.barRegion, row.track, row.trackTexture, row.contrastEdge}) do c:SetWidth(width - current) end
    if current == desired or seconds <= 0 or paused then return end
    if not row.stripeTimeline then
        row.stripeTimeline = ANIMATION_MANAGER:CreateTimeline()
        row.stripeAnimations = {}
        for _, c in ipairs({row.accent, row.progressRegion, row.barRegion, row.track, row.trackTexture, row.contrastEdge}) do
            local animation = row.stripeTimeline:InsertAnimation(ANIMATION_SIZE, c, 0)
            animation:SetEasingFunction(LinearEase)
            row.stripeAnimations[#row.stripeAnimations + 1] = animation
        end
        row.stripeTimeline:SetHandler("OnStop", function() row.stripeRunning = false end)
    end
    local heights = {row.lastRowHeight, row.lastRowHeight, row.barHeight, row.barHeight, row.barHeight, row.contrastHeight}
    local enabled = {true, true, not full, not full and (high or not row.stripeTrack),
        not full and not high and row.stripeTrack, high}
    for i, animation in ipairs(row.stripeAnimations) do
        animation:SetEnabled(enabled[i]); animation:SetDuration(math.max(1, math.ceil(seconds * 1000)))
        if enabled[i] then
            animation:SetStartAndEndWidth(i == 1 and current or width - current, i == 1 and desired or width - desired)
            animation:SetStartAndEndHeight(heights[i], heights[i])
        end
    end
    row.stripeRunning = true; row.stripeTimeline:PlayFromStart()
end

local function StopProgress(row)
    if row.progressRunning then
        row.progressRunning = false -- manual stops must not complete an old target
        row.progressTimeline:Stop()
    end
end

local function EnsureProgress(row)
    if row.progressTimeline then return end
    local timeline = ANIMATION_MANAGER:CreateTimeline()
    row.progressTimeline = timeline
    row.progressAnimations, row.progressTransitionAnimations = {}, {}
    for i, control in ipairs({row.fullFill, row.fill, row.mediaFill}) do
        local animation = timeline:InsertAnimation(ANIMATION_SIZE, control, 0)
        animation:SetEasingFunction(LinearEase)
        row.progressTransitionAnimations[i] = animation
    end
    for i, control in ipairs({row.fullFill, row.fill, row.mediaFill}) do
        local animation = timeline:InsertAnimation(ANIMATION_SIZE, control, 0)
        animation:SetEasingFunction(LinearEase)
        row.progressAnimations[i] = animation
    end
    timeline:SetHandler("OnStop", function(_, completed)
        if not row.progressRunning then return end
        row.progressRunning = false
        local target = row.progressTarget
        if completed and target and target.startTime == row.progressStart
            and target.endTime == row.progressEnd and A.DemoNow(A.Now()) >= row.progressEnd then
            -- Expiry is a single visual boundary. Tracking, sorting and warning
            -- processing remain on their normal schedule, never in this callback.
            SetHidden(row.fullFill, true)
            SetHidden(row.fill, true)
            SetHidden(row.mediaFill, true)
            SetHidden(row.progressTip, true)
            if row.lastDisplayTime ~= "0,0" then
                row.time:SetText("0,0")
                row.lastDisplayTime = "0,0"
            end
            local color = row.progressHighContrast and C.highDanger or C.danger
            SetColor(row.time, color)
            row.lastTimeColor = color
        end
    end)
end

local function AnimateProgress(row, target, now, width, fullMode, highContrast, expired)
    local full = fullMode == true
    local solid = not full and not row.useMediaFill
    local textured = not full and row.useMediaFill
    local height = full and row.lastRowHeight or row.barHeight
    local paused = A.demo and A.demoPausedAt ~= nil
    local changed = row.progressTarget ~= target or row.progressStart ~= target.startTime
        or row.progressEnd ~= target.endTime or row.progressWidth ~= width
        or row.progressFull ~= full or row.progressSolid ~= solid or row.progressTextured ~= textured
        or row.progressHighContrast ~= highContrast
        or row.progressHeight ~= height or row.progressPaused ~= paused
        or row.progressStripeRevision ~= row.stripeRevision
        or row.progressMirrored ~= A.saved.mirrorTauntList
    local remaining = math.max(0, target.endTime - now)
    if not changed and row.progressRunning and not expired and remaining > 0 then return end

    StopProgress(row)
    row.progressTarget, row.progressStart, row.progressEnd = target, target.startTime, target.endTime
    row.progressWidth, row.progressHeight, row.progressPaused = width, height, paused
    row.progressFull, row.progressSolid, row.progressTextured = full, solid, textured
    row.progressHighContrast, row.progressMirrored = highContrast, A.saved.mirrorTauntList
    row.progressStripeRevision = row.stripeRevision
    local currentSpace = row.stripeWidth - StripeWidth(row, now)
    local durationSeconds = math.max(0.1, target.endTime - target.startTime)
    local currentWidth = expired and 0 or currentSpace * A.Clamp(remaining / durationSeconds, 0, 1)
    -- Only the visible variant needs width writes, including while paused.
    if full then
        if row.lastFullBarWidth ~= currentWidth or changed then row.fullFill:SetWidth(currentWidth) end
        row.lastFullBarWidth = currentWidth
    else
        if row.lastThinBarWidth ~= currentWidth or changed then
            if solid then row.fill:SetWidth(currentWidth) end
            if textured then row.mediaFill:SetWidth(currentWidth) end
        end
        row.lastThinBarWidth = currentWidth
    end
    if expired or remaining <= 0 or paused then return end

    EnsureProgress(row)
    local duration = math.max(1, math.ceil(remaining * 1000))
    local transition = row.stripeRunning and math.min(duration, math.max(1, math.ceil((STRIPE_SECONDS - (now - row.stripeAt)) * 1000))) or 0
    local after = width * A.Clamp((remaining - transition / 1000) / durationSeconds, 0, 1)
    for i, animation in ipairs(row.progressAnimations) do
        local enabled = (i == 1 and full) or (i == 2 and solid) or (i == 3 and textured)
        local lead = row.progressTransitionAnimations[i]
        lead:SetEnabled(enabled and transition > 0)
        lead:SetDuration(math.max(1, transition))
        if enabled and transition > 0 then
            lead:SetStartAndEndWidth(currentWidth, after)
            lead:SetStartAndEndHeight(height, height)
        end
        animation:SetEnabled(enabled and duration > transition)
        row.progressTimeline:SetAnimationOffset(animation, transition)
        animation:SetDuration(math.max(1, duration - transition))
        if enabled then
            animation:SetStartAndEndWidth(transition > 0 and after or currentWidth, 0)
            animation:SetStartAndEndHeight(height, height)
        end
    end
    row.progressRunning = true
    row.progressTimeline:PlayFromStart()
end

local function ObserveFocus(id, now)
    if A.focusTargetId ~= id then
        A.focusTargetId, A.focusAcquiredAt = id, id and now or nil
        A.focusSerial = (A.focusSerial or 0) + 1
    end
end

-- A row keeps its enemy's controls. Only order-preserving vertical compaction
-- moves; crossing re-taunts and layout changes snap instead of crossing names.
local function RowPosition(row, now)
    local x, y = row.placementX, row.placementY
    if row.placementAt and row.placementFromY then
        local p = A.Clamp((now - row.placementAt) / REFLOW_SECONDS, 0, 1)
        y = row.placementFromY + (y - row.placementFromY) * ReflowEase(p)
    end
    return x, y
end
local function StopPlacement(row)
    if row.placementRunning then row.placementRunning = false; row.placementTimeline:Stop() end
    if row.revealRunning then row.revealRunning = false; row.revealTimeline:Stop() end
end
local function RevealRow(row, now, paused)
    if not row.revealAt then
        if row.revealAlpha ~= 1 then row.gate:SetAlpha(1); row.revealAlpha = 1 end
        return
    end
    if row.revealPaused == paused then return end
    if row.revealRunning then row.revealRunning = false; row.revealTimeline:Stop() end
    row.revealPaused = paused
    local p = A.Clamp((now - row.revealAt) / REVEAL_SECONDS, 0, 1)
    row.gate:SetAlpha(p); row.revealAlpha = p
    if p >= 1 then row.revealAt = nil; return end
    if paused then return end
    if not row.revealTimeline then
        row.revealTimeline = ANIMATION_MANAGER:CreateTimeline()
        row.revealAnimation = row.revealTimeline:InsertAnimation(ANIMATION_ALPHA, row.gate, 0)
        row.revealAnimation:SetEasingFunction(LinearEase)
        row.revealTimeline:SetHandler("OnStop", function(_, completed)
            row.revealRunning = false
            if completed then
                row.revealAt, row.revealAlpha = nil, 1
                row.gate:SetAlpha(1)
            end
        end)
    end
    row.revealTimeline:SetAnimationOffset(row.revealAnimation, math.max(0, math.ceil((row.revealAt - now) * 1000)))
    row.revealAnimation:SetAlphaValues(p, 1)
    row.revealAnimation:SetDuration(math.max(1, math.ceil((1 - p) * REVEAL_SECONDS * 1000)))
    row.revealRunning = true; row.revealTimeline:PlayFromStart()
end
local function PlaceRow(row, target, now, x, y)
    local paused = A.demo and A.demoPausedAt ~= nil
    local reduced = A.saved.reduceAnimations == true
    local plan = row.placementPlan
    if plan or row.placementTarget ~= target or row.placementX ~= x or row.placementY ~= y then
        StopPlacement(row)
        row.placementPlan = nil
        row.placementTarget, row.placementX, row.placementY = target, x, y
        row.placementAt = not reduced and plan and plan.move and now or nil
        row.placementFromY = row.placementAt and plan.fromY or nil
        row.placementPaused = nil
        row.revealAt = not reduced and plan and plan.wait and now + REFLOW_SECONDS or nil
        row.revealPaused = nil
    end
    if row.placementPaused ~= paused then
        if row.placementRunning then row.placementRunning = false; row.placementTimeline:Stop() end
        row.placementPaused = paused
        local _, currentY = RowPosition(row, now)
        row.box:ClearAnchors(); row.box:SetAnchor(TOPLEFT, A.root, TOPLEFT, x, currentY)
        local left = row.placementAt and REFLOW_SECONDS - (now - row.placementAt) or 0
        if not paused and left > 0 and math.abs(currentY - y) > .001 then
            if not row.placementTimeline then
                row.placementTimeline = ANIMATION_MANAGER:CreateTimeline()
                row.placementAnimation = row.placementTimeline:InsertAnimation(ANIMATION_TRANSLATE, row.box, 0)
                row.placementAnimation:SetEasingFunction(ReflowEase)
                row.placementTimeline:SetHandler("OnStop", function() row.placementRunning = false end)
            end
            row.placementAnimation:SetTranslateOffsets(x, currentY, x, y)
            row.placementAnimation:SetDuration(math.max(1, math.ceil(left * 1000)))
            row.placementRunning = true; row.placementTimeline:PlayFromStart()
        end
    end
    RevealRow(row, now, paused)
end

-- One shared, lazy visual for the entire HUD. No per-row gloss timers, idle
-- animation, pending queue or texture asset. Only a Strong focus acquisition
-- triggers it; taunt applications and renewals never launch a reflection.
local function StopGloss(row)
    local g = A.gloss
    if not g or not g.owner or (row and g.owner ~= row) then return end
    if g.running then g.running = false; g.timeline:Stop() end
    SetHidden(g.viewport, true)
    g.owner, g.target, g.at, g.paused = nil, nil, nil, nil
end
local function MakeGloss(row)
    local viewport = A.WM:CreateControl(nil, row.box, CT_CONTROL)
    viewport:SetAutoRectClipChildren(true); viewport:SetMouseEnabled(false)
    viewport:SetDrawLayer(DL_BACKGROUND); viewport:SetDrawLevel(4)
    SetHidden(viewport, true)
    local sweep = A.WM:CreateControl(nil, viewport, CT_CONTROL)
    local g = {viewport = viewport, sweep = sweep, strips = {}, duration = GLOSS_SECONDS}
    -- Four staggered soft bands approximate a diagonal reflection without a
    -- bitmap. All remain below text, skull, urgency stripe and narrow fills.
    for i = 1, 8 do
        local strip = A.Solid(sweep, {1, 1, .98, 1})
        if strip.SetPixelRoundingEnabled then strip:SetPixelRoundingEnabled(false) end
        local left = i % 2 == 1
        local band = math.floor((i - 1) / 2)
        local intensity = (band == 0 or band == 3) and .35 or 1
        strip:SetGradientColors(ORIENTATION_HORIZONTAL, 1, 1, .98, left and 0 or intensity,
            1, 1, .98, left and intensity or 0)
        strip:SetDrawLayer(DL_BACKGROUND); strip:SetDrawLevel(4)
        g.strips[i] = strip
    end
    g.timeline = ANIMATION_MANAGER:CreateTimeline()
    g.move = g.timeline:InsertAnimation(ANIMATION_TRANSLATE, sweep, 0)
    g.fadeIn = g.timeline:InsertAnimation(ANIMATION_ALPHA, viewport, 0)
    g.fadeOut = g.timeline:InsertAnimation(ANIMATION_ALPHA, viewport, 0)
    for _, animation in ipairs({g.move, g.fadeIn, g.fadeOut}) do animation:SetEasingFunction(LinearEase) end
    g.timeline:SetHandler("OnStop", function(_, completed)
        g.running = false
        if completed then StopGloss() end
    end)
    A.gloss = g
    return g
end
local function UpdateGlossMotion(g, now, paused)
    if g.paused == paused then return end
    if g.running then g.running = false; g.timeline:Stop() end
    g.paused = paused
    local elapsed = A.Clamp(now - g.at, 0, GLOSS_SECONDS)
    local p = elapsed / GLOSS_SECONDS
    local alpha = g.peakAlpha * math.min(1, elapsed / GLOSS_FADE_IN, (GLOSS_SECONDS - elapsed) / GLOSS_FADE_OUT)
    local fromX, toX = -g.sweepWidth, g.width + 2 * g.halfWidth
    if g.mirror then fromX, toX = toX, fromX end
    local x, y = fromX + (toX - fromX) * p, -g.height + 1.4 * g.height * p
    g.sweep:ClearAnchors(); g.sweep:SetAnchor(TOPLEFT, g.viewport, TOPLEFT, x, y)
    g.viewport:SetAlpha(alpha)
    if paused then return end
    local left = GLOSS_SECONDS - elapsed
    g.move:SetTranslateOffsets(x, y, toX, .4 * g.height)
    g.move:SetDuration(math.max(1, math.ceil(left * 1000)))
    g.fadeIn:SetEnabled(elapsed < GLOSS_FADE_IN)
    if elapsed < GLOSS_FADE_IN then
        g.fadeIn:SetAlphaValues(alpha, g.peakAlpha)
        g.fadeIn:SetDuration(math.max(1, math.ceil((GLOSS_FADE_IN - elapsed) * 1000)))
    end
    g.timeline:SetAnimationOffset(g.fadeOut, math.max(0, math.ceil((GLOSS_SECONDS - GLOSS_FADE_OUT - elapsed) * 1000)))
    g.fadeOut:SetAlphaValues(elapsed > GLOSS_SECONDS - GLOSS_FADE_OUT and alpha or g.peakAlpha, 0)
    g.fadeOut:SetDuration(math.max(1, math.ceil(math.min(left, GLOSS_FADE_OUT) * 1000)))
    g.running = true; g.timeline:PlayFromStart()
end
local function AnimateGloss(row, target, now, width, full, danger)
    local paused = A.demo and A.demoPausedAt ~= nil
    local strong = A.saved.highlightTarget ~= false and A.saved.targetHighlightStyle == "strong"
    local selected = A.saved.highlightTarget ~= false and A.focusTargetId == target.unitId
    local acquired = selected and A.glossFocusSerialSeen ~= A.focusSerial
    -- Consume acquisition even in Subtle, on pause or while busy. A strength
    -- toggle or a suppressed trigger must never replay an old target change.
    if selected then A.glossFocusSerialSeen = A.focusSerial end
    if A.saved.reduceAnimations then StopGloss(row); return end
    local g = A.gloss
    if g and g.owner == row then
        if g.target ~= target or not selected or not strong or danger or row.revealAt or g.width ~= width or g.height ~= row.lastRowHeight
            or g.full ~= full or g.mirror ~= A.saved.mirrorTauntList or g.strong ~= strong
            or now - g.at >= GLOSS_SECONDS then
            StopGloss(row)
        else UpdateGlossMotion(g, now, paused) end
    end
    if not strong or not acquired or paused or danger or row.revealAt then return end
    -- A late/hidden application is not a reason to play old visual feedback.
    if target.endTime - now <= A.saved.dangerAt + GLOSS_SECONDS then return end
    if g and g.owner then return end
    g = g or MakeGloss(row)
    g.viewport:SetParent(row.box)
    g.viewport:ClearAnchors(); g.viewport:SetAnchorFill(row.progressRegion)
    local height = row.lastRowHeight
    local halfWidth, sweepWidth = 48, 128
    if g.height ~= height or g.mirror ~= A.saved.mirrorTauntList or g.halfWidth ~= halfWidth then
        local sign = A.saved.mirrorTauntList and -1 or 1
        g.sweep:SetDimensions(sweepWidth, 2 * height)
        for i, strip in ipairs(g.strips) do
            local band = math.floor((i - 1) / 2)
            strip:ClearAnchors()
            strip:SetAnchor(TOPLEFT, g.sweep, TOPLEFT, sign * band * 10 + (i % 2 == 1 and 0 or halfWidth), band * height / 2)
            strip:SetDimensions(halfWidth, height / 2)
        end
    end
    g.owner, g.target, g.at, g.paused = row, target, now, nil
    g.width, g.height, g.full, g.mirror = width, height, full, A.saved.mirrorTauntList
    g.strong, g.peakAlpha, g.halfWidth, g.sweepWidth = true, .18, halfWidth, sweepWidth
    SetHidden(g.viewport, false)
    UpdateGlossMotion(g, now, paused)
end

local function StopFocus(row)
    if row.focusRunning then row.focusRunning = false; row.focusTimeline:Stop() end
    row.focusSerial = nil
end

local function AnimateFocus(row, selected, now)
    local paused = A.demo and A.demoPausedAt ~= nil
    if row.focusSelected ~= selected then
        StopFocus(row)
        -- External edges must remain above an adjacent row's countdown strip.
        row.box:SetDrawLevel(selected and 1 or 0)
        row.gate:SetDrawLevel(selected and 1 or 0)
        for _, edge in pairs(row.focusOutline) do SetHidden(edge, not selected) end
        row.focusSelected = selected
    end
    if not selected then SetHidden(row.focusViewport, true); return end
    if A.saved.reduceAnimations then
        StopFocus(row)
        row.focusSuppressedSerial = A.focusSerial
        SetHidden(row.focusViewport, true)
        return
    end
    if row.focusSuppressedSerial == A.focusSerial then SetHidden(row.focusViewport, true); return end
    if row.focusSerial == A.focusSerial and row.focusPaused == paused
        and row.focusMirror == A.saved.mirrorTauntList and row.focusWidth == row.focusTravelWidth then return end
    StopFocus(row)
    row.focusSerial, row.focusPaused, row.focusMirror = A.focusSerial, paused, A.saved.mirrorTauntList
    row.focusWidth = row.focusTravelWidth
    local progress = A.Clamp((now - (A.focusAcquiredAt or now)) / FOCUS_SECONDS, 0, 1)
    SetHidden(row.focusViewport, progress >= 1)
    if progress >= 1 then return end
    local from, to = -64, row.focusTravelWidth
    if row.focusMirror then from, to = to, from end
    local x = from + (to - from) * progress
    row.focusSweep:ClearAnchors()
    row.focusSweep:SetAnchor(TOPLEFT, row.focusViewport, TOPLEFT, x, 0)
    if paused then return end
    if not row.focusTimeline then
        row.focusTimeline = ANIMATION_MANAGER:CreateTimeline()
        row.focusAnimation = row.focusTimeline:InsertAnimation(ANIMATION_TRANSLATE, row.focusSweep, 0)
        row.focusAnimation:SetEasingFunction(LinearEase)
        row.focusTimeline:SetHandler("OnStop", function(_, completed)
            row.focusRunning = false
            if completed then SetHidden(row.focusViewport, true) end
        end)
    end
    row.focusAnimation:SetTranslateOffsets(x, 0, to, 0)
    row.focusAnimation:SetDuration(math.max(1, math.ceil((1 - progress) * FOCUS_SECONDS * 1000)))
    row.focusRunning = true; row.focusTimeline:PlayFromStart()
end

-- Weak keys retain a visual birth time while the actual combat/preview record
-- lives, without adding fields to it. Moving that record between row slots
-- continues the same entrance rather than making the sorted list flash.
A.rowEntryStarts = setmetatable({}, {__mode = "k"})
local function StopEntry(row)
    if row.entryRunning then row.entryRunning = false; row.entryTimeline:Stop() end
end
local function AnimateEntry(row, target, now, selected)
    local paused = A.demo and A.demoPausedAt ~= nil
    local at = A.rowEntryStarts[target]
    if not at then
        at = (paused or selected or A.saved.reduceAnimations or target.endTime - now <= A.saved.dangerAt) and now - ENTRY_SECONDS or now
        A.rowEntryStarts[target] = at
    end
    if selected or A.saved.reduceAnimations or target.endTime - now <= A.saved.dangerAt then
        if now - at < ENTRY_SECONDS then A.rowEntryStarts[target] = now - ENTRY_SECONDS end
        StopEntry(row)
        if row.entryTarget ~= target or row.entryAlpha ~= 1 then row.box:SetAlpha(1) end
        row.entryAlpha, row.entryTarget, row.entryPaused = 1, target, paused
        return
    end
    if row.entryTarget == target and row.entryPaused == paused then return end
    StopEntry(row)
    row.entryTarget, row.entryPaused = target, paused
    local progress = A.Clamp((now - at) / ENTRY_SECONDS, 0, 1)
    local alpha = ENTRY_ALPHA + (1 - ENTRY_ALPHA) * progress
    row.box:SetAlpha(alpha)
    row.entryAlpha = alpha
    if progress >= 1 or paused then return end
    if not row.entryTimeline then
        row.entryTimeline = ANIMATION_MANAGER:CreateTimeline()
        row.entryAnimation = row.entryTimeline:InsertAnimation(ANIMATION_ALPHA, row.box, 0)
        row.entryAnimation:SetEasingFunction(LinearEase)
        row.entryTimeline:SetHandler("OnStop", function(_, completed)
            row.entryRunning = false
            if completed then row.entryAlpha = 1 end
        end)
    end
    row.entryAnimation:SetAlphaValues(alpha, 1)
    row.entryAnimation:SetDuration(math.max(1, math.ceil((1 - progress) * ENTRY_SECONDS * 1000)))
    row.entryRunning = true; row.entryTimeline:PlayFromStart()
end

local function StopAlertProgress(alert)
    if alert.progressRunning then alert.progressRunning = false; alert.progressTimeline:Stop() end
    alert.nativeProgressUntil = nil
end
local function AnimateAlertProgress(alert, now)
    if not alert.timerFill or not alert.visibleUntil then return end
    local finish, width = alert.progressUntil or alert.visibleUntil, alert.width or 458
    if alert.nativeProgressUntil == finish and alert.nativeDuration == alert.duration
        and alert.nativeWidth == width and alert.progressRunning then return end
    StopAlertProgress(alert)
    alert.nativeProgressUntil, alert.nativeDuration, alert.nativeWidth = finish, alert.duration, width
    local remaining = math.max(0, finish - now)
    local current = width * A.Clamp(remaining / alert.duration, 0, 1)
    alert.timerFill:SetWidth(current)
    alert.timerWidth = current
    if remaining <= 0 then return end
    if not alert.progressTimeline then
        alert.progressTimeline = ANIMATION_MANAGER:CreateTimeline()
        alert.progressAnimation = alert.progressTimeline:InsertAnimation(ANIMATION_SIZE, alert.timerFill, 0)
        alert.progressAnimation:SetEasingFunction(LinearEase)
        alert.progressTimeline:SetHandler("OnStop", function(_, completed)
            if not alert.progressRunning then return end
            alert.progressRunning = false
            if completed and alert.visibleUntil and A.Now() >= alert.nativeProgressUntil then
                -- Check only the affected warning slot at its deadline. No HUD
                -- sorting, combat event synthesis or sound replay in this callback.
                A.UpdateBossAlert(A.Now(), alert.kind)
            end
        end)
    end
    alert.progressAnimation:SetStartAndEndWidth(current, 0)
    alert.progressAnimation:SetStartAndEndHeight(3, 3)
    alert.progressAnimation:SetDuration(math.max(1, math.ceil(remaining * 1000)))
    alert.progressRunning = true; alert.progressTimeline:PlayFromStart()
end

local function StopRowAnimations(row)
    StopGloss(row)
    StopPlacement(row)
    StopProgress(row)
    StopFocus(row)
    StopStripe(row)
    StopEntry(row)
    row.box:SetAlpha(1)
    row.entryTarget, row.stripeTarget = nil, nil
    row.progressTarget = nil -- release retired combat records when a row is hidden
    row.placementTarget, row.displayTarget, row.placementPlan = nil, nil, nil
    row.placementAt, row.placementFromY, row.revealAt = nil, nil, nil
    row.gate:SetAlpha(1); row.revealAlpha = 1
end

A.AnimateRowProgress = AnimateProgress
A.ObserveFocus = ObserveFocus
A.AnimateRowAccent = AnimateAccent
A.AnimateRowEntry = AnimateEntry
A.AnimateRowFocus = AnimateFocus
A.StopRowAnimations = StopRowAnimations
A.AnimateAlertProgress = AnimateAlertProgress
A.StopAlertProgress = StopAlertProgress
A.RowPosition = RowPosition
A.PlaceRow = PlaceRow
A.REFLOW_SECONDS = REFLOW_SECONDS
A.AnimateRowGloss = AnimateGloss
A.StopGloss = StopGloss

-- Changing this preference settles visible decoration now. Countdown timelines
-- retain their own lifecycle; banner logic continues on the existing 100-ms tick.
function A.RefreshAnimationMode()
    local enabled = not A.saved.reduceAnimations
    for _, alert in pairs(A.bossAlerts) do
        if alert.root and alert.frameHandler and alert.frameUpdatesEnabled ~= enabled then
            alert.root:SetHandler("OnUpdate", enabled and alert.frameHandler or nil)
            alert.frameUpdatesEnabled = enabled
        end
    end
    A.Tick()
    A.UpdateBossAlert(A.Now())
end
