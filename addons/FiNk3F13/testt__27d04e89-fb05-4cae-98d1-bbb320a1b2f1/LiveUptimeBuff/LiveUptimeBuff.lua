local NAME = "LiveUptimeBuff"
local TITLE = "Live Uptime Buff"
local Meter = LiveUptimeBuffMeter
local Group = LiveUptimeBuffGroup
local wm = WINDOW_MANAGER
local settings, panel
local trackers = {}
local inCombat = false
local fightEndedAt
local fightStartedAt, activeStartedAt, finalDuration
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
local defaults = { show = true, combatOnly = false, nextKey = 1, trackers = {} }
local unitNames = { player = "Auf mir", reticleover = "Auf dem Gegner", group = "Auf der Gruppe" }
local unitItems = {
    { name = unitNames.player, data = "player" },
    { name = unitNames.reticleover, data = "reticleover" },
    { name = unitNames.group, data = "group" },
}

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
    if config.id == id then return true end
    local aliases = LiveUptimeBuffAliases or {}
    if (aliases[config.id] or config.id) == (aliases[id] or id) then return true end
    local name = normalizedName(config.id)
    return name and name == normalizedName(id)
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

local function render(tracker, now)
    local state = tracker.state
    local active = state.active and (state.expires == 0 or state.expires > now)
    local remaining = math.max(0, state.expires - now)
    local timer = "--"
    if active then
        if state.expires == 0 then
            timer = "*"
        elseif remaining >= 100 then
            timer = tostring(math.ceil(remaining))
        else
            timer = string.format("%.1f", remaining)
        end
    end
    tracker.timer:SetText(timer)
    tracker.icon:SetColor(active and 1 or 0.4, active and 1 or 0.4, active and 1 or 0.4, 1)
    local measuredUntil = inCombat and now or fightEndedAt
    local starts = math.max(state.since, activeStartedAt or fightStartedAt or state.since)
    local duration = finalDuration
    if duration and fightStartedAt and state.since > fightStartedAt then
        duration = math.min(duration, math.max(1, measuredUntil - starts))
    end
    local percent = 0
    if tracker.config.unit == "group" then
        percent = tracker.group.percent
    elseif measuredUntil then
        if useLibCombat and tracker.config.unit == "player" then
            percent = Meter.ScopePercent(tracker.scope, starts, measuredUntil, duration)
        else
            percent = Meter.Percent(state, measuredUntil, starts, duration)
        end
    end
    tracker.uptime:SetText(string.format("%.1f %%", percent))
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
    tracker.window:SetHidden(not (unlocked or (settings.show and (not settings.combatOnly or showCombat))))
end

