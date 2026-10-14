local NAME = "LiveBuffUptime"
local TITLE = "LiveBuffUptime"
local Meter = LiveBuffUptimeMeter
local Group = LiveBuffUptimeGroup
local Cooldowns = LiveBuffUptimeCooldowns
local LiveUptime = LiveBuffUptimeEngine
local liveUptimeMode, liveUptimeFight, liveUptimePlayerId, liveUptimeTargetId = false, nil, nil, nil
local wm = WINDOW_MANAGER
local settings, panel
local settingsSections = {}
local trackers = {}
local enabledTrackers = {}
local inCombat = false
local fightEndedAt
local fightStartedAt, activeStartedAt, finalDuration
local fightRole
local lastActiveAt
local useLibCombat = false
local LibCombat
local Performance = LiveBuffUptimePerformance
local BuffDebug = LiveBuffUptimeBuffDebug
local BuffReports = LiveBuffUptimeReports
local function beginBuffDebug(time)
    if not BuffDebug or not BuffDebug.active then return end
    BuffDebug.BeginFight(time)
    if not BuffDebug.IsGroup() then
        for index = 1, GetNumBuffs("player") do
            local _, _, ends, slot, _, _, _, _, _, _, ability = GetUnitBuffInfo("player", index)
            if ability then BuffDebug.Snapshot(ability, ends, slot) end
        end
    end
end
local function measured(category, callback)
    return Performance and Performance.Wrap(category, callback) or callback
end
local function registerESOEvent(owner, event, callback)
    EVENT_MANAGER:RegisterForEvent(owner, event, measured("ESO-Ereignisse", callback))
end
local function registerCombatEvent(owner, event, callback)
    LibCombat:RegisterForCombatEvent(owner, event, measured("Bibliotheks-Ereignisse", callback))
end
local libraryStatusReason
local libraryFightClosed = false
local abilityNameCache = {}
local groupEffects = {}
local unlocked = false
local moveOverlay, selectedTracker
local previousUIMode, previousCameraMode, lastMoveInputAt, moveLastX, moveLastY
local moveDragging = false
local draftId = ""
local draftUnit = "player"
local refreshSettings, update, setUnlocked, selectTracker
local seedGroupTimers
local defaults = { combatOnly = false, nextKey = 1, trackers = {} }
local unitNames = { player = "Auf mir", reticleover = "Auf dem Gegner", group = "Auf der Gruppe", dds = "Nur DDs" }
local unitItems = {
    { name = unitNames.player, data = "player" },
    { name = unitNames.group, data = "group" },
    { name = unitNames.dds, data = "dds" },
}
local function unitLabel(config)
    return unitNames[config.unit == "group" and config.groupRole == "damage" and "dds" or config.unit]
end
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
        if tracker.config.enabled ~= false then
            LiveUptime.Seed(liveUptimeFight, tracker, now, matches)
            if seedGroupTimers then seedGroupTimers(tracker, now) end
        end
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
    if IsUnitGrouped and not IsUnitGrouped("player") then count = 0 end
    for index = 1, math.max(1, count) do
        local tag = count == 0 and "player" or (GetGroupUnitTagByIndex and GetGroupUnitTagByIndex(index) or "group" .. index)
        if tag and DoesUnitExist(tag) then
            local online = not IsUnitOnline or IsUnitOnline(tag)
            local sameZone = not GetUnitZoneIndex or GetUnitZoneIndex(tag) == playerZone
            local dead = IsUnitDeadOrReincarnating and IsUnitDeadOrReincarnating(tag) or IsUnitDead(tag)
            local isPlayer = tag == "player" or (AreUnitsEqual and AreUnitsEqual(tag, "player"))
            local role = isPlayer and GetSelectedLFGRole and GetSelectedLFGRole()
                or GetGroupMemberSelectedRole and GetGroupMemberSelectedRole(tag)
            if role ~= LFG_ROLE_DPS and role ~= LFG_ROLE_TANK and role ~= LFG_ROLE_HEAL then role = nil end
            roster[#roster + 1] = { tag = tag, key = groupMemberKey(tag), eligible = online and sameZone and not dead,
                inCombat = online and sameZone and IsUnitInCombat(tag), role = role, dead = dead, available = online and sameZone }
        end
    end
    return roster
end

local function bindGroupId(key, id)
    local member = liveUptimeFight and liveUptimeFight.groupMembers and liveUptimeFight.groupMembers[key]
    if not member or not id or member.id == id then return end
    for _, tracker in ipairs(enabledTrackers) do
        if tracker.config.unit == "group" and tracker.liveUptimeUnits then
            local previous = member.id or key
            local unit = liveUptimeFight.units[previous]
            if tracker.liveUptimeUnits[previous] and not (unit and LiveUptime.IsPet(unit.kind)) then
                tracker.liveUptimeUnits[id] = LiveUptime.MergeUnits(tracker.liveUptimeUnits[previous], tracker.liveUptimeUnits[id])
            end
            tracker.liveUptimeUnits[previous] = nil
        end
    end
    member.id = id
end

