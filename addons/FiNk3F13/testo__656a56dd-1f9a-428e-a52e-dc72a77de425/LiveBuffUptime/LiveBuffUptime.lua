local NAME = "LiveBuffUptime"
local TITLE = "LiveBuffUptime"
local Meter = LiveBuffUptimeMeter
local Group = LiveBuffUptimeGroup
local Cooldowns = LiveBuffUptimeCooldowns
local Audit = LiveBuffUptimeDiagnostics
local LiveUptime = LiveBuffUptimeEngine
local liveUptimeMode, liveUptimeFight, liveUptimePlayerId, liveUptimeTargetId = false, nil, nil, nil
local audit = Audit.New(function(message) d(message) end)
local wm = WINDOW_MANAGER
local settings, panel
local settingsSections = {}
local debugCooldowns = false
local trackers = {}
local enabledTrackers = {}
local inCombat = false
local fightEndedAt
local fightStartedAt, activeStartedAt, finalDuration
local lastActiveAt
local useLibCombat = false
local abilityNameCache = {}
local groupEffects = {}
local unlocked = false
local moveOverlay, selectedTracker
local previousUIMode, previousCameraMode, lastMoveInputAt, moveLastX, moveLastY
local moveDragging = false
local draftId = ""
local draftUnit = "player"
local refreshSettings, update, setUnlocked, selectTracker
local defaults = { combatOnly = false, nextKey = 1, trackers = {}, checkUptime = false }
local unitNames = { player = "Auf mir", reticleover = "Auf dem Gegner", group = "Auf der Gruppe" }
local unitItems = {
    { name = unitNames.player, data = "player" },
    { name = unitNames.reticleover, data = "reticleover" },
    { name = unitNames.group, data = "group" },
}
local OFF_BALANCE_ID, OFF_BALANCE_IMMUNITY_ID = 39077, 134599

local function refreshEnabledTrackers()
    enabledTrackers = {}
    for _, tracker in ipairs(trackers) do
        if tracker.config.enabled ~= false then enabledTrackers[#enabledTrackers + 1] = tracker end
    end
end

local function nowSeconds()
    return GetFrameTimeSeconds()
end

local function displayName(id)
    local name = GetAbilityName(id)
    return name and name ~= "" and zo_strformat("<<1>>", name) or tostring(id)
end

local function normalizedName(id)
    if abilityNameCache[id] == nil then
        local name = GetAbilityName(id)
        abilityNameCache[id] = name and name ~= "" and string.lower(zo_strformat("<<t:1>>", name)) or false
    end
    return abilityNameCache[id]
end

local function matches(config, id)
    local trackedId = Cooldowns.TrackedId(config)
    if trackedId == id then return true end
    local aliases = LiveBuffUptimeAliases or {}
    if (aliases[trackedId] or trackedId) == (aliases[id] or id) then return true end
    local name = normalizedName(trackedId)
    return name and name == normalizedName(id)
end

local function cooldownProfile(config)
    return Cooldowns.Profile(config, (LiveBuffUptimeAliases or {})[config.id] or config.id)
end

local function findEffect(config, effects)
    local result
    for id, effect in pairs(effects) do
        if matches(config, id) then
            if not result then
                result = { starts = effect.starts, ends = effect.ends, icon = effect.icon }
            else
                result.starts = math.min(result.starts, effect.starts)
                result.ends = (result.ends == 0 or effect.ends == 0) and 0 or math.max(result.ends, effect.ends)
            end
        end
    end
    return result
end

local function readEffects(unitTag, now)
    local effects = {}
    if not DoesUnitExist(unitTag) then return effects end
    if unitTag == "reticleover" and (AreUnitsCurrentlyAllied("player", unitTag) or IsUnitDead(unitTag)) then
        return effects
    end
    for index = 1, GetNumBuffs(unitTag) do
        local _, starts, ends, _, _, icon, _, _, _, _, id = GetUnitBuffInfo(unitTag, index)
        if id and id > 0 and (ends == 0 or ends > now) then
            local previous = effects[id]
            if not previous then
                effects[id] = { starts = starts, ends = ends, icon = icon }
            else
                previous.starts = math.min(previous.starts, starts)
                previous.ends = (previous.ends == 0 or ends == 0) and 0 or math.max(previous.ends, ends)
            end
        end
    end
    return effects
end

local function seedPrebuff(tracker, now)
    tracker.prebuff, tracker.prebuffExpires = nil, nil
    if liveUptimeMode then
        if tracker.config.enabled ~= false then LiveUptime.Seed(liveUptimeFight, tracker, now, matches) end
        return
    end
    if tracker.config.enabled == false or not useLibCombat or not inCombat or tracker.config.unit ~= "player" then return end
    local effect = findEffect(tracker.config, readEffects("player", now))
    if effect then
        tracker.prebuff, tracker.prebuffExpires = "prebuff", effect.ends
        Meter.ScopeEvent(tracker.scope, tracker.prebuff, now, true)
    end
end

local function groupMemberKey(tag)
    local account = GetUnitDisplayName and GetUnitDisplayName(tag)
    if account and account ~= "" then return account end
    local name = GetUnitName and GetUnitName(tag)
    return name and name ~= "" and name or tag
end

local function groupRoster()
    local roster = {}
    local playerZone = GetUnitZoneIndex and GetUnitZoneIndex("player")
    local count = GetGroupSize and GetGroupSize() or 0
    for index = 1, math.max(1, count) do
        local tag = count == 0 and "player" or (GetGroupUnitTagByIndex and GetGroupUnitTagByIndex(index) or "group" .. index)
        if tag and DoesUnitExist(tag) then
            local online = not IsUnitOnline or IsUnitOnline(tag)
            local sameZone = not GetUnitZoneIndex or GetUnitZoneIndex(tag) == playerZone
            local dead = IsUnitDeadOrReincarnating and IsUnitDeadOrReincarnating(tag) or IsUnitDead(tag)
            roster[#roster + 1] = { tag = tag, key = groupMemberKey(tag), eligible = online and sameZone and not dead,
                inCombat = online and sameZone and IsUnitInCombat(tag) }
        end
    end
    return roster
end

local function readGroupEffects(member, now)
    if not member.eligible then
        groupEffects[member.key] = nil
        return {}
    end
    local effects = readEffects(member.tag, now)
    for slot, effect in pairs(groupEffects[member.key] or {}) do
        if effect.ends ~= 0 and effect.ends <= now then
            groupEffects[member.key][slot] = nil
        else
            local previous = effects[effect.id]
            if not previous then
                effects[effect.id] = effect
            else
                previous.starts = math.min(previous.starts, effect.starts)
                previous.ends = (previous.ends == 0 or effect.ends == 0) and 0 or math.max(previous.ends, effect.ends)
            end
        end
    end
    return effects
end

local function position(tracker)
    local config = tracker.config
    tracker.window:ClearAnchors()
    tracker.window:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, config.x, config.y)
    tracker.window:SetScale(config.scale)
end

local function savePosition(tracker)
    tracker.config.x = tracker.window:GetLeft()
    tracker.config.y = tracker.window:GetTop()
end

local function hudVisible()
    if not SCENE_MANAGER or not SCENE_MANAGER.GetCurrentScene then return true end
    local scene = SCENE_MANAGER:GetCurrentScene()
    local name = scene and scene:GetName()
    return name == "hud" or name == "hudui"
end

