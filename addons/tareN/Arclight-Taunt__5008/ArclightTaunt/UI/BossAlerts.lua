-- Arclight Taunt | Boss warning lifecycle, banners and sounds
-- Loaded in manifest order; requires Core.lua and uses its shared namespace.
local A = ArclightTaunt
local ALERT_BATCH_SECONDS = A.ALERT_BATCH_SECONDS
local ALERT_SOUNDS = A.ALERT_SOUNDS
local ALERT_SOUND_COOLDOWN = A.ALERT_SOUND_COOLDOWN
local Clamp = A.Clamp
local Now = A.Now
local PREVIEW_EARLY_DELAY = 1.0
local REVEAL_SECONDS = 0.28
local function SettleEase(value)
    local t = Clamp(value, 0, 1)
    return t * t * t * (t * (t * 6 - 15) + 10)
end
local function ReadableEase(value)
    local t = 1 - Clamp(value, 0, 1)
    return 1 - t * t * t
end

local function BossVisible(t)
    if t.isPlayer then return false end
    if t.isBoss then return true end
    local mode = A.saved.bossMode
    local rank = t.bossDifficulty or 0
    if mode == "comprehensive" then return rank >= MONSTER_DIFFICULTY_HARD end
    return false
end

-- Do not confuse a taunt's disappearance with a confirmed loss of enemy
-- aggro. Warn ONLY about the known taunt expiring, not a change of target.
-- Default requires the official boss unit tag; optional elites use the
-- difficulty classifier (which can also include hard ordinary enemies).
local function EligibleForBossAlert(t)
    if t.dead or t.isPlayer then return false end
    if t.isBoss then return true end
    return A.saved.bossAlertElites and BossVisible(t) or false
end

local function PlayBossAlertSound(preview)
    if not preview and not A.saved.bossAlertSound then return end
    local key = ALERT_SOUNDS[A.saved.bossAlertSoundKey]
    local sound = (key and SOUNDS[key]) or SOUNDS.DUEL_START
    if sound then
        -- Missing optional sounds fall back to the configured type's default.
        -- We cannot verify audible output from Lua; use the in-game preview.
        PlaySound(sound)
    end
end

local function HasUrgentBossWarning(now)
    local red = A.bossAlerts.expired
    if red.visibleUntil and now < red.visibleUntil then return true end
    -- Also protect the start of red audio when the visual banner is disabled.
    if A.lastAlertSoundAt and now - A.lastAlertSoundAt < 1 then return true end
    for key, entry in pairs(A.pendingBossWarnings or {}) do
        local target = entry.target
        if A.targets[key] == target and (target.tauntGeneration or 0) == entry.generation
            and A.IsLost(target, now) and EligibleForBossAlert(target) then return true end
    end
    return false
end
local function PlayEarlyBossSound(preview)
    if not A.saved.bossEarlyWarning or not A.saved.bossEarlySound then return end
    local now = Now()
    if HasUrgentBossWarning(now) then return end
    if not preview and A.lastEarlySoundAt and now - A.lastEarlySoundAt < A.EARLY_SOUND_COOLDOWN then return end
    local key = ALERT_SOUNDS[A.saved.bossEarlySoundKey]
    local sound = (key and SOUNDS[key]) or SOUNDS.DUEL_BOUNDARY_WARNING
    if sound then
        PlaySound(sound)
        if not preview then A.lastEarlySoundAt = now end
        return true
    end
end

local function SetAlertAlpha(alert, alpha)
    if alert.alpha ~= alpha then
        alert.root:SetAlpha(alpha)
        alert.alpha = alpha
    end
end
local function PositionBossAlert(alert, y)
    if alert.anchorY ~= y then
        alert.root:ClearAnchors()
        alert.root:SetAnchor(TOP, GuiRoot, TOP, 0, y)
        alert.anchorY = y
    end
end
local function PositionBossAlerts()
    local red, early = A.bossAlerts.expired, A.bossAlerts.early
    if not red.root or not early.root then return end
    local height = GuiRoot:GetHeight()
    local y = A.saved.bossAlertOffsetY
    -- Reserve room for the second slot before either warning appears. A
    -- subsequent overlap then needs no jump and never changes the preference.
    if height > 0 then
        local stackHeight = red.height
        if A.saved.bossEarlyWarning or early.visibleUntil then stackHeight = early.offsetY + early.height end
        y = Clamp(y, 0, math.max(0, height - stackHeight - 4))
    end
    PositionBossAlert(red, y)
    PositionBossAlert(early, y + early.offsetY)
