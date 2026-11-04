-- Arclight Taunt 1.1.1 | Native row and banner progress animations
-- No frame-driven Lua loop: ESO animates cached visible controls directly.
local A = ArclightTaunt
local C, SetHidden, SetColor = A.C, A.SetHidden, A.SetColor
local FOCUS_SECONDS = 0.36
local STRIPE_SECONDS = 0.30
local ENTRY_SECONDS, ENTRY_ALPHA = 0.12, 0.82
local LinearEase = ZO_LinearEase or function(progress) return progress end

local function StopStripe(row)
    if row.stripeRunning then row.stripeRunning = false; row.stripeTimeline:Stop() end
end
local function StripeWidth(row, now)
    local p = A.Clamp((now - (row.stripeAt or now)) / STRIPE_SECONDS, 0, 1)
    return row.stripeFrom + (row.stripeTo - row.stripeFrom) * p
end
local function AnimateAccent(row, target, now, width, desired, full, high)
    local paused = A.demo and A.demoPausedAt ~= nil
    local reset = row.stripeTarget ~= target or row.stripeWidth ~= width
        or row.stripeHeight ~= row.lastRowHeight or row.stripeFull ~= full
        or row.stripeBarHeight ~= row.barHeight or row.stripeDividerHeight ~= row.contrastHeight
        or row.stripeHigh ~= high or row.stripeMirror ~= A.saved.mirrorTauntList
        or row.stripeTrack ~= A.saved.texturedTrack
    local changed = reset or row.stripeTo ~= desired or row.stripePaused ~= paused
    if not changed then return end
    local current = reset and desired or StripeWidth(row, now)
    local transitionChanged = row.stripeRunning or (not reset and row.stripeTo ~= desired)
    StopStripe(row)
    if transitionChanged then row.stripeRevision = (row.stripeRevision or 0) + 1 end
    row.stripeTarget, row.stripeWidth, row.stripeHeight = target, width, row.lastRowHeight
    row.stripeBarHeight, row.stripeDividerHeight = row.barHeight, row.contrastHeight
    row.stripeFull, row.stripeHigh, row.stripeMirror = full, high, A.saved.mirrorTauntList
    row.stripeTrack, row.stripePaused = A.saved.texturedTrack, paused
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
    local solid = not full and (not row.useMediaFill or highContrast)
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
        for _, edge in pairs(row.focusOutline) do SetHidden(edge, not selected) end
        row.focusSelected = selected
    end
    if not selected then SetHidden(row.focusViewport, true); return end
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
        at = (paused or selected or target.endTime - now <= A.saved.dangerAt) and now - ENTRY_SECONDS or now
        A.rowEntryStarts[target] = at
    end
    if selected or target.endTime - now <= A.saved.dangerAt then
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
    StopProgress(row)
    StopFocus(row)
    StopStripe(row)
    StopEntry(row)
    row.box:SetAlpha(1)
    row.entryTarget, row.stripeTarget = nil, nil
    row.progressTarget = nil -- release retired combat records when a row is hidden
end

A.AnimateRowProgress = AnimateProgress
A.ObserveFocus = ObserveFocus
A.AnimateRowAccent = AnimateAccent
A.AnimateRowEntry = AnimateEntry
A.AnimateRowFocus = AnimateFocus
A.StopRowAnimations = StopRowAnimations
A.AnimateAlertProgress = AnimateAlertProgress
A.StopAlertProgress = StopAlertProgress
