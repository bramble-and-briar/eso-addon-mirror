local ADDON_NAME = "Leo_tracker_beta"
local SAVED_VARS_NAME = "Leo_tracker_beta_SavedVariables"
local TIMER_UPDATE_NAME = ADDON_NAME .. "_TimerUpdate"
local TARGET_REFRESH_NAME = ADDON_NAME .. "_TargetRefresh"
local TARGET_SCAN_NAME = ADDON_NAME .. "_TargetScan"

local MAX_WATCHED_EFFECTS = 100
local ICON_SIZE = 72
local ICON_GAP = 4
local PANEL_PADDING = 8
local MIN_TEXT_SIZE = 10
local MAX_TEXT_SIZE = 36
local TIMER_INTERVAL_MS = 100
local TARGET_REFRESH_DELAY_MS = 50
local TARGET_REFRESH_ATTEMPTS = 4
local TARGET_SCAN_INTERVAL_MS = 250
local MISSING_ICON = "EsoUI/Art/Icons/icon_missing.dds"
local BUFF_BORDER_COLOR = { 0.20, 1.00, 0.20 }
local DEBUFF_BORDER_COLOR = { 1.00, 0.20, 0.20 }

local DEFAULTS = {
    x = 40,
    y = 120,
    scale = 1.0,
    panelAlpha = 0.88,
    iconAlpha = 1.0,
    textSize = 18,
    watched = {},
}

local panel
local panelBackdrop
local savedVars
local settingsPanel
local settingsOptions
local consoleSettings
local settingsMenuOpen = false
local settingsRegistered = false
local settingsCallbacksRegistered = false
local consoleSceneCallbackRegistered = false
local inputBuffer = ""
local removeInputBuffer = ""

local watchedById = {}
local activeInstances = {}
local activeById = {}
local iconControls = {}
local timerUpdateRegistered = false
local targetRefreshRegistered = false
local targetScanRegistered = false
local targetRefreshAttempt = 0
local scanDiagnostics = {
    buffCount = 0,
    matchingCount = 0,
    lastScanAt = 0,
}
local effectEventDiagnostics = {
    total = 0,
    target = 0,
    watched = 0,
    last = {},
}
local PrintTargetScanDiagnostics

local function IsCurrentTarget(unitTag)
    if unitTag == "reticleover" then
        return true
    end

    return AreUnitsEqual ~= nil and AreUnitsEqual(unitTag, "reticleover")
end

local function AddChatLine(text)
    if CHAT_SYSTEM then
        CHAT_SYSTEM:AddMessage("[Leo Tracker Beta] " .. text)
    end
end

local function PrintDiagnostics(command)
    if not CHAT_SYSTEM then
        return
    end

    if tostring(command or ""):lower():match("^%s*scan%s*$") then
        if PrintTargetScanDiagnostics then
            PrintTargetScanDiagnostics()
        end
        return
    end

    local panelState = panel and "OK" or "NOT_INITIALIZED"
    local savedVarsState = savedVars and "OK" or "NOT_INITIALIZED"
    local settingsState = settingsRegistered and "OK" or "NOT_REGISTERED"
    local lamState = LibAddonMenu2 and "OK" or "MISSING"

    CHAT_SYSTEM:AddMessage(string.format(
        "[Leo Tracker Beta] Lua=LOADED | HUD=%s | SavedVariables=%s | Settings=%s | LibAddonMenu=%s",
        panelState,
        savedVarsState,
        settingsState,
        lamState
    ))
end

SLASH_COMMANDS["/leotracker"] = PrintDiagnostics
SLASH_COMMANDS["/ltb"] = PrintDiagnostics

local function Clamp(value, minimum, maximum)
    return math.max(minimum, math.min(maximum, value))
end

local function GetNowMilliseconds()
    return GetFrameTimeMilliseconds()
end

local function GetTrackerTextFont()
    local fontSize = savedVars and tonumber(savedVars.textSize) or DEFAULTS.textSize
    fontSize = Clamp(fontSize, MIN_TEXT_SIZE, MAX_TEXT_SIZE)

    local fontFace
    if IsInGamepadPreferredMode and IsInGamepadPreferredMode() then
        fontFace = "$(GAMEPAD_BOLD_FONT)"
    elseif ZO_IsConsoleOrGameCoreUI and ZO_IsConsoleOrGameCoreUI() then
        fontFace = "$(GAMEPAD_BOLD_FONT)"
    else
        fontFace = "$(BOLD_FONT)"
    end

    if ZO_CreateFontString then
        local fontStyle = FONT_STYLE_OUTLINE_THICK or FONT_STYLE_SOFT_SHADOW_THICK or FONT_STYLE_NORMAL or 0
        local success, dynamicFont = pcall(ZO_CreateFontString, fontFace, fontSize, fontStyle)
        if success and type(dynamicFont) == "string" and dynamicFont ~= "" then
            return dynamicFont
        end
    end

    if fontFace == "$(GAMEPAD_BOLD_FONT)" then
        return "ZoFontGamepadBold18"
    end

    return "ZoFontGameBold"