end
local function SetContentOffset(alert, offset)
    if alert.content and alert.contentOffset ~= offset then
        alert.content:ClearAnchors()
        alert.content:SetAnchor(TOPLEFT, alert.root, TOPLEFT, 0, offset)
        alert.contentOffset = offset
    end
end

local function SetStaticBossVisual(alert, now)
    alert.revealFrom = nil
    alert.fadeFrom, alert.fadeStartedAt = 1, now - (alert.fadeInSeconds or .18)
    SetContentOffset(alert, 0)
    SetAlertAlpha(alert, 1)
end

-- Animation frames are useful only while a visible banner animates. Keep
-- hidden slots detached even when decorative animations are enabled.
local function SetBossAlertFrameUpdates(alert, enabled)
    enabled = enabled and alert.root and alert.frameHandler and true or false
    if alert.root and alert.frameUpdatesEnabled ~= enabled then
        alert.root:SetHandler("OnUpdate", enabled and alert.frameHandler or nil)
        alert.frameUpdatesEnabled = enabled
    end
end
A.SetBossAlertFrameUpdates = SetBossAlertFrameUpdates

local previewStateActive = false
local function IsBossWarningPreviewActive()
    if A.pendingBossPreview then return true end
    for _, alert in pairs(A.bossAlerts) do
        if alert.isPreview and alert.visibleUntil then return true end
    end
    return false
end
local function RefreshBossWarningPreviewState()
    local active = IsBossWarningPreviewActive()
    if previewStateActive ~= active then
        previewStateActive = active
        if A.RefreshSettingsPanel then A.RefreshSettingsPanel() end
    end
end

-- With no kind, clear both independent slots (combat end / tracking reset).
local function HideBossWarning(kind, deferPreviewRefresh)
    local sequenceActive = A.pendingBossPreview ~= nil
    A.pendingBossPreview = nil
    for key, alert in pairs(A.bossAlerts) do
        if not kind or kind == key or (sequenceActive and alert.isPreview) then
            if A.StopAlertProgress then A.StopAlertProgress(alert) end
            alert.visibleUntil, alert.visibleFrom = nil, nil
            alert.subjects, alert.currentCount, alert.isPreview = nil, nil, nil
            alert.progressUntil, alert.duration = nil, nil
            alert.previewRequest, alert.revealFrom = nil, nil
            if alert.root then
                SetBossAlertFrameUpdates(alert, false)
                A.SetHidden(alert.root, true)
                SetAlertAlpha(alert, 0)
            end
        end
    end
    if previewStateActive and not deferPreviewRefresh then RefreshBossWarningPreviewState() end
end

local function StopBossWarningPreview(deferPreviewRefresh)
    A.pendingBossPreview = nil
    for kind, alert in pairs(A.bossAlerts) do
        if alert.isPreview then HideBossWarning(kind, true) end
    end
    if not deferPreviewRefresh then
        RefreshBossWarningPreviewState()
        A.RefreshUpdateState()
    end
end
local function FinishBossWarningShow(result, preview, deferPreviewRefresh)
    A.RefreshUpdateState()
    if not deferPreviewRefresh and (preview or previewStateActive) then RefreshBossWarningPreviewState() end
    return result
end

local function CountAlertSubjects(subjects)
    local count, lastName = 0, nil
    for _, subject in pairs(subjects) do
        count, lastName = count + 1, subject.name
    end
    return count, lastName
end
local function RefreshAlertText(alert)
    local count, lastName = CountAlertSubjects(alert.subjects)
    if count == 0 then
        HideBossWarning(alert.kind)
        return
    end
    alert.currentCount = count
    A.SetAlertText(alert.kind, A.BossAlertText(alert.kind, count, lastName))
end

local function IsEarlySubjectCurrent(key, subject, now)
    local target = A.targets[key]
    return target and (target.tauntGeneration or 0) == subject.generation
        and (not subject.target or subject.target == target)
        and EligibleForBossAlert(target) and not A.IsLost(target, now)
        and target.endTime - now <= A.saved.bossEarlySeconds