local function createTracker(config)
    local tracker = { config = config, state = Meter.New(nowSeconds()), scope = Meter.NewScope(), group = Group.New(nowSeconds()) }
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
    tracker.timer:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    tracker.timer:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    tracker.timer:SetDrawLayer(DL_OVERLAY)
    tracker.uptime = wm:CreateControl(nil, window, CT_LABEL)
    tracker.uptime:SetAnchor(LEFT, tracker.icon, RIGHT, 8, 0)
    tracker.uptime:SetDimensions(108, 48)
    tracker.uptime:SetFont("$(BOLD_FONT)|22|soft-shadow-thick")
    tracker.uptime:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    position(tracker)
    trackers[#trackers + 1] = tracker
    return tracker
end

update = function(targetChanged)
    local now = nowSeconds()
    local snapshots = {}
    local roster, groupCombat
    for _, tracker in ipairs(trackers) do
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
    for _, tracker in ipairs(trackers) do
        local unit = tracker.config.unit
        local effect
        if unit == "group" then
            local observations = {}
            for _, member in ipairs(roster) do
                observations[#observations + 1] = { key = member.key, eligible = member.eligible,
                    effect = findEffect(tracker.config, snapshots[member.tag]) }
            end
            effect = Group.Update(tracker.group, observations, now, groupCombat)
            tracker.state.active = effect ~= nil
            tracker.state.expires = effect and effect.ends or 0
        else
            if not snapshots[unit] then snapshots[unit] = readEffects(unit, now) end
            if targetChanged and unit == "reticleover" then
                Meter.Advance(tracker.state, now, inCombat)
                tracker.state.active = false
            end
            effect = findEffect(tracker.config, snapshots[unit])
            Meter.Observe(tracker.state, effect, now, inCombat, not targetChanged)
        end
        if effect and effect.icon and effect.icon ~= "" then tracker.icon:SetTexture(effect.icon) end
        render(tracker, now)
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
    if value and #trackers == 0 then
        d(TITLE .. ": Bitte zuerst einen Tracker hinzufuegen.")
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
        selectedTracker = selectedTracker or trackers[1]
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
    for _, tracker in ipairs(trackers) do
        tracker.state = Meter.New(now)
        if not preserveGroup then tracker.group = Group.New(now) end
        tracker.scope = Meter.NewScope()
        tracker.prebuff = nil
        if useLibCombat and inCombat and tracker.config.unit == "player" then
            local effect = findEffect(tracker.config, readEffects("player", now))
            if effect then
                tracker.prebuff = "prebuff"
                Meter.ScopeEvent(tracker.scope, tracker.prebuff, now, true)
            end
        end
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
        fightEndedAt = nowSeconds()
        inCombat = false
        update()
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
    if useLibCombat and inCombat and config.unit == "player" then
        local tracker = trackers[#trackers]
        if findEffect(config, readEffects("player", nowSeconds())) then
            tracker.prebuff = "prebuff"
            Meter.ScopeEvent(tracker.scope, tracker.prebuff, nowSeconds(), true)
        end
    end
    update()
    zo_callLater(refreshSettings, 0)
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
    if selectedTracker == tracker then selectTracker(trackers[1]) end
    if #trackers == 0 and unlocked then setUnlocked(false) end
    zo_callLater(refreshSettings, 0)
end

refreshSettings = function()
    local lib = LibHarvensAddonSettings
    local descriptors = {
        { type = lib.ST_CHECKBOX, label = "Anzeige aktiv",
          getFunction = function() return settings.show end,
          setFunction = function(value) settings.show = value; update() end },
        { type = lib.ST_CHECKBOX, label = "Nur im Kampf anzeigen",
          getFunction = function() return settings.combatOnly end,
          setFunction = function(value) settings.combatOnly = value; update() end },
        { type = lib.ST_CHECKBOX, label = "Positionen entsperren",
          tooltip = "Icons mit der Maus verschieben. Alternativ /lub move verwenden.",
          getFunction = function() return unlocked end, setFunction = setUnlocked },
        { type = lib.ST_BUTTON, label = "Move UI", buttonText = "Oeffnen",
          tooltip = "Mit Maus oder rechtem Stick verschieben. Endet nach 3 Sekunden ohne Bewegung.",
          clickHandler = function() setUnlocked(true) end },
        { type = lib.ST_BUTTON, label = "Uptime zuruecksetzen", buttonText = "Zuruecksetzen",
          clickHandler = resetMeasurements },
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
    for _, item in ipairs(trackers) do
        local tracker = item
        local config = tracker.config
        descriptors[#descriptors + 1] = { type = lib.ST_SECTION,
            label = displayName(config.id) .. " (" .. config.id .. ") - " .. unitNames[config.unit] }
        descriptors[#descriptors + 1] = { type = lib.ST_BUTTON, label = "Move UI",
            buttonText = "Icon verschieben",
            tooltip = "Diesen Tracker verschieben. Endet nach 3 Sekunden ohne Bewegung.",
            clickHandler = function() selectTracker(tracker); setUnlocked(true) end }
        descriptors[#descriptors + 1] = { type = lib.ST_DROPDOWN, label = "Einheit", items = unitItems,
            tooltip = "Gruppe: durchschnittliche Uptime lebender Mitglieder in derselben Zone. Tote/Offline zaehlen nicht mit. Ziel: aktueller Gegner.",
            getFunction = function() return unitNames[config.unit] end,
            setFunction = function(_, _, entry)
                config.unit = entry.data
                tracker.state = Meter.New(nowSeconds())
                tracker.group = Group.New(nowSeconds())
                tracker.scope = Meter.NewScope()
                tracker.prebuff = nil
                if useLibCombat and inCombat and config.unit == "player" and findEffect(config, readEffects("player", nowSeconds())) then
                    tracker.prebuff = "prebuff"
                    Meter.ScopeEvent(tracker.scope, tracker.prebuff, nowSeconds(), true)
                end
                update()
            end }
        descriptors[#descriptors + 1] = { type = lib.ST_SLIDER, label = "Groesse",
            min = 0.5, max = 2, step = 0.05,
            getFunction = function() return config.scale end,
            setFunction = function(value) config.scale = value; position(tracker) end }
        descriptors[#descriptors + 1] = { type = lib.ST_SLIDER, label = "Position X",
            min = 0, max = GuiRoot:GetWidth(), step = 1,
            getFunction = function() return config.x end,
            setFunction = function(value) config.x = value; position(tracker) end }
        descriptors[#descriptors + 1] = { type = lib.ST_SLIDER, label = "Position Y",
            min = 0, max = GuiRoot:GetHeight(), step = 1,
            getFunction = function() return config.y end,
            setFunction = function(value) config.y = value; position(tracker) end }
        descriptors[#descriptors + 1] = { type = lib.ST_BUTTON, label = "Tracker entfernen",
            buttonText = "Entfernen", clickHandler = function() removeTracker(tracker) end }
    end
    panel:RemoveAllSettings(false)
    panel:AddSettings(descriptors, nil, false)
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
        "EVENT_HEAL_OUT", "EVENT_HEAL_SELF", "EVENT_EFFECTS_IN", "MESSAGE_COMBATSTART" }) do
        if not libConstant(name) then return end
    end
    useLibCombat = true
    LibCombat:RegisterForCombatEvent(NAME, libConstant("EVENT_MESSAGES"), function(_, timeMS, message)
        if message == libConstant("MESSAGE_COMBATSTART") then startLibraryFight(libTime(timeMS)) end
    end)
    local function action(_, timeMS)
        local time = libTime(timeMS)
        startLibraryFight(time)
        activeStartedAt = activeStartedAt or time
        update()
    end
    for _, event in ipairs({ "EVENT_DAMAGE_OUT", "EVENT_DAMAGE_SELF", "EVENT_HEAL_OUT", "EVENT_HEAL_SELF" }) do
        LibCombat:RegisterForCombatEvent(NAME, libConstant(event), action)
    end
    LibCombat:RegisterForCombatEvent(NAME, libConstant("EVENT_EFFECTS_IN"), function(_, timeMS, unitId, id, changeType, _, _, _, slot)
        if not inCombat then return end
        if changeType ~= EFFECT_RESULT_GAINED and changeType ~= EFFECT_RESULT_UPDATED and changeType ~= EFFECT_RESULT_FADED then return end
        local time = libTime(timeMS)
        local gained = changeType ~= EFFECT_RESULT_FADED
        for _, tracker in ipairs(trackers) do
            if tracker.config.unit == "player" and matches(tracker.config, id) then
                local key = tostring(unitId) .. ":" .. tostring(id) .. ":" .. tostring(slot)
                -- Replace the initial snapshot once authoritative effect events arrive.
                if gained then Meter.ScopeEvent(tracker.scope, key, time, true) end
                if tracker.prebuff then
                    Meter.ScopeEvent(tracker.scope, tracker.prebuff, time, false)
                    tracker.prebuff = nil
                end
                if not gained then Meter.ScopeEvent(tracker.scope, key, time, false) end
            end
        end
        update()
    end)
    LibCombat:RegisterForCombatEvent(NAME, libConstant("EVENT_FIGHTSUMMARY"), function(_, fight)
        if not inCombat or not fight then return end
        local starts = fight.starttime or fight.dpsstart or fight.hpsstart
        local ends = fight.endtime or fight.dpsend or fight.hpsend
        if not starts or not ends or ends <= starts then
            inCombat = false
            resetMeasurements(nil, true)
            return
        end
        update()
        fightStartedAt, activeStartedAt, fightEndedAt = libTime(starts), libTime(starts), libTime(ends)
        local activeDuration = math.max(fight.activetime or 0, fight.dpstime or 0, fight.hpstime or 0)
        finalDuration = math.max(1, activeDuration)
        for _, tracker in ipairs(trackers) do tracker.scope = Meter.RebuildScope(tracker.scope) end
        inCombat = false
        update()
    end)
end

local function loaded(_, addonName)
    if addonName ~= NAME then return end
    EVENT_MANAGER:UnregisterForEvent(NAME, EVENT_ADD_ON_LOADED)
    settings = ZO_SavedVars:NewAccountWide("LiveUptimeBuff_SavedVariables", 1, nil, defaults)
    createMoveUI()
    for _, config in ipairs(settings.trackers) do createTracker(config) end
    panel = LibHarvensAddonSettings:AddAddon(TITLE, { allowRefresh = true })
    registerLibCombat()
    refreshSettings()
    EVENT_MANAGER:RegisterForEvent(NAME, EVENT_PLAYER_COMBAT_STATE, combatChanged)
    EVENT_MANAGER:RegisterForEvent(NAME, EVENT_RETICLE_TARGET_CHANGED, function() update(true) end)
    if EVENT_UNIT_DEATH_STATE_CHANGED then
        EVENT_MANAGER:RegisterForEvent(NAME, EVENT_UNIT_DEATH_STATE_CHANGED, function() update() end)
    end
    if EVENT_GROUP_UPDATE then
        EVENT_MANAGER:RegisterForEvent(NAME, EVENT_GROUP_UPDATE, function() update() end)
    end
    EVENT_MANAGER:RegisterForEvent(NAME, EVENT_EFFECT_CHANGED, function(_, changeType, slot, _, unitTag, starts, ends, _, icon, _, _, _, _, _, _, id)
        if type(unitTag) ~= "string" then return end
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
                for _, tracker in ipairs(trackers) do
                    if tracker.config.unit == "group" and matches(tracker.config, id) then
                        relevantGroupEffect = true
                        groupEffects[key] = cached or {}
                        groupEffects[key][slot] = { id = id, starts = starts or nowSeconds(), ends = ends or 0, icon = icon }
                        break
                    end
                end
            end
        end
        if unitTag == "player" or unitTag == "reticleover" or relevantGroupEffect then update() end
    end)
    EVENT_MANAGER:RegisterForEvent(NAME, EVENT_PLAYER_ACTIVATED, function()
        if not inCombat then registerLibCombat() end
        inCombat = IsUnitInCombat("player")
        resetMeasurements()
    end)
    EVENT_MANAGER:RegisterForUpdate(NAME, 100, function() update() end)
    SLASH_COMMANDS["/lub"] = function(command)
        if command == "move" then
            setUnlocked(not unlocked)
            d(TITLE .. (unlocked and ": Positionen entsperrt. /lub move sperrt sie wieder." or ": Positionen gesperrt."))
        elseif command == "reset" then
            resetMeasurements()
        else
            d(TITLE .. ": Einstellungen unter Addons. /lub move | /lub reset")
        end
    end
    inCombat = IsUnitInCombat("player")
    resetMeasurements()
end

EVENT_MANAGER:RegisterForEvent(NAME, EVENT_ADD_ON_LOADED, loaded)