local function syncGroupRoster(roster, now)
    if not liveUptimeMode or not inCombat or not liveUptimeFight or not liveUptimeFight.running then return end
    local present = {}
    for _, entry in ipairs(roster) do
        present[entry.key] = true
        local previous = liveUptimeFight.groupMembers and liveUptimeFight.groupMembers[entry.key]
        local wasAlive = previous and previous.aliveSince ~= nil
        local id = LibCombat and LibCombat.GetUnitIdByTag and LibCombat.GetUnitIdByTag(entry.tag)
        if entry.tag == "player" or (AreUnitsEqual and AreUnitsEqual(entry.tag, "player")) then
            id = liveUptimePlayerId or (LibCombat and LibCombat.GetPlayerUnitId and LibCombat.GetPlayerUnitId()) or id
        end
        bindGroupId(entry.key, id)
        local member = LiveUptime.GroupMember(liveUptimeFight, entry.key, id, now, entry.eligible,
            GetUnitName and GetUnitName(entry.tag) or entry.key)
        member.isPlayer = entry.tag == "player" or (AreUnitsEqual and AreUnitsEqual(entry.tag, "player")) or false
        member.role = member.role or entry.role
        local dataId = member.id or entry.key
        if wasAlive ~= entry.eligible then
            for _, tracker in ipairs(enabledTrackers) do
                if tracker.config.unit == "group" then
                    local data = tracker.liveUptimeUnits and tracker.liveUptimeUnits[dataId]
                    local slots = {}
                    for slot, effect in pairs(previous and data and data.slots or {}) do slots[#slots + 1] = { slot, effect.ability } end
                    for _, effect in ipairs(slots) do
                        LiveUptime.Effect(liveUptimeFight, tracker, now, dataId, effect[2], effect[1], false, false, 1)
                    end
                    if entry.eligible and GetNumBuffs and GetUnitBuffInfo then
                        for index = 1, GetNumBuffs(entry.tag) do
                            local _, _, ends, slot, stacks, _, _, _, _, _, ability, _, own = GetUnitBuffInfo(entry.tag, index)
                            if ability and slot and matches(tracker.config, ability) then
                                LiveUptime.Effect(liveUptimeFight, tracker, now, dataId, ability, slot, true, own, stacks,
                                    own and COMBAT_UNIT_TYPE_PLAYER or COMBAT_UNIT_TYPE_NONE, ends)
                            end
                        end
                    end
                end
            end
        end
    end
    for key, member in pairs(liveUptimeFight.groupMembers or {}) do
        if not present[key] then LiveUptime.GroupMember(liveUptimeFight, key, member.id, now, false) end
    end
end

seedGroupTimers = function(tracker, now)
    if tracker.config.unit ~= "group" or not liveUptimeFight or not liveUptimeFight.running then return end
    for _, entry in ipairs(groupRoster()) do
        if entry.eligible then
            local member = liveUptimeFight.groupMembers and liveUptimeFight.groupMembers[entry.key]
            local id = member and member.id or (LibCombat and LibCombat.GetUnitIdByTag and LibCombat.GetUnitIdByTag(entry.tag)) or entry.key
            for index = 1, GetNumBuffs(entry.tag) do
                local _, _, ends, slot, stacks, _, _, _, _, _, ability, _, own = GetUnitBuffInfo(entry.tag, index)
                if ability and slot and matches(tracker.config, ability) then
                    LiveUptime.Effect(liveUptimeFight, tracker, now, id, ability, slot, true, own, stacks,
                        own and COMBAT_UNIT_TYPE_PLAYER or COMBAT_UNIT_TYPE_NONE, ends)
                end
            end
        end
    end
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

local function createTracker(config)
    config.includePets = nil
    config.buffSource = nil
    config.personalTime, config.uptimeMetric = "auto", "time"
    config.view, config.includeOverheal = nil, nil
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
        local text = displayName(config.id) .. " | " .. unitLabel(config) .. " | ID " .. config.id
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
            syncGroupRoster(roster, now)
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
    if BuffReports and inCombat then
        local dead = IsUnitDeadOrReincarnating and IsUnitDeadOrReincarnating("player") or IsUnitDead("player")
        BuffReports.ObserveDeathRoster(roster, now, groupMemberKey("player"), dead)
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
                observations[#observations + 1] = { key = member.key, eligible = member.eligible
                    and (tracker.config.groupRole ~= "damage" or (LFG_ROLE_DPS ~= nil and member.role == LFG_ROLE_DPS)),
                    effect = findEffect(tracker.config, snapshots[member.tag]), excluded = excluded }
            end
            local window
            if EVENT_COMBAT_EVENT then
                if groupCombat and not tracker.group.running and (tracker.group.lastDamageAt or -math.huge) < now then
                    tracker.group.firstDamageAt, tracker.group.lastDamageAt = nil, nil
                end
                window = { starts = tracker.group.firstDamageAt or now, ends = tracker.group.lastDamageAt or now }
            end
            -- Solo fallback uses the same action window as the personal tracker.
            if not liveUptimeMode and #roster == 1 and (roster[1].tag == "player"
                or (AreUnitsEqual and AreUnitsEqual(roster[1].tag, "player"))
                or roster[1].key == groupMemberKey("player")) then
                local first = math.max(tracker.state.since, activeStartedAt or fightStartedAt or tracker.state.since)
                local last = inCombat and (lastActiveAt or (not EVENT_COMBAT_EVENT and not useLibCombat and now)) or fightEndedAt
                window = { starts = first, ends = last or first }
            end
            effect = Group.Update(tracker.group, observations, now, groupCombat, window, sampleOnly or liveUptimeMode)
            if not liveUptimeMode then tracker.group.measurementWindow = window end
            for _, member in ipairs(roster) do
                local recorded = tracker.group.members[member.key]
                if recorded then recorded.role = recorded.role or member.role end
            end
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
    if LibCombat and LibCombat.CancelPending then LibCombat.CancelPending() end
    local now = type(at) == "number" and at or nowSeconds()
    fightRole = GetSelectedLFGRole and GetSelectedLFGRole()
    if BuffReports then BuffReports.BeginEncounter(now, inCombat, groupMemberKey("player")) end
    libraryFightClosed = false
    fightEndedAt = nil
    finalDuration = nil
    fightStartedAt = inCombat and now or nil
    activeStartedAt = nil
    lastActiveAt = nil
    if liveUptimeMode then
        liveUptimeFight = LiveUptime.New(now)
        liveUptimeFight.personalRole = fightRole
        liveUptimeFight.personalBasis = LibCombat and LibCombat.name == "LibCombat2" and "alive" or "combat"
        if IsUnitDead and IsUnitDead("player") then LiveUptime.PlayerAlive(liveUptimeFight, now, false) end
        liveUptimeTargetId = nil
    end
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