end
local function RefreshEarlyTiming(alert)
    local firstEnd, lastEnd = math.huge, 0
    for key in pairs(alert.subjects) do
        local target = A.targets[key]
        firstEnd, lastEnd = math.min(firstEnd, target.endTime), math.max(lastEnd, target.endTime)
    end
    alert.progressUntil, alert.visibleUntil = firstEnd, lastEnd
    alert.duration = A.saved.bossEarlySeconds
end
-- Small, current subject set only; no reticle or full target scan per frame.
-- Preview samples have their own finite lifetime and no combat owners.
local function PruneEarlyWarning(now, frameOnly)
    local alert = A.bossAlerts.early
    if not alert.visibleUntil or alert.isPreview then return end
    if not A.inCombat or not A.saved.bossEarlyWarning
        or IsUnitDead("player") then
        HideBossWarning("early")
        return
    end
    -- Events remove renewed/dead subjects immediately. Between logic ticks,
    -- frames only need a full check at expiry or after relevant data/settings
    -- changed; the visual animation still runs every frame.
    if frameOnly and not A.earlyWarningDirty and now < alert.progressUntil
        and alert.checkedBossMode == A.saved.bossMode
        and alert.checkedElites == A.saved.bossAlertElites
        and alert.checkedEarlySeconds == A.saved.bossEarlySeconds then return end
    local changed = false
    local firstEnd, lastEnd = math.huge, 0
    for key, subject in pairs(alert.subjects) do
        if not IsEarlySubjectCurrent(key, subject, now) then
            alert.subjects[key] = nil
            changed = true
        else
            local endTime = A.targets[key].endTime
            firstEnd, lastEnd = math.min(firstEnd, endTime), math.max(lastEnd, endTime)
        end
    end
    A.earlyWarningDirty = nil
    alert.checkedBossMode, alert.checkedElites = A.saved.bossMode, A.saved.bossAlertElites
    alert.checkedEarlySeconds = A.saved.bossEarlySeconds
    if changed then RefreshAlertText(alert) end
    if alert.visibleUntil then
        alert.progressUntil, alert.visibleUntil = firstEnd, lastEnd
        alert.duration = A.saved.bossEarlySeconds
    end
end

-- Re-taunt and death remove only this exact unit from each slot. Preview
-- samples deliberately have no owners and are unaffected by combat events.
local function DismissBossAlertForTarget(unitId, kind)
    local key = tostring(unitId)
    for slot, alert in pairs(A.bossAlerts) do
        if (not kind or slot == kind) and not alert.isPreview and alert.subjects
            and alert.visibleUntil and alert.subjects[key] then
            alert.subjects[key] = nil
            RefreshAlertText(alert)
            if slot == "early" and alert.visibleUntil then RefreshEarlyTiming(alert) end
        end
    end
end