local function render(tracker, now, sceneVisible)
    if tracker.config.enabled == false then tracker.window:SetHidden(true); return end
    local state = tracker.state
    local active = state.active and (state.expires == 0 or state.expires > now)
    local remaining = math.max(0, state.expires - now)
    local immunity = not active and tracker.immunity
    if immunity and immunity.ends <= now then immunity = nil end
    local cooldown = not active and tracker.cooldown
    if cooldown and cooldown.ends <= now then cooldown = nil end
    local timer = "--"
    if active then
        if state.expires == 0 then
            timer = "*"
        elseif remaining >= 100 then
            timer = tostring(math.ceil(remaining))
        else
            timer = string.format("%.1f", remaining)
        end
    elseif immunity then
        timer = string.format("%.1f", immunity.ends - now)
    elseif cooldown then
        timer = string.format("%.1f", cooldown.ends - now)
    end
    tracker.timer:SetText(timer)
    local waiting = immunity or cooldown
    tracker.timer:SetColor(waiting and 1 or 0.65, waiting and 0.75 or 1, waiting and 0.35 or 0.45, 1)
    tracker.icon:SetColor(active and 1 or 0.4, active and 1 or 0.4, active and 1 or 0.4, 1)
    local measuredUntil = inCombat and (lastActiveAt or (not EVENT_COMBAT_EVENT and not useLibCombat and now)) or fightEndedAt
    local starts = math.max(state.since, activeStartedAt or fightStartedAt or state.since)
    local duration = finalDuration
    if duration and measuredUntil then
        duration = math.min(duration, math.max(1, measuredUntil - starts))
    end
    local percent = 0
    if liveUptimeMode then
        tracker.liveUptimeResult = LiveUptime.Calculate(liveUptimeFight, tracker, liveUptimePlayerId, liveUptimeTargetId)
        percent = tracker.liveUptimeResult.percent
    elseif tracker.config.unit == "group" then
        percent = cooldownProfile(tracker.config) and tracker.config.excludeCooldown ~= false
            and tracker.group.adjustedPercent or tracker.group.percent
    elseif measuredUntil then
        if useLibCombat and tracker.config.unit == "player" then
            if cooldownProfile(tracker.config) and tracker.config.excludeCooldown ~= false then
                percent = Meter.ScopePercentExcluding(tracker.scope, tracker.cooldownState, starts, measuredUntil, duration)
            else
                percent = Meter.ScopePercent(tracker.scope, starts, measuredUntil, duration)
            end
        elseif tracker.config.id == OFF_BALANCE_ID and tracker.config.unit == "reticleover" and tracker.config.excludeImmunity ~= false then
            percent = Meter.PercentExcluding(state, tracker.immunityState, measuredUntil, starts, duration)
        elseif cooldownProfile(tracker.config) and tracker.config.excludeCooldown ~= false then
            percent = Meter.PercentExcluding(state, tracker.cooldownState, measuredUntil, starts, duration)
        else
            percent = Meter.Percent(state, measuredUntil, starts, duration)
        end
    end
    tracker.uptime:SetText(string.format("%.1f %%", percent))
    tracker.displayPercent = percent
    local isGroup = tracker.config.unit == "group"
    if tracker.coverageLayout ~= isGroup then
        tracker.uptime:ClearAnchors()
        tracker.uptime:SetAnchor(TOPLEFT, tracker.window, TOPLEFT, 56, 0)
        tracker.uptime:SetDimensions(108, isGroup and 27 or 48)
        tracker.coverage:SetHidden(not isGroup)
        tracker.coverageLayout = isGroup
    end
    if isGroup then
        tracker.coverage:SetText(string.format("%d/%d", tracker.group.activeMembers or 0, tracker.group.eligibleMembers or 0))
    end
    if tracker.config.unit == "player" then
        tracker.uptime:SetColor(0.45, 1, 0.65, 1)
    elseif tracker.config.unit == "group" then
        tracker.uptime:SetColor(0.45, 0.85, 1, 1)
    else
        tracker.uptime:SetColor(1, 0.75, 0.35, 1)
    end
    local moving = unlocked and selectedTracker == tracker
    tracker.window:SetMouseEnabled(moving)
    tracker.window:SetMovable(moving)
    tracker.border:SetHidden(not moving)
    tracker.border:SetEdgeColor(selectedTracker == tracker and 0.35 or 1, 1, selectedTracker == tracker and 0.55 or 1, 0.85)
    local showCombat = tracker.config.unit == "group" and tracker.group.running or inCombat
    if sceneVisible == nil then sceneVisible = hudVisible() end
    tracker.window:SetHidden(not (unlocked or (sceneVisible and (not settings.combatOnly or showCombat))))
end