local function captureFallbackReport()
    if BuffReports then
        BuffReports.CaptureFallback(enabledTrackers, activeStartedAt or fightStartedAt, fightEndedAt,
            finalDuration, useLibCombat, displayName, groupRoster(), function(tracker)
                return cooldownProfile(tracker.config) and tracker.config.excludeCooldown ~= false
            end, fightRole)
    end
end

local function combatChanged(_, value)
    if useLibCombat then return end
    if value == inCombat then return end
    if value then
        inCombat = true
        resetMeasurements(nil, true)
        beginBuffDebug(nowSeconds())
    else
        update()
        fightEndedAt = lastActiveAt or (not EVENT_COMBAT_EVENT and nowSeconds())
        inCombat = false
        update()
        captureFallbackReport()
        if BuffDebug and BuffDebug.active then BuffDebug.EndFight(fightEndedAt or nowSeconds()) end
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
        if matches(config, id) and config.unit == (draftUnit == "dds" and "group" or draftUnit)
            and (config.groupRole == "damage") == (draftUnit == "dds") then
            d(TITLE .. ": Dieser Effekt wird fuer diese Einheit bereits angezeigt.")
            return
        end
    end
    local count = #settings.trackers
    local config = {
        key = settings.nextKey, id = id, unit = draftUnit == "dds" and "group" or draftUnit,
        groupRole = draftUnit == "dds" and "damage" or nil, scale = 1,
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
        { type = lib.ST_BUTTON, label = "Kampfstatistiken", buttonText = "Kampfbericht oeffnen",
          clickHandler = function()
              if unlocked then setUnlocked(false) end
              if BuffReports then BuffReports.Open() end
          end },
        { type = lib.ST_CHECKBOX, label = "Nur im Kampf anzeigen",
          getFunction = function() return settings.combatOnly end,
          setFunction = function(value) settings.combatOnly = value; update() end },
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
            label = displayName(config.id) .. " (" .. config.id .. ") - " .. unitLabel(config) }
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
            tooltip = "Auf mir: persoenlich. Gruppe: alle Mitglieder. Nur DDs: Spieler mit ausgewaehlter Schadensrolle, auch ohne Buff.",
            getFunction = function() return unitLabel(config) end,
            setFunction = function(_, _, entry)
                config.unit = entry.data == "dds" and "group" or entry.data
                config.groupRole = entry.data == "dds" and "damage" or nil
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
    return (LibCombat and (LibCombat["LIBCOMBAT_" .. name] or LibCombat[name])) or _G["LIBCOMBAT_" .. name]
end

local function libTime(timeMS)
    -- LibCombat uses the game clock; buff durations use the frame clock.
    return nowSeconds() + (timeMS - GetGameTimeMilliseconds()) / 1000
end

local function startLibraryFight(time)
    if inCombat then return end
    inCombat = true
    resetMeasurements(time, true)
    beginBuffDebug(time)
    if LibCombat and LibCombat.GetTargetUnitId then liveUptimeTargetId = LibCombat.GetTargetUnitId() end
end