local function ShowBossWarning(count, bossName, preview, kind, subjects, previewDuration, deferPreviewRefresh)
    local now = Now()
    kind = (kind == "early") and "early" or "expired"
    -- Genuine warnings supersede the whole synthetic sequence.
    if not preview and IsBossWarningPreviewActive() then StopBossWarningPreview(true) end
    A.pendingBossPreview = nil
    local alert = A.bossAlerts[kind]
    if kind == "early" and not A.saved.bossEarlyWarning and not preview then
        return FinishBossWarningShow(nil, preview, deferPreviewRefresh)
    end
    if not preview and kind == "expired" then
        if subjects then
            for key in pairs(subjects) do DismissBossAlertForTarget(key, "early") end
        end
        if not A.saved.bossAlertText and not A.saved.bossAlertSound then
            return FinishBossWarningShow(nil, preview, deferPreviewRefresh)
        end
        if A.saved.bossAlertSound and
            (not A.lastAlertSoundAt or now - A.lastAlertSoundAt >= ALERT_SOUND_COOLDOWN) then
            PlayBossAlertSound(false)
            A.lastAlertSoundAt = now
        end
        if not A.saved.bossAlertText then return FinishBossWarningShow(nil, preview, deferPreviewRefresh) end
    end
    if not alert.root then return FinishBossWarningShow(nil, preview, deferPreviewRefresh) end
    if kind == "early" and not preview and not subjects then
        return FinishBossWarningShow(nil, preview, deferPreviewRefresh)
    end
    -- Each slot merges only its own kind. Red never blocks or replaces early.
    local merge = not preview and not alert.isPreview and alert.visibleUntil and now < alert.visibleUntil
    if merge and alert.subjects and subjects then
        for key, subject in pairs(subjects) do alert.subjects[key] = subject end
        subjects = alert.subjects
    end
    alert.subjects = not preview and subjects or nil
    if subjects and not preview then
        count, bossName = CountAlertSubjects(subjects)
    elseif merge then
        count = (alert.currentCount or 1) + count
    end
    alert.currentCount, alert.isPreview = count, preview == true
    alert.previewRequest = nil
    A.SetAlertText(kind, A.BossAlertText(kind, count, bossName))
    if kind == "early" and not preview then
        RefreshEarlyTiming(alert)
    else
        alert.duration = preview and previewDuration or A.saved.bossAlertDuration
        alert.visibleUntil = now + alert.duration
        alert.progressUntil = alert.visibleUntil
    end
    local life = math.max(0.01, alert.visibleUntil - now)
    -- Reach readable opacity promptly, then retain it until close to the real
    -- deadline. Short observations must not spend most of their life fading.
    alert.fadeInSeconds = math.min(kind == "early" and 0.18 or 0.14, life * 0.25)
    alert.fadeOutSeconds = math.min(kind == "early" and 0.12 or 0.28, life * 0.15)
    alert.revealSeconds = math.min(REVEAL_SECONDS, math.max(0.01, (alert.progressUntil - now) * 0.4))
    if merge then
        alert.fadeFrom, alert.fadeStartedAt = alert.alpha or 0, now
    end
    -- Adding another early subject updates the group without restarting its
    -- entrance. Red keeps the established finite display duration on merges.
    if not merge or kind == "expired" then
        alert.visibleFrom = now
    end
    if not merge then PositionBossAlerts() end
    if A.saved.reduceAnimations then
        SetStaticBossVisual(alert, now)
    elseif not merge then
        local red = A.bossAlerts.expired
        alert.revealFrom = kind == "early" and red.visibleUntil and now < red.visibleUntil
            and -(alert.revealDistance or 64) or nil
        alert.fadeFrom = alert.revealFrom and 1 or 0
        alert.fadeStartedAt = now
        SetContentOffset(alert, alert.revealFrom or 0)
        SetAlertAlpha(alert, alert.fadeFrom)
    end
    A.SetHidden(alert.root, false)
    SetBossAlertFrameUpdates(alert, not A.saved.reduceAnimations)
    A.AnimateAlertProgress(alert, now)
    return FinishBossWarningShow(true, preview, deferPreviewRefresh)
end

local function CanPreviewBossWarnings()
    for _, alert in pairs(A.bossAlerts) do
        if alert.visibleUntil and not alert.isPreview then return false end
    end
    if A.pendingBossWarnings and next(A.pendingBossWarnings) then return false end
    return true
end

local function PreviewBossWarnings()
    -- Never replace an actual fight warning with a settings sample.
    if not CanPreviewBossWarnings() then return false end
    HideBossWarning(nil, true)
    local now = Now()
    if A.saved.bossEarlyWarning then
        local early = A.bossAlerts.early
        if ShowBossWarning(1, A.T("Bone Colossus"), true, "early", nil, A.saved.bossEarlySeconds, true) then
            PlayEarlyBossSound(true)
            local request = {stage = "expired", owner = "early", at = early.visibleUntil}
            early.previewRequest, A.pendingBossPreview = request, request
        end
    else
        ShowBossWarning(1, A.T("Bone Colossus"), true, nil, nil, nil, true)
        PlayBossAlertSound(false)
    end
    A.RefreshUpdateState()
    RefreshBossWarningPreviewState()
    return true
end

local function ToggleBossWarningPreview()
    if IsBossWarningPreviewActive() then
        StopBossWarningPreview()
        return true
    end
    return PreviewBossWarnings()
end

local function ProcessBossPreview(now)
    local request = A.pendingBossPreview
    if not request then return end
    if not A.saved.bossEarlyWarning then A.pendingBossPreview = nil; return end
    if now < request.at then return end
    local owner = A.bossAlerts[request.owner]
    local live = false
    for _, alert in pairs(A.bossAlerts) do
        if alert.visibleUntil and not alert.isPreview then live = true end
    end
    if live or not owner.isPreview
        or owner.previewRequest ~= request or not owner.visibleUntil
        or (A.pendingBossWarnings and next(A.pendingBossWarnings))
        or now > request.at + 0.75
        or (request.stage == "overlap" and now >= owner.visibleUntil) then
        A.pendingBossPreview = nil
        return
    end
    A.pendingBossPreview = nil
    if request.stage == "expired" then
        HideBossWarning("early", true)
        local duration = math.max(A.saved.bossAlertDuration, PREVIEW_EARLY_DELAY + 1)
        ShowBossWarning(1, A.T("Bone Colossus"), true, "expired", nil, duration, true)
        PlayBossAlertSound(false)
        request.stage, request.owner, request.at = "overlap", "expired", now + PREVIEW_EARLY_DELAY
        A.bossAlerts.expired.previewRequest, A.pendingBossPreview = request, request
    else
        ShowBossWarning(1, A.T("Daedra Guardian"), true, "early", nil, A.saved.bossEarlySeconds, true)
        -- Red has audio priority; the second early sample never queues a sound.
    end
