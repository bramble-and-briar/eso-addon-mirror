-- Arclight Taunt 1.1.1 | BossAlerts module
-- Loaded in manifest order; requires Core.lua and uses its shared namespace.
local A = ArclightTaunt
local ALERT_BATCH_SECONDS = A.ALERT_BATCH_SECONDS
local ALERT_SOUNDS = A.ALERT_SOUNDS
local ALERT_SOUND_COOLDOWN = A.ALERT_SOUND_COOLDOWN
local Clamp = A.Clamp
local Now = A.Now
local PREVIEW_EARLY_DELAY = 1.0
local REVEAL_SECONDS = 0.32
local function SmoothStep(value)
    local t = Clamp(value, 0, 1)
    return t * t * (3 - 2 * t)
end

local function BossVisible(t)
    if t.isPlayer then return false end
    if t.isBoss then return true end
    local mode = A.saved.bossMode
    local rank = t.bossDifficulty or 0
    local hard = MONSTER_DIFFICULTY_HARD or 3
    local deadly = MONSTER_DIFFICULTY_DEADLY or 4
    if mode == "comprehensive" then return rank >= hard end
    if mode == "dangerous" then return rank >= deadly end
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
    local sound = key and SOUNDS and SOUNDS[key]
    if not sound and SOUNDS then sound = SOUNDS.DUEL_START end
    if sound and type(PlaySound) == "function" then
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
    local sound = SOUNDS and (SOUNDS[key or "DUEL_BOUNDARY_WARNING"] or SOUNDS.DUEL_BOUNDARY_WARNING)
    if sound and type(PlaySound) == "function" then
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
local function PositionBossAlert(alert)
    if not alert.root then return end
    local y = A.saved.bossAlertOffsetY + (alert.offsetY or 0) - (alert.slidePixels or 0)
    if alert.anchorY ~= y then
        alert.root:ClearAnchors()
        alert.root:SetAnchor(TOP, GuiRoot, TOP, 0, y)
        alert.anchorY = y
    end
end
local function PositionBossAlerts()
    for _, alert in pairs(A.bossAlerts) do PositionBossAlert(alert) end
end
local function SetContentOffset(alert, offset)
    if alert.content and alert.contentOffset ~= offset then
        alert.content:ClearAnchors()
        alert.content:SetAnchor(TOPLEFT, alert.root, TOPLEFT, 0, offset)
        alert.contentOffset = offset
    end
end

-- With no kind, clear both independent slots (combat end / tracking reset).
local function HideBossWarning(kind)
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
                A.SetHidden(alert.root, true)
                SetAlertAlpha(alert, 0)
            end
        end
    end
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
        or (type(IsUnitDead) == "function" and IsUnitDead("player")) then
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