local function queueCheck(tracker, group)
    if not audit.enabled or tracker.config.enabled == false then return end
    if liveUptimeMode then
        if not liveUptimeFight or liveUptimeFight.running or not liveUptimeFight.starts or not liveUptimeFight.ends then return end
        local result = LiveUptime.Calculate(liveUptimeFight, tracker, liveUptimePlayerId, liveUptimeTargetId, true)
        settings.lastFights = settings.lastFights or {}
        local record = { id = tracker.config.id, unit = tracker.config.unit, source = tracker.config.buffSource or "all",
            view = tracker.config.view or (tracker.config.unit == "reticleover" and "damageOut" or "healingOut"),
            includePets = tracker.config.includePets == true, includeOverheal = tracker.config.includeOverheal == true,
            metric = tracker.config.uptimeMetric or "time", normalCovered = result.normalCovered, stackCovered = result.stackCovered,
            timestamp = GetTimeStamp and GetTimeStamp() or nil, covered = result.covered, duration = result.duration,
            percent = result.percent, combatDuration = liveUptimeFight.ends - liveUptimeFight.starts, members = {}, truncated = result.truncated }
        for _, member in ipairs(result.members) do
            if #record.members >= 48 then break end
            record.members[#record.members + 1] = { id = member.id, name = member.name, covered = member.covered, duration = member.duration }
        end
        if #settings.lastFights >= 12 then table.remove(settings.lastFights, 1) end
        settings.lastFights[#settings.lastFights + 1] = record
        Audit.Queue(audit, { label = string.format("Live-Uptime ID %d %s %s %s %s", tracker.config.id, tracker.config.unit,
            tracker.config.buffSource == "own" and "eigene Quelle" or "alle Quellen", record.view, record.metric),
            starts = liveUptimeFight.starts, ends = liveUptimeFight.ends, percent = tracker.displayPercent or 0,
            duration = result.duration, group = true, members = result.members, truncated = result.truncated,
            weighted = tracker.config.uptimeMetric == "stacks" })
        return
    end
    local starts = group and tracker.group.firstDamageAt or activeStartedAt or fightStartedAt
    local ends = group and tracker.group.lastDamageAt or fightEndedAt
    if not starts or not ends then return end
    if not group and ends < math.max(starts, tracker.state.since) then return end
    local job = { label = string.format("ID %d %s (Kampf %.2fs)", tracker.config.id, tracker.config.unit, ends - starts),
        starts = math.max(starts, tracker.state.since), ends = ends, percent = tracker.displayPercent or 0,
        duration = math.max(1, ends - math.max(starts, tracker.state.since)), group = group, members = {} }
    if group then
        job.starts = starts
        local exclude = cooldownProfile(tracker.config) and tracker.config.excludeCooldown ~= false
        for _, member in pairs(tracker.group.members) do
            if #job.members >= 48 then job.truncated = true; break end
            job.members[#job.members + 1] = { intervals = member.meter.intervals,
                eligibility = member.eligibility.intervals, excluded = exclude and member.excluded.intervals or nil }
        end
    else
        local data = { intervals = tracker.state.intervals }
        if useLibCombat and tracker.config.unit == "player" then
            data.intervals, data.open = tracker.scope.intervals, tracker.scope.starts
        end
        if tracker.config.id == OFF_BALANCE_ID and tracker.config.unit == "reticleover" and tracker.config.excludeImmunity ~= false then
            data.excluded = tracker.immunityState.intervals
        elseif cooldownProfile(tracker.config) and tracker.config.excludeCooldown ~= false then
            data.excluded = tracker.cooldownState.intervals
        end
        job.members[1] = data
    end
    Audit.Queue(audit, job)
end

local function createTracker(config)
    local tracker = { config = config, state = Meter.New(nowSeconds()), immunityState = Meter.New(nowSeconds()), cooldownState = Meter.New(nowSeconds()), scope = Meter.NewScope(), group = Group.New(nowSeconds()) }
    local window = wm:CreateTopLevelWindow(NAME .. "Tracker" .. config.key)
    tracker.window = window
    window:SetDimensions(164, 48)
    window:SetMovable(false)
    window:SetClampedToScreen(true)
    window:SetDrawLayer(DL_OVERLAY)
    window:SetMouseEnabled(false)
    window:SetHandler("OnMouseDown", function(control, button)
        if unlocked and selectedTracker == tracker and button == MOUSE_BUTTON_INDEX_LEFT then
            moveDragging = true
            lastMoveInputAt = nowSeconds()
            control:StartMoving()
        end
    end)
    window:SetHandler("OnMouseUp", function(control, button)
        if selectedTracker == tracker and button == MOUSE_BUTTON_INDEX_LEFT and moveDragging then
            control:StopMovingOrResizing()
            moveDragging = false
            lastMoveInputAt = nowSeconds()
            savePosition(tracker)
        end
    end)
    window:SetHandler("OnMoveStop", function() savePosition(tracker) end)
    window:SetHandler("OnMouseEnter", function(control)
        InitializeTooltip(InformationTooltip, control, BOTTOM, 0, -8)
        local text = displayName(config.id) .. " | " .. unitNames[config.unit] .. " | ID " .. config.id
        if config.unit == "group" then
            text = text .. string.format("\nAktiv: %d/%d | Restzeit: kuerzeste aktive Anwendung", tracker.group.activeMembers or 0, tracker.group.eligibleMembers or 0)
        end
        if config.id == OFF_BALANCE_ID and config.unit == "reticleover" then
            text = text .. "\nGruen: Off Balance | Orange: Immunitaet. Uptime zaehlt nur Off Balance."
            if not liveUptimeMode and config.excludeImmunity ~= false then text = text .. "\nUptime ohne Immunitaetszeit." end
        end
        local profile = cooldownProfile(config)
        if profile then
            text = text .. "\nGruen: Effekt | Orange: Cooldown - " .. profile.name
            if profile.key == "nunatak" then text = text .. "\nNunatak: laufender Cooldown hat Vorrang vor der Debuff-Restzeit." end
            if not liveUptimeMode and config.excludeCooldown ~= false then text = text .. "\nUptime ohne inaktive Cooldownzeit (kein normaler Kampfwert)." end
        end
        SetTooltipText(InformationTooltip, text)
    end)
    window:SetHandler("OnMouseExit", function() ClearTooltip(InformationTooltip) end)

    tracker.border = wm:CreateControl(nil, window, CT_BACKDROP)
    tracker.border:SetAnchorFill(window)
    tracker.border:SetCenterColor(0, 0, 0, 0.55)
    tracker.border:SetEdgeColor(1, 1, 1, 0.7)
    tracker.border:SetEdgeTexture("EsoUI/Art/Miscellaneous/centerscreen_left.dds", 1, 1, 1, 0)
    tracker.icon = wm:CreateControl(nil, window, CT_TEXTURE)
    tracker.icon:SetAnchor(TOPLEFT, window, TOPLEFT, 0, 0)
    tracker.icon:SetDimensions(48, 48)
    tracker.icon:SetTexture(GetAbilityIcon(config.id))
    tracker.timer = wm:CreateControl(nil, window, CT_LABEL)
    tracker.timer:SetAnchorFill(tracker.icon)
    tracker.timer:SetFont("$(BOLD_FONT)|20|soft-shadow-thick")
    tracker.timer:SetColor(0.65, 1, 0.45, 1)
    tracker.timer:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    tracker.timer:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    tracker.timer:SetDrawLayer(DL_OVERLAY)
    tracker.uptime = wm:CreateControl(nil, window, CT_LABEL)
    tracker.uptime:SetAnchor(LEFT, tracker.icon, RIGHT, 8, 0)
    tracker.uptime:SetDimensions(108, 48)
    tracker.uptime:SetFont("$(BOLD_FONT)|22|soft-shadow-thick")
    tracker.uptime:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    tracker.coverage = wm:CreateControl(nil, window, CT_LABEL)
    tracker.coverage:SetAnchor(TOPLEFT, window, TOPLEFT, 56, 27)
    tracker.coverage:SetDimensions(108, 21)
    tracker.coverage:SetFont("$(BOLD_FONT)|16|soft-shadow-thick")
    tracker.coverage:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    tracker.coverage:SetColor(0.85, 0.9, 0.95, 1)
    tracker.coverage:SetHidden(true)
    position(tracker)
    window:SetHidden(config.enabled == false)
    trackers[#trackers + 1] = tracker
    refreshEnabledTrackers()
    return tracker
end

update = function(targetChanged, sampleOnly)
    local now = nowSeconds()
    local snapshots = {}
    local roster, groupCombat
    for _, tracker in ipairs(enabledTrackers) do
        if tracker.config.unit == "group" then
            roster = groupRoster()
            groupCombat = inCombat
            local present = {}
            for _, member in ipairs(roster) do
                present[member.key] = true
                groupCombat = groupCombat or member.inCombat
                snapshots[member.tag] = readGroupEffects(member, now)
            end
            for key in pairs(groupEffects) do
                if not present[key] then groupEffects[key] = nil end
            end
            break
        end
    end
    for _, tracker in ipairs(enabledTrackers) do
        local unit = tracker.config.unit
        local effect
        tracker.immunity = nil
        tracker.cooldown = nil
        local profile = cooldownProfile(tracker.config)
        if unit == "group" then
            local observations = {}
            for _, member in ipairs(roster) do
                local cooldownKey = profile and profile.recipient and member.key or "player"
                local excluded = Cooldowns.Get(profile, cooldownKey, now)
                if member.eligible and excluded and (not tracker.cooldown or excluded.ends < tracker.cooldown.ends) then
                    tracker.cooldown = excluded
                end
                observations[#observations + 1] = { key = member.key, eligible = member.eligible,
                    effect = findEffect(tracker.config, snapshots[member.tag]), excluded = excluded }
            end
            local window
            if EVENT_COMBAT_EVENT then
                if groupCombat and not tracker.group.running and (tracker.group.lastDamageAt or -math.huge) < now then
                    tracker.group.firstDamageAt, tracker.group.lastDamageAt = nil, nil
                end
                window = { starts = tracker.group.firstDamageAt or now, ends = tracker.group.lastDamageAt or now }
            end
            local wasRunning = tracker.group.running
            effect = Group.Update(tracker.group, observations, now, groupCombat, window, sampleOnly or liveUptimeMode)
            if wasRunning and not tracker.group.running and not liveUptimeMode then tracker.checkGroupPending = true end
            tracker.state.active = effect ~= nil
            tracker.state.expires = effect and effect.ends or 0
        else
            if not snapshots[unit] then snapshots[unit] = readEffects(unit, now) end
            if targetChanged and unit == "reticleover" then
                Meter.Advance(tracker.state, now, inCombat)
                tracker.state.active = false
                Meter.Advance(tracker.immunityState, now, inCombat)
                tracker.immunityState.active = false
            end
            effect = findEffect(tracker.config, snapshots[unit])
            if tracker.prebuff and tracker.prebuffExpires and tracker.prebuffExpires > 0 then
                local expires = tracker.prebuffExpires
                if effect and effect.starts <= expires then
                    tracker.prebuffExpires = effect.ends == 0 and 0 or math.max(expires, effect.ends)
                end
                if tracker.prebuffExpires > 0 and tracker.prebuffExpires <= now then
                    Meter.ScopeEvent(tracker.scope, tracker.prebuff, tracker.prebuffExpires, false)
                    tracker.prebuff, tracker.prebuffExpires = nil, nil
                end
            end
            Meter.Observe(tracker.state, effect, now, inCombat, not targetChanged)
            local memberKey = profile and profile.recipient and groupMemberKey("player") or "player"
            tracker.cooldown = Cooldowns.Get(profile, memberKey, now)
            Meter.Observe(tracker.cooldownState, tracker.cooldown, now, inCombat, true)
            if unit == "reticleover" and tracker.config.id == OFF_BALANCE_ID then
                local immunity = snapshots[unit][OFF_BALANCE_IMMUNITY_ID]
                if immunity and immunity.ends > now then tracker.immunity = immunity end
                Meter.Observe(tracker.immunityState, tracker.immunity, now, inCombat, not targetChanged)
            end
        end
        if effect and effect.icon and effect.icon ~= "" then tracker.icon:SetTexture(effect.icon) end
        if not sampleOnly then
            render(tracker, now)
            if tracker.checkGroupPending then
                queueCheck(tracker, true)
                tracker.checkGroupPending = nil
            end
        end
    end
end

selectTracker = function(tracker)
    if unlocked then setUnlocked(false) end
    selectedTracker = tracker
    update()
end

local function moveUpdate()
    if not unlocked or not selectedTracker then return end
    local now = nowSeconds()
    local frame = selectedTracker.window
    local x, y = frame:GetLeft(), frame:GetTop()
    if x ~= moveLastX or y ~= moveLastY or moveDragging then
        lastMoveInputAt = now
        savePosition(selectedTracker)
    end
    if SCENE_MANAGER and SCENE_MANAGER.IsInUIMode and SCENE_MANAGER.SetInUIMode and not SCENE_MANAGER:IsInUIMode() then
        SCENE_MANAGER:SetInUIMode(true)
    end
    if SetGameCameraUIMode and IsGameCameraUIModeActive and not IsGameCameraUIModeActive() then
        SetGameCameraUIMode(true)
    end
    local stickX = GetGamepadRightStickX and GetGamepadRightStickX(GAMEPAD_INCLUDE_DEADZONE) or 0
    local stickY = GetGamepadRightStickY and GetGamepadRightStickY(GAMEPAD_INCLUDE_DEADZONE) or 0
    local config = selectedTracker.config
    if not moveDragging and (math.abs(stickX) >= 0.05 or math.abs(stickY) >= 0.05) then
        config.x = math.max(0, math.min(math.max(0, GuiRoot:GetWidth() - 164 * config.scale), x + stickX * 22))
        config.y = math.max(0, math.min(math.max(0, GuiRoot:GetHeight() - 48 * config.scale), y - stickY * 22))
        position(selectedTracker)
        savePosition(selectedTracker)
        lastMoveInputAt = now
    end
    moveLastX, moveLastY = frame:GetLeft(), frame:GetTop()
    if now - lastMoveInputAt >= 3 then setUnlocked(false) end
end

local function createMoveUI()
    moveOverlay = wm:CreateTopLevelWindow(NAME .. "MoveOverlay")
    moveOverlay:SetAnchorFill(GuiRoot)
    moveOverlay:SetMouseEnabled(false)
    moveOverlay:SetDrawLayer(DL_OVERLAY)
    moveOverlay:SetDrawTier(DT_HIGH)
    moveOverlay:SetHidden(true)

    local dim = wm:CreateControl(nil, moveOverlay, CT_BACKDROP)
    dim:SetAnchorFill(moveOverlay)
    dim:SetCenterColor(0, 0, 0, 0.10)
    dim:SetEdgeColor(0, 0, 0, 0)
    for _, offset in ipairs({ -220, 0, 220 }) do
        for _, horizontal in ipairs({ true, false }) do
            local line = wm:CreateControl(nil, moveOverlay, CT_BACKDROP)
            line:SetAnchor(CENTER, moveOverlay, CENTER, horizontal and 0 or offset, horizontal and offset or 0)
            line:SetDimensions(horizontal and GuiRoot:GetWidth() or (offset == 0 and 2 or 1), horizontal and (offset == 0 and 2 or 1) or GuiRoot:GetHeight())
            line:SetCenterColor(1, 1, 1, offset == 0 and 0.45 or 0.18)
            line:SetEdgeColor(0, 0, 0, 0)
        end
    end
end

setUnlocked = function(value)
    if value == unlocked then return end
    if value and #enabledTrackers == 0 then
        d(TITLE .. ": Bitte zuerst einen Tracker aktivieren.")
        return
    end
    unlocked = value
    EVENT_MANAGER:UnregisterForUpdate(NAME .. "Move")
    if value then
        if SCENE_MANAGER and SCENE_MANAGER.IsInUIMode and SCENE_MANAGER.SetInUIMode then
            previousUIMode = SCENE_MANAGER:IsInUIMode()
            SCENE_MANAGER:SetInUIMode(true)
        end
        if SetGameCameraUIMode then
            previousCameraMode = IsGameCameraUIModeActive and IsGameCameraUIModeActive() or false
            SetGameCameraUIMode(true)
        end
        selectedTracker = selectedTracker and selectedTracker.config.enabled ~= false and selectedTracker or enabledTrackers[1]
        lastMoveInputAt = nowSeconds()
        moveLastX, moveLastY = selectedTracker.window:GetLeft(), selectedTracker.window:GetTop()
        moveDragging = false
        EVENT_MANAGER:RegisterForUpdate(NAME .. "Move", 16, moveUpdate)
    end
    moveOverlay:SetHidden(not value)
    if not value then
        for _, tracker in ipairs(trackers) do
            tracker.window:StopMovingOrResizing()
            savePosition(tracker)
        end
        moveDragging = false
        if SCENE_MANAGER and SCENE_MANAGER.SetInUIMode and previousUIMode == false then SCENE_MANAGER:SetInUIMode(false) end
        if SetGameCameraUIMode and previousCameraMode == false then SetGameCameraUIMode(false) end
        previousUIMode, previousCameraMode = nil, nil
        ClearTooltip(InformationTooltip)
    end
    update()
end

local function resetMeasurements(at, preserveGroup)
    local now = type(at) == "number" and at or nowSeconds()
    fightEndedAt = nil
    finalDuration = nil
    fightStartedAt = inCombat and now or nil
    activeStartedAt = nil
    lastActiveAt = nil
    if liveUptimeMode then liveUptimeFight = LiveUptime.New(now); liveUptimeTargetId = nil end
    for _, tracker in ipairs(trackers) do
        tracker.state = Meter.New(now)
        tracker.immunityState = Meter.New(now)
        tracker.cooldownState = Meter.New(now)
        if not preserveGroup then tracker.group = Group.New(now) end
        tracker.scope = Meter.NewScope()
        tracker.liveUptimeUnits = {}
        seedPrebuff(tracker, now)
    end
    update()
end

local function combatChanged(_, value)
    if useLibCombat then return end
    if value == inCombat then return end
    if value then
        inCombat = true
        resetMeasurements(nil, true)
    else
        update()
        fightEndedAt = lastActiveAt or (not EVENT_COMBAT_EVENT and nowSeconds())
        inCombat = false
        update()
        for _, tracker in ipairs(trackers) do
            if tracker.config.unit ~= "group" then queueCheck(tracker, false) end
        end
    end
end

local function validId(value)
    local id = tonumber(value)
    if not id or id ~= math.floor(id) or id <= 0 or id > 2147483647 then return nil end
    local icon = GetAbilityIcon(id)
    if not icon or icon == "" or GetAbilityName(id) == "" then return nil end
    return id
end

local function addTracker()
    local id = validId(draftId)
    if not id then
        d(TITLE .. ": Bitte eine gueltige Effekt-ID eingeben.")
        return
    end
    for _, config in ipairs(settings.trackers) do
        if matches(config, id) and config.unit == draftUnit then
            d(TITLE .. ": Dieser Effekt wird fuer diese Einheit bereits angezeigt.")
            return
        end
    end
    local count = #settings.trackers
    local config = {
        key = settings.nextKey, id = id, unit = draftUnit, scale = 1,
        x = math.max(0, (GuiRoot:GetWidth() - 164) / 2),
        y = math.max(0, math.min(GuiRoot:GetHeight() - 48, 300 + count * 56)),
    }
    settings.nextKey = settings.nextKey + 1
    settings.trackers[#settings.trackers + 1] = config
    createTracker(config)
    seedPrebuff(trackers[#trackers], nowSeconds())
    update()
    zo_callLater(function() refreshSettings(config.key) end, 0)
end

local function removeTracker(tracker)
    tracker.window:StopMovingOrResizing()
    tracker.window:SetHidden(true)
    tracker.window:SetMouseEnabled(false)
    ClearTooltip(InformationTooltip)
    for i, item in ipairs(trackers) do
        if item == tracker then
            table.remove(trackers, i)
            table.remove(settings.trackers, i)
            break
        end
    end
    refreshEnabledTrackers()
    if selectedTracker == tracker then selectTracker(enabledTrackers[1]) end
    if #enabledTrackers == 0 and unlocked then setUnlocked(false) end
    zo_callLater(refreshSettings, 0)
end

refreshSettings = function(openSection, selectedLabel)
    local lib = LibHarvensAddonSettings
    local scrollList = lib.scrollList
    local activeList = panel.selected and scrollList and scrollList:GetCurrentList()
    local sectionKey = openSection
    if not sectionKey and activeList and activeList.currentSection then
        for key, section in pairs(settingsSections) do
            if section == activeList.currentSection then sectionKey = key; break end
        end
    end
    local sectionIndexes = {}
    local descriptors = {
        { type = lib.ST_CHECKBOX, label = "Nur im Kampf anzeigen",
          getFunction = function() return settings.combatOnly end,
          setFunction = function(value) settings.combatOnly = value; update() end },
        { type = lib.ST_CHECKBOX, label = "Uptime-Selbstpruefung",
          tooltip = "Begrenzte interne Nachrechnung nach Kampfende mit Chatbericht. Fehlende ESO-Ereignisse koennen nicht sicher erkannt werden.",
          getFunction = function() return settings.checkUptime end,
          setFunction = function(value) settings.checkUptime = value; Audit.SetEnabled(audit, value) end },
        { type = lib.ST_SECTION, label = "Neuer Tracker" },
        { type = lib.ST_EDIT, label = "Effekt-ID", maxChars = 10,
          tooltip = "Die ID des Buffs oder Debuffs, nicht zwingend die ID der ausloesenden Fertigkeit.",
          getFunction = function() return draftId end,
          setFunction = function(value) draftId = value end },
        { type = lib.ST_DROPDOWN, label = "Einheit", items = unitItems,
          getFunction = function() return unitNames[draftUnit] end,
          setFunction = function(_, _, item) draftUnit = item.data end },
        { type = lib.ST_BUTTON, label = "Tracker hinzufuegen", buttonText = "Hinzufuegen", clickHandler = addTracker },
    }
    for index, descriptor in ipairs(descriptors) do
        if descriptor.type == lib.ST_SECTION then sectionIndexes.new = index end
    end
    for _, item in ipairs(trackers) do
        local tracker = item
        local config = tracker.config
        descriptors[#descriptors + 1] = { type = lib.ST_SECTION,
            label = displayName(config.id) .. " (" .. config.id .. ") - " .. unitNames[config.unit] }
        sectionIndexes[config.key] = #descriptors
        descriptors[#descriptors + 1] = { type = lib.ST_CHECKBOX, label = "Buff aktiv",
            getFunction = function() return config.enabled ~= false end,
            setFunction = function(value)
                if selectedTracker == tracker and unlocked then setUnlocked(false) end
                config.enabled = value and true or false
                tracker.state = Meter.New(nowSeconds())
                tracker.immunityState = Meter.New(nowSeconds())
                tracker.cooldownState = Meter.New(nowSeconds())
                tracker.group = Group.New(nowSeconds())
                tracker.scope = Meter.NewScope()
                tracker.liveUptimeUnits = {}
                tracker.checkGroupPending = nil
                seedPrebuff(tracker, nowSeconds())
                refreshEnabledTrackers()
                tracker.window:SetHidden(config.enabled == false)
                tracker.window:SetMouseEnabled(false)
                if selectedTracker == tracker and not config.enabled then selectedTracker = enabledTrackers[1] end
                update()
            end }
        descriptors[#descriptors + 1] = { type = lib.ST_BUTTON, label = "Move UI",
            buttonText = "Icon verschieben",
            tooltip = "Diesen Tracker verschieben. Endet nach 3 Sekunden ohne Bewegung.",
            disable = function() return config.enabled == false end,
            clickHandler = function()
                if config.enabled == false then return end
                selectTracker(tracker); setUnlocked(true)
            end }
        descriptors[#descriptors + 1] = { type = lib.ST_DROPDOWN, label = "Einheit", items = unitItems,
            tooltip = "Live-Uptime-Messung: Gruppen-Uptime ueber individuelle Ereigniszeiten, ohne pauschalen Abzug von Todeszeiten. Ziel: aktueller Gegner.",
            getFunction = function() return unitNames[config.unit] end,
            setFunction = function(_, _, entry)
                config.unit = entry.data
                config.view = nil
                tracker.state = Meter.New(nowSeconds())
                tracker.immunityState = Meter.New(nowSeconds())
                tracker.cooldownState = Meter.New(nowSeconds())
                tracker.group = Group.New(nowSeconds())
                tracker.scope = Meter.NewScope()
                tracker.liveUptimeUnits = {}
                seedPrebuff(tracker, nowSeconds())
                update()
                zo_callLater(function() refreshSettings(config.key, "Einheit") end, 0)
            end }
        descriptors[#descriptors + 1] = { type = lib.ST_DROPDOWN, label = "Buff-Quelle",
            items = { { name = "Alle Quellen", data = "all" }, { name = "Nur ich und meine Begleiter", data = "own" } },
            getFunction = function() return config.buffSource == "own" and "Nur ich und meine Begleiter" or "Alle Quellen" end,
            setFunction = function(_, _, entry) config.buffSource = entry.data; update() end,
            disable = function() return not liveUptimeMode end }
        local views = config.unit == "reticleover"
            and { { name = "Schaden ausgehend", data = "damageOut" }, { name = "Schaden eingehend", data = "damageIn" } }
            or { { name = "Heilung ausgehend", data = "healingOut" }, { name = "Heilung eingehend", data = "healingIn" } }
        descriptors[#descriptors + 1] = { type = lib.ST_DROPDOWN, label = "Auswertungsansicht", items = views,
            tooltip = "Einheiten zaehlen bei beobachteten Effekten oder positiven Werten in dieser Ansicht. Nur der Zeitnenner wird gefiltert.",
            getFunction = function()
                for _, view in ipairs(views) do if config.view == view.data then return view.name end end
                return views[1].name
            end,
            setFunction = function(_, _, entry) config.view = entry.data; update() end,
            disable = function() return not liveUptimeMode end }
        if config.unit == "group" then
            descriptors[#descriptors + 1] = { type = lib.ST_CHECKBOX, label = "Begleiter in Gruppenmessung",
                getFunction = function() return config.includePets == true end,
                setFunction = function(value) config.includePets = value; update() end,
                disable = function() return not liveUptimeMode end }
        end
        if config.unit ~= "reticleover" then
            descriptors[#descriptors + 1] = { type = lib.ST_CHECKBOX, label = "Ueberheilung als relevante Daten",
                getFunction = function() return config.includeOverheal == true end,
                setFunction = function(value) config.includeOverheal = value; update() end,
                disable = function() return not liveUptimeMode or config.view == "healingIn" end }
        end
        descriptors[#descriptors + 1] = { type = lib.ST_DROPDOWN, label = "Uptime-Auswertung",
            items = { { name = "Normale Buffzeit", data = "time" }, { name = "Stapelgewichtet", data = "stacks" } },
            tooltip = "Stapelzeit je Effekt-ID, normalisiert auf den hoechsten beobachteten Stapel je Einheit. Mehrere Anwendungen koennen ueber 100 Prozent ergeben.",
            getFunction = function() return config.uptimeMetric == "stacks" and "Stapelgewichtet" or "Normale Buffzeit" end,
            setFunction = function(_, _, entry) config.uptimeMetric = entry.data; update() end,
            disable = function() return not liveUptimeMode end }
        if config.id == OFF_BALANCE_ID and config.unit == "reticleover" then
            descriptors[#descriptors + 1] = { type = lib.ST_CHECKBOX, label = "Immunitaetszeit aus Uptime ausnehmen",
                tooltip = "Off-Balance-Uptime nur ueber die Zeit ohne erkannte Immunitaet. Deaktivieren fuer normale Kampf-Uptime.",
                getFunction = function() return not liveUptimeMode and config.excludeImmunity ~= false end,
                setFunction = function(value) config.excludeImmunity = value; update() end,
                disable = function() return liveUptimeMode end }
        end
        local cooldownItems = { { name = "Keiner", data = "none" } }
        for _, profile in ipairs(Cooldowns.profiles) do
            local candidate = { id = config.id, unit = config.unit, cooldownProfile = profile.key }
            if cooldownProfile(candidate) then cooldownItems[#cooldownItems + 1] = { name = profile.name, data = profile.key } end
        end
        if #cooldownItems > 1 then
            descriptors[#descriptors + 1] = { type = lib.ST_DROPDOWN, label = "Cooldown-Quelle", items = cooldownItems,
                tooltip = "Set gezielt waehlen. Orange zeigt den Cooldown erkannter Procs, nicht eine Gegner-Immunitaet.",
                getFunction = function() local profile = cooldownProfile(config); return profile and profile.name or "Keiner" end,
                setFunction = function(_, _, entry)
                    config.cooldownProfile = entry.data
                    tracker.cooldownState = Meter.New(nowSeconds())
                    tracker.state = Meter.New(nowSeconds())
                    tracker.scope = Meter.NewScope()
                    tracker.liveUptimeUnits = {}
                    tracker.group = Group.New(nowSeconds())
                    seedPrebuff(tracker, nowSeconds())
                    update()
                end }
            descriptors[#descriptors + 1] = { type = lib.ST_CHECKBOX, label = "Cooldownzeit aus Uptime ausnehmen",
                tooltip = "Zaehlt nur Zeit ohne inaktiven Set-Cooldown. Andere Quellen koennen den Effekt trotzdem aufrechterhalten.",
                getFunction = function() return not liveUptimeMode and config.excludeCooldown ~= false end,
                setFunction = function(value) config.excludeCooldown = value; update() end,
                disable = function() return liveUptimeMode or not cooldownProfile(config) end }
        end
        descriptors[#descriptors + 1] = { type = lib.ST_SLIDER, label = "Groesse",
            min = 0.5, max = 2, step = 0.05,
            getFunction = function() return config.scale end,
            setFunction = function(value) config.scale = value; position(tracker) end }
        descriptors[#descriptors + 1] = { type = lib.ST_BUTTON, label = "Tracker entfernen",
            buttonText = "Entfernen", clickHandler = function() removeTracker(tracker) end }
    end
    panel:RemoveAllSettings(false)
    local controls = panel:AddSettings(descriptors, nil, false)
    settingsSections = {}
    for key, index in pairs(sectionIndexes) do
        settingsSections[key] = controls and controls[index]
    end
    if activeList then
        -- Gamepad sections use setting-object identity; restore the newly built section.
        local section = settingsSections[sectionKey]
        local list = section and scrollList:GetList("Section") or scrollList:GetMainList()
        activeList.currentSection = nil
        list.currentSection = section
        if list ~= activeList then scrollList:SetCurrentList(list) end
        panel:CreateControls()
        if section and selectedLabel then
            local first = sectionIndexes[sectionKey] + 1
            for index = first, #descriptors do
                if descriptors[index].type == lib.ST_SECTION then break end
                if descriptors[index].label == selectedLabel then
                    panel.lastSelectedRow = controls[index]
                    break
                end
            end
        end
        panel:RefreshSelection()
    end
end

local function libConstant(name)
    return _G["LIBCOMBAT_" .. name] or (LibCombat and (LibCombat["LIBCOMBAT_" .. name] or LibCombat[name]))
end

local function libTime(timeMS)
    -- LibCombat uses the game clock; buff durations use the frame clock.
    return nowSeconds() + (timeMS - GetGameTimeMilliseconds()) / 1000
end

local function startLibraryFight(time)
    if inCombat then return end
    inCombat = true
    resetMeasurements(time, true)
end

local function registerLibCombat()
    if useLibCombat then return end
    if not LibCombat or type(LibCombat.RegisterForCombatEvent) ~= "function" then return end
    for _, name in ipairs({ "EVENT_MESSAGES", "EVENT_FIGHTSUMMARY", "EVENT_DAMAGE_OUT", "EVENT_DAMAGE_SELF",
        "EVENT_EFFECTS_IN", "MESSAGE_COMBATSTART" }) do
        if not libConstant(name) then return end
    end
    useLibCombat = true
    local liveUptimeEvents = { "EVENT_DAMAGE_OUT", "EVENT_DAMAGE_IN", "EVENT_DAMAGE_SELF", "EVENT_HEAL_OUT",
        "EVENT_HEAL_IN", "EVENT_HEAL_SELF", "EVENT_EFFECTS_IN", "EVENT_EFFECTS_OUT",
        "EVENT_GROUPEFFECTS_IN", "EVENT_GROUPEFFECTS_OUT" }
    liveUptimeMode = LiveUptime ~= nil
    for _, name in ipairs(liveUptimeEvents) do if not libConstant(name) then liveUptimeMode = false end end
    if liveUptimeMode then
        LibCombat:RegisterForCombatEvent(NAME, libConstant("EVENT_MESSAGES"), function(_, timeMS, message)
            if message == libConstant("MESSAGE_COMBATSTART") then startLibraryFight(libTime(timeMS)) end
        end)
        for _, name in ipairs(liveUptimeEvents) do
            local eventName = name
            if string.find(name, "EFFECTS") then
                LibCombat:RegisterForCombatEvent(NAME, libConstant(name), function(_, timeMS, unitId, id, changeType, _, stacks, sourceType, slot)
                    if not inCombat or not liveUptimeFight or not unitId or not slot then return end
                    if changeType ~= EFFECT_RESULT_GAINED and changeType ~= EFFECT_RESULT_UPDATED and changeType ~= EFFECT_RESULT_FADED then return end
                    local time = libTime(timeMS)
                    local unit = LiveUptime.Touch(liveUptimeFight, unitId, time)
                    if not unit then return end
                    if eventName == "EVENT_EFFECTS_IN" then
                        liveUptimePlayerId, unit.player, unit.kind = unitId, true, COMBAT_UNIT_TYPE_PLAYER
                    elseif eventName == "EVENT_GROUPEFFECTS_IN" then
                        unit.kind = unit.kind or COMBAT_UNIT_TYPE_GROUP
                    end
                    LiveUptime.Kind(liveUptimeFight, unitId, unit.kind)
                    local own = sourceType == COMBAT_UNIT_TYPE_PLAYER or sourceType == COMBAT_UNIT_TYPE_PLAYER_PET
                    LiveUptime.Remember(unit, id, slot, changeType ~= EFFECT_RESULT_FADED, own, stacks)
                    for _, tracker in ipairs(enabledTrackers) do
                        if matches(tracker.config, id) then
                            LiveUptime.Effect(liveUptimeFight, tracker, time, unitId, id, slot, changeType ~= EFFECT_RESULT_FADED, own, stacks)
                        end
                    end
                end)
            else
                LibCombat:RegisterForCombatEvent(NAME, libConstant(name), function(_, timeMS, _, source, target, _, value, _, overflow)
                    local time = libTime(timeMS)
                    startLibraryFight(time)
                    LiveUptime.Action(liveUptimeFight, eventName, time, source, target, value, overflow)
                    if eventName == "EVENT_HEAL_SELF" or eventName == "EVENT_DAMAGE_SELF" then
                        liveUptimePlayerId = target or source
                    end
                    activeStartedAt, lastActiveAt = liveUptimeFight.starts, liveUptimeFight.ends
                end)
            end
        end
        LibCombat:RegisterForCombatEvent(NAME, libConstant("EVENT_FIGHTSUMMARY"), function(_, fight)
            if not inCombat or not fight or not liveUptimeFight then return end
            LiveUptime.Finish(liveUptimeFight, fight, libTime)
            for id, unit in pairs(liveUptimeFight.units) do
                if unit.kind == COMBAT_UNIT_TYPE_PLAYER then liveUptimePlayerId, unit.player = id, true end
            end
            fightStartedAt, activeStartedAt, fightEndedAt = liveUptimeFight.starts, liveUptimeFight.starts, liveUptimeFight.ends
            finalDuration = liveUptimeFight.starts and liveUptimeFight.ends and math.max(1, liveUptimeFight.ends - liveUptimeFight.starts) or nil
            inCombat = false
            update()
            for _, tracker in ipairs(enabledTrackers) do
                tracker.checkGroupPending = nil
                queueCheck(tracker, tracker.config.unit == "group")
            end
        end)
        return
    end
    LibCombat:RegisterForCombatEvent(NAME, libConstant("EVENT_MESSAGES"), function(_, timeMS, message)
        if message == libConstant("MESSAGE_COMBATSTART") then startLibraryFight(libTime(timeMS)) end
    end)
    local function action(_, timeMS)
        local time = libTime(timeMS)
        startLibraryFight(time)
        activeStartedAt = math.min(activeStartedAt or time, time)
        lastActiveAt = math.max(lastActiveAt or time, time)
    end
    for _, event in ipairs({ "EVENT_DAMAGE_OUT", "EVENT_DAMAGE_SELF" }) do
        LibCombat:RegisterForCombatEvent(NAME, libConstant(event), action)
    end
    LibCombat:RegisterForCombatEvent(NAME, libConstant("EVENT_EFFECTS_IN"), function(_, timeMS, unitId, id, changeType, _, _, _, slot)
        if not inCombat then return end
        if changeType ~= EFFECT_RESULT_GAINED and changeType ~= EFFECT_RESULT_UPDATED and changeType ~= EFFECT_RESULT_FADED then return end
        local time = libTime(timeMS)
        local gained = changeType ~= EFFECT_RESULT_FADED
        for _, tracker in ipairs(enabledTrackers) do
            if tracker.config.unit == "player" and matches(tracker.config, id) then
                local key = tostring(unitId) .. ":" .. tostring(id) .. ":" .. tostring(slot)
                -- Replace the initial snapshot once authoritative effect events arrive.
                if gained then Meter.ScopeEvent(tracker.scope, key, time, true) end
                if tracker.prebuff then
                    local ends = tracker.prebuffExpires and tracker.prebuffExpires > 0
                        and math.min(time, tracker.prebuffExpires) or time
                    Meter.ScopeEvent(tracker.scope, tracker.prebuff, ends, false)
                    tracker.prebuff, tracker.prebuffExpires = nil, nil
                end
                if not gained then Meter.ScopeEvent(tracker.scope, key, time, false) end
            end
        end
    end)
    LibCombat:RegisterForCombatEvent(NAME, libConstant("EVENT_FIGHTSUMMARY"), function(_, fight)
        if not inCombat or not fight then return end
        local starts = activeStartedAt
        local ends = lastActiveAt
        if not starts or not ends or ends <= starts then
            inCombat = false
            resetMeasurements(nil, true)
            return
        end
        update()
        fightStartedAt, activeStartedAt, fightEndedAt = starts, starts, ends
        finalDuration = math.max(1, ends - starts)
        for _, tracker in ipairs(enabledTrackers) do tracker.scope = Meter.RebuildScope(tracker.scope) end
        inCombat = false
        update()
        for _, tracker in ipairs(trackers) do
            if tracker.config.unit ~= "group" then queueCheck(tracker, false) end
        end
    end)
end

local damageResults = {}
for _, name in ipairs({ "ACTION_RESULT_DAMAGE", "ACTION_RESULT_CRITICAL_DAMAGE", "ACTION_RESULT_DOT_TICK",
    "ACTION_RESULT_DOT_TICK_CRITICAL", "ACTION_RESULT_BLOCKED_DAMAGE", "ACTION_RESULT_DAMAGE_SHIELDED",
    "ACTION_RESULT_PRECISE_DAMAGE", "ACTION_RESULT_WRECKING_DAMAGE" }) do
    if _G[name] then damageResults[_G[name]] = true end
end

local friendlyTypes = {}
for _, name in ipairs({ "COMBAT_UNIT_TYPE_PLAYER", "COMBAT_UNIT_TYPE_PLAYER_PET",
    "COMBAT_UNIT_TYPE_GROUP", "COMBAT_UNIT_TYPE_GROUP_PET" }) do
    if _G[name] then friendlyTypes[_G[name]] = true end
end

local function combatActivity(_, result, isError, _, _, _, _, sourceType, _, targetType, hitValue, _, _, _, sourceId, targetId)
    if liveUptimeMode then
        if isError or not inCombat or not liveUptimeFight then return end
        LiveUptime.Kind(liveUptimeFight, sourceId, sourceType)
        LiveUptime.Kind(liveUptimeFight, targetId, targetType)
        if sourceType == COMBAT_UNIT_TYPE_PLAYER then liveUptimePlayerId = sourceId or liveUptimePlayerId end
        if targetType == COMBAT_UNIT_TYPE_PLAYER then liveUptimePlayerId = targetId or liveUptimePlayerId end
        return
    end
    if isError or not damageResults[result] or not hitValue or hitValue <= 0 then return end
    if (friendlyTypes[sourceType] == true) == (friendlyTypes[targetType] == true) then return end
    local now = nowSeconds()
    if IsUnitInCombat("player") then
        if not inCombat then
            inCombat = true
            resetMeasurements(now, true)
        end
        activeStartedAt = activeStartedAt or now
        lastActiveAt = math.max(lastActiveAt or now, now)
    end
    for _, tracker in ipairs(enabledTrackers) do
        if tracker.config.unit == "group" then
            if not tracker.group.running and (not tracker.group.lastDamageAt or tracker.group.lastDamageAt <= tracker.group.sampledAt) then
                tracker.group.firstDamageAt = now
            end
            tracker.group.firstDamageAt = tracker.group.firstDamageAt or now
            tracker.group.lastDamageAt = now
        end
    end
end

local function isOwnProc(sourceName, sourceType)
    if sourceType == COMBAT_UNIT_TYPE_PLAYER or (COMBAT_UNIT_TYPE_PLAYER_PET and sourceType == COMBAT_UNIT_TYPE_PLAYER_PET) then
        return true
    end
    local playerName = GetUnitName and GetUnitName("player")
    return playerName and playerName ~= "" and sourceName and sourceName ~= ""
        and string.lower(zo_strformat("<<t:1>>", sourceName)) == string.lower(zo_strformat("<<t:1>>", playerName))
end

local function cooldownCombatEvent(_, result, isError, _, _, _, sourceName, sourceType, targetName, targetType, _, _, _, _, _, _, id)
    if isError or not id then return end
    if debugCooldowns then
        for _, profile in ipairs(Cooldowns.profiles) do
            if Cooldowns.IsProc(profile, id) then
                d(string.format("%s: %s | ID %d | Result %s | Quelle %s (%s) | eigenes Proc %s",
                    TITLE, profile.key, id, tostring(result), tostring(sourceName), tostring(sourceType), tostring(isOwnProc(sourceName, sourceType))))
                break
            end
        end
    end
    local valid = result == ACTION_RESULT_EFFECT_GAINED or result == ACTION_RESULT_EFFECT_GAINED_DURATION
        or result == ACTION_RESULT_DAMAGE or result == ACTION_RESULT_CRITICAL_DAMAGE
        or result == ACTION_RESULT_HEAL or result == ACTION_RESULT_CRITICAL_HEAL or result == ACTION_RESULT_POWER_ENERGIZE
    for _, profile in ipairs(Cooldowns.profiles) do
        if Cooldowns.IsProc(profile, id) then
            local periodic = profile.key == "nunatak" and (
                (ACTION_RESULT_DOT_TICK and result == ACTION_RESULT_DOT_TICK)
                or (ACTION_RESULT_DOT_TICK_CRITICAL and result == ACTION_RESULT_DOT_TICK_CRITICAL))
            local gained = result == ACTION_RESULT_EFFECT_GAINED or result == ACTION_RESULT_EFFECT_GAINED_DURATION
            if profile.gainOnly and not gained then return end
            if not valid and not periodic then return end
            local key
            if profile.recipient then
                if targetType == COMBAT_UNIT_TYPE_PLAYER then
                    key = groupMemberKey("player")
                elseif targetName and targetName ~= "" and GetUnitName then
                    local target = zo_strformat("<<t:1>>", targetName)
                    for _, member in ipairs(groupRoster()) do
                        if zo_strformat("<<t:1>>", GetUnitName(member.tag)) == target then key = member.key; break end
                    end
                end
            elseif isOwnProc(sourceName, sourceType) then
                key = "player"
            end
            if key and Cooldowns.Start(profile, key, nowSeconds()) then update(nil, true) end
            return
        end
    end
end

local function loaded(_, addonName)
    if addonName ~= NAME then return end
    EVENT_MANAGER:UnregisterForEvent(NAME, EVENT_ADD_ON_LOADED)
    settings = ZO_SavedVars:NewAccountWide("LiveBuffUptime_SavedVariables", 1, nil, defaults)
    Audit.SetEnabled(audit, settings.checkUptime)
    Audit.Restore(audit, settings.lastCheck, function(state)
        local lines = {}
        for _, line in ipairs(state.last) do lines[#lines + 1] = line end
        settings.lastCheck = { last = lines, samples = state.samples, totalMS = state.totalMS,
            maxMS = state.maxMS, slow = state.slow, dropped = state.dropped }
    end)
    createMoveUI()
    for _, config in ipairs(settings.trackers) do createTracker(config) end
    panel = LibHarvensAddonSettings:AddAddon(TITLE, { allowRefresh = true })
    registerLibCombat()
    if useLibCombat and not liveUptimeMode then d(TITLE .. ": Ereignisbasierte Live-Uptime nicht verfuegbar; LibCombat aktualisieren. Ersatzmessung verwendet andere Messregeln.") end
    refreshSettings()
    if SCENE_MANAGER and SCENE_MANAGER.RegisterCallback then
        SCENE_MANAGER:RegisterCallback("SceneStateChanged", function(scene, state)
            if not scene or not scene.GetName then return end
            if state == SCENE_SHOWING or state == SCENE_SHOWN or state == "showing" or state == "shown" then
                local name = scene:GetName()
                for _, tracker in ipairs(trackers) do render(tracker, nowSeconds(), name == "hud" or name == "hudui") end
            end
        end)
    end
    EVENT_MANAGER:RegisterForEvent(NAME, EVENT_PLAYER_COMBAT_STATE, combatChanged)
    if EVENT_COMBAT_EVENT then
        EVENT_MANAGER:RegisterForEvent(NAME .. "CombatTiming", EVENT_COMBAT_EVENT, combatActivity)
        for _, profile in ipairs(Cooldowns.profiles) do
            for _, id in ipairs(profile.ids or {profile.id}) do
                local eventName = NAME .. "Cooldown" .. id
                EVENT_MANAGER:RegisterForEvent(eventName, EVENT_COMBAT_EVENT, cooldownCombatEvent)
                if EVENT_MANAGER.AddFilterForEvent and REGISTER_FILTER_ABILITY_ID then
                    EVENT_MANAGER:AddFilterForEvent(eventName, EVENT_COMBAT_EVENT, REGISTER_FILTER_ABILITY_ID, id)
                end
            end
        end
    end
    EVENT_MANAGER:RegisterForEvent(NAME, EVENT_RETICLE_TARGET_CHANGED, function()
        if liveUptimeMode then liveUptimeTargetId = nil end
        update(true, true)
    end)
    if EVENT_UNIT_DEATH_STATE_CHANGED then
        EVENT_MANAGER:RegisterForEvent(NAME, EVENT_UNIT_DEATH_STATE_CHANGED, function() update(nil, true) end)
    end
    if EVENT_GROUP_UPDATE then
        EVENT_MANAGER:RegisterForEvent(NAME, EVENT_GROUP_UPDATE, function() update(nil, true) end)
    end
    EVENT_MANAGER:RegisterForEvent(NAME, EVENT_EFFECT_CHANGED, function(_, changeType, slot, _, unitTag, starts, ends, _, icon, _, _, _, _, _, unitId, id, sourceType)
        if type(unitTag) ~= "string" then return end
        if liveUptimeMode and unitId and liveUptimeFight then
            local kind = unitTag == "player" and COMBAT_UNIT_TYPE_PLAYER
                or string.match(unitTag, "^group%d+$") and COMBAT_UNIT_TYPE_GROUP
            LiveUptime.Kind(liveUptimeFight, unitId, kind)
            if unitTag == "player" then liveUptimePlayerId = unitId end
            if unitTag == "reticleover" then liveUptimeTargetId = unitId end
        end
        if debugCooldowns and (id == 167682 or id == 172992 or id == 145977 or id == 167681) then
            d(string.format("%s: Nunatak-Effekt | ID %d | Aenderung %s | Einheit %s | Quelle %s | Start %s | Ende %s",
                TITLE, id, tostring(changeType), unitTag, tostring(sourceType), tostring(starts), tostring(ends)))
        end
        if changeType == EFFECT_RESULT_GAINED or (id == 167682 and changeType == EFFECT_RESULT_UPDATED) then
            for _, profile in ipairs(Cooldowns.profiles) do
                local key
                if Cooldowns.IsProc(profile, id) then
                    if profile.recipient and (unitTag == "player" or string.match(unitTag, "^group%d+$")) then
                        key = groupMemberKey(unitTag)
                    elseif not profile.recipient and isOwnProc(nil, sourceType) then
                        key = "player"
                    end
                end
                if key then
                    local now = nowSeconds()
                    local at = starts and starts > 0 and math.min(starts, now) or now
                    if Cooldowns.Start(profile, key, at) then update(nil, true) end
                    break
                end
            end
        end
        local groupUnit = unitTag == "player" or string.match(unitTag, "^group%d+$")
        local relevantGroupEffect = false
        if groupUnit and id and slot then
            local key = groupMemberKey(unitTag)
            local cached = groupEffects[key]
            if cached then
                relevantGroupEffect = cached[slot] ~= nil
                cached[slot] = nil
            end
            if changeType == EFFECT_RESULT_GAINED or changeType == EFFECT_RESULT_UPDATED then
                for _, tracker in ipairs(enabledTrackers) do
                    if tracker.config.unit == "group" and matches(tracker.config, id) then
                        relevantGroupEffect = true
                        groupEffects[key] = cached or {}
                        groupEffects[key][slot] = { id = id, starts = starts or nowSeconds(), ends = ends or 0, icon = icon }
                        break
                    end
                end
            end
        end
        if not liveUptimeMode and (unitTag == "player" or unitTag == "reticleover" or relevantGroupEffect) then update(nil, true) end
    end)
    EVENT_MANAGER:RegisterForEvent(NAME, EVENT_PLAYER_ACTIVATED, function()
        if not inCombat then registerLibCombat() end
        inCombat = IsUnitInCombat("player")
        resetMeasurements()
    end)
    EVENT_MANAGER:RegisterForUpdate(NAME, 100, function()
        local started = audit.enabled and GetGameTimeMilliseconds and GetGameTimeMilliseconds()
        update()
        if started then Audit.RecordTime(audit, GetGameTimeMilliseconds() - started) end
        Audit.Tick(audit)
    end)
    SLASH_COMMANDS["/lbu"] = function(command)
        if command == "check on" or command == "check off" then
            settings.checkUptime = command == "check on"
            Audit.SetEnabled(audit, settings.checkUptime)
            d(TITLE .. (settings.checkUptime and ": Selbstpruefung aktiv. Ergebnisse nach Kampfende." or ": Selbstpruefung aus."))
        elseif command == "check" or command == "check last" then
            Audit.ShowLast(audit)
        elseif command == "report" then
            local records = settings.lastFights or {}
            local record = records[#records]
            for index = #records, 1, -1 do
                if records[index].unit == "group" then record = records[index]; break end
            end
            if not record then d(TITLE .. ": Noch kein gespeicherter Live-Uptime-Bericht. /lbu check on vor dem Kampf."); return end
            d(string.format("%s Live-Uptime-Bericht: ID %d %s %s | Kampf %.2fs | Buff %.2fs / Einheitenzeit %.2fs = %.1f%%",
                TITLE, record.id, record.unit, record.source, record.combatDuration, record.covered, record.duration, record.percent))
            d(string.format("Ansicht %s | Auswertung %s | Begleiter %s | Ueberheilung %s", record.view or "healingOut",
                record.metric or "time", record.includePets and "ja" or "nein", record.includeOverheal and "ja" or "nein"))
            for _, member in ipairs(record.members) do
                d(string.format("Einheit %s: Buff %.2fs / Zeit %.2fs = %.1f%%", member.name or tostring(member.id), member.covered,
                    member.duration, member.duration > 0 and member.covered / member.duration * 100 or 0))
            end
        elseif command == "move" then
            setUnlocked(not unlocked)
            d(TITLE .. (unlocked and ": Positionen entsperrt. /lbu move sperrt sie wieder." or ": Positionen gesperrt."))
        elseif command == "debug" then
            debugCooldowns = not debugCooldowns
            d(TITLE .. (debugCooldowns and ": Cooldown-Debug aktiv." or ": Cooldown-Debug aus."))
            if debugCooldowns then
                for _, tracker in ipairs(trackers) do
                    local profile = cooldownProfile(tracker.config)
                    d(string.format("%s: Tracker %s | ID %d | Einheit %s | Cooldown-Quelle %s",
                        TITLE, tostring(tracker.config.key), tracker.config.id, tracker.config.unit, profile and profile.key or "Keiner"))
                end
            end
        elseif command == "reset" then
            resetMeasurements()
        else
            d(TITLE .. ": Einstellungen unter Addons. /lbu move | /lbu reset | /lbu check on | /lbu check off | /lbu check last | /lbu report")
        end
    end
    inCombat = IsUnitInCombat("player")
    resetMeasurements()
end

EVENT_MANAGER:RegisterForEvent(NAME, EVENT_ADD_ON_LOADED, loaded)