end

-- Admit current own taunts independently of the red slot. Existing subjects
-- stay until expiry/re-taunt/death, even when the chosen early window exceeds
-- the red banner duration. Allocate additions only when membership changes.
local function CheckEarlyBossWarnings(now)
    -- ExpireBossAlert validates existing subjects once before this admission
    -- pass in the logic tick. Frames handle any expiry between those ticks.
    if not A.inCombat or not A.saved.bossEarlyWarning then return end
    local alert = A.bossAlerts.early
    local subjects, count, lastName, soundNeeded
    count = 0
    for key, target in pairs(A.targets) do
        if EligibleForBossAlert(target) and not A.IsLost(target, now)
            and target.endTime - now <= A.saved.bossEarlySeconds then
            local previous = not alert.isPreview and alert.subjects and alert.subjects[key]
            if not previous or previous.generation ~= (target.tauntGeneration or 0)
                or previous.target ~= target or previous.name ~= target.name then
                if not subjects and IsUnitDead("player") then return end
                subjects = subjects or {}
                subjects[key] = { name = target.name, generation = target.tauntGeneration or 0, target = target }
                local generation = target.tauntGeneration or 0
                if target.earlySoundGeneration ~= generation then
                    -- Consume the opportunity even when muted/suppressed. Never
                    -- replay a stale cue after red clears or the option changes.
                    target.earlySoundGeneration, soundNeeded = generation, true
                end
                count, lastName = count + 1, target.name
            end
        end
    end
    if count > 0 then
        ShowBossWarning(count, lastName, false, "early", subjects)
        if soundNeeded then PlayEarlyBossSound(false) end
    end
end
-- Deduplicate per target/taunt generation; ignore expirations outside combat,
-- foreign taunts, and uncertain boss identifications by default.
local function QueueBossLosses(lost, now)
    if not A.inCombat then return end
    if not A.saved.bossAlertText and not A.saved.bossAlertSound then return end
    local checkedPlayer = false
    for _, t in ipairs(lost) do
        if A.targets[t.unitId] == t and EligibleForBossAlert(t) and not t.bossWarnQueued then
            if not checkedPlayer then
                if IsUnitDead("player") then return end
                checkedPlayer = true
            end
            if A.pendingBossPreview then HideBossWarning(A.pendingBossPreview.owner, true) end
            t.bossWarnQueued = true
            if not A.pendingBossWarnings then
                A.pendingBossWarnings, A.pendingFirstAt = {}, now
            end
            local key = tostring(t.unitId)
            A.pendingBossWarnings[key] = { target = t, generation = t.tauntGeneration or 0 }
        end
    end
end

local function ProcessBossWarnings(now)
    if not A.pendingBossWarnings or now - A.pendingFirstAt < ALERT_BATCH_SECONDS then return end
    local count, singleName = 0, nil
    local subjects
    for key, entry in pairs(A.pendingBossWarnings) do
        local target = entry.target
        -- If re-taunted or killed during the debounce window, suppress the alert.
        if A.targets[key] == target and (target.tauntGeneration or 0) == entry.generation
            and A.IsLost(target, now) and EligibleForBossAlert(target) then
            count = count + 1
            singleName = target.name
            subjects = subjects or {}
            subjects[key] = { name = target.name, generation = entry.generation }
        end
    end
    A.pendingBossWarnings, A.pendingFirstAt = nil, nil
    if IsUnitDead("player") then return end
    if count > 0 and A.inCombat then ShowBossWarning(count, singleName, false, "expired", subjects) end
end