local function ShowBossWarning(count, bossName, preview, kind, subjects, previewDuration)
    local now = Now()
    kind = (kind == "early") and "early" or "expired"
    -- Genuine warnings supersede the whole synthetic sequence.
    if not preview then
        for slot, sample in pairs(A.bossAlerts) do
            if sample.isPreview then HideBossWarning(slot) end
        end
    end
    A.pendingBossPreview = nil
    local alert = A.bossAlerts[kind]
    if kind == "early" and not A.saved.bossEarlyWarning and not preview then return end
    if not preview and kind == "expired" then
        if subjects then
            for key in pairs(subjects) do DismissBossAlertForTarget(key, "early") end
        end
        if not A.saved.bossAlertText and not A.saved.bossAlertSound then return end
        if A.saved.bossAlertSound and
            (not A.lastAlertSoundAt or now - A.lastAlertSoundAt >= ALERT_SOUND_COOLDOWN) then
            PlayBossAlertSound(false)
            A.lastAlertSoundAt = now
        end
        if not A.saved.bossAlertText then return end
    end
    if not alert.root then return end
    if kind == "early" and not preview and not subjects then return end
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
    alert.fadeInSeconds = kind == "early" and math.min(0.18, math.max(0.01, life * 0.25)) or 0.18
    alert.fadeOutSeconds = kind == "early" and math.min(0.45, math.max(0.01, life * 0.35)) or 0.45
    alert.revealSeconds = math.min(REVEAL_SECONDS, math.max(0.01, (alert.progressUntil - now) * 0.4))
    if merge then
        alert.fadeFrom, alert.fadeStartedAt = alert.alpha or 0, now
    end
    -- Adding another early subject updates the group without restarting its
    -- entrance. Red keeps the established finite display duration on merges.
    if not merge or kind == "expired" then
        alert.visibleFrom = now
        alert.startSlide = merge and (alert.slidePixels or 0) or (alert.introSlide or 0)
        alert.slidePixels = alert.startSlide
        local red = A.bossAlerts.expired
        alert.revealFrom = kind == "early" and red.visibleUntil and now < red.visibleUntil
            and -(alert.revealDistance or 64) or nil
        alert.fadeFrom = merge and (alert.alpha or 0) or (alert.revealFrom and 1 or 0)
        alert.fadeStartedAt = now
        SetContentOffset(alert, alert.revealFrom or 0)
        SetAlertAlpha(alert, alert.fadeFrom)
        PositionBossAlert(alert)
    end
    A.SetHidden(alert.root, false)
    A.AnimateAlertProgress(alert, now)
    A.RefreshUpdateState()
    return true
end

local function PreviewBossWarnings()
    -- Never replace an actual fight warning with a settings sample.
    for _, alert in pairs(A.bossAlerts) do
        if alert.visibleUntil and not alert.isPreview then return false end
    end
    if A.pendingBossWarnings and next(A.pendingBossWarnings) then return false end
    HideBossWarning()
    local now = Now()
    if A.saved.bossEarlyWarning then
        local early = A.bossAlerts.early
        if ShowBossWarning(1, A.T("Bone Colossus"), true, "early", nil, A.saved.bossEarlySeconds) then
            PlayEarlyBossSound(true)
            local request = {stage = "expired", owner = "early", at = early.visibleUntil}
            early.previewRequest, A.pendingBossPreview = request, request
        end
    else
        ShowBossWarning(1, A.T("Bone Colossus"), true)
        PlayBossAlertSound(false)
    end
    A.RefreshUpdateState()
    return true
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
        HideBossWarning("early")
        local duration = math.max(A.saved.bossAlertDuration, PREVIEW_EARLY_DELAY + 1)
        ShowBossWarning(1, A.T("Bone Colossus"), true, "expired", nil, duration)
        PlayBossAlertSound(false)
        request.stage, request.owner, request.at = "overlap", "expired", now + PREVIEW_EARLY_DELAY
        A.bossAlerts.expired.previewRequest, A.pendingBossPreview = request, request
    else
        ShowBossWarning(1, A.T("Daedra Guardian"), true, "early", nil, A.saved.bossEarlySeconds)
        -- Red has audio priority; the second early sample never queues a sound.
    end
end

-- Admit current own taunts independently of the red slot. Existing subjects
-- stay until expiry/re-taunt/death, even when the chosen early window exceeds
-- the red banner duration. Allocate additions only when membership changes.
local function CheckEarlyBossWarnings(now)
    -- ExpireBossAlert validates existing subjects once before this admission
    -- pass in the logic tick. Frames handle any expiry between those ticks.
    if A.demo or not A.inCombat or not A.saved.bossEarlyWarning then return end
    if type(IsUnitDead) == "function" and IsUnitDead("player") then return end
    local alert = A.bossAlerts.early
    local subjects, count, lastName, soundNeeded
    count = 0
    for key, target in pairs(A.targets) do
        if EligibleForBossAlert(target) and not A.IsLost(target, now)
            and target.endTime - now <= A.saved.bossEarlySeconds then
            local previous = not alert.isPreview and alert.subjects and alert.subjects[key]
            if not previous or previous.generation ~= (target.tauntGeneration or 0)
                or previous.target ~= target or previous.name ~= target.name then
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
    if A.demo or not A.inCombat then return end
    if type(IsUnitDead) == "function" and IsUnitDead("player") then return end
    if not A.saved.bossAlertText and not A.saved.bossAlertSound then return end
    for _, t in ipairs(lost) do
        if EligibleForBossAlert(t) and not t.bossWarnQueued then
            if A.pendingBossPreview then HideBossWarning(A.pendingBossPreview.owner) end
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
    if type(IsUnitDead) == "function" and IsUnitDead("player") then return end
    if count > 0 and A.inCombat then ShowBossWarning(count, singleName, false, "expired", subjects) end