end

local function EffectTimeToMilliseconds(endTime)
    if not endTime or endTime <= 0 then
        return nil
    end

    -- ESO returns EVENT_EFFECT_CHANGED/GetUnitBuffInfo timestamps in seconds.
    -- The tracker stores timestamps in milliseconds for countdown updates.
    return endTime * 1000
end

PrintTargetScanDiagnostics = function()
    if not CHAT_SYSTEM then
        return
    end

    local targetExists = DoesUnitExist("reticleover")
    local targetDead = targetExists and IsUnitDead("reticleover") or false
    local buffCount = targetExists and (GetNumBuffs("reticleover") or 0) or 0
    local now = GetNowMilliseconds()

    AddChatLine(string.format(
        "Target exists=%s dead=%s buffs=%d now=%d watched=%d",
        tostring(targetExists),
        tostring(targetDead),
        buffCount,
        now,
        savedVars and #savedVars.watched or 0
    ))

    local matchingCount = 0
    if targetExists and not targetDead then
        for buffIndex = 1, buffCount do
            local effectName, beginTime, endTime, effectSlot, stackCount, iconName, _, effectType, _, _, abilityId, _, castByPlayer = GetUnitBuffInfo("reticleover", buffIndex)
            if abilityId and watchedById[abilityId] then
                matchingCount = matchingCount + 1
                AddChatLine(string.format(
                    "MATCH id=%d slot=%s end=%s delta=%s type=%s stacks=%s castByPlayer=%s name=%s",
                    abilityId,
                    tostring(effectSlot),
                    tostring(endTime),
                    tostring(endTime and (endTime * 1000 - now) or nil),
                    tostring(effectType),
                    tostring(stackCount),
                    tostring(castByPlayer),
                    tostring(effectName)
                ))
            end
        end
    end

    scanDiagnostics.buffCount = buffCount
    scanDiagnostics.matchingCount = matchingCount
    scanDiagnostics.lastScanAt = now

    if matchingCount == 0 then
        AddChatLine("No watched AbilityId was returned by GetUnitBuffInfo for reticleover.")
    end

    local lastEvent = effectEventDiagnostics.last
    if lastEvent.unitTag ~= nil then
        AddChatLine(string.format(
            "Events total=%d target=%d watched=%d last=(unit=%s id=%s change=%s type=%s source=%s end=%s)",
            effectEventDiagnostics.total,
            effectEventDiagnostics.target,
            effectEventDiagnostics.watched,
            tostring(lastEvent.unitTag),
            tostring(lastEvent.abilityId),
            tostring(lastEvent.changeType),
            tostring(lastEvent.effectType),
            tostring(lastEvent.sourceType),
            tostring(lastEvent.endTime)
        ))
    else
        AddChatLine(string.format(
            "Events total=%d target=%d watched=%d last=none",
            effectEventDiagnostics.total,
            effectEventDiagnostics.target,
            effectEventDiagnostics.watched
        ))
    end
end

local function ParseAbilityId(value)
    local text = tostring(value or "")
    if text == "" or not text:match("^%d+$") then
        return nil
    end

    local abilityId = tonumber(text)
    if not abilityId or abilityId <= 0 or abilityId ~= math.floor(abilityId) then
        return nil
    end

    return abilityId
end

local function GetAbilityDisplayName(abilityId, fallback)
    local name = GetAbilityName(abilityId)
    if name and name ~= "" then
        return name
    end

    return fallback or ("Ability " .. tostring(abilityId))
end