-- Logic can retire both slots without any animation frame, including menus.
local function ExpireBossAlert(now)
    ProcessBossPreview(now)
    PruneEarlyWarning(now)
    for kind, alert in pairs(A.bossAlerts) do
        if alert.visibleUntil and now >= alert.visibleUntil then HideBossWarning(kind, true) end
    end
    -- Natural completion needs only the existing logic tick. Phase changes
    -- retain the stop label; idle ticks do no preview-state work.
    if previewStateActive then RefreshBossWarningPreviewState() end
end
local function AnimateBossAlert(alert, now)
    if not alert.root or not alert.visibleUntil then return end
    if A.saved.reduceAnimations then
        SetStaticBossVisual(alert, now)
        A.AnimateAlertProgress(alert, now)
        return
    end
    local left = alert.visibleUntil - now
    -- Roots stay fixed so thin borders do not resample while fading. Only the
    -- compact content reveals beneath red; early merges keep visibleFrom.
    if alert.revealFrom then
        local since = math.max(0, now - (alert.visibleFrom or now))
        local reveal = SettleEase(since / alert.revealSeconds)
        local offset = alert.revealFrom * (1 - reveal)
        SetContentOffset(alert, offset)
        if offset == 0 then alert.revealFrom = nil end
    end
    local from = alert.fadeFrom or 0
    local fadeSince = math.max(0, now - (alert.fadeStartedAt or alert.visibleFrom or now))
    local alpha = fadeSince >= alert.fadeInSeconds and 1
        or from + (1 - from) * ReadableEase(fadeSince / alert.fadeInSeconds)
    -- Fade in place; moving a deadline warning away would weaken its meaning.
    if left < alert.fadeOutSeconds then alpha = math.min(alpha, SettleEase(left / alert.fadeOutSeconds)) end
    SetAlertAlpha(alert, alpha)
    A.AnimateAlertProgress(alert, now)
end
local function UpdateBossAlert(now, kind)
    ProcessBossPreview(now)
    if kind == "early" or not kind then PruneEarlyWarning(now, true) end
    for slot, alert in pairs(A.bossAlerts) do
        if not kind or slot == kind then
            if alert.visibleUntil and now >= alert.visibleUntil then HideBossWarning(slot, true) end
            AnimateBossAlert(alert, now)
        end
    end
end
local function IsBossTag(unitTag)
    if type(unitTag) ~= "string" or unitTag == "" then return false end
    if unitTag:match("^boss%d+$") then return true end
    for i = BOSS_RANK_ITERATION_BEGIN, BOSS_RANK_ITERATION_END do
        local tag = "boss" .. i
        if DoesUnitExist(tag) and AreUnitsEqual(unitTag, tag) then return true end
    end
    return false
end

-- GetUnitDifficulty is an ESO API for valid unitTags, NOT for combat unit IDs.
-- Store the observed rank only after a safe unit identification.
local function ObserveBoss(t, unitTag)
    if type(unitTag) ~= "string" or unitTag == "" then return end
    if not t.isBoss and IsBossTag(unitTag) then t.isBoss = true end
    if DoesUnitExist(unitTag) then
        local rank = GetUnitDifficulty(unitTag)
        if type(rank) == "number" and rank >= 0 and rank <= 10 then
            t.bossDifficulty = math.max(t.bossDifficulty or 0, rank)
        end
    end
end


-- Public entry points used across modules.
A.BossVisible = BossVisible
A.EligibleForBossAlert = EligibleForBossAlert
A.PlayBossAlertSound = PlayBossAlertSound
A.PreviewBossWarnings = PreviewBossWarnings
A.IsBossWarningPreviewActive = IsBossWarningPreviewActive
A.StopBossWarningPreview = StopBossWarningPreview
A.ToggleBossWarningPreview = ToggleBossWarningPreview
A.ProcessBossPreview = ProcessBossPreview
A.ShowBossWarning = ShowBossWarning
A.CanPreviewBossWarnings = CanPreviewBossWarnings
A.HideBossWarning = HideBossWarning
A.DismissBossAlertForTarget = DismissBossAlertForTarget
A.CheckEarlyBossWarnings = CheckEarlyBossWarnings
A.QueueBossLosses = QueueBossLosses
A.ProcessBossWarnings = ProcessBossWarnings
A.UpdateBossAlert = UpdateBossAlert
A.ExpireBossAlert = ExpireBossAlert
A.PositionBossAlerts = PositionBossAlerts
A.IsBossTag = IsBossTag
A.ObserveBoss = ObserveBoss