end

-- Logic can retire both slots without any animation frame, including menus.
local function ExpireBossAlert(now)
    ProcessBossPreview(now)
    PruneEarlyWarning(now)
    for kind, alert in pairs(A.bossAlerts) do
        if alert.visibleUntil and now >= alert.visibleUntil then HideBossWarning(kind) end
    end
end
local function AnimateBossAlert(alert, now)
    if not alert.root or not alert.visibleUntil then return end
    local left = alert.visibleUntil - now
    local since = math.max(0, now - (alert.visibleFrom or now))
    if alert.slidePixels ~= 0 then
        local ease = 1 - (1 - Clamp(since / 0.22, 0, 1)) ^ 3
        local slide = math.floor((alert.startSlide or 0) * (1 - ease) + 0.5)
        if alert.slidePixels ~= slide then
            alert.slidePixels = slide
            PositionBossAlert(alert)
        end
    end
    if alert.revealFrom then
        local reveal = 1 - (1 - Clamp(since / alert.revealSeconds, 0, 1)) ^ 3
        local offset = math.floor(alert.revealFrom * (1 - reveal) + 0.5)
        SetContentOffset(alert, offset)
        if offset == 0 then alert.revealFrom = nil end
    end
    local from = alert.fadeFrom or 0
    local fadeSince = math.max(0, now - (alert.fadeStartedAt or alert.visibleFrom or now))
    local alpha = fadeSince >= alert.fadeInSeconds and 1
        or from + (1 - from) * SmoothStep(fadeSince / alert.fadeInSeconds)
    if left < alert.fadeOutSeconds then alpha = math.min(alpha, SmoothStep(left / alert.fadeOutSeconds)) end
    SetAlertAlpha(alert, alpha)
    A.AnimateAlertProgress(alert, now)
end
local function UpdateBossAlert(now, kind)
    ProcessBossPreview(now)
    if kind == "early" or not kind then PruneEarlyWarning(now, true) end
    for slot, alert in pairs(A.bossAlerts) do
        if not kind or slot == kind then
            if alert.visibleUntil and now >= alert.visibleUntil then HideBossWarning(slot) end
            AnimateBossAlert(alert, now)
        end
    end
end
local function IsBossTag(unitTag)
    if type(unitTag) ~= "string" or unitTag == "" then return false end
    if unitTag:match("^boss%d+$") then return true end
    if type(AreUnitsEqual) ~= "function" or type(DoesUnitExist) ~= "function" then
        return false
    end
    for i = 1, (MAX_BOSSES or 6) do
        local tag = "boss" .. i
        if DoesUnitExist(tag) and AreUnitsEqual(unitTag, tag) then return true end
    end
    return false
end

-- GetUnitDifficulty is an ESO API for valid unitTags, NOT for combat unit IDs.
-- Store the observed rank only after a safe unit identification.
local function ObserveBoss(t, unitTag)
    if type(unitTag) ~= "string" or unitTag == "" then return end
    if IsBossTag(unitTag) then t.isBoss = true end
    if type(GetUnitDifficulty) == "function" and type(DoesUnitExist) == "function"
        and DoesUnitExist(unitTag) then
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
A.ProcessBossPreview = ProcessBossPreview
A.ShowBossWarning = ShowBossWarning
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