local function registerLibCombat()
    if useLibCombat then return end
    local bridge = LiveBuffUptimeCombatBridge
    local adapted
    local preferPC = IsConsoleUI and not IsConsoleUI() and _G.LibCombat
    if bridge and not preferPC then adapted, libraryStatusReason = bridge.Create(_G.LibCombat2) end
    LibCombat = adapted or _G.LibCombat
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
        if LibCombat.EVENT_ENCOUNTER_DAMAGE then
            registerCombatEvent(NAME, LibCombat.EVENT_ENCOUNTER_DAMAGE, function(_, timeMS)
                if inCombat and not libraryFightClosed then LiveUptime.EncounterDamage(liveUptimeFight, libTime(timeMS)) end
            end)
        end
        registerCombatEvent(NAME, libConstant("EVENT_MESSAGES"), function(_, timeMS, message)
            if message == libConstant("MESSAGE_COMBATSTART") then
                if LibCombat.IsContinuation and not LibCombat.IsContinuation() then inCombat = false end
                startLibraryFight(libTime(timeMS))
            end
        end)
        for _, name in ipairs(liveUptimeEvents) do
            local eventName = name
            if string.find(name, "EFFECTS") then
                registerCombatEvent(NAME, libConstant(name), function(_, timeMS, unitId, id, changeType, _, stacks, sourceType, slot)
                    if libraryFightClosed then
                        return
                    end
                    if not inCombat or not liveUptimeFight or not unitId or not slot then return end
                    if changeType ~= EFFECT_RESULT_GAINED and changeType ~= EFFECT_RESULT_UPDATED and changeType ~= EFFECT_RESULT_FADED then return end
                    local time = libTime(timeMS)
                    local unit = LiveUptime.Touch(liveUptimeFight, unitId, time)
                    if LibCombat.GetUnitType and unit then unit.kind = LibCombat.GetUnitType(unitId) or unit.kind end
                    if not unit then return end
                    if eventName == "EVENT_EFFECTS_IN" and not LiveUptime.IsPet(unit.kind) then
                        -- v1 EFFECTS_IN includes playerpet tags; it is not proof of player identity.
                        if not liveUptimePlayerId then liveUptimePlayerId = unitId end
                        if unitId == liveUptimePlayerId then unit.player, unit.kind = true, COMBAT_UNIT_TYPE_PLAYER end
                    elseif eventName == "EVENT_GROUPEFFECTS_IN" then
                        unit.kind = unit.kind or COMBAT_UNIT_TYPE_GROUP
                    end
                    LiveUptime.Kind(liveUptimeFight, unitId, unit.kind)
                    if unitId == liveUptimePlayerId and not LiveUptime.IsPet(unit.kind) then
                        for key, member in pairs(liveUptimeFight.groupMembers or {}) do
                            if member.isPlayer then bindGroupId(key, unitId) end
                        end
                    end
                    local own = sourceType == COMBAT_UNIT_TYPE_PLAYER
                    LiveUptime.Remember(unit, id, slot, changeType ~= EFFECT_RESULT_FADED, own, stacks, sourceType)
                    for _, tracker in ipairs(enabledTrackers) do
                        local groupDead = false
                        if tracker.config.unit == "group" then
                            for _, member in pairs(liveUptimeFight.groupMembers or {}) do
                                if member.id == unitId and not member.aliveSince then groupDead = true; break end
                            end
                        end
                        if matches(tracker.config, id) and not groupDead and not (unitId == liveUptimePlayerId and not liveUptimeFight.aliveSince
                            and tracker.config.unit == "player" and LiveUptime.PersonalBasis(liveUptimeFight, tracker.config) == "alive") then
                            LiveUptime.Effect(liveUptimeFight, tracker, time, unitId, id, slot, changeType ~= EFFECT_RESULT_FADED, own, stacks, sourceType)
                        end
                    end
                end)
            else
                registerCombatEvent(NAME, libConstant(name), function(_, timeMS, _, source, target, _, value, _, overflow)
                    if libraryFightClosed then
                        return
                    end
                    local time = libTime(timeMS)
                    startLibraryFight(time)
                    if LibCombat.GetUnitType then
                        LiveUptime.Kind(liveUptimeFight, source, LibCombat.GetUnitType(source))
                        LiveUptime.Kind(liveUptimeFight, target, LibCombat.GetUnitType(target))
                        liveUptimePlayerId = LibCombat.GetPlayerUnitId() or liveUptimePlayerId
                    end
                    LiveUptime.Action(liveUptimeFight, eventName, time, source, target, value, overflow)
                    -- SELF can involve pets as well; never infer player identity from its target.
                    activeStartedAt, lastActiveAt = liveUptimeFight.starts, liveUptimeFight.ends
                end)
            end
        end
        registerCombatEvent(NAME, libConstant("EVENT_FIGHTSUMMARY"), function(_, fight)
            if not inCombat or not fight or not liveUptimeFight then return end
            local confirmedId = fight.playerid or (LibCombat.GetPlayerUnitId and LibCombat.GetPlayerUnitId())
            if confirmedId then
                liveUptimePlayerId = confirmedId
                for key, member in pairs(liveUptimeFight.groupMembers or {}) do
                    if member.isPlayer then bindGroupId(key, confirmedId) end
                end
            end
            for _, tracker in ipairs(enabledTrackers) do
                LiveUptime.Expire(liveUptimeFight, tracker, liveUptimeFight.encounterEnds)
            end
            LiveUptime.Finish(liveUptimeFight, fight, libTime)
            libraryFightClosed = true
            local current = liveUptimePlayerId and liveUptimeFight.units[liveUptimePlayerId]
            if not confirmedId and (not current or current.kind ~= COMBAT_UNIT_TYPE_PLAYER) then
                for id, unit in pairs(liveUptimeFight.units) do
                    if unit.kind == COMBAT_UNIT_TYPE_PLAYER then liveUptimePlayerId = id; break end
                end
            end
            for id, unit in pairs(liveUptimeFight.units) do
                unit.player = id == liveUptimePlayerId and not LiveUptime.IsPet(unit.kind)
            end
            fightStartedAt, activeStartedAt, fightEndedAt = liveUptimeFight.starts, liveUptimeFight.starts, liveUptimeFight.ends
            finalDuration = liveUptimeFight.starts and liveUptimeFight.ends and math.max(1, liveUptimeFight.ends - liveUptimeFight.starts) or nil
            inCombat = false
            update()
            if BuffReports then BuffReports.Capture(liveUptimeFight, enabledTrackers, liveUptimePlayerId, liveUptimeTargetId, displayName) end
            if BuffDebug and BuffDebug.active then
                BuffDebug.EndFight(liveUptimeFight.encounterEnds or liveUptimeFight.ends or nowSeconds())
            end
        end)
        return
    end
    registerCombatEvent(NAME, libConstant("EVENT_MESSAGES"), function(_, timeMS, message)
        if message == libConstant("MESSAGE_COMBATSTART") then startLibraryFight(libTime(timeMS)) end
    end)
    local function action(_, timeMS)
        local time = libTime(timeMS)
        startLibraryFight(time)
        activeStartedAt = math.min(activeStartedAt or time, time)
        lastActiveAt = math.max(lastActiveAt or time, time)
    end
    for _, event in ipairs({ "EVENT_DAMAGE_OUT", "EVENT_DAMAGE_SELF" }) do
        registerCombatEvent(NAME, libConstant(event), action)
    end
    registerCombatEvent(NAME, libConstant("EVENT_EFFECTS_IN"), function(_, timeMS, unitId, id, changeType, _, _, _, slot)
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
    registerCombatEvent(NAME, libConstant("EVENT_FIGHTSUMMARY"), function(_, fight)
        if not inCombat or not fight then return end
        local starts = activeStartedAt
        local ends = lastActiveAt
        if not starts or not ends or ends <= starts then
            inCombat = false
            resetMeasurements(nil, true)
            if BuffDebug and BuffDebug.active then BuffDebug.EndFight(nowSeconds()) end
            return
        end
        update()
        fightStartedAt, activeStartedAt, fightEndedAt = starts, starts, ends
        finalDuration = math.max(1, ends - starts)
        for _, tracker in ipairs(enabledTrackers) do tracker.scope = Meter.RebuildScope(tracker.scope) end
        inCombat = false
        update()
        captureFallbackReport()
        if BuffDebug and BuffDebug.active then BuffDebug.EndFight(ends or nowSeconds()) end
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

local function groupCombatEffect(result, ability, targetId, sourceType, hitValue)
    if not ability or not targetId or libraryFightClosed or not liveUptimeFight.running then return end
    if result ~= ACTION_RESULT_EFFECT_GAINED_DURATION and result ~= ACTION_RESULT_EFFECT_GAINED
        and result ~= ACTION_RESULT_EFFECT_FADED then return end
    local recipient
    for _, member in pairs(liveUptimeFight.groupMembers or {}) do
        if member.id == targetId and member.aliveSince then recipient = member; break end
    end
    if not recipient then return end
    local now = nowSeconds()
    local slot = "combat:" .. ability
    for _, tracker in ipairs(enabledTrackers) do
        if tracker.config.unit == "group" and matches(tracker.config, ability) then
            LiveUptime.Expire(liveUptimeFight, tracker, now)
            local data = tracker.liveUptimeUnits and tracker.liveUptimeUnits[targetId]
            local previous = data and data.slots[slot]
            local standard = false
            for key, effect in pairs(data and data.slots or {}) do
                if type(key) ~= "string" or not key:match("^combat:") then
                    if matches(tracker.config, effect.ability) then standard = true; break end
                end
            end
            if result == ACTION_RESULT_EFFECT_FADED then
                if previous then LiveUptime.Effect(liveUptimeFight, tracker, now, targetId, ability, slot, false, false, 1) end
            elseif not standard then
                local duration = result == ACTION_RESULT_EFFECT_GAINED_DURATION and type(hitValue) == "number" and hitValue > 0 and hitValue / 1000
                    or result == ACTION_RESULT_EFFECT_GAINED and hitValue == 1 and previous and previous.duration
                if duration then
                    LiveUptime.Effect(liveUptimeFight, tracker, now, targetId, ability, slot, true,
                        sourceType == COMBAT_UNIT_TYPE_PLAYER, 1, sourceType, now + duration)
                    local effect = tracker.liveUptimeUnits[targetId].slots[slot]
                    if effect then effect.duration = duration end
                end
            end
        end
    end
end

local function combatActivity(_, result, isError, _, _, _, _, sourceType, targetName, targetType, hitValue, _, _, _, sourceId, targetId, ability)
    if liveUptimeMode then
        if isError or not inCombat or not liveUptimeFight then return end
        if damageResults[result] then LiveUptime.EncounterDamage(liveUptimeFight, nowSeconds()) end
        if damageResults[result] and BuffReports then BuffReports.RecordDamage(sourceType, targetType, targetId, targetName, hitValue) end
        LiveUptime.Kind(liveUptimeFight, sourceId, sourceType)
        LiveUptime.Kind(liveUptimeFight, targetId, targetType)
        if sourceType == COMBAT_UNIT_TYPE_PLAYER then liveUptimePlayerId = sourceId or liveUptimePlayerId end
        if targetType == COMBAT_UNIT_TYPE_PLAYER then liveUptimePlayerId = targetId or liveUptimePlayerId end
        groupCombatEffect(result, ability, targetId, sourceType, hitValue)
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
    if inCombat and BuffReports then BuffReports.RecordDamage(sourceType, targetType, targetId, targetName, hitValue) end
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
    if BuffReports then BuffReports.Init(settings) end
    settings.fps = nil
    settings.checkUptime, settings.lastCheck, settings.lastFights = nil, nil, nil
    createMoveUI()
    for _, config in ipairs(settings.trackers) do createTracker(config) end
    panel = LibHarvensAddonSettings:AddAddon(TITLE, { allowRefresh = true })
    registerLibCombat()
    if not useLibCombat then d(TITLE .. ": LibCombat2 (Konsole) oder LibCombat (PC) fehlt bzw. ist inkompatibel. Nur Ersatzmessung aktiv.") end
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
    registerESOEvent(NAME, EVENT_PLAYER_COMBAT_STATE, combatChanged)
    if EVENT_COMBAT_EVENT then
        registerESOEvent(NAME .. "CombatTiming", EVENT_COMBAT_EVENT, combatActivity)
        for _, profile in ipairs(Cooldowns.profiles) do
            for _, id in ipairs(profile.ids or {profile.id}) do
                local eventName = NAME .. "Cooldown" .. id
                registerESOEvent(eventName, EVENT_COMBAT_EVENT, cooldownCombatEvent)
                if EVENT_MANAGER.AddFilterForEvent and REGISTER_FILTER_ABILITY_ID then
                    EVENT_MANAGER:AddFilterForEvent(eventName, EVENT_COMBAT_EVENT, REGISTER_FILTER_ABILITY_ID, id)
                end
            end
        end
    end
    registerESOEvent(NAME, EVENT_RETICLE_TARGET_CHANGED, function()
        if liveUptimeMode then liveUptimeTargetId = nil end
        update(true, true)
    end)
    if EVENT_UNIT_DEATH_STATE_CHANGED then
        registerESOEvent(NAME, EVENT_UNIT_DEATH_STATE_CHANGED, function(_, tag, dead)
            if BuffReports and type(tag) == "string" and (tag == "player" or tag:match("^group%d+$")
                or (AreUnitsEqual and AreUnitsEqual(tag, "player"))) then
                BuffReports.ObserveDeath(groupMemberKey(tag), nowSeconds(), dead)
            end
            if liveUptimeMode and inCombat and (tag == "player" or (AreUnitsEqual and AreUnitsEqual(tag, "player"))) then
                local now = nowSeconds()
                if LiveUptime.PlayerAlive(liveUptimeFight, now, not dead) then
                    local unit = liveUptimePlayerId and liveUptimeFight.units[liveUptimePlayerId]
                    if dead then
                        for _, tracker in ipairs(enabledTrackers) do
                            if LiveUptime.PersonalBasis(liveUptimeFight, tracker.config) == "alive" and tracker.config.unit == "player" then
                                local data = tracker.liveUptimeUnits and tracker.liveUptimeUnits[liveUptimePlayerId]
                                local slots = {}
                                for slot, effect in pairs(data and data.slots or {}) do slots[#slots + 1] = { slot, effect.ability } end
                                for _, effect in ipairs(slots) do
                                    LiveUptime.Effect(liveUptimeFight, tracker, now, liveUptimePlayerId, effect[2], effect[1], false, false, 1)
                                end
                            end
                        end
                        if unit then unit.effects = {} end
                    elseif liveUptimePlayerId and GetNumBuffs and GetUnitBuffInfo then
                        for index = 1, GetNumBuffs("player") do
                            local _, _, _, slot, stacks, _, _, effectType, _, _, ability, _, own = GetUnitBuffInfo("player", index)
                            if ability and slot then
                                for _, tracker in ipairs(enabledTrackers) do
                                    if tracker.config.unit == "player" and LiveUptime.PersonalBasis(liveUptimeFight, tracker.config) == "alive"
                                        and matches(tracker.config, ability) then
                                        LiveUptime.Effect(liveUptimeFight, tracker, now, liveUptimePlayerId, ability, slot, true, own, stacks,
                                            own and COMBAT_UNIT_TYPE_PLAYER or COMBAT_UNIT_TYPE_NONE)
                                    end
                                end
                            end
                        end
                    end
                end
            end
            update(nil, true)
        end)
    end
    if EVENT_GROUP_UPDATE then
        registerESOEvent(NAME, EVENT_GROUP_UPDATE, function() update(nil, true) end)
    end
    registerESOEvent(NAME, EVENT_EFFECT_CHANGED, function(_, changeType, slot, _, unitTag, starts, ends, stacks, icon, _, effectType, _, _, unitName, unitId, id, sourceType)
        if type(unitTag) ~= "string" then return end
        if BuffReports and BUFF_EFFECT_TYPE_DEBUFF ~= nil and effectType == BUFF_EFFECT_TYPE_DEBUFF
            and (unitTag:match("^boss%d+$") or (unitTag == "reticleover" and GetUnitReaction
                and UNIT_REACTION_HOSTILE ~= nil and GetUnitReaction(unitTag) == UNIT_REACTION_HOSTILE))
            and (changeType == EFFECT_RESULT_GAINED or changeType == EFFECT_RESULT_UPDATED or changeType == EFFECT_RESULT_FADED) then
            for _, tracker in ipairs(enabledTrackers) do
                if matches(tracker.config, id) then
                    local now = nowSeconds()
                    BuffReports.RecordDebuff(tracker.config.id, unitId, unitName, slot,
                        starts and starts > 0 and changeType == EFFECT_RESULT_GAINED and math.min(starts, now) or now,
                        ends, changeType ~= EFFECT_RESULT_FADED)
                    break
                end
            end
        end
        if BuffDebug and BuffDebug.active and (unitTag == "player" or (AreUnitsEqual and AreUnitsEqual(unitTag, "player"))
            or (BuffDebug.IsGroup() and string.match(unitTag, "^group%d+$"))) then
            local count = 0
            for _, tracker in ipairs(enabledTrackers) do
                if tracker.config.unit ~= "reticleover" and id and matches(tracker.config, id) then count = count + 1 end
            end
            BuffDebug.Raw(id, changeType, slot, starts, ends, unitId, inCombat, count,
                groupMemberKey(unitTag), unitName and unitName ~= "" and unitName or groupMemberKey(unitTag))
        end
        if liveUptimeMode and unitId and liveUptimeFight then
            if inCombat and not libraryFightClosed and (unitTag == "player" or string.match(unitTag, "^group%d+$")) then
                bindGroupId(groupMemberKey(unitTag), unitId)
            end
            local kind = unitTag == "player" and COMBAT_UNIT_TYPE_PLAYER
                or string.match(unitTag, "^group%d+$") and COMBAT_UNIT_TYPE_GROUP
                or string.match(unitTag, "^playerpet%d+$") and COMBAT_UNIT_TYPE_PLAYER_PET
                or unitTag == "companion" and COMBAT_UNIT_TYPE_PLAYER_COMPANION
                or string.match(unitTag, "^group%d+companion$") and COMBAT_UNIT_TYPE_GROUP_COMPANION
            LiveUptime.Kind(liveUptimeFight, unitId, kind)
            if unitTag == "player" then liveUptimePlayerId = unitId end
            if unitTag == "reticleover" then liveUptimeTargetId = unitId end
            if inCombat and not libraryFightClosed and LibCombat and LibCombat.RawEffect
                and (changeType == EFFECT_RESULT_GAINED or changeType == EFFECT_RESULT_UPDATED or changeType == EFFECT_RESULT_FADED) then
                LibCombat.RawEffect(GetGameTimeMilliseconds(), unitId, id, changeType, effectType,
                    math.max(1, stacks or 1), sourceType, slot, kind, unitName)
            end
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
            if liveUptimeMode and inCombat and not libraryFightClosed and liveUptimeFight and liveUptimeFight.running then
                local member = liveUptimeFight.groupMembers and liveUptimeFight.groupMembers[key]
                if member then
                    local dataId = member.id or key
                    for _, tracker in ipairs(enabledTrackers) do
                        if tracker.config.unit == "group" and matches(tracker.config, id)
                            and (changeType == EFFECT_RESULT_GAINED or changeType == EFFECT_RESULT_UPDATED or changeType == EFFECT_RESULT_FADED) then
                            local data = tracker.liveUptimeUnits and tracker.liveUptimeUnits[dataId]
                            local fallbackSlots = {}
                            if changeType ~= EFFECT_RESULT_FADED then
                                for key, effect in pairs(data and data.slots or {}) do
                                    if type(key) == "string" and key:match("^combat:") and matches(tracker.config, effect.ability) then
                                        fallbackSlots[#fallbackSlots + 1] = { key, effect.ability }
                                    end
                                end
                            end
                            for _, fallback in ipairs(fallbackSlots) do
                                LiveUptime.Effect(liveUptimeFight, tracker, nowSeconds(), dataId, fallback[2], fallback[1], false, false, 1)
                            end
                            LiveUptime.Effect(liveUptimeFight, tracker, nowSeconds(), dataId, id, slot,
                                changeType ~= EFFECT_RESULT_FADED, isOwnProc(nil, sourceType), stacks, sourceType, ends)
                        end
                    end
                end
            end
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
    registerESOEvent(NAME, EVENT_PLAYER_ACTIVATED, function()
        if not inCombat then registerLibCombat() end
        inCombat = IsUnitInCombat("player")
        resetMeasurements()
    end)
    EVENT_MANAGER:RegisterForUpdate(NAME, 100, measured("Live-Update", function()
        if LibCombat and LibCombat.Poll then LibCombat.Poll() end
        update()
    end))
    SLASH_COMMANDS["/lbu"] = function(command)
        local groupDebugId = command:match("^buffdebug group%s+(%d+)$")
        local quickId = command:match("^buffdebug%s+(%d+)$")
        local debugId = command:match("^buffdebug start%s+(%d+)$")
        if command == "uptime" and BuffReports then
            if unlocked then setUnlocked(false) end
            BuffReports.Open()
        elseif (command == "buffdebug start" or debugId or quickId or groupDebugId) and BuffDebug then
            local id = tonumber(groupDebugId or quickId or debugId)
            if not id then
                for _, tracker in ipairs(enabledTrackers) do
                    if tracker.config.unit ~= "reticleover" then id = tracker.config.id; break end
                end
            end
            if not id or id <= 0 then
                d("LBU Buff-Debug: Bitte eine Effekt-ID angeben, z.B. /lbu buffdebug start 61771")
                return
            end
            if (quickId or groupDebugId) and BuffDebug.IsRecording(id, groupDebugId ~= nil) then
                BuffDebug.Report(true)
                return
            end
            local groupProvider
            if groupDebugId then
                local found = false
                for _, tracker in ipairs(enabledTrackers) do
                    if tracker.config.unit == "group" and matches(tracker.config, id) then found = true; break end
                end
                if not found or not liveUptimeMode then
                    d("LBU Gruppen-Debug: Fuer diese ID einen aktiven Gruppentracker mit Live-Uptime einrichten.")
                    return
                end
                groupProvider = function()
                    update()
                    if not liveUptimeFight or not liveUptimeFight.groupMembers then return nil, "Noch keine Gruppen-Kampfwerte vorhanden." end
                    for _, tracker in ipairs(enabledTrackers) do
                        if tracker.config.unit == "group" and matches(tracker.config, id) then
                            local result = LiveUptime.Calculate(liveUptimeFight, tracker, liveUptimePlayerId, liveUptimeTargetId, true)
                            if result.truncated then return nil, "Einzelbericht unvollstaendig; keine verlaessliche Summenpruefung moeglich." end
                            local members = {}
                            for key, member in pairs(liveUptimeFight.groupMembers) do
                                if tracker.config.groupRole ~= "damage" or (LFG_ROLE_DPS ~= nil and member.role == LFG_ROLE_DPS) then
                                local covered, duration = 0, 0
                                for _, row in ipairs(result.members) do
                                    if row.id == (member.id or key) then
                                        duration = 0
                                        for _, window in ipairs(row.eligibility or {}) do
                                            duration = duration + window[2] - window[1]
                                            local intervals = {}
                                            for _, interval in ipairs(row.intervals or {}) do
                                                intervals[#intervals + 1] = { interval[1], interval[2] }
                                            end
                                            if row.open then intervals[#intervals + 1] = { row.open, row.ends } end
                                            table.sort(intervals, function(a, b) return a[1] < b[1] end)
                                            local last = window[1]
                                            for _, interval in ipairs(intervals) do
                                                local first, ending = math.max(last, window[1], interval[1]), math.min(window[2], interval[2])
                                                if ending > first then covered = covered + ending - first; last = ending end
                                            end
                                        end
                                        break
                                    end
                                end
                                members[#members + 1] = { key = key, name = member.name or key, covered = covered, duration = duration }
                                end
                            end
                            table.sort(members, function(a, b) return a.name < b.name end)
                            return { members = members, starts = result.starts or liveUptimeFight.combatstart,
                                hud = tracker.liveUptimeResult and tracker.liveUptimeResult.percent or result.percent }
                        end
                    end
                    return nil, "Passender Gruppentracker wurde deaktiviert oder entfernt."
                end
            end
            BuffDebug.Start(id, function(ability) return ability and matches({ id = id }, ability) end,
                function(fight, unitId)
                    if not unitId then return false end
                    if unitId == liveUptimePlayerId then return true end
                    for key, member in pairs(fight and fight.groupMembers or {}) do
                        if (groupDebugId or member.isPlayer) and (member.id == unitId or key == unitId) then return true end
                    end
                    return false
                end, quickId ~= nil or groupDebugId ~= nil, groupProvider)
            if inCombat then beginBuffDebug(nowSeconds()) end
        elseif (command == "buffdebug stop" or command == "buffdebug off") and BuffDebug then
            BuffDebug.Stop()
        elseif command == "buffdebug report" and BuffDebug then
            BuffDebug.Report()
        elseif command == "perf start" and Performance then
            local ok, reason = Performance.Start()
            d(ok and "LiveBuffUptime: Performance-Debug gestartet. Beenden mit /lbu perf stop."
                or ("LiveBuffUptime: " .. reason))
        elseif command == "perf stop" and Performance then
            Performance.Stop()
            Performance.Report()
        elseif command == "perf report" and Performance then
            Performance.Report()
        elseif command == "status" then
            local v2 = _G.LibCombat2
            d(string.format("%s Status: LibCombat2 %s Version %s | Anbindung %s | Live-Modus %s | Kampf %s",
                TITLE, v2 and "geladen" or "fehlt", tostring(v2 and v2.version or "unbekannt"),
                useLibCombat and (LibCombat.name or "LibCombat") or "nicht verbunden", liveUptimeMode and "ja" or "nein", inCombat and "ja" or "nein"))
            if libraryStatusReason and not (LibCombat and LibCombat.GetStatus) then d("LibCombat2-Pruefung: " .. libraryStatusReason) end
            if LibCombat and LibCombat.GetStatus then
                local state = LibCombat.GetStatus()
                d(string.format("LibCombat2: %d Registrierungen, %d abgelehnt | Start/Status %d | Schaden %d | Heilung %d | Effekte %d | Abschluss %d",
                    state.registered, state.registrationFailures, state.state, state.damage, state.heal, state.effect, state.summary))
                d(string.format("Weitergeleitet %d | Aktionen ohne eigene Zuordnung %d | Callback-Fehler %d | Spieler-ID %s",
                    state.dispatched, state.unclassified, state.errors, tostring(liveUptimePlayerId)))
                d(string.format("Direkte ESO-Effekte %d | Doppelmeldungen ignoriert %d | Einheiten-Limit %d",
                    state.rawEffects, state.duplicateEffects, state.rawUnitsOmitted))
                d(string.format("Boss-Fortsetzungen %d | Abschluesse zurueckgestellt %d | Boss-Pause %s | Fortsetzungs-Limit %d",
                    state.continuedSegments, state.deferredSummaries, state.pendingBoss and "ja" or "nein", state.encounterUnitsOmitted))
                if state.effect == 0 and state.rawEffects == 0 and state.damage > 0 then
                    d("WARN: Keine Effektmeldungen empfangen. Leere Buffdaten bestaetigen keine korrekte Uptime.")
                end
                if state.lastError then d("Letzter Bibliotheksfehler: " .. state.lastError) end
            end
            local result = enabledTrackers[1] and enabledTrackers[1].liveUptimeResult
            d(string.format("Aktive Tracker %d | Erster Tracker: Buff %.2fs / Bezugszeit %.2fs", #enabledTrackers,
                result and result.covered or 0, result and result.duration or 0))
            if enabledTrackers[1] and enabledTrackers[1].config.unit == "player" then
                d("Persoenliche Messbasis: " .. (result and result.personalTime == "alive" and "Lebendzeit (BattleScrolls)"
                    or result and result.personalTime == "unit" and "Einheitenzeit" or "Aktive Kampfzeit (CMX)"))
            end
        elseif command == "move" then
            setUnlocked(not unlocked)
            d(TITLE .. (unlocked and ": Positionen entsperrt. /lbu move sperrt sie wieder." or ": Positionen gesperrt."))
        elseif command == "reset" then
            resetMeasurements()
        else
            d(TITLE .. ": Einstellungen unter Addons. /lbu move | /lbu reset | /lbu status | /lbu perf start | /lbu perf stop | /lbu buffdebug ID | /lbu buffdebug off")
        end
    end
    inCombat = IsUnitInCombat("player")
    resetMeasurements()
end

EVENT_MANAGER:RegisterForEvent(NAME, EVENT_ADD_ON_LOADED, loaded)