local function RebuildWatchedIndex()
    watchedById = {}

    local cleaned = {}
    local storedWatched = type(savedVars.watched) == "table" and savedVars.watched or {}
    for _, entry in ipairs(storedWatched) do
        local rawId = type(entry) == "table" and entry.id or entry
        local savedName = type(entry) == "table" and entry.name or nil
        local abilityId = ParseAbilityId(rawId)
        if abilityId and not watchedById[abilityId] and #cleaned < MAX_WATCHED_EFFECTS then
            local name = savedName or GetAbilityDisplayName(abilityId)
            local cleanEntry = {
                id = abilityId,
                name = name,
            }

            cleaned[#cleaned + 1] = cleanEntry
            watchedById[abilityId] = cleanEntry
        end
    end

    savedVars.watched = cleaned
end

local function NormalizeSavedVars()
    savedVars.x = tonumber(savedVars.x) or DEFAULTS.x
    savedVars.y = tonumber(savedVars.y) or DEFAULTS.y
    savedVars.scale = Clamp(tonumber(savedVars.scale) or DEFAULTS.scale, 0.5, 2.0)
    savedVars.panelAlpha = Clamp(tonumber(savedVars.panelAlpha) or DEFAULTS.panelAlpha, 0.1, 1.0)
    savedVars.iconAlpha = Clamp(tonumber(savedVars.iconAlpha) or DEFAULTS.iconAlpha, 0.1, 1.0)
    savedVars.textSize = Clamp(tonumber(savedVars.textSize) or DEFAULTS.textSize, MIN_TEXT_SIZE, MAX_TEXT_SIZE)
end

local function IsDebuff(effectType)
    return BUFF_EFFECT_TYPE_DEBUFF ~= nil and effectType == BUFF_EFFECT_TYPE_DEBUFF
end

local function GetCurrentTargetEffectSource(abilityId, effectSlot)
    if not abilityId or not DoesUnitExist("reticleover") then
        return nil, nil
    end

    local buffCount = GetNumBuffs("reticleover") or 0
    local firstEffectType
    local firstCastByPlayer
    local found = false
    for buffIndex = 1, buffCount do
        local _, _, _, currentSlot, _, _, _, currentEffectType, _, _, currentAbilityId, _, currentCastByPlayer = GetUnitBuffInfo("reticleover", buffIndex)
        if currentAbilityId == abilityId and (effectSlot == nil or currentSlot == effectSlot) then
            if currentCastByPlayer == true then
                return currentEffectType, true
            end

            if not found then
                firstEffectType = currentEffectType
                firstCastByPlayer = currentCastByPlayer
                found = true
            end
        end
    end

    if found then
        return firstEffectType, firstCastByPlayer
    end

    return nil, nil
end

local function GetCurrentTargetStackCount(abilityId, effectSlot)
    if not abilityId or not DoesUnitExist("reticleover") then
        return nil
    end

    local buffCount = GetNumBuffs("reticleover") or 0
    for buffIndex = 1, buffCount do
        local _, _, _, currentSlot, currentStackCount, _, _, _, _, _, currentAbilityId = GetUnitBuffInfo("reticleover", buffIndex)
        if currentAbilityId == abilityId and (effectSlot == nil or currentSlot == effectSlot) then
            return tonumber(currentStackCount) or 0
        end
    end

    return nil
end

local function IsAllowedSource(effectType, sourceType, castByPlayer, abilityId, effectSlot)
    if effectType == nil then
        local currentEffectType, currentCastByPlayer = GetCurrentTargetEffectSource(abilityId, effectSlot)
        effectType = currentEffectType
        castByPlayer = currentCastByPlayer
    end

    if effectType == nil then
        return false
    end

    if not IsDebuff(effectType) then
        return true
    end

    if sourceType == COMBAT_UNIT_TYPE_PLAYER or castByPlayer == true then
        return true
    end

    -- ESO can report COMBAT_UNIT_TYPE_NONE for a player-applied effect in
    -- EVENT_EFFECT_CHANGED. Read the live target aura to recover castByPlayer.
    if sourceType == nil or (COMBAT_UNIT_TYPE_NONE ~= nil and sourceType == COMBAT_UNIT_TYPE_NONE) then
        local _, currentCastByPlayer = GetCurrentTargetEffectSource(abilityId, effectSlot)
        return currentCastByPlayer == true
    end

    return false
end

local function ClearActiveEffects()
    activeInstances = {}
    activeById = {}
end

local function SetEffectInstance(abilityId, effectSlot, effectName, endTime, iconName, stackCount, effectType, sourceType, castByPlayer)
    local watched = watchedById[abilityId]
    local endTimeMs = EffectTimeToMilliseconds(endTime)
    if not watched or not endTimeMs or endTimeMs <= GetNowMilliseconds() then
        return
    end

    -- EVENT_EFFECT_CHANGED can occasionally provide a missing/zero stack value.
    -- The live target aura is authoritative for the stack counter.
    local normalizedStackCount = tonumber(stackCount)
    if not normalizedStackCount or normalizedStackCount < 1 then
        normalizedStackCount = GetCurrentTargetStackCount(abilityId, effectSlot) or 0
    end

    local instances = activeInstances[abilityId]
    if not instances then
        instances = {}
        activeInstances[abilityId] = instances
    end

    local slotKey = tostring(effectSlot or abilityId)
    instances[slotKey] = {
        abilityId = abilityId,
        effectSlot = effectSlot,
        name = effectName or watched.name,
        endTime = endTimeMs,
        iconName = iconName or MISSING_ICON,
        stackCount = math.max(0, math.floor(normalizedStackCount)),
        effectType = effectType,
        sourceType = sourceType,
        castByPlayer = castByPlayer,
    }

    if effectName and effectName ~= "" then
        watched.name = effectName
    end
end

local function RemoveEffectInstance(abilityId, effectSlot)
    local instances = activeInstances[abilityId]
    if not instances then
        return
    end

    instances[tostring(effectSlot or abilityId)] = nil
    if next(instances) == nil then
        activeInstances[abilityId] = nil
    end
end

local function RebuildActiveEffects()
    activeById = {}

    for abilityId, instances in pairs(activeInstances) do
        local latest
        for _, instance in pairs(instances) do
            if not latest or instance.endTime > latest.endTime then
                latest = instance
            end
        end

        if latest then
            activeById[abilityId] = latest
        end
    end
end

local function PruneExpiredEffects()
    local now = GetNowMilliseconds()
    local changed = false

    for abilityId, instances in pairs(activeInstances) do
        for slotKey, instance in pairs(instances) do
            if instance.endTime <= now then
                instances[slotKey] = nil
                changed = true
            end
        end

        if next(instances) == nil then
            activeInstances[abilityId] = nil
        end
    end

    if changed then
        RebuildActiveEffects()
    end
end

local function SetPanelDimensions(activeCount)
    local count = math.max(1, activeCount)
    local width = PANEL_PADDING * 2 + count * ICON_SIZE + math.max(0, count - 1) * ICON_GAP
    local height = PANEL_PADDING * 2 + ICON_SIZE
    panel:SetDimensions(width, height)
end

local function CreateIconControl(index)
    if iconControls[index] then
        return iconControls[index]
    end

    local control = WINDOW_MANAGER:CreateControlFromVirtual(
        ADDON_NAME .. "Icon" .. tostring(index),
        panel,
        "Leo_tracker_beta_IconTemplate"
    )

    local timer = WINDOW_MANAGER:CreateControl(
        ADDON_NAME .. "Icon" .. tostring(index) .. "Timer",
        control,
        CT_LABEL
    )
    timer:SetAnchorFill(control)
    timer:SetFont(GetTrackerTextFont())
    timer:SetColor(1, 1, 1, 1)
    timer:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    timer:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    timer:SetDrawLayer(DL_OVERLAY)
    timer:SetDrawTier(DT_HIGH)
    timer:SetDrawLevel(10)
    timer:SetHidden(false)

    local stacks = WINDOW_MANAGER:CreateControl(
        ADDON_NAME .. "Icon" .. tostring(index) .. "Stacks",
        control,
        CT_LABEL
    )
    local border = control:GetNamedChild("Frame")
    if border then
        -- Keep the backdrop's center transparent so only its edge is drawn
        -- above the icon texture.
        border:SetCenterColor(0, 0, 0, 0)
        -- Use a plain one-pixel edge instead of the default backdrop shadow.
        border:SetEdgeTexture("", 1, 1, 0, 0)
        border:SetAlpha(1)
        border:SetDrawLayer(DL_OVERLAY)
        border:SetDrawTier(DT_HIGH)
        border:SetDrawLevel(9)
        border:SetHidden(false)
    end

    stacks:SetDimensions(24, 24)
    stacks:SetAnchor(TOPRIGHT, control, TOPRIGHT, -3, 3)
    stacks:SetFont(GetTrackerTextFont())
    stacks:SetColor(1, 1, 1, 1)
    stacks:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    stacks:SetVerticalAlignment(TEXT_ALIGN_TOP)
    stacks:SetDrawLayer(DL_OVERLAY)
    stacks:SetDrawTier(DT_HIGH)
    stacks:SetDrawLevel(11)
    stacks:SetHidden(false)

    iconControls[index] = {
        control = control,
        icon = control:GetNamedChild("Icon"),
        border = border,
        timer = timer,
        stacks = stacks,
    }

    return iconControls[index]
end

local function ApplyIconBorder(iconData, effect)
    if not iconData.border then
        return
    end

    local color = IsDebuff(effect.effectType) and DEBUFF_BORDER_COLOR or BUFF_BORDER_COLOR
    iconData.border:SetEdgeColor(color[1], color[2], color[3], 1)
end

local function ApplyTextFonts()
    local font = GetTrackerTextFont()
    for _, iconData in ipairs(iconControls) do
        iconData.timer:SetFont(font)
        iconData.stacks:SetFont(font)
    end
end

local function HideUnusedIcons(usedCount)
    for index, iconData in ipairs(iconControls) do
        if index > usedCount then
            iconData.control:SetHidden(true)
        end
    end
end

local function RenderPanel()
    if not panel then
        return
    end

    local visibleEffects = {}
    for _, watched in ipairs(savedVars.watched) do
        local effect = activeById[watched.id]
        if effect then
            visibleEffects[#visibleEffects + 1] = effect
        end
    end

    SetPanelDimensions(#visibleEffects)

    -- Keep an empty preview visible while the settings scene is open, but do
    -- not occupy HUD space during normal gameplay when there is nothing to show.
    panel:SetHidden(not settingsMenuOpen and #visibleEffects == 0)

    for index, effect in ipairs(visibleEffects) do
        local iconData = CreateIconControl(index)
        local offsetX = PANEL_PADDING + (index - 1) * (ICON_SIZE + ICON_GAP)

        iconData.control:ClearAnchors()
        iconData.control:SetAnchor(TOPLEFT, panel, TOPLEFT, offsetX, PANEL_PADDING)
        iconData.control:SetHidden(false)
        iconData.icon:SetTexture(effect.iconName or MISSING_ICON)
        iconData.icon:SetAlpha(savedVars.iconAlpha)
        ApplyIconBorder(iconData, effect)

        local remaining = math.max(0, (effect.endTime - GetNowMilliseconds()) / 1000)
        iconData.timer:SetHidden(false)
        iconData.timer:SetText(string.format("%.1f", remaining))

        local stackCount = tonumber(effect.stackCount) or 0
        iconData.stacks:SetHidden(false)
        iconData.stacks:SetText(stackCount > 1 and tostring(stackCount) or "")
    end

    HideUnusedIcons(#visibleEffects)
end

local function StopTimerUpdates()
    if timerUpdateRegistered then
        EVENT_MANAGER:UnregisterForUpdate(TIMER_UPDATE_NAME)
        timerUpdateRegistered = false
    end
end

local function TimerUpdate()
    PruneExpiredEffects()
    RenderPanel()

    if next(activeById) == nil then
        StopTimerUpdates()
    end
end

local function StartTimerUpdates()
    if timerUpdateRegistered then
        return
    end

    EVENT_MANAGER:RegisterForUpdate(TIMER_UPDATE_NAME, TIMER_INTERVAL_MS, TimerUpdate)
    timerUpdateRegistered = true
end

local function ApplyPanelSettings()
    if not panel then
        return
    end

    panel:ClearAnchors()
    panel:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, savedVars.x, savedVars.y)
    panel:SetScale(savedVars.scale)
    if panelBackdrop then
        panelBackdrop:SetAlpha(savedVars.panelAlpha)
    end
    RenderPanel()
end

local function OnLAMPanelOpened(selectedPanel)
    if selectedPanel == settingsPanel then
        settingsMenuOpen = true
        ApplyPanelSettings()
    end
end

local function OnLAMPanelClosed(selectedPanel)
    if selectedPanel == settingsPanel then
        settingsMenuOpen = false
        ApplyPanelSettings()
    end
end

local function OnConsoleSettingsSceneStateChange(newState)
    if newState == SCENE_SHOWING or newState == SCENE_SHOWN then
        if consoleSettings and consoleSettings.selected then
            settingsMenuOpen = true
            ApplyPanelSettings()
        end
    elseif newState == SCENE_HIDING or newState == SCENE_HIDDEN then
        settingsMenuOpen = false
        ApplyPanelSettings()
    end
end

local function RegisterConsoleSettingsSceneCallback()
    if consoleSceneCallbackRegistered or not LibHarvensAddonSettings then
        return
    end

    local settingsScene = LibHarvensAddonSettings.scene
    if settingsScene and settingsScene.RegisterCallback then
        settingsScene:RegisterCallback("StateChange", OnConsoleSettingsSceneStateChange)
        consoleSceneCallbackRegistered = true
    end
end

local function OnConsoleAddonSelected(_, addonSettings)
    RegisterConsoleSettingsSceneCallback()

    local isOurSettings = addonSettings == consoleSettings
    if not isOurSettings and not consoleSettings and addonSettings then
        isOurSettings = addonSettings.name == "Leo Tracker Beta"
        if isOurSettings then
            consoleSettings = addonSettings
        end
    end

    settingsMenuOpen = isOurSettings
    ApplyPanelSettings()
end

local function RegisterSettingsCallbacks()
    if settingsCallbacksRegistered or not CALLBACK_MANAGER then
        return
    end

    CALLBACK_MANAGER:RegisterCallback("LAM-PanelOpened", OnLAMPanelOpened)
    CALLBACK_MANAGER:RegisterCallback("LAM-PanelClosed", OnLAMPanelClosed)
    CALLBACK_MANAGER:RegisterCallback("LibHarvensAddonSettings_AddonSelected", OnConsoleAddonSelected)
    settingsCallbacksRegistered = true
end

local function ScanCurrentTarget()
    if not DoesUnitExist("reticleover") or IsUnitDead("reticleover") then
        ClearActiveEffects()
        RenderPanel()
        StopTimerUpdates()
        return
    end

    local buffCount = GetNumBuffs("reticleover") or 0
    for buffIndex = 1, buffCount do
        local effectName, _, endTime, effectSlot, stackCount, iconName, _, effectType, _, _, abilityId, _, castByPlayer = GetUnitBuffInfo("reticleover", buffIndex)
        if abilityId and watchedById[abilityId] and IsAllowedSource(effectType, nil, castByPlayer, abilityId, effectSlot) then
            SetEffectInstance(abilityId, effectSlot, effectName, endTime, iconName, stackCount, effectType, nil, castByPlayer)
        end
    end

    RebuildActiveEffects()
    RenderPanel()

    if next(activeById) ~= nil then
        StartTimerUpdates()
    else
        StopTimerUpdates()
    end
end

local function StopTargetScanUpdates()
    if targetScanRegistered then
        EVENT_MANAGER:UnregisterForUpdate(TARGET_SCAN_NAME)
        targetScanRegistered = false
    end
end

local function TargetScanUpdate()
    if not DoesUnitExist("reticleover") or IsUnitDead("reticleover") then
        ClearActiveEffects()
        RenderPanel()
        StopTimerUpdates()
        StopTargetScanUpdates()
        return
    end

    ScanCurrentTarget()
end

local function StartTargetScanUpdates()
    if targetScanRegistered then
        return
    end

    EVENT_MANAGER:RegisterForUpdate(TARGET_SCAN_NAME, TARGET_SCAN_INTERVAL_MS, TargetScanUpdate)
    targetScanRegistered = true
end

local function RequestTargetRefresh()
    ClearActiveEffects()
    StopTimerUpdates()
    RenderPanel()

    if targetRefreshRegistered then
        return
    end

    targetRefreshAttempt = 0
    EVENT_MANAGER:RegisterForUpdate(TARGET_REFRESH_NAME, TARGET_REFRESH_DELAY_MS, function()
        targetRefreshAttempt = targetRefreshAttempt + 1
        ScanCurrentTarget()

        if targetRefreshAttempt >= TARGET_REFRESH_ATTEMPTS or next(activeById) ~= nil then
            EVENT_MANAGER:UnregisterForUpdate(TARGET_REFRESH_NAME)
            targetRefreshRegistered = false
            targetRefreshAttempt = 0
            StartTargetScanUpdates()
        end
    end)
    targetRefreshRegistered = true
end

local function OnReticleTargetChanged()
    RequestTargetRefresh()
end

local function OnEffectChanged(_, changeType, effectSlot, effectName, unitTag, beginTime, endTime, stackCount, iconName, buffType, effectType, abilityType, statusEffectType, unitName, unitId, abilityId, sourceType)
    effectEventDiagnostics.total = effectEventDiagnostics.total + 1
    local lastEvent = effectEventDiagnostics.last
    lastEvent.unitTag = unitTag
    lastEvent.abilityId = abilityId
    lastEvent.changeType = changeType
    lastEvent.effectType = effectType
    lastEvent.sourceType = sourceType
    lastEvent.endTime = endTime

    if not IsCurrentTarget(unitTag) then
        return
    end

    effectEventDiagnostics.target = effectEventDiagnostics.target + 1
    if not abilityId or not watchedById[abilityId] then
        return
    end

    effectEventDiagnostics.watched = effectEventDiagnostics.watched + 1

    RemoveEffectInstance(abilityId, effectSlot)

    if changeType ~= EFFECT_RESULT_FADED and IsAllowedSource(effectType, sourceType, nil, abilityId, effectSlot) then
        SetEffectInstance(abilityId, effectSlot, effectName, endTime, iconName, stackCount, effectType, sourceType, nil)
    end

    RebuildActiveEffects()
    RenderPanel()

    if next(activeById) ~= nil then
        StartTimerUpdates()
    else
        StopTimerUpdates()
    end

    StartTargetScanUpdates()
end

local function AddWatchedAbility(value)
    local abilityId = ParseAbilityId(value)
    if not abilityId or watchedById[abilityId] or #savedVars.watched >= MAX_WATCHED_EFFECTS then
        return false
    end

    if DoesAbilityExist and not DoesAbilityExist(abilityId) then
        return false
    end

    local entry = {
        id = abilityId,
        name = GetAbilityDisplayName(abilityId),
    }

    savedVars.watched[#savedVars.watched + 1] = entry
    watchedById[abilityId] = entry
    RequestTargetRefresh()
    return true
end

local function RemoveWatchedAbility(abilityId)
    abilityId = ParseAbilityId(abilityId)
    if not abilityId or not watchedById[abilityId] then
        return false
    end

    for index, entry in ipairs(savedVars.watched) do
        if entry.id == abilityId then
            table.remove(savedVars.watched, index)
            break
        end
    end

    watchedById[abilityId] = nil
    activeInstances[abilityId] = nil
    activeById[abilityId] = nil
    RenderPanel()
    return true
end

local function RefreshSettingsDisplay()
    if CALLBACK_MANAGER and settingsPanel then
        CALLBACK_MANAGER:FireCallbacks("LAM-RefreshPanel", settingsPanel)
    end

    if LibAddonMenu2 and IsKeyboardUISupported and not IsKeyboardUISupported() and LibAddonMenu2.LHASConversion and LibAddonMenu2.LHASConversion.settingTables then
        local consoleSettings = LibAddonMenu2.LHASConversion.settingTables[ADDON_NAME .. "_Settings"]
        if consoleSettings and consoleSettings.RefreshSettings then
            consoleSettings:RefreshSettings()
        end
    end
end

local function GetTrackedEffectsDescription()
    if #savedVars.watched == 0 then
        return "No tracked effects."
    end

    local lines = {}
    for _, entry in ipairs(savedVars.watched) do
        lines[#lines + 1] = string.format("%s  [%d]", entry.name, entry.id)
    end

    return table.concat(lines, "\n")
end

local function RebuildSettingsOptions()
    if not LibAddonMenu2 or not LibAddonMenu2.RegisterOptionControls then
        return
    end

    settingsOptions = {
        {
            type = "description",
            text = "Tracks only effects on your current reticle target. Debuffs are shown only when their source is you.",
        },
        {
            type = "slider",
            name = "Position X",
            min = -3000,
            max = 3000,
            step = 1,
            decimals = 0,
            getFunc = function() return savedVars.x end,
            setFunc = function(value)
                savedVars.x = math.floor(tonumber(value) or DEFAULTS.x)
                ApplyPanelSettings()
            end,
            default = DEFAULTS.x,
        },
        {
            type = "slider",
            name = "Position Y",
            min = -2000,
            max = 2000,
            step = 1,
            decimals = 0,
            getFunc = function() return savedVars.y end,
            setFunc = function(value)
                savedVars.y = math.floor(tonumber(value) or DEFAULTS.y)
                ApplyPanelSettings()
            end,
            default = DEFAULTS.y,
        },
        {
            type = "slider",
            name = "Scale",
            min = 0.5,
            max = 2.0,
            step = 0.05,
            decimals = 2,
            getFunc = function() return savedVars.scale end,
            setFunc = function(value)
                savedVars.scale = Clamp(tonumber(value) or DEFAULTS.scale, 0.5, 2.0)
                ApplyPanelSettings()
            end,
            default = DEFAULTS.scale,
        },
        {
            type = "slider",
            name = "Panel opacity",
            min = 0.1,
            max = 1.0,
            step = 0.05,
            decimals = 2,
            getFunc = function() return savedVars.panelAlpha end,
            setFunc = function(value)
                savedVars.panelAlpha = Clamp(tonumber(value) or DEFAULTS.panelAlpha, 0.1, 1.0)
                ApplyPanelSettings()
            end,
            default = DEFAULTS.panelAlpha,
        },
        {
            type = "slider",
            name = "Icon opacity",
            min = 0.1,
            max = 1.0,
            step = 0.05,
            decimals = 2,
            getFunc = function() return savedVars.iconAlpha end,
            setFunc = function(value)
                savedVars.iconAlpha = Clamp(tonumber(value) or DEFAULTS.iconAlpha, 0.1, 1.0)
                RenderPanel()
            end,
            default = DEFAULTS.iconAlpha,
        },
        {
            type = "slider",
            name = "Text size",
            tooltip = "Changes the size of the timer and stack counter.",
            min = MIN_TEXT_SIZE,
            max = MAX_TEXT_SIZE,
            step = 1,
            decimals = 0,
            getFunc = function() return savedVars.textSize end,
            setFunc = function(value)
                savedVars.textSize = Clamp(math.floor(tonumber(value) or DEFAULTS.textSize), MIN_TEXT_SIZE, MAX_TEXT_SIZE)
                ApplyTextFonts()
                RenderPanel()
            end,
            default = DEFAULTS.textSize,
        },
        {
            type = "header",
            name = "Tracked effects",
        },
        {
            type = "description",
            text = GetTrackedEffectsDescription,
        },
        {
            type = "editbox",
            name = "Add AbilityId",
            tooltip = "Enter a positive integer AbilityId.",
            getFunc = function() return inputBuffer end,
            setFunc = function(value)
                AddWatchedAbility(value)
                inputBuffer = ""
                RefreshSettingsDisplay()
            end,
            isMultiline = false,
            isExtraWide = true,
            maxChars = 10,
            default = "",
        },
        {
            type = "editbox",
            name = "Remove AbilityId",
            tooltip = "Enter an existing AbilityId to remove it from the tracking list.",
            getFunc = function() return removeInputBuffer end,
            setFunc = function(value)
                RemoveWatchedAbility(value)
                removeInputBuffer = ""
                RefreshSettingsDisplay()
            end,
            isMultiline = false,
            isExtraWide = true,
            maxChars = 10,
            default = "",
        },
    }

    local registered, registrationError = pcall(function()
        LibAddonMenu2:RegisterOptionControls(ADDON_NAME .. "_Settings", settingsOptions)
    end)
    if registered then
        settingsRegistered = true
    else
        AddChatLine("settings option registration failed: " .. tostring(registrationError))
    end
end

local function InitializeSettings()
    if not LibAddonMenu2 then
        return
    end

    local registered, panelOrError = pcall(function()
        return LibAddonMenu2:RegisterAddonPanel(ADDON_NAME .. "_Settings", {
            type = "panel",
            name = "Leo Tracker Beta",
            displayName = "Leo Tracker Beta",
            author = "Leo_Kujo",
            version = "0.2.19",
            registerForRefresh = true,
            registerForDefaults = true,
        })
    end)

    if registered then
        settingsPanel = panelOrError
    else
        AddChatLine("settings panel registration failed: " .. tostring(panelOrError))
    end

    RebuildSettingsOptions()

    if LibAddonMenu2.LHASConversion and LibAddonMenu2.LHASConversion.settingTables then
        consoleSettings = LibAddonMenu2.LHASConversion.settingTables[ADDON_NAME .. "_Settings"]
    end

    RegisterSettingsCallbacks()
end

local function OnPlayerActivated()
    ApplyPanelSettings()
    RequestTargetRefresh()
end

local function OnAddOnLoaded(_, addonName)
    if addonName ~= ADDON_NAME then
        return
    end

    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)

    panel = Leo_tracker_beta
    if not panel then
        AddChatLine("HUD root control Leo_tracker_beta was not created from XML")
        return
    end

    panelBackdrop = panel:GetNamedChild("Panel")
    if not panelBackdrop then
        AddChatLine("HUD backdrop control Leo_tracker_betaPanel was not found")
    end
    savedVars = ZO_SavedVars:NewAccountWide(SAVED_VARS_NAME, 1, nil, DEFAULTS)

    RebuildWatchedIndex()
    NormalizeSavedVars()
    ApplyPanelSettings()
    InitializeSettings()

    EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_PLAYER_ACTIVATED, OnPlayerActivated)
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_RETICLE_TARGET_CHANGED, OnReticleTargetChanged)
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_EFFECT_CHANGED, OnEffectChanged)

end

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
