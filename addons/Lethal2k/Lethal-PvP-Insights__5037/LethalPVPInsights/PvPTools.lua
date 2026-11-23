
LPI_PvPTools = {}
local PvPFPSLimiter = LPI_PvPTools
local ADDON_NAME = "LPI_PvPTools"
local LPI_ADDON = "LethalPVPInsights"
local ADDON_VERSION = "7.31.0"
local SAVED_VARS_VERSION = 1
local MIN_FRAME_TIME_CVAR = "MinFrameTime.2"
local MIN_FPS_LIMIT = 10
local MAX_FPS_LIMIT = 300
local NOTIFY_MODE_OFF = "OFF"
local NOTIFY_MODE_CHAT = "CHAT"
local NOTIFY_MODE_NOTIFICATION = "NOTIFICATION"
local NOTIFY_MODE_BOTH = "CHAT AND NOTIFICATION"
local NOTIFY_MODE_CHOICES = { NOTIFY_MODE_OFF, NOTIFY_MODE_CHAT, NOTIFY_MODE_NOTIFICATION, NOTIFY_MODE_BOTH }
local function NormalizeNotifyMode(value)
    for _, choice in ipairs(NOTIFY_MODE_CHOICES) do
        if value == choice then return value end
    end
    return NOTIFY_MODE_OFF -- defensive: an unrecognized/corrupt value is treated as off, never as some unintended "on" state
end
local defaults =
{
    zoneFpsLimitsEnabled = false,
    zoneFpsLimitsCvarSnapshot = nil,
    pvpFpsLimit = 30,
    pveFpsLimit = 100,
    includeBattlegrounds = false,
    debug = false,
    perfBoostEnabled = false,
    perfBoostViewDistance = 1.6,
    perfBoostApplied = false,
    autoAcceptQueueEnabled = false,
    notifyBlockingMode = NOTIFY_MODE_BOTH,
    notifyUltimateMode = NOTIFY_MODE_BOTH,
    notifyBlockingText = "@accountname BLOCKED",
    notifyBlockingColor = { r = 1, g = 0.65, b = 0.1 }, -- orange
    notifyUltimateText = "ULTIMATE: @accountname used {ability}",
    notifyUltimateColor = { r = 1, g = 0.15, b = 0.15 }, -- red
    notifyStunnedMode = NOTIFY_MODE_BOTH,
    notifyStunnedText = "STUNNED by @accountname",
    notifyStunnedColor = { r = 1, g = 0.95, b = 0.2 }, -- yellow
    notifyImmobilizedMode = NOTIFY_MODE_BOTH,
    notifyImmobilizedText = "IMMOBILIZED by @accountname",
    notifyImmobilizedColor = { r = 0.3, g = 0.85, b = 1 }, -- cyan/light blue
    notifyTextSize = 24,
    notifyTextOffsetX = 0,
    notifyTextOffsetY = -210, -- matches the original fixed FLOATING_TEXT_START_OFFSET_Y
    notifyTextDurationSeconds = 2, -- matches the original fixed ~1800ms duration, rounded to a whole second
    duplicateMessageSuppressSeconds = 2, -- matches the original ULTIMATE_NOTIFY_DEBOUNCE_MS of 2000ms
    criticalDelayedMode = NOTIFY_MODE_BOTH,
    criticalDelayedText = "BLOCK",
    criticalDelayedColor = { r = 1, g = 0.1, b = 0.1 }, -- bright red
    criticalDelayedLeadSeconds = 2,
    criticalDelayedAlertDurationSeconds = 2,
    criticalDelayedAbilityList = "Haunting Curse=3.5,12\nShattering Rocks=0.01\nFossilize=0.01\nPetrify=0.01\nDark Convergence=1,5\nRush of Agony=0.8,2.8\nDeep Fissure=6\nSubterranean Assault=3",
    criticalAoeMode = NOTIFY_MODE_BOTH,
    criticalAoeText = "BLOCK or AVOID",
    criticalAoeColor = { r = 1, g = 0.5, b = 0 }, -- orange
    criticalAoeGraceSeconds = 2,
    criticalAoeAbilityList = "Dragonknight Standard\nShifting Standard\nStandard of Might\nNova\nSolar Prison\nSolar Disturbance\nSleet Storm\nNorthern Storm\nPermafrost\nThe Unblinking Eye\nThe Tide King's Gaze\nThe Languid Eye\nMeteor\nIce Comet\nShooting Star\nElemental Storm\nElemental Rage\nEye of Flame\nEye of Lightning\nEye of Frost\nFire Storm\nIce Storm\nThunder Storm\nFiery Rage\nIcy Rage\nThunderous Rage\nRavenous Goliath\nRapid Fire\nBallista\nToxic Barrage\nLacerate\nRend\nThrive in Chaos\nFrozen Colossus\nGlacial Colossus\nPestilent Colossus\nOnslaught\n85451\n85462\n83687\n17879\n62310\n40161\n62314\n40160\n80435\n47160",
    criticalTextSize = 36,
    showLeaderMarkerCyrodiil = false,
    showLeaderMarkerImperialCity = false,
    showLeaderMarkerBattlegrounds = false,
    leaderMarkerColor = { r = 1, g = 1, b = 1 }, -- v7.22.0: white (was cyan) - "make it white", per direct user request
    leaderMarkerSize = 300, -- unchanged since v7.20.0 - still the OUTER ring's diameter
    showBreakFreeAlert = false,
    breakFreeChat = false,
    breakFreeAlertText = "{type} - BREAK FREE",
    breakFreeAlertColor = { r = 1, g = 0.1, b = 0.1 }, -- bright red - same as criticalDelayedColor, for the same "impossible to miss" reason
    breakFreeAlertTextSize = 72, -- v7.27.0: bumped from 48 per direct user request, for maximum visibility
    breakFreeAlertPvpOnly = false,
    showBlockingAlert = false,
    blockingChat = false,
    blockingAlertText = "BLOCKING",
    blockingAlertColor = { r = 0.3, g = 0.6, b = 1 }, -- light/shield blue - distinct from the other alerts' red/orange/yellow
    blockingAlertTextSize = 48,
    blockingAlertPvpOnly = true,
    blockingAlertOffsetX = 0,
    blockingAlertOffsetY = -160,
    blockingAlertPvpOnlyMigratedV730 = false,
    quickslotKeybindsEnabled = true,
    quickslotNotifyEnabled = true,
}
local MIN_DUPLICATE_SUPPRESS_SECONDS = 0
local MAX_DUPLICATE_SUPPRESS_SECONDS = 30
local MIN_NOTIFY_TEXT_SIZE = 10
local MAX_NOTIFY_TEXT_SIZE = 48
local MIN_NOTIFY_TEXT_OFFSET_X = -600
local MAX_NOTIFY_TEXT_OFFSET_X = 600
local MIN_NOTIFY_TEXT_OFFSET_Y = -600
local MAX_NOTIFY_TEXT_OFFSET_Y = 300
local MIN_NOTIFY_TEXT_DURATION_SECONDS = 1
local MAX_NOTIFY_TEXT_DURATION_SECONDS = 5
local MIN_CRITICAL_SECONDS = 0.5
local MAX_CRITICAL_SECONDS = 10
local MIN_CRITICAL_TEXT_SIZE = 16
local MAX_CRITICAL_TEXT_SIZE = 200
local MIN_LEADER_MARKER_SIZE = 60
local MAX_LEADER_MARKER_SIZE = 400
local MIN_BREAKFREE_TEXT_SIZE = 16
local MAX_BREAKFREE_TEXT_SIZE = 200
local MIN_BLOCKING_TEXT_SIZE = 16
local MAX_BLOCKING_TEXT_SIZE = 200
local MIN_BLOCKING_TEXT_OFFSET_X = -600
local MAX_BLOCKING_TEXT_OFFSET_X = 600
local MIN_BLOCKING_TEXT_OFFSET_Y = -600
local MAX_BLOCKING_TEXT_OFFSET_Y = 300
local function ClampNumber(value, lo, hi)
    value = tonumber(value) or lo
    if value < lo then value = lo end
    if value > hi then value = hi end
    return value
end
local KNOWN_ULTIMATE_FOLLOWUP_ABILITY_IDS =
{
    [114769] = "Power Overload",
}
local function IsUltimateAbility(abilityId)
    return IsAbilityUltimate(abilityId) or KNOWN_ULTIMATE_FOLLOWUP_ABILITY_IDS[abilityId] ~= nil
end
local function IsInTargetPvPZone()
    if IsInCyrodiil() or IsInImperialCity() then
        return true
    end
    if PvPFPSLimiter.savedVars.includeBattlegrounds and IsActiveWorldBattleground() then
        return true
    end
    return false
end
local function IsPlayerDuelActive()
    local duelState = GetDuelInfo()
    return duelState == DUEL_STATE_DUELING
end
local function ClampFpsLimit(value)
    value = tonumber(value) or defaults.pveFpsLimit
    if value < MIN_FPS_LIMIT then value = MIN_FPS_LIMIT end
    if value > MAX_FPS_LIMIT then value = MAX_FPS_LIMIT end
    return zo_floor(value + 0.5)
end
local function SetFpsLimit(fps)
    local minFrameTime = string.format("%.8f", 1 / fps)
    SetCVar(MIN_FRAME_TIME_CVAR, minFrameTime)
end
local function GetCurrentFpsLimit()
    local minFrameTime = tonumber(GetCVar(MIN_FRAME_TIME_CVAR))
    return minFrameTime and zo_floor(1 / minFrameTime + 0.5) or nil
end
local function CaptureFpsLimitCvarSnapshot()
    if PvPFPSLimiter.savedVars.zoneFpsLimitsCvarSnapshot == nil then
        PvPFPSLimiter.savedVars.zoneFpsLimitsCvarSnapshot = GetCVar(MIN_FRAME_TIME_CVAR)
    end
end
local function RestoreFpsLimitCvarSnapshot()
    local snapshot = PvPFPSLimiter.savedVars.zoneFpsLimitsCvarSnapshot
    if snapshot ~= nil then
        SetCVar(MIN_FRAME_TIME_CVAR, snapshot)
        PvPFPSLimiter.savedVars.zoneFpsLimitsCvarSnapshot = nil
    end
end
local PERF_BOOST_SETTINGS =
{
    { id = GRAPHICS_SETTING_VIEW_DISTANCE,                        perfValueKey = "perfBoostViewDistance" },
    { id = GRAPHICS_SETTING_SHOW_ADDITIONAL_ALLY_EFFECTS,         perfValue = "false" },
    { id = GRAPHICS_SETTING_VFX_FRIENDLY_INTENSITY,               perfValue = VFX_INTENSITY_VALUE_MINIMAL },
    { id = GRAPHICS_SETTING_VFX_ENEMY_INTENSITY,                  perfValue = VFX_INTENSITY_VALUE_MINIMAL },
    { id = GRAPHICS_SETTING_SHADOWS,                              perfValue = SHADOWS_CHOICE_LOW },
    { id = GRAPHICS_SETTING_AMBIENT_OCCLUSION_TYPE,               perfValue = AMBIENT_OCCLUSION_TYPE_NONE },
    { id = GRAPHICS_SETTING_PLANAR_WATER_REFLECTION_QUALITY,      perfValue = PLANAR_WATER_REFLECTION_QUALITY_OFF },
    { id = GRAPHICS_SETTING_SCREENSPACE_WATER_REFLECTION_QUALITY, perfValue = SCREENSPACE_WATER_REFLECTION_QUALITY_OFF },
    { id = GRAPHICS_SETTING_CLUTTER_2D_QUALITY,                   perfValue = CLUTTER_QUALITY_LOW },
    { id = GRAPHICS_SETTING_DISTORTION,                           perfValue = "false" },
    { id = GRAPHICS_SETTING_GOD_RAYS,                             perfValue = "false" },
}
local function CaptureGraphicsSnapshot()
    local snapshot = {}
    for _, entry in ipairs(PERF_BOOST_SETTINGS) do
        snapshot[entry.id] = GetSetting(SETTING_TYPE_GRAPHICS, entry.id)
    end
    return snapshot
end
local function ApplyPerformanceBoostValues()
    for _, entry in ipairs(PERF_BOOST_SETTINGS) do
        local value = entry.perfValueKey and PvPFPSLimiter.savedVars[entry.perfValueKey] or entry.perfValue
        SetSetting(SETTING_TYPE_GRAPHICS, entry.id, tostring(value))
    end
    ApplySettings()
end
local function RestoreGraphicsSnapshot()
    local snapshot = PvPFPSLimiter.savedVars.perfBoostSnapshot
    if not snapshot then return end
    for _, entry in ipairs(PERF_BOOST_SETTINGS) do
        local value = snapshot[entry.id]
        if value ~= nil then
            SetSetting(SETTING_TYPE_GRAPHICS, entry.id, value)
        end
    end
    ApplySettings()
    PvPFPSLimiter.savedVars.perfBoostSnapshot = nil
end
local function ApplyPerformanceBoostForCurrentZone(inPvPZone)
    if not PvPFPSLimiter.savedVars.perfBoostEnabled then
        if PvPFPSLimiter.savedVars.perfBoostApplied then
            RestoreGraphicsSnapshot()
            PvPFPSLimiter.savedVars.perfBoostApplied = false
            if PvPFPSLimiter.savedVars.debug then
                d("|c33cc33[LPI]|r Performance Boost was turned off - restored your normal graphics settings.")
            end
        end
        return
    end
    if inPvPZone then
        if not PvPFPSLimiter.savedVars.perfBoostApplied then
            PvPFPSLimiter.savedVars.perfBoostSnapshot = CaptureGraphicsSnapshot()
            ApplyPerformanceBoostValues()
            PvPFPSLimiter.savedVars.perfBoostApplied = true
            if PvPFPSLimiter.savedVars.debug then
                d("|c33cc33[LPI]|r Performance Boost applied for this PvP zone (your previous settings were saved).")
            end
        end
    else
        if PvPFPSLimiter.savedVars.perfBoostApplied then
            RestoreGraphicsSnapshot()
            PvPFPSLimiter.savedVars.perfBoostApplied = false
            if PvPFPSLimiter.savedVars.debug then
                d("|c33cc33[LPI]|r Left the PvP zone - restored your normal graphics settings.")
            end
        end
    end
end
local function OnCampaignQueueStateChanged(eventCode, campaignId, isGroup, state)
    if not PvPFPSLimiter.savedVars.autoAcceptQueueEnabled then return end
    if state ~= CAMPAIGN_QUEUE_REQUEST_STATE_CONFIRMING then return end
    ConfirmCampaignEntry(campaignId, isGroup, true)
    if PvPFPSLimiter.savedVars.debug then
        d(string.format("|c33cc33[LPI]|r Auto-accepted the campaign queue pop (campaign %s, %s queue).",
            tostring(campaignId), isGroup and "group" or "solo"))
    end
end
local FLOATING_TEXT_POOL_SIZE = 4
local FLOATING_TEXT_RISE_PX = 70
local floatingTextPool = {}
local floatingTextNextIndex = 1
local floatingTextTopLevelWindow = nil
local function GetFloatingTextTopLevelWindow()
    if not floatingTextTopLevelWindow then
        floatingTextTopLevelWindow = WINDOW_MANAGER:CreateTopLevelWindow(ADDON_NAME .. "FloatingTextTopLevel")
        floatingTextTopLevelWindow:SetHidden(false) -- the container itself always stays visible; individual labels are shown/hidden
    end
    return floatingTextTopLevelWindow
end
local function GetFloatingTextSlot()
    local slot = floatingTextPool[floatingTextNextIndex]
    if not slot then
        local control = WINDOW_MANAGER:CreateControl("LPI_PvPToolsFloatText" .. floatingTextNextIndex, GetFloatingTextTopLevelWindow(), CT_LABEL)
        control:SetFont("ZoFontGameLargeBold") -- overwritten per-show in ShowFloatingNotification to reflect the current text-size setting; this initial value just avoids a blank font before the first show
        control:SetDrawLayer(DL_OVERLAY)
        control:SetDrawTier(DT_HIGH)
        control:SetHidden(true)
        slot = { control = control, timeline = nil }
        floatingTextPool[floatingTextNextIndex] = slot
    end
    floatingTextNextIndex = (floatingTextNextIndex % FLOATING_TEXT_POOL_SIZE) + 1
    return slot
end
local function ShowFloatingNotification(message, r, g, b, sizeOverride, durationSecondsOverride)
    r, g, b = r or 1, g or 0.65, b or 0.1 -- default to orange if no color is given
    local slot = GetFloatingTextSlot()
    local control = slot.control
    if slot.timeline then
        slot.timeline:Stop()
    end
    local size = sizeOverride or ClampNumber(PvPFPSLimiter.savedVars.notifyTextSize, MIN_NOTIFY_TEXT_SIZE, MAX_NOTIFY_TEXT_SIZE)
    local offsetX = ClampNumber(PvPFPSLimiter.savedVars.notifyTextOffsetX, MIN_NOTIFY_TEXT_OFFSET_X, MAX_NOTIFY_TEXT_OFFSET_X)
    local offsetY = ClampNumber(PvPFPSLimiter.savedVars.notifyTextOffsetY, MIN_NOTIFY_TEXT_OFFSET_Y, MAX_NOTIFY_TEXT_OFFSET_Y)
    local durationMs = (durationSecondsOverride or
        ClampNumber(PvPFPSLimiter.savedVars.notifyTextDurationSeconds, MIN_NOTIFY_TEXT_DURATION_SECONDS, MAX_NOTIFY_TEXT_DURATION_SECONDS)) * 1000
    control:SetFont(string.format("$(BOLD_FONT)|%d|soft-shadow-thick", size))
    control:ClearAnchors()
    control:SetAnchor(CENTER, GuiRoot, CENTER, offsetX, offsetY)
    control:SetColor(r, g, b, 1)
    control:SetText(message)
    control:SetAlpha(1)
    control:SetHidden(false)
    local timeline = ANIMATION_MANAGER:CreateTimeline()
    local translate = timeline:InsertAnimation(ANIMATION_TRANSLATE, control, 0)
    translate:SetTranslateOffsets(0, offsetY, 0, offsetY - FLOATING_TEXT_RISE_PX)
    translate:SetDuration(durationMs)
    local fade = timeline:InsertAnimation(ANIMATION_ALPHA, control, durationMs * 0.3)
    fade:SetAlphaValues(1, 0)
    fade:SetDuration(durationMs * 0.7)
    timeline:SetHandler("OnStop", function()
        control:SetHidden(true)
    end)
    slot.timeline = timeline
    timeline:PlayFromStart()
end
local lastMessageShownAt = {} -- key: exact rendered message text -> GetGameTimeMilliseconds() of last time it was shown
local function ShowPvPNotification(message, r, g, b, mode)
    if mode == nil or mode == NOTIFY_MODE_OFF then return end
    local suppressMs = ClampNumber(PvPFPSLimiter.savedVars.duplicateMessageSuppressSeconds,
        MIN_DUPLICATE_SUPPRESS_SECONDS, MAX_DUPLICATE_SUPPRESS_SECONDS) * 1000
    if suppressMs > 0 then
        local now = GetGameTimeMilliseconds()
        local last = lastMessageShownAt[message]
        if last and (now - last) < suppressMs then
            return -- exact same message shown too recently - skip entirely, regardless of mode
        end
        lastMessageShownAt[message] = now
    end
    if mode == NOTIFY_MODE_CHAT or mode == NOTIFY_MODE_BOTH then
        d("|cff6600[LPI]|r " .. message)
    end
    if mode == NOTIFY_MODE_NOTIFICATION or mode == NOTIFY_MODE_BOTH then
        local floatOk, floatErr = pcall(ShowFloatingNotification, message, r, g, b)
        if not floatOk then
            d("|cffff00[LPI]|r Floating text display failed (" .. tostring(floatErr) ..
                ") - showing the on-screen alert banner instead this time. Please copy/paste this exact error so it can be fixed.")
            ZO_Alert(UI_ALERT_CATEGORY_ALERT, NO_SOUND, message)
        end
    end
end
local function ShowCriticalAlert(message, r, g, b, mode, durationSecondsOverride)
    if mode == nil or mode == NOTIFY_MODE_OFF then return end
    if mode == NOTIFY_MODE_CHAT or mode == NOTIFY_MODE_BOTH then
        d("|cff0000[LPI CRITICAL]|r " .. message)
    end
    if mode == NOTIFY_MODE_NOTIFICATION or mode == NOTIFY_MODE_BOTH then
        local size = ClampNumber(PvPFPSLimiter.savedVars.criticalTextSize, MIN_CRITICAL_TEXT_SIZE, MAX_CRITICAL_TEXT_SIZE)
        local floatOk, floatErr = pcall(ShowFloatingNotification, message, r, g, b, size, durationSecondsOverride)
        if not floatOk then
            d("|cffff00[LPI]|r Critical alert floating text display failed (" .. tostring(floatErr) ..
                ") - showing the on-screen alert banner instead this time. Please copy/paste this exact error so it can be fixed.")
            ZO_Alert(UI_ALERT_CATEGORY_ALERT, NO_SOUND, message)
        end
    end
end
function PvPFPSLimiter.ShowScreenAlert(message, r, g, b, seconds)
    ShowCriticalAlert(message, r, g, b, NOTIFY_MODE_NOTIFICATION, seconds)
end
local function StripIndirectSourceAsterisk(name)
    return (name:gsub("%s*%*+%s*$", ""))
end
local function CleanDisplayName(name)
    if not name or name == "" then return name end
    local ok, cleaned = pcall(zo_strformat, "<<1>>", name)
    if ok and cleaned and cleaned ~= "" then
        name = cleaned
    end
    return StripIndirectSourceAsterisk(name)
end
local function PlainReplace(str, find, replace)
    local out, searchStart = {}, 1
    while true do
        local s, e = str:find(find, searchStart, true) -- true = plain/literal find, no pattern matching
        if not s then
            table.insert(out, str:sub(searchStart))
            break
        end
        table.insert(out, str:sub(searchStart, s - 1))
        table.insert(out, replace)
        searchStart = e + 1
    end
    return table.concat(out)
end
local function ApplyNotificationTemplate(template, placeholders)
    local text = template or ""
    for key, value in pairs(placeholders) do
        text = PlainReplace(text, "{" .. key .. "}", tostring(value))
    end
    if placeholders.accountname ~= nil then
        text = PlainReplace(text, "@accountname", tostring(placeholders.accountname))
    end
    return text
end
local ABILITY_ID_BREAK_FREE = 16565
local BREAK_FREE_ABILITY_TYPE_NAMES = {
    [ABILITY_TYPE_STUN] = "Stun",
    [ABILITY_TYPE_FEAR] = "Fear",
    [ABILITY_TYPE_KNOCKBACK] = "Knockback",
}
local BREAK_FREE_ALERT_OFFSET_Y = -120
local breakFreeAlertControl = nil
local activeBreakFreeCc = {}
local function IsBreakFreeAlertZoneAllowed()
    if not PvPFPSLimiter.savedVars.breakFreeAlertPvpOnly then return true end
    return IsInTargetPvPZone() or IsPlayerDuelActive()
end
local breakFreeAlertTopLevelWindow = nil
local function GetBreakFreeAlertTopLevelWindow()
    if not breakFreeAlertTopLevelWindow then
        breakFreeAlertTopLevelWindow = WINDOW_MANAGER:CreateTopLevelWindow(ADDON_NAME .. "BreakFreeAlertTopLevel")
        breakFreeAlertTopLevelWindow:SetHidden(false) -- the container itself always stays visible; the label inside is shown/hidden
    end
    return breakFreeAlertTopLevelWindow
end
local function EnsureBreakFreeAlertControlCreated()
    if breakFreeAlertControl then return end
    breakFreeAlertControl = WINDOW_MANAGER:CreateControl(ADDON_NAME .. "BreakFreeAlert", GetBreakFreeAlertTopLevelWindow(), CT_LABEL)
    breakFreeAlertControl:SetDrawLayer(DL_OVERLAY)
    breakFreeAlertControl:SetDrawTier(DT_HIGH)
    breakFreeAlertControl:SetHidden(true)
end
local BREAK_FREE_DISPLAY_ORDER = { "Stun", "Fear", "Knockback", "Charm" }
local function GetActiveBreakFreeTypeNamesText()
    local present = {}
    for _, typeName in pairs(activeBreakFreeCc) do
        present[typeName] = true
    end
    local names = {}
    for _, typeName in ipairs(BREAK_FREE_DISPLAY_ORDER) do
        if present[typeName] then table.insert(names, typeName) end
    end
    return table.concat(names, ", ")
end
local BREAK_FREE_TYPE_DISPLAY_LABELS = {
    Stun = "STUNNED",
    Fear = "FEARED",
    Knockback = "KNOCKED BACK",
    Charm = "CHARMED",
}
local function GetActiveBreakFreeDisplayLabelsText()
    local present = {}
    for _, typeName in pairs(activeBreakFreeCc) do
        present[typeName] = true
    end
    local labels = {}
    for _, typeName in ipairs(BREAK_FREE_DISPLAY_ORDER) do
        if present[typeName] then table.insert(labels, BREAK_FREE_TYPE_DISPLAY_LABELS[typeName]) end
    end
    return table.concat(labels, ", ")
end
local function UpdateBreakFreeAlert()
    if next(activeBreakFreeCc) == nil or not PvPFPSLimiter.savedVars.showBreakFreeAlert then
        if breakFreeAlertControl then breakFreeAlertControl:SetHidden(true) end
        return
    end
    EnsureBreakFreeAlertControlCreated()
    local size = ClampNumber(PvPFPSLimiter.savedVars.breakFreeAlertTextSize, MIN_BREAKFREE_TEXT_SIZE, MAX_BREAKFREE_TEXT_SIZE)
    local c = PvPFPSLimiter.savedVars.breakFreeAlertColor
    local message = ApplyNotificationTemplate(PvPFPSLimiter.savedVars.breakFreeAlertText,
        { type = GetActiveBreakFreeDisplayLabelsText() })
    breakFreeAlertControl:SetFont(string.format("$(BOLD_FONT)|%d|soft-shadow-thick", size))
    breakFreeAlertControl:ClearAnchors()
    breakFreeAlertControl:SetAnchor(CENTER, GuiRoot, CENTER, 0, BREAK_FREE_ALERT_OFFSET_Y)
    breakFreeAlertControl:SetColor(c.r, c.g, c.b, 1)
    breakFreeAlertControl:SetText(message)
    breakFreeAlertControl:SetHidden(false)
end
local function AddActiveBreakFreeCc(abilityId, typeName)
    if activeBreakFreeCc[abilityId] == typeName then return end -- already tracked identically; avoid a pointless re-render
    local wasFree = next(activeBreakFreeCc) == nil
    activeBreakFreeCc[abilityId] = typeName
    if wasFree and PvPFPSLimiter.savedVars.breakFreeChat then
        d("|cff3333[LPI] BREAK FREE|r (" .. tostring(typeName) .. ")")
    end
    UpdateBreakFreeAlert()
end
local function RemoveActiveBreakFreeCc(abilityId)
    if activeBreakFreeCc[abilityId] == nil then return end
    activeBreakFreeCc[abilityId] = nil
    UpdateBreakFreeAlert()
end
local function ClearAllActiveBreakFreeCc()
    if next(activeBreakFreeCc) == nil then return end
    activeBreakFreeCc = {}
    UpdateBreakFreeAlert()
end
local BLOCKING_ALERT_POLL_MS = 100
local blockingAlertControl = nil
local blockingAlertCurrentlyShown = false
local blockingAlertTopLevelWindow = nil
local function GetBlockingAlertTopLevelWindow()
    if not blockingAlertTopLevelWindow then
        blockingAlertTopLevelWindow = WINDOW_MANAGER:CreateTopLevelWindow(ADDON_NAME .. "BlockingAlertTopLevel")
        blockingAlertTopLevelWindow:SetHidden(false) -- the container itself always stays visible; the label inside is shown/hidden
    end
    return blockingAlertTopLevelWindow
end
local function EnsureBlockingAlertControlCreated()
    if blockingAlertControl then return end
    blockingAlertControl = WINDOW_MANAGER:CreateControl(ADDON_NAME .. "BlockingAlert", GetBlockingAlertTopLevelWindow(), CT_LABEL)
    blockingAlertControl:SetDrawLayer(DL_OVERLAY)
    blockingAlertControl:SetDrawTier(DT_HIGH)
    blockingAlertControl:SetHidden(true)
end
local function IsBlockingAlertZoneAllowed()
    if not PvPFPSLimiter.savedVars.blockingAlertPvpOnly then return true end
    return IsInTargetPvPZone() or IsPlayerDuelActive()
end
local function RefreshBlockingAlertAppearance()
    if not blockingAlertControl then return end
    local size = ClampNumber(PvPFPSLimiter.savedVars.blockingAlertTextSize, MIN_BLOCKING_TEXT_SIZE, MAX_BLOCKING_TEXT_SIZE)
    local c = PvPFPSLimiter.savedVars.blockingAlertColor
    blockingAlertControl:SetFont(string.format("$(BOLD_FONT)|%d|soft-shadow-thick", size))
    blockingAlertControl:ClearAnchors()
    blockingAlertControl:SetAnchor(CENTER, GuiRoot, CENTER,
        PvPFPSLimiter.savedVars.blockingAlertOffsetX, PvPFPSLimiter.savedVars.blockingAlertOffsetY)
    blockingAlertControl:SetColor(c.r, c.g, c.b, 1)
    blockingAlertControl:SetText(PvPFPSLimiter.savedVars.blockingAlertText)
end
local blockingChatActive = false
local function UpdateBlockingAlertState()
    local blockChat = PvPFPSLimiter.savedVars.blockingChat and IsBlockingAlertZoneAllowed() and IsBlockActive()
    if blockChat and not blockingChatActive then d("|c4d99ff[LPI] Blocking|r") end
    blockingChatActive = blockChat and true or false
    local shouldShow = PvPFPSLimiter.savedVars.showBlockingAlert
        and IsBlockingAlertZoneAllowed()
        and IsBlockActive()
    if shouldShow == blockingAlertCurrentlyShown then return end
    blockingAlertCurrentlyShown = shouldShow
    if not shouldShow then
        if blockingAlertControl then blockingAlertControl:SetHidden(true) end
        return
    end
    EnsureBlockingAlertControlCreated()
    RefreshBlockingAlertAppearance()
    blockingAlertControl:SetHidden(false)
end
local function OnPlayerEffectChanged(_, changeType, _, effectName, _, _, _, _, _, buffType, _, abilityType, _, _, _, abilityId, _)
    if PvPFPSLimiter.savedVars.debug then
        d(string.format("|cffff00[LPI DEBUG]|r EVENT_EFFECT_CHANGED on player: effect=\"%s\" (abilityId %s) | changeType=%s | abilityType=%s | buffType=%s | MatchesBreakFreeType=%s | showBreakFreeAlert=%s | ZoneAllowed=%s",
            tostring(effectName), tostring(abilityId), tostring(changeType), tostring(abilityType), tostring(buffType),
            tostring(BREAK_FREE_ABILITY_TYPE_NAMES[abilityType] ~= nil),
            tostring(PvPFPSLimiter.savedVars.showBreakFreeAlert), tostring(IsBreakFreeAlertZoneAllowed())))
    end
    if not (PvPFPSLimiter.savedVars.showBreakFreeAlert or PvPFPSLimiter.savedVars.breakFreeChat) then return end
    if not IsBreakFreeAlertZoneAllowed() then return end
    local typeName = BREAK_FREE_ABILITY_TYPE_NAMES[abilityType]
    if not typeName then return end -- not one of the three types tracked this way (includes Disorient, deliberately excluded - see comment above)
    if changeType == EFFECT_RESULT_FADED then
        RemoveActiveBreakFreeCc(abilityId)
    elseif changeType == EFFECT_RESULT_GAINED or changeType == EFFECT_RESULT_FULL_REFRESH or changeType == EFFECT_RESULT_UPDATED then
        AddActiveBreakFreeCc(abilityId, typeName)
    end
end
local function IsNameInMyGroup(name)
    if not name or name == "" then return false end
    local groupSize = GetGroupSize()
    for i = 1, groupSize do
        local tag = GetGroupUnitTagByIndex(i)
        if tag and GetRawUnitName(tag) == name then
            return true
        end
    end
    return false
end
local function IsEnemySource(sourceName, playerName)
    return sourceName ~= nil and sourceName ~= "" and sourceName ~= playerName and not IsNameInMyGroup(sourceName)
end
local function TryResolveRealAccountHandle(characterName)
    if not characterName or characterName == "" then return nil end
    if not DoesUnitExist("reticleover") then return nil end
    if GetRawUnitName("reticleover") ~= characterName then return nil end
    local ok, handle = pcall(GetUnitDisplayName, "reticleover")
    if ok and handle ~= nil and handle ~= "" and handle ~= "@" then
        return handle
    end
    return nil
end
local criticalDelayedParsedCache = { raw = nil, parsed = nil }
local function GetParsedDelayedAbilities()
    local raw = PvPFPSLimiter.savedVars.criticalDelayedAbilityList or ""
    if criticalDelayedParsedCache.raw == raw then
        return criticalDelayedParsedCache.parsed
    end
    local parsed = {}
    for line in (raw .. "\n"):gmatch("([^\n]*)\n") do
        local name, stagesStr = line:match("^%s*(.-)%s*=%s*(.-)%s*$")
        if name and name ~= "" and stagesStr and stagesStr ~= "" then
            local stages = {}
            for numStr in stagesStr:gmatch("[^,]+") do
                local num = tonumber((numStr:gsub("%s+", "")))
                if num and num > 0 then
                    table.insert(stages, num)
                end
            end
            if #stages > 0 then
                parsed[name:lower()] = stages
            end
        end
    end
    criticalDelayedParsedCache.raw = raw
    criticalDelayedParsedCache.parsed = parsed
    return parsed
end
local criticalAoeParsedCache = { raw = nil, parsed = nil }
local function GetParsedAoeAbilities()
    local raw = PvPFPSLimiter.savedVars.criticalAoeAbilityList or ""
    if criticalAoeParsedCache.raw == raw then
        return criticalAoeParsedCache.parsed
    end
    local parsed = { names = {}, ids = {} }
    for rawEntry in raw:gmatch("[^,\n]+") do
        local entry = rawEntry:match("^%s*(.-)%s*$")
        if entry ~= "" then
            local id = entry:match("^%d+$")
            if id then
                parsed.ids[tonumber(id)] = true
            else
                parsed.names[entry:lower()] = true
            end
        end
    end
    criticalAoeParsedCache.raw = raw
    criticalAoeParsedCache.parsed = parsed
    return parsed
end
local function IsCriticalAoeUltimateAbility(abilityName, abilityId)
    local parsed = GetParsedAoeAbilities()
    if abilityId and parsed.ids[abilityId] then
        return true
    end
    if not abilityName or abilityName == "" then return false end
    return parsed.names[CleanDisplayName(abilityName):lower()] == true
end
local criticalDelayedScheduledUntil = {}
local function ScheduleCriticalDelayedAlert(abilityNameLower, abilityDisplay, sourceDisplay)
    local stages = GetParsedDelayedAbilities()[abilityNameLower]
    if not stages then return end
    local now = GetGameTimeMilliseconds()
    local cooldownUntil = criticalDelayedScheduledUntil[abilityNameLower]
    if cooldownUntil and now < cooldownUntil then
        return -- still mid-cascade for this ability - this is presumably one of its own later hits, not a brand new cast
    end
    local leadSeconds = ClampNumber(PvPFPSLimiter.savedVars.criticalDelayedLeadSeconds, MIN_CRITICAL_SECONDS, MAX_CRITICAL_SECONDS)
    local alertDurationSeconds = ClampNumber(PvPFPSLimiter.savedVars.criticalDelayedAlertDurationSeconds, MIN_CRITICAL_SECONDS, MAX_CRITICAL_SECONDS)
    local mode = PvPFPSLimiter.savedVars.criticalDelayedMode
    local message = ApplyNotificationTemplate(PvPFPSLimiter.savedVars.criticalDelayedText,
        { source = sourceDisplay, ability = abilityDisplay, accountname = sourceDisplay })
    local c = PvPFPSLimiter.savedVars.criticalDelayedColor
    local maxStage = 0
    for _, stageSeconds in ipairs(stages) do
        if stageSeconds > maxStage then maxStage = stageSeconds end
        local fireAtMs = math.floor(math.max(0, stageSeconds - leadSeconds) * 1000 + 0.5)
        zo_callLater(function()
            ShowCriticalAlert(message, c.r, c.g, c.b, mode, alertDurationSeconds)
        end, fireAtMs)
    end
    criticalDelayedScheduledUntil[abilityNameLower] = now + (maxStage + 1) * 1000
    if PvPFPSLimiter.savedVars.debug then
        d(string.format("|cffff00[LPI DEBUG]|r Critical delayed-ability cascade scheduled for \"%s\" from %s: %d hit(s), warning %gs before each.",
            abilityDisplay, tostring(sourceDisplay), #stages, leadSeconds))
    end
end
local function OnPvPNotificationCombatEvent(eventCode, result, isError, abilityName, abilityGraphic,
    abilityActionSlotType, sourceName, sourceType, targetName, targetType, hitValue, powerType,
    damageType, log, sourceUnitId, targetUnitId, abilityId, overflow)
    local playerName = GetRawUnitName("player")
    if (PvPFPSLimiter.savedVars.showBreakFreeAlert or PvPFPSLimiter.savedVars.breakFreeChat) and IsBreakFreeAlertZoneAllowed()
        and targetType == COMBAT_UNIT_TYPE_PLAYER and targetName == playerName then
        if result == ACTION_RESULT_CHARMED then
            AddActiveBreakFreeCc(abilityId, "Charm")
        elseif result == ACTION_RESULT_EFFECT_FADED and activeBreakFreeCc[abilityId] == "Charm" then
            RemoveActiveBreakFreeCc(abilityId)
        end
    end
    if (PvPFPSLimiter.savedVars.showBreakFreeAlert or PvPFPSLimiter.savedVars.breakFreeChat) and IsBreakFreeAlertZoneAllowed()
        and sourceType == COMBAT_UNIT_TYPE_PLAYER and sourceName == playerName
        and abilityId == ABILITY_ID_BREAK_FREE then
        ClearAllActiveBreakFreeCc()
    end
    if PvPFPSLimiter.savedVars.debug and sourceType == COMBAT_UNIT_TYPE_PLAYER and sourceName == playerName
        and abilityId == ABILITY_ID_BREAK_FREE then
        d(string.format("|cffff00[LPI DEBUG]|r Break Free action (ability %d) detected - force-clearing all tracked CC. result=%s",
            ABILITY_ID_BREAK_FREE, tostring(result)))
    end
    if PvPFPSLimiter.savedVars.debug and targetType == COMBAT_UNIT_TYPE_PLAYER and targetName == playerName
        and (result == ACTION_RESULT_STUNNED or result == ACTION_RESULT_ROOTED or result == ACTION_RESULT_CHARMED
            or result == ACTION_RESULT_FEARED or result == ACTION_RESULT_DISORIENTED
            or result == ACTION_RESULT_SILENCED or result == ACTION_RESULT_SNARED
            or result == ACTION_RESULT_EFFECT_FADED) then
        d(string.format("|cffff00[LPI DEBUG]|r EVENT_COMBAT_EVENT CC-family result on player: result=%s | source=%s (sourceType=%s) | ability=\"%s\" (abilityId %s) | InPvPZoneOrDuel=%s",
            tostring(result), tostring(sourceName), tostring(sourceType), tostring(abilityName), tostring(abilityId),
            tostring(IsInTargetPvPZone() or IsPlayerDuelActive())))
    end
    if not (IsInTargetPvPZone() or IsPlayerDuelActive()) then return end
    if PvPFPSLimiter.savedVars.debug
        and targetType == COMBAT_UNIT_TYPE_PLAYER
        and targetName == playerName then
        d(string.format("|cffff00[LPI DEBUG]|r Affected by %s (sourceType=%s) with \"%s\" (abilityId %s) | result=%s | IsAbilityUltimate=%s | MatchedKnownFollowup=%s | IsStunResult=%s | IsImmobilizeResult=%s | IsNameInMyGroup=%s | notifyUltimateMode=%s",
            tostring(sourceName), tostring(sourceType), tostring(abilityName), tostring(abilityId),
            tostring(result), tostring(IsAbilityUltimate(abilityId)),
            tostring(KNOWN_ULTIMATE_FOLLOWUP_ABILITY_IDS[abilityId] ~= nil),
            tostring(result == ACTION_RESULT_STUNNED), tostring(result == ACTION_RESULT_ROOTED),
            tostring(IsNameInMyGroup(sourceName)),
            tostring(PvPFPSLimiter.savedVars.notifyUltimateMode)))
    end
    if PvPFPSLimiter.savedVars.notifyBlockingMode ~= NOTIFY_MODE_OFF
        and sourceType == COMBAT_UNIT_TYPE_PLAYER
        and sourceName == playerName
        and (result == ACTION_RESULT_BLOCKED or result == ACTION_RESULT_BLOCKED_DAMAGE) then
        local targetDisplay = CleanDisplayName((targetName ~= nil and targetName ~= "") and targetName or "Your target")
        local accountDisplay = TryResolveRealAccountHandle(targetName) or targetDisplay
        local message = ApplyNotificationTemplate(PvPFPSLimiter.savedVars.notifyBlockingText,
            { target = targetDisplay, accountname = accountDisplay })
        local c = PvPFPSLimiter.savedVars.notifyBlockingColor
        ShowPvPNotification(message, c.r, c.g, c.b, PvPFPSLimiter.savedVars.notifyBlockingMode)
    end
    if PvPFPSLimiter.savedVars.notifyUltimateMode ~= NOTIFY_MODE_OFF
        and targetType == COMBAT_UNIT_TYPE_PLAYER
        and targetName == playerName
        and IsEnemySource(sourceName, playerName)
        and IsUltimateAbility(abilityId)
        and not IsCriticalAoeUltimateAbility(abilityName, abilityId) then
        local sourceDisplay = CleanDisplayName((sourceName ~= nil and sourceName ~= "") and sourceName or "An enemy")
        local abilityDisplay = CleanDisplayName((abilityName ~= nil and abilityName ~= "") and abilityName or "an ultimate")
        local message = ApplyNotificationTemplate(PvPFPSLimiter.savedVars.notifyUltimateText,
            { source = sourceDisplay, ability = abilityDisplay, accountname = sourceDisplay })
        local c = PvPFPSLimiter.savedVars.notifyUltimateColor
        ShowPvPNotification(message, c.r, c.g, c.b, PvPFPSLimiter.savedVars.notifyUltimateMode)
    end
    if PvPFPSLimiter.savedVars.criticalAoeMode ~= NOTIFY_MODE_OFF
        and targetType == COMBAT_UNIT_TYPE_PLAYER
        and targetName == playerName
        and IsEnemySource(sourceName, playerName)
        and (result == ACTION_RESULT_DAMAGE or result == ACTION_RESULT_BLOCKED_DAMAGE
            or result == ACTION_RESULT_BLOCKED or result == ACTION_RESULT_CRITICAL_DAMAGE
            or result == ACTION_RESULT_DOT_TICK or result == ACTION_RESULT_DOT_TICK_CRITICAL)
        and IsCriticalAoeUltimateAbility(abilityName, abilityId) then
        if PvPFPSLimiter.savedVars.debug then
            d(string.format("|cffff00[LPI DEBUG]|r Critical AOE-ultimate trigger seen: \"%s\" from %s (result=%s).",
                CleanDisplayName(abilityName), tostring(sourceName), tostring(result)))
        end
        local sourceDisplay = CleanDisplayName((sourceName ~= nil and sourceName ~= "") and sourceName or "An enemy")
        local abilityDisplay = CleanDisplayName(abilityName)
        local message = ApplyNotificationTemplate(PvPFPSLimiter.savedVars.criticalAoeText,
            { source = sourceDisplay, ability = abilityDisplay, accountname = sourceDisplay })
        local c = PvPFPSLimiter.savedVars.criticalAoeColor
        local graceSeconds = ClampNumber(PvPFPSLimiter.savedVars.criticalAoeGraceSeconds, MIN_CRITICAL_SECONDS, MAX_CRITICAL_SECONDS)
        ShowCriticalAlert(message, c.r, c.g, c.b, PvPFPSLimiter.savedVars.criticalAoeMode, graceSeconds)
    end
    if PvPFPSLimiter.savedVars.criticalDelayedMode ~= NOTIFY_MODE_OFF
        and targetType == COMBAT_UNIT_TYPE_PLAYER
        and targetName == playerName
        and IsEnemySource(sourceName, playerName)
        and abilityName and abilityName ~= "" then
        local abilityNameLower = CleanDisplayName(abilityName):lower()
        if GetParsedDelayedAbilities()[abilityNameLower] then
            local sourceDisplay = CleanDisplayName((sourceName ~= nil and sourceName ~= "") and sourceName or "An enemy")
            local abilityDisplay = CleanDisplayName(abilityName)
            if PvPFPSLimiter.savedVars.debug then
                d(string.format("|cffff00[LPI DEBUG]|r Critical delayed-ability trigger seen: \"%s\" from %s (result=%s).",
                    abilityDisplay, tostring(sourceName), tostring(result)))
            end
            ScheduleCriticalDelayedAlert(abilityNameLower, abilityDisplay, sourceDisplay)
        end
    end
    if PvPFPSLimiter.savedVars.notifyStunnedMode ~= NOTIFY_MODE_OFF
        and targetType == COMBAT_UNIT_TYPE_PLAYER
        and targetName == playerName
        and result == ACTION_RESULT_STUNNED
        and IsEnemySource(sourceName, playerName) then
        local sourceDisplay = CleanDisplayName((sourceName ~= nil and sourceName ~= "") and sourceName or "An enemy")
        local abilityDisplay = CleanDisplayName((abilityName ~= nil and abilityName ~= "") and abilityName or "an ability")
        local message = ApplyNotificationTemplate(PvPFPSLimiter.savedVars.notifyStunnedText,
            { source = sourceDisplay, ability = abilityDisplay, accountname = sourceDisplay })
        local c = PvPFPSLimiter.savedVars.notifyStunnedColor
        ShowPvPNotification(message, c.r, c.g, c.b, PvPFPSLimiter.savedVars.notifyStunnedMode)
    end
    if PvPFPSLimiter.savedVars.notifyImmobilizedMode ~= NOTIFY_MODE_OFF
        and targetType == COMBAT_UNIT_TYPE_PLAYER
        and targetName == playerName
        and result == ACTION_RESULT_ROOTED
        and IsEnemySource(sourceName, playerName) then
        local sourceDisplay = CleanDisplayName((sourceName ~= nil and sourceName ~= "") and sourceName or "An enemy")
        local abilityDisplay = CleanDisplayName((abilityName ~= nil and abilityName ~= "") and abilityName or "an ability")
        local message = ApplyNotificationTemplate(PvPFPSLimiter.savedVars.notifyImmobilizedText,
            { source = sourceDisplay, ability = abilityDisplay, accountname = sourceDisplay })
        local c = PvPFPSLimiter.savedVars.notifyImmobilizedColor
        ShowPvPNotification(message, c.r, c.g, c.b, PvPFPSLimiter.savedVars.notifyImmobilizedMode)
    end
end
local function ApplyZoneSettings()
    local inPvPZone = IsInTargetPvPZone()
    if not PvPFPSLimiter.savedVars.zoneFpsLimitsEnabled then
        RestoreFpsLimitCvarSnapshot()
        PvPFPSLimiter.currentLimit = nil
        PvPFPSLimiter.currentlyInPvPZone = inPvPZone
        if PvPFPSLimiter.savedVars.debug then
            d("|c33cc33[LPI]|r Zone FPS Limits is off - no FPS cap applied.")
        end
        ApplyPerformanceBoostForCurrentZone(inPvPZone)
        return
    end
    CaptureFpsLimitCvarSnapshot()
    local targetLimit = inPvPZone and PvPFPSLimiter.savedVars.pvpFpsLimit or PvPFPSLimiter.savedVars.pveFpsLimit
    targetLimit = ClampFpsLimit(targetLimit)
    SetFpsLimit(targetLimit)
    PvPFPSLimiter.currentLimit = targetLimit
    PvPFPSLimiter.currentlyInPvPZone = inPvPZone
    if PvPFPSLimiter.savedVars.debug then
        d(string.format("|c33cc33[LPI]|r FPS limit set to %d (%s) - CVar now reads %s",
            targetLimit, inPvPZone and "PvP zone" or "PvE/default zone",
            tostring(GetCurrentFpsLimit())))
    end
    ApplyPerformanceBoostForCurrentZone(inPvPZone)
end
local function ProjectWorldPositionToScreen(camX, camY, camZ, fwdX, fwdY, fwdZ,
    rightX, rightY, rightZ, upX, upY, upZ, worldX, worldY, worldZ)
    local relX, relY, relZ = worldX - camX, worldY - camY, worldZ - camZ
    local pRight   = relX * rightX + relY * rightY + relZ * rightZ
    local pUp      = relX * upX    + relY * upY    + relZ * upZ
    local pForward = relX * fwdX   + relY * fwdY   + relZ * fwdZ
    if pForward <= 0 then
        return nil, nil, pForward, false -- behind the camera - see the caller for why this is deliberately NOT given a screen position
    end
    local frustumW, frustumH = GetWorldDimensionsOfViewFrustumAtDepth(pForward)
    if not frustumW or frustumW == 0 or not frustumH or frustumH == 0 then
        return nil, nil, pForward, false
    end
    local uiW, uiH = GuiRoot:GetDimensions()
    local screenX = pRight * uiW / frustumW
    local screenY = -pUp * uiH / frustumH
    return screenX, screenY, pForward, true
end
local leaderMarkerWindow            -- WINDOW_MANAGER top-level window (3D-render-space-enabled), created once, lazily
local leaderMarkerOuterControl      -- outer ring - shown whenever the marker is visible and the leader is in front of the camera
local leaderMarkerInnerControl      -- smaller inner ring - shown only while the leader is FAR (not in group support range)
local leaderMarkerDotControl        -- center dot - shown only while the leader is FAR, alongside the inner ring
local leaderMarkerTurnBackControl   -- shown INSTEAD of the outer/inner/dot above when the leader is behind the camera
local leaderMarkerLoopRunning = false -- guard flag - see CheckLeaderMarkerWatchdog below for why this matters
local LEADER_MARKER_TICK_MS = 50
local LEADER_MARKER_ROTATE_DEGREES_PER_TICK = 0.6
local LEADER_MARKER_PULSE_PERIOD_TICKS = 100 -- one full grow/shrink cycle = LEADER_MARKER_TICK_MS * this (50ms * 100 = 5s)
local LEADER_MARKER_PULSE_AMPLITUDE = 0.08 -- +/- 8% size - v7.22.0: toned down from 12% as part of "much more subtle" (see below)
local LEADER_MARKER_TARGET_HEIGHT_OFFSET = 120
local LEADER_MARKER_INNER_SIZE_RATIO = 0.55 -- the far-only inner ring, as a ratio of the outer ring's size
local LEADER_MARKER_DOT_SIZE_RATIO = 0.12 -- the far-only center dot, as a ratio of the outer ring's size
local LEADER_MARKER_TURNBACK_SIZE_RATIO = 250 / 300 -- unchanged from v7.20.0 - still matches TDAddon's own reported turnback.dds proportion
local LEADER_MARKER_RING_ALPHA = 0.35
local LEADER_MARKER_DOT_ALPHA = 0.55
local leaderMarkerRotationDegrees = 0
local leaderMarkerPulseTick = 0
local function EnsureLeaderMarkerControlsCreated()
    if leaderMarkerWindow then return end
    leaderMarkerWindow = WINDOW_MANAGER:CreateTopLevelWindow(ADDON_NAME .. "LeaderMarkerTopLevel")
    leaderMarkerWindow:SetAnchorFill(GuiRoot)
    leaderMarkerWindow:Create3DRenderSpace()
    leaderMarkerWindow:SetHidden(true)
    leaderMarkerOuterControl = WINDOW_MANAGER:CreateControl(ADDON_NAME .. "LeaderMarkerOuter", leaderMarkerWindow, CT_TEXTURE)
    leaderMarkerOuterControl:SetTexture("LethalPVPInsights/textures/leader_marker_ring_outer.dds") -- v7.23.0: perforated/dashed ring, per direct user request
    leaderMarkerOuterControl:SetHidden(true)
    leaderMarkerInnerControl = WINDOW_MANAGER:CreateControl(ADDON_NAME .. "LeaderMarkerInner", leaderMarkerWindow, CT_TEXTURE)
    leaderMarkerInnerControl:SetTexture("LethalPVPInsights/textures/leader_marker_ring.dds") -- plain solid ring, unchanged - user asked to replace only the external/outer ring
    leaderMarkerInnerControl:SetHidden(true)
    leaderMarkerDotControl = WINDOW_MANAGER:CreateControl(ADDON_NAME .. "LeaderMarkerDot", leaderMarkerWindow, CT_TEXTURE)
    leaderMarkerDotControl:SetTexture("LethalPVPInsights/textures/leader_marker_dot.dds")
    leaderMarkerDotControl:SetHidden(true)
    leaderMarkerTurnBackControl = WINDOW_MANAGER:CreateControl(ADDON_NAME .. "LeaderMarkerTurnBack", leaderMarkerWindow, CT_TEXTURE)
    leaderMarkerTurnBackControl:SetTexture("LethalPVPInsights/textures/turnback.dds")
    leaderMarkerTurnBackControl:SetHidden(true)
end
local function ShouldShowLeaderMarkerForCurrentZone()
    if IsActiveWorldBattleground() then
        return PvPFPSLimiter.savedVars.showLeaderMarkerBattlegrounds
    end
    if IsInImperialCity() then
        return PvPFPSLimiter.savedVars.showLeaderMarkerImperialCity
    end
    if IsInCyrodiil() then
        return PvPFPSLimiter.savedVars.showLeaderMarkerCyrodiil
    end
    return false -- outside all three zones, the marker never shows, regardless of any of the three settings
end
local function ShouldShowLeaderMarker()
    if not ShouldShowLeaderMarkerForCurrentZone() then return false end
    if not IsUnitGrouped("player") then return false end
    if IsUnitGroupLeader("player") then return false end -- the leader doesn't need a marker pointing at themselves
    local leaderTag = GetGroupLeaderUnitTag()
    if not leaderTag or not DoesUnitExist(leaderTag) then return false end
    return true, leaderTag
end
local function HideLeaderMarker()
    if leaderMarkerOuterControl then leaderMarkerOuterControl:SetHidden(true) end
    if leaderMarkerInnerControl then leaderMarkerInnerControl:SetHidden(true) end
    if leaderMarkerDotControl then leaderMarkerDotControl:SetHidden(true) end
    if leaderMarkerTurnBackControl then leaderMarkerTurnBackControl:SetHidden(true) end
    if leaderMarkerWindow then leaderMarkerWindow:SetHidden(true) end
end
local function UpdateLeaderMarkerOnce()
    local show, leaderTag = ShouldShowLeaderMarker()
    if not show then
        HideLeaderMarker()
        leaderMarkerLoopRunning = false
        return -- chain stops here - see CheckLeaderMarkerWatchdog for how it restarts later
    end
    EnsureLeaderMarkerControlsCreated()
    leaderMarkerWindow:SetHidden(false)
    leaderMarkerRotationDegrees = (leaderMarkerRotationDegrees + LEADER_MARKER_ROTATE_DEGREES_PER_TICK) % 360
    leaderMarkerPulseTick = (leaderMarkerPulseTick + 1) % LEADER_MARKER_PULSE_PERIOD_TICKS
    local pulsePhase = (leaderMarkerPulseTick / LEADER_MARKER_PULSE_PERIOD_TICKS) * 2 * math.pi
    local pulseScale = 1 + LEADER_MARKER_PULSE_AMPLITUDE * math.sin(pulsePhase)
    local rotationRadians = math.rad(leaderMarkerRotationDegrees)
    local size = ClampNumber(PvPFPSLimiter.savedVars.leaderMarkerSize, MIN_LEADER_MARKER_SIZE, MAX_LEADER_MARKER_SIZE)
    local c = PvPFPSLimiter.savedVars.leaderMarkerColor
    Set3DRenderSpaceToCurrentCamera(leaderMarkerWindow:GetName())
    local camX, camY, camZ = GuiRender3DPositionToWorldPosition(leaderMarkerWindow:Get3DRenderSpaceOrigin())
    local fwdX, fwdY, fwdZ = leaderMarkerWindow:Get3DRenderSpaceForward()
    local rightX, rightY, rightZ = leaderMarkerWindow:Get3DRenderSpaceRight()
    local upX, upY, upZ = leaderMarkerWindow:Get3DRenderSpaceUp()
    local _, worldX, worldY, worldZ = GetUnitRawWorldPosition(leaderTag)
    worldY = worldY + LEADER_MARKER_TARGET_HEIGHT_OFFSET
    local screenX, screenY, _, inFront = ProjectWorldPositionToScreen(
        camX, camY, camZ, fwdX, fwdY, fwdZ, rightX, rightY, rightZ, upX, upY, upZ,
        worldX, worldY, worldZ)
    if inFront then
        local inSupportRange = IsUnitInGroupSupportRange(leaderTag)
        leaderMarkerTurnBackControl:SetHidden(true)
        leaderMarkerOuterControl:SetHidden(false)
        leaderMarkerOuterControl:SetDimensions(size * pulseScale, size * pulseScale)
        leaderMarkerOuterControl:SetColor(c.r, c.g, c.b, LEADER_MARKER_RING_ALPHA)
        leaderMarkerOuterControl:SetTransformRotationZ(rotationRadians)
        leaderMarkerOuterControl:ClearAnchors()
        leaderMarkerOuterControl:SetAnchor(CENTER, leaderMarkerWindow, CENTER, screenX, screenY)
        if inSupportRange then
            leaderMarkerInnerControl:SetHidden(true)
            leaderMarkerDotControl:SetHidden(true)
        else
            local innerSize = size * LEADER_MARKER_INNER_SIZE_RATIO
            leaderMarkerInnerControl:SetHidden(false)
            leaderMarkerInnerControl:SetDimensions(innerSize * pulseScale, innerSize * pulseScale)
            leaderMarkerInnerControl:SetColor(c.r, c.g, c.b, LEADER_MARKER_RING_ALPHA)
            leaderMarkerInnerControl:SetTransformRotationZ(rotationRadians)
            leaderMarkerInnerControl:ClearAnchors()
            leaderMarkerInnerControl:SetAnchor(CENTER, leaderMarkerWindow, CENTER, screenX, screenY)
            local dotSize = size * LEADER_MARKER_DOT_SIZE_RATIO
            leaderMarkerDotControl:SetHidden(false)
            leaderMarkerDotControl:SetDimensions(dotSize * pulseScale, dotSize * pulseScale)
            leaderMarkerDotControl:SetColor(c.r, c.g, c.b, LEADER_MARKER_DOT_ALPHA)
            leaderMarkerDotControl:ClearAnchors()
            leaderMarkerDotControl:SetAnchor(CENTER, leaderMarkerWindow, CENTER, screenX, screenY)
        end
    else
        leaderMarkerOuterControl:SetHidden(true)
        leaderMarkerInnerControl:SetHidden(true)
        leaderMarkerDotControl:SetHidden(true)
        local turnbackSize = size * LEADER_MARKER_TURNBACK_SIZE_RATIO
        leaderMarkerTurnBackControl:SetHidden(false)
        leaderMarkerTurnBackControl:SetDimensions(turnbackSize * pulseScale, turnbackSize * pulseScale)
        leaderMarkerTurnBackControl:SetColor(c.r, c.g, c.b, 0.5) -- 50% alpha, matching TDAddon's own turnback.dds alpha
        leaderMarkerTurnBackControl:SetTransformRotationZ(rotationRadians)
        leaderMarkerTurnBackControl:ClearAnchors()
        leaderMarkerTurnBackControl:SetAnchor(CENTER, leaderMarkerWindow, CENTER, 0, 0)
    end
    leaderMarkerLoopRunning = true
    zo_callLater(UpdateLeaderMarkerOnce, LEADER_MARKER_TICK_MS)
end
local function CheckLeaderMarkerWatchdog()
    if leaderMarkerLoopRunning then return end
    if ShouldShowLeaderMarker() then
        UpdateLeaderMarkerOnce()
    else
        HideLeaderMarker()
    end
end
local QUICKSLOT_WHEEL_TO_SLOT_INDEX_PRE_101034 = {12, 11, 10, 9, 16, 15, 14, 13}
local QUICKSLOT_WHEEL_TO_SLOT_INDEX_CURRENT = {4, 3, 2, 1, 8, 7, 6, 5}
local function GetQuickslotWheelToSlotIndexTable()
    if GetAPIVersion and GetAPIVersion() < 101034 then
        return QUICKSLOT_WHEEL_TO_SLOT_INDEX_PRE_101034
    end
    return QUICKSLOT_WHEEL_TO_SLOT_INDEX_CURRENT
end
local QUICKSLOT_KEYBIND_LABELS = {
    "Quickslot 1 (Top)",
    "Quickslot 2 (Top Right)",
    "Quickslot 3 (Middle Right)",
    "Quickslot 4 (Bottom Right)",
    "Quickslot 5 (Bottom)",
    "Quickslot 6 (Bottom Left)",
    "Quickslot 7 (Middle Left)",
    "Quickslot 8 (Top Left)",
}
local function RegisterQuickslotKeybindStrings()
    for i = 1, 8 do
        ZO_CreateStringId("SI_BINDING_NAME_LPI_QUICKSLOT_" .. i, QUICKSLOT_KEYBIND_LABELS[i])
    end
end
function PvPFPSLimiter.UseQuickSlot(wheelPosition)
    if not PvPFPSLimiter.savedVars.quickslotKeybindsEnabled then return end
    local slotIndex = GetQuickslotWheelToSlotIndexTable()[wheelPosition]
    if not slotIndex then return end
    SetCurrentQuickslot(slotIndex)
    if PvPFPSLimiter.savedVars.quickslotNotifyEnabled then
        local link = GetSlotItemLink and GetSlotItemLink(slotIndex)
        local name = (link and link ~= "") and GetItemLinkName(link) or nil
        if name and name ~= "" then
            d(string.format("|c33cc33[LPI]|r Quickslot %d: %s", wheelPosition, name))
        end
    end
end
function PvPFPSLimiter.GetOptions()
    local optionsTable =
    {
        {
            type = "header",
            name = "Zone FPS Limits",
        },
        {
            type = "description",
            text = "Sets a live FPS cap (via the MinFrameTime.2 engine CVar) based on your current zone. " ..
                "Takes effect immediately; values are re-applied every time you change zones.",
        },
        {
            type = "checkbox",
            name = "Enable Zone FPS Limits",
            tooltip = "Master on/off switch for the FPS cap below. Off by default. Turning this off restores whatever FPS limit CVar value was in effect right before it was turned on.",
            getFunc = function() return PvPFPSLimiter.savedVars.zoneFpsLimitsEnabled end,
            setFunc = function(value)
                PvPFPSLimiter.savedVars.zoneFpsLimitsEnabled = value
                ApplyZoneSettings()
            end,
            width = "full",
            default = defaults.zoneFpsLimitsEnabled,
        },
        {
            type = "slider",
            name = "PvP Zone FPS Limit",
            tooltip = "FPS limit applied while in Cyrodiil or the Imperial City (and Battlegrounds, if enabled below).",
            min = MIN_FPS_LIMIT,
            max = MAX_FPS_LIMIT,
            step = 1,
            getFunc = function() return PvPFPSLimiter.savedVars.pvpFpsLimit end,
            setFunc = function(value)
                PvPFPSLimiter.savedVars.pvpFpsLimit = ClampFpsLimit(value)
                ApplyZoneSettings()
            end,
            width = "full",
            default = defaults.pvpFpsLimit,
            disabled = function() return not PvPFPSLimiter.savedVars.zoneFpsLimitsEnabled end,
        },
        {
            type = "slider",
            name = "PvE / Default Zone FPS Limit",
            tooltip = "FPS limit applied everywhere else.",
            min = MIN_FPS_LIMIT,
            max = MAX_FPS_LIMIT,
            step = 1,
            getFunc = function() return PvPFPSLimiter.savedVars.pveFpsLimit end,
            setFunc = function(value)
                PvPFPSLimiter.savedVars.pveFpsLimit = ClampFpsLimit(value)
                ApplyZoneSettings()
            end,
            width = "full",
            default = defaults.pveFpsLimit,
            disabled = function() return not PvPFPSLimiter.savedVars.zoneFpsLimitsEnabled end,
        },
        {
            type = "checkbox",
            name = "Treat Battlegrounds as a PvP Zone",
            tooltip = "When enabled, the PvP Zone FPS Limit above also applies inside Battlegrounds, not just Cyrodiil/Imperial City.",
            getFunc = function() return PvPFPSLimiter.savedVars.includeBattlegrounds end,
            setFunc = function(value)
                PvPFPSLimiter.savedVars.includeBattlegrounds = value
                ApplyZoneSettings()
            end,
            width = "full",
            default = defaults.includeBattlegrounds,
            disabled = function() return not PvPFPSLimiter.savedVars.zoneFpsLimitsEnabled end,
        },
        {
            type = "checkbox",
            name = "Print a Chat Message When the Limit Changes",
            tooltip = "Debug option: prints the new FPS limit to chat every time it's applied.",
            getFunc = function() return PvPFPSLimiter.savedVars.debug end,
            setFunc = function(value) PvPFPSLimiter.savedVars.debug = value end,
            width = "full",
            default = defaults.debug,
        },
        {
            type = "button",
            name = "Re-apply Now",
            tooltip = "Force re-apply the FPS limit for your current zone right now.",
            func = function()
                ApplyZoneSettings()
                d("|c33cc33[LPI]|r Re-applied FPS limit for current zone.")
            end,
            width = "full",
            disabled = function() return not PvPFPSLimiter.savedVars.zoneFpsLimitsEnabled end,
        },
        {
            type = "header",
            name = "Performance Boost (PvP Graphics Preset)",
        },
        {
            type = "description",
            text = "Unlike the FPS cap above, this actually reduces rendering load during big fights by " ..
                "temporarily lowering View Distance, ally/enemy VFX intensity, shadows, ambient occlusion, " ..
                "water reflections, grass/clutter, distortion and god rays while you're in a PvP zone - then " ..
                "restores your exact previous values the moment you leave. Off by default.",
        },
        {
            type = "checkbox",
            name = "Enable Performance Boost in PvP",
            tooltip = "Automatically lowers several graphics-quality settings while in a PvP zone, and restores your normal settings when you leave.",
            getFunc = function() return PvPFPSLimiter.savedVars.perfBoostEnabled end,
            setFunc = function(value)
                PvPFPSLimiter.savedVars.perfBoostEnabled = value
                ApplyZoneSettings()
            end,
            width = "full",
            default = defaults.perfBoostEnabled,
            warning = "Reduces visual quality while in PvP zones. Your normal settings are restored automatically when you leave.",
        },
        {
            type = "slider",
            name = "Performance View Distance",
            tooltip = "View Distance used while the boost is active (native slider range: 0.4 = shortest, 2.0 = longest). Lower = better performance.",
            min = 0.4,
            max = 2.0,
            step = 0.1,
            decimals = 1,
            getFunc = function() return PvPFPSLimiter.savedVars.perfBoostViewDistance end,
            setFunc = function(value)
                PvPFPSLimiter.savedVars.perfBoostViewDistance = value
                if PvPFPSLimiter.savedVars.perfBoostApplied then
                    ApplyPerformanceBoostValues() -- live-update immediately if already applied
                end
            end,
            width = "full",
            default = defaults.perfBoostViewDistance,
            disabled = function() return not PvPFPSLimiter.savedVars.perfBoostEnabled end,
        },
        {
            type = "button",
            name = "Restore My Normal Settings Now",
            tooltip = "Immediately restores your pre-boost graphics settings, in case you ever get stuck in the performance preset (e.g. after a crash).",
            func = function()
                if PvPFPSLimiter.savedVars.perfBoostApplied then
                    RestoreGraphicsSnapshot()
                    PvPFPSLimiter.savedVars.perfBoostApplied = false
                    d("|c33cc33[LPI]|r Restored your normal graphics settings.")
                else
                    d("|c33cc33[LPI]|r Performance Boost isn't currently applied - nothing to restore.")
                end
            end,
            width = "full",
        },
        {
            type = "header",
            name = "Campaign Queue",
        },
        {
            type = "description",
            text = "When you've queued for a Cyrodiil/Imperial City campaign and a slot opens up, automatically " ..
                "confirm entry instead of needing to click accept yourself within the time limit.",
        },
        {
            type = "checkbox",
            name = "Auto-Accept Campaign Queue Pop",
            tooltip = "Automatically accepts the 'ready to enter' prompt when your campaign queue pops, for both solo and group queues.",
            getFunc = function() return PvPFPSLimiter.savedVars.autoAcceptQueueEnabled end,
            setFunc = function(value) PvPFPSLimiter.savedVars.autoAcceptQueueEnabled = value end,
            width = "full",
            default = defaults.autoAcceptQueueEnabled,
        },
        {
            type = "header",
            name = "PvP Notifications",
        },
        {
            type = "description",
            text = "Notifications are active while you're in PvP zone OR in an active duel (anywhere) and shown both in chat and as floating text.",
        },
        {
            type = "dropdown",
            name = "Notify When Target Blocks Your Attack",
            tooltip = "Notifies when an attack you land gets mitigated by your target's block. Only fires on attacks you actually land - " ..
                "there's no way to see an untouched enemy's block state.",
            choices = { "Off", "On screen", "In chat", "On screen and in chat" }, choicesValues = { NOTIFY_MODE_OFF, NOTIFY_MODE_NOTIFICATION, NOTIFY_MODE_CHAT, NOTIFY_MODE_BOTH },
            getFunc = function() return NormalizeNotifyMode(PvPFPSLimiter.savedVars.notifyBlockingMode) end,
            setFunc = function(value) PvPFPSLimiter.savedVars.notifyBlockingMode = NormalizeNotifyMode(value) end,
            width = "full",
            default = defaults.notifyBlockingMode,
        },
        {
            type = "editbox",
            name = "Block Notification Text",
            tooltip = "The message shown when your attack gets blocked. @accountname tries to show the enemy's real " ..
                "@Handle (falls back to their character name if they're not currently under your reticle - see README) " ..
                "- {target} always shows their character name instead, if you'd rather have that.",
            getFunc = function() return PvPFPSLimiter.savedVars.notifyBlockingText end,
            setFunc = function(value)
                PvPFPSLimiter.savedVars.notifyBlockingText = (value ~= nil and value ~= "") and value or defaults.notifyBlockingText
            end,
            width = "full",
            default = defaults.notifyBlockingText,
            disabled = function() return PvPFPSLimiter.savedVars.notifyBlockingMode == NOTIFY_MODE_OFF end,
        },
        {
            type = "colorpicker",
            name = "Block Notification Color",
            tooltip = "Color of the floating text (and, if shown, the fallback on-screen alert) for the block notification.",
            getFunc = function()
                local c = PvPFPSLimiter.savedVars.notifyBlockingColor
                return c.r, c.g, c.b
            end,
            setFunc = function(r, g, b)
                PvPFPSLimiter.savedVars.notifyBlockingColor = { r = r, g = g, b = b }
            end,
            width = "full",
            default = defaults.notifyBlockingColor,
            disabled = function() return PvPFPSLimiter.savedVars.notifyBlockingMode == NOTIFY_MODE_OFF end,
        },
        {
            type = "dropdown",
            name = "Notify When Hit by an Enemy Ultimate",
            tooltip = "Notifies when a player's ultimate ability affects you. Excludes yourself and your current group/raid members. " ..
                "Debounced so a multi-tick/AOE ultimate only notifies once every couple seconds, not per tick.",
            choices = { "Off", "On screen", "In chat", "On screen and in chat" }, choicesValues = { NOTIFY_MODE_OFF, NOTIFY_MODE_NOTIFICATION, NOTIFY_MODE_CHAT, NOTIFY_MODE_BOTH },
            getFunc = function() return NormalizeNotifyMode(PvPFPSLimiter.savedVars.notifyUltimateMode) end,
            setFunc = function(value) PvPFPSLimiter.savedVars.notifyUltimateMode = NormalizeNotifyMode(value) end,
            width = "full",
            default = defaults.notifyUltimateMode,
        },
        {
            type = "editbox",
            name = "Ultimate Notification Text",
            tooltip = "The message shown when an enemy's ultimate hits you. Use @accountname (or {source}) for the enemy's " ..
                "name and {ability} for the ultimate's name, anywhere in the text.",
            getFunc = function() return PvPFPSLimiter.savedVars.notifyUltimateText end,
            setFunc = function(value)
                PvPFPSLimiter.savedVars.notifyUltimateText = (value ~= nil and value ~= "") and value or defaults.notifyUltimateText
            end,
            width = "full",
            default = defaults.notifyUltimateText,
            disabled = function() return PvPFPSLimiter.savedVars.notifyUltimateMode == NOTIFY_MODE_OFF end,
        },
        {
            type = "colorpicker",
            name = "Ultimate Notification Color",
            tooltip = "Color of the floating text (and, if shown, the fallback on-screen alert) for the ultimate notification.",
            getFunc = function()
                local c = PvPFPSLimiter.savedVars.notifyUltimateColor
                return c.r, c.g, c.b
            end,
            setFunc = function(r, g, b)
                PvPFPSLimiter.savedVars.notifyUltimateColor = { r = r, g = g, b = b }
            end,
            width = "full",
            default = defaults.notifyUltimateColor,
            disabled = function() return PvPFPSLimiter.savedVars.notifyUltimateMode == NOTIFY_MODE_OFF end,
        },
        {
            type = "dropdown",
            name = "Notify When Stunned",
            tooltip = "Notifies when you get stunned by an enemy. Excludes yourself and your current group/raid members.",
            choices = { "Off", "On screen", "In chat", "On screen and in chat" }, choicesValues = { NOTIFY_MODE_OFF, NOTIFY_MODE_NOTIFICATION, NOTIFY_MODE_CHAT, NOTIFY_MODE_BOTH },
            getFunc = function() return NormalizeNotifyMode(PvPFPSLimiter.savedVars.notifyStunnedMode) end,
            setFunc = function(value) PvPFPSLimiter.savedVars.notifyStunnedMode = NormalizeNotifyMode(value) end,
            width = "full",
            default = defaults.notifyStunnedMode,
        },
        {
            type = "editbox",
            name = "Stunned Notification Text",
            tooltip = "The message shown when you get stunned. Use @accountname (or {source}) for the enemy's name and " ..
                "{ability} for the ability's name, anywhere in the text.",
            getFunc = function() return PvPFPSLimiter.savedVars.notifyStunnedText end,
            setFunc = function(value)
                PvPFPSLimiter.savedVars.notifyStunnedText = (value ~= nil and value ~= "") and value or defaults.notifyStunnedText
            end,
            width = "full",
            default = defaults.notifyStunnedText,
            disabled = function() return PvPFPSLimiter.savedVars.notifyStunnedMode == NOTIFY_MODE_OFF end,
        },
        {
            type = "colorpicker",
            name = "Stunned Notification Color",
            tooltip = "Color of the floating text (and, if shown, the fallback on-screen alert) for the stunned notification.",
            getFunc = function()
                local c = PvPFPSLimiter.savedVars.notifyStunnedColor
                return c.r, c.g, c.b
            end,
            setFunc = function(r, g, b)
                PvPFPSLimiter.savedVars.notifyStunnedColor = { r = r, g = g, b = b }
            end,
            width = "full",
            default = defaults.notifyStunnedColor,
            disabled = function() return PvPFPSLimiter.savedVars.notifyStunnedMode == NOTIFY_MODE_OFF end,
        },
        {
            type = "dropdown",
            name = "Notify When Immobilized",
            tooltip = "Notifies when you get immobilized (rooted) by an enemy. Excludes yourself and your current " ..
                "group/raid members. NOTE: this is distinct from being snared (slowed) - only a full immobilize counts.",
            choices = { "Off", "On screen", "In chat", "On screen and in chat" }, choicesValues = { NOTIFY_MODE_OFF, NOTIFY_MODE_NOTIFICATION, NOTIFY_MODE_CHAT, NOTIFY_MODE_BOTH },
            getFunc = function() return NormalizeNotifyMode(PvPFPSLimiter.savedVars.notifyImmobilizedMode) end,
            setFunc = function(value) PvPFPSLimiter.savedVars.notifyImmobilizedMode = NormalizeNotifyMode(value) end,
            width = "full",
            default = defaults.notifyImmobilizedMode,
        },
        {
            type = "editbox",
            name = "Immobilized Notification Text",
            tooltip = "The message shown when you get immobilized. Use @accountname (or {source}) for the enemy's name and " ..
                "{ability} for the ability's name, anywhere in the text.",
            getFunc = function() return PvPFPSLimiter.savedVars.notifyImmobilizedText end,
            setFunc = function(value)
                PvPFPSLimiter.savedVars.notifyImmobilizedText = (value ~= nil and value ~= "") and value or defaults.notifyImmobilizedText
            end,
            width = "full",
            default = defaults.notifyImmobilizedText,
            disabled = function() return PvPFPSLimiter.savedVars.notifyImmobilizedMode == NOTIFY_MODE_OFF end,
        },
        {
            type = "colorpicker",
            name = "Immobilized Notification Color",
            tooltip = "Color of the floating text (and, if shown, the fallback on-screen alert) for the immobilized notification.",
            getFunc = function()
                local c = PvPFPSLimiter.savedVars.notifyImmobilizedColor
                return c.r, c.g, c.b
            end,
            setFunc = function(r, g, b)
                PvPFPSLimiter.savedVars.notifyImmobilizedColor = { r = r, g = g, b = b }
            end,
            width = "full",
            default = defaults.notifyImmobilizedColor,
            disabled = function() return PvPFPSLimiter.savedVars.notifyImmobilizedMode == NOTIFY_MODE_OFF end,
        },
        {
            type = "header",
            name = "Notification Display",
        },
        {
            type = "description",
            text = "These apply to ALL FOUR notifications above (block, ultimate, stunned, immobilized) - they control how the floating text itself " ..
                "looks and behaves on screen, separately from each notification's own text/color.",
        },
        {
            type = "slider",
            name = "Notification Text Size",
            tooltip = "Font point size of the floating text. The default (18) matches the size used before this was configurable.",
            min = MIN_NOTIFY_TEXT_SIZE,
            max = MAX_NOTIFY_TEXT_SIZE,
            step = 1,
            getFunc = function() return PvPFPSLimiter.savedVars.notifyTextSize end,
            setFunc = function(value)
                PvPFPSLimiter.savedVars.notifyTextSize = ClampNumber(value, MIN_NOTIFY_TEXT_SIZE, MAX_NOTIFY_TEXT_SIZE)
            end,
            width = "full",
            default = defaults.notifyTextSize,
        },
        {
            type = "slider",
            name = "Notification Horizontal Position",
            tooltip = "Moves the floating text left (negative) or right (positive) from the center of your screen.",
            min = MIN_NOTIFY_TEXT_OFFSET_X,
            max = MAX_NOTIFY_TEXT_OFFSET_X,
            step = 5,
            getFunc = function() return PvPFPSLimiter.savedVars.notifyTextOffsetX end,
            setFunc = function(value)
                PvPFPSLimiter.savedVars.notifyTextOffsetX = ClampNumber(value, MIN_NOTIFY_TEXT_OFFSET_X, MAX_NOTIFY_TEXT_OFFSET_X)
            end,
            width = "full",
            default = defaults.notifyTextOffsetX,
        },
        {
            type = "slider",
            name = "Notification Vertical Position",
            tooltip = "Moves the floating text up (negative) or down (positive) from the center of your screen. The default " ..
                "(-210) places it above your reticle/character, matching where it always appeared before this was configurable.",
            min = MIN_NOTIFY_TEXT_OFFSET_Y,
            max = MAX_NOTIFY_TEXT_OFFSET_Y,
            step = 5,
            getFunc = function() return PvPFPSLimiter.savedVars.notifyTextOffsetY end,
            setFunc = function(value)
                PvPFPSLimiter.savedVars.notifyTextOffsetY = ClampNumber(value, MIN_NOTIFY_TEXT_OFFSET_Y, MAX_NOTIFY_TEXT_OFFSET_Y)
            end,
            width = "full",
            default = defaults.notifyTextOffsetY,
        },
        {
            type = "slider",
            name = "Notification Display Duration (Seconds)",
            tooltip = "How many seconds the floating text stays on screen (rising and fading out) before disappearing.",
            min = MIN_NOTIFY_TEXT_DURATION_SECONDS,
            max = MAX_NOTIFY_TEXT_DURATION_SECONDS,
            step = 1,
            getFunc = function() return PvPFPSLimiter.savedVars.notifyTextDurationSeconds end,
            setFunc = function(value)
                PvPFPSLimiter.savedVars.notifyTextDurationSeconds = ClampNumber(value, MIN_NOTIFY_TEXT_DURATION_SECONDS, MAX_NOTIFY_TEXT_DURATION_SECONDS)
            end,
            width = "full",
            default = defaults.notifyTextDurationSeconds,
        },
        {
            type = "slider",
            name = "Avoid Duplicate Messages For (Seconds)",
            tooltip = "If the exact same notification message would show again within this many seconds, it's skipped " ..
                "entirely (chat and floating text both) - useful for a channeled/AOE ultimate that hits you repeatedly, or " ..
                "the same enemy blocking you again right away. Set to 0 to disable and always show every notification.",
            min = MIN_DUPLICATE_SUPPRESS_SECONDS,
            max = MAX_DUPLICATE_SUPPRESS_SECONDS,
            step = 1,
            getFunc = function() return PvPFPSLimiter.savedVars.duplicateMessageSuppressSeconds end,
            setFunc = function(value)
                PvPFPSLimiter.savedVars.duplicateMessageSuppressSeconds = ClampNumber(value, MIN_DUPLICATE_SUPPRESS_SECONDS, MAX_DUPLICATE_SUPPRESS_SECONDS)
            end,
            width = "full",
            default = defaults.duplicateMessageSuppressSeconds,
        },
        {
            type = "header",
            name = "Break Free Alert",
        },
        {
            type = "description",
            text = "A persistent on-screen warning shown for as long as you're actually under a breakable hard-CC effect " ..
                "(Stun, Fear, Knockback, or Charm) - it disappears the instant it ends, whether you break free or it simply " ..
                "runs out.",
        },
        {
            type = "dropdown",
            name = "Show Break Free Alert",
            tooltip = "Where it is shown: a large text in the middle of the screen while it lasts, and/or a line in chat when it starts. Off by default.",
            choices = { "Off", "On screen", "In chat", "On screen and in chat" }, choicesValues = { NOTIFY_MODE_OFF, NOTIFY_MODE_NOTIFICATION, NOTIFY_MODE_CHAT, NOTIFY_MODE_BOTH },
            getFunc = function()
                local sv = PvPFPSLimiter.savedVars
                if sv.showBreakFreeAlert and sv.breakFreeChat then return NOTIFY_MODE_BOTH end
                if sv.showBreakFreeAlert then return NOTIFY_MODE_NOTIFICATION end
                if sv.breakFreeChat then return NOTIFY_MODE_CHAT end
                return NOTIFY_MODE_OFF
            end,
            setFunc = function(value)
                local sv = PvPFPSLimiter.savedVars
                sv.showBreakFreeAlert = (value == NOTIFY_MODE_NOTIFICATION or value == NOTIFY_MODE_BOTH)
                sv.breakFreeChat = (value == NOTIFY_MODE_CHAT or value == NOTIFY_MODE_BOTH)
                UpdateBreakFreeAlert()
            end,
            width = "full",
            default = NOTIFY_MODE_OFF,
        },
        {
            type = "checkbox",
            name = "Only Show in PvP Zones / Duels",
            tooltip = "OFF by default, so the alert works anywhere (including PvE content, like a boss fight) - crowd " ..
                "control and Break Free work the same way there as in PvP. Turn this ON to restrict it to Cyrodiil/" ..
                "Imperial City/Battlegrounds and active duels only, same as the regular PvP Notifications below.",
            getFunc = function() return PvPFPSLimiter.savedVars.breakFreeAlertPvpOnly end,
            setFunc = function(value) PvPFPSLimiter.savedVars.breakFreeAlertPvpOnly = value end,
            width = "full",
            default = defaults.breakFreeAlertPvpOnly,
            disabled = function() return not PvPFPSLimiter.savedVars.showBreakFreeAlert end,
        },
        {
            type = "editbox",
            name = "Break Free Alert Text",
            tooltip = "The message shown while you're under a breakable CC effect. Use {type} anywhere in the text for " ..
                "which CC type(s) are currently active, as STUNNED/FEARED/KNOCKED BACK/CHARMED (e.g. 'STUNNED', or " ..
                "'STUNNED, FEARED' if more than one overlaps).",
            getFunc = function() return PvPFPSLimiter.savedVars.breakFreeAlertText end,
            setFunc = function(value)
                PvPFPSLimiter.savedVars.breakFreeAlertText = (value ~= nil and value ~= "") and value or defaults.breakFreeAlertText
                UpdateBreakFreeAlert()
            end,
            width = "full",
            default = defaults.breakFreeAlertText,
            disabled = function() return not PvPFPSLimiter.savedVars.showBreakFreeAlert end,
        },
        {
            type = "colorpicker",
            name = "Break Free Alert Color",
            tooltip = "Color of the Break Free Alert text.",
            getFunc = function()
                local c = PvPFPSLimiter.savedVars.breakFreeAlertColor
                return c.r, c.g, c.b
            end,
            setFunc = function(r, g, b)
                PvPFPSLimiter.savedVars.breakFreeAlertColor = { r = r, g = g, b = b }
                UpdateBreakFreeAlert()
            end,
            width = "full",
            default = defaults.breakFreeAlertColor,
            disabled = function() return not PvPFPSLimiter.savedVars.showBreakFreeAlert end,
        },
        {
            type = "slider",
            name = "Break Free Alert Text Size",
            tooltip = "Font point size of the Break Free Alert text. Bigger than regular notifications by default (48), " ..
                "meant to be read at a glance mid-fight.",
            min = MIN_BREAKFREE_TEXT_SIZE,
            max = MAX_BREAKFREE_TEXT_SIZE,
            step = 1,
            getFunc = function() return PvPFPSLimiter.savedVars.breakFreeAlertTextSize end,
            setFunc = function(value)
                PvPFPSLimiter.savedVars.breakFreeAlertTextSize = ClampNumber(value, MIN_BREAKFREE_TEXT_SIZE, MAX_BREAKFREE_TEXT_SIZE)
                UpdateBreakFreeAlert()
            end,
            width = "full",
            default = defaults.breakFreeAlertTextSize,
            disabled = function() return not PvPFPSLimiter.savedVars.showBreakFreeAlert end,
        },
        {
            type = "header",
            name = "Blocking Alert",
        },
        {
            type = "description",
            text = "A persistent on-screen alert shown for as long as you're actually holding the block input " ..
                "(right mouse button by default on PC, or the block key on gamepad) - not just when an attack " ..
                "actually lands. Disappears the instant you let go.",
        },
        {
            type = "dropdown",
            name = "Show Blocking Alert",
            tooltip = "Where it is shown: a large text in the middle of the screen while it lasts, and/or a line in chat when it starts. Off by default.",
            choices = { "Off", "On screen", "In chat", "On screen and in chat" }, choicesValues = { NOTIFY_MODE_OFF, NOTIFY_MODE_NOTIFICATION, NOTIFY_MODE_CHAT, NOTIFY_MODE_BOTH },
            getFunc = function()
                local sv = PvPFPSLimiter.savedVars
                if sv.showBlockingAlert and sv.blockingChat then return NOTIFY_MODE_BOTH end
                if sv.showBlockingAlert then return NOTIFY_MODE_NOTIFICATION end
                if sv.blockingChat then return NOTIFY_MODE_CHAT end
                return NOTIFY_MODE_OFF
            end,
            setFunc = function(value)
                local sv = PvPFPSLimiter.savedVars
                sv.showBlockingAlert = (value == NOTIFY_MODE_NOTIFICATION or value == NOTIFY_MODE_BOTH)
                sv.blockingChat = (value == NOTIFY_MODE_CHAT or value == NOTIFY_MODE_BOTH)
                UpdateBlockingAlertState()
            end,
            width = "full",
            default = NOTIFY_MODE_OFF,
        },
        {
            type = "checkbox",
            name = "Only Show in PvP Zones / Duels",
            tooltip = "OFF by default, so the alert works anywhere - blocking works the same way in PvE as in PvP. " ..
                "Turn this ON to restrict it to Cyrodiil/Imperial City/Battlegrounds and active duels only, same as " ..
                "the Break Free Alert's equivalent setting above.",
            getFunc = function() return PvPFPSLimiter.savedVars.blockingAlertPvpOnly end,
            setFunc = function(value)
                PvPFPSLimiter.savedVars.blockingAlertPvpOnly = value
                UpdateBlockingAlertState()
            end,
            width = "full",
            default = defaults.blockingAlertPvpOnly,
            disabled = function() return not PvPFPSLimiter.savedVars.showBlockingAlert end,
        },
        {
            type = "editbox",
            name = "Blocking Alert Text",
            tooltip = "The message shown while you're holding block.",
            getFunc = function() return PvPFPSLimiter.savedVars.blockingAlertText end,
            setFunc = function(value)
                PvPFPSLimiter.savedVars.blockingAlertText = (value ~= nil and value ~= "") and value or defaults.blockingAlertText
                RefreshBlockingAlertAppearance()
            end,
            width = "full",
            default = defaults.blockingAlertText,
            disabled = function() return not PvPFPSLimiter.savedVars.showBlockingAlert end,
        },
        {
            type = "colorpicker",
            name = "Blocking Alert Color",
            tooltip = "Color of the Blocking Alert text.",
            getFunc = function()
                local c = PvPFPSLimiter.savedVars.blockingAlertColor
                return c.r, c.g, c.b
            end,
            setFunc = function(r, g, b)
                PvPFPSLimiter.savedVars.blockingAlertColor = { r = r, g = g, b = b }
                RefreshBlockingAlertAppearance()
            end,
            width = "full",
            default = defaults.blockingAlertColor,
            disabled = function() return not PvPFPSLimiter.savedVars.showBlockingAlert end,
        },
        {
            type = "slider",
            name = "Blocking Alert Text Size",
            tooltip = "Font point size of the Blocking Alert text.",
            min = MIN_BLOCKING_TEXT_SIZE,
            max = MAX_BLOCKING_TEXT_SIZE,
            step = 1,
            getFunc = function() return PvPFPSLimiter.savedVars.blockingAlertTextSize end,
            setFunc = function(value)
                PvPFPSLimiter.savedVars.blockingAlertTextSize = ClampNumber(value, MIN_BLOCKING_TEXT_SIZE, MAX_BLOCKING_TEXT_SIZE)
                RefreshBlockingAlertAppearance()
            end,
            width = "full",
            default = defaults.blockingAlertTextSize,
            disabled = function() return not PvPFPSLimiter.savedVars.showBlockingAlert end,
        },
        {
            type = "slider",
            name = "Blocking Alert Horizontal Position",
            tooltip = "Moves the Blocking Alert left/right from the center of your screen.",
            min = MIN_BLOCKING_TEXT_OFFSET_X,
            max = MAX_BLOCKING_TEXT_OFFSET_X,
            step = 5,
            getFunc = function() return PvPFPSLimiter.savedVars.blockingAlertOffsetX end,
            setFunc = function(value)
                PvPFPSLimiter.savedVars.blockingAlertOffsetX = ClampNumber(value, MIN_BLOCKING_TEXT_OFFSET_X, MAX_BLOCKING_TEXT_OFFSET_X)
                RefreshBlockingAlertAppearance()
            end,
            width = "full",
            default = defaults.blockingAlertOffsetX,
            disabled = function() return not PvPFPSLimiter.savedVars.showBlockingAlert end,
        },
        {
            type = "slider",
            name = "Blocking Alert Vertical Position",
            tooltip = "Moves the Blocking Alert up/down from the center of your screen. Default (-160) sits " ..
                "slightly above center, just above Break Free Alert's own default spot.",
            min = MIN_BLOCKING_TEXT_OFFSET_Y,
            max = MAX_BLOCKING_TEXT_OFFSET_Y,
            step = 5,
            getFunc = function() return PvPFPSLimiter.savedVars.blockingAlertOffsetY end,
            setFunc = function(value)
                PvPFPSLimiter.savedVars.blockingAlertOffsetY = ClampNumber(value, MIN_BLOCKING_TEXT_OFFSET_Y, MAX_BLOCKING_TEXT_OFFSET_Y)
                RefreshBlockingAlertAppearance()
            end,
            width = "full",
            default = defaults.blockingAlertOffsetY,
            disabled = function() return not PvPFPSLimiter.savedVars.showBlockingAlert end,
        },
        {
            type = "header",
            name = "Critical Alerts",
        },
        {
            type = "description",
            text = "Two alert types, bigger/harder to miss than the four notifications above (separate text size below). Both are " ..
                "matched by ability NAME, which you maintain yourself in the lists below - this addon has no way to look up " ..
                "which abilities are 'delayed telegraphs' or 'persistent AOE ultimates' on its own. Turn on /lpi debug to see " ..
                "exactly what's being detected if timing ever looks off.",
        },
        {
            type = "dropdown",
            name = "Notify Before a Delayed Hit Lands",
            tooltip = "For an ability that announces itself and then actually hits some seconds later (see the ability list " ..
                "below) - warns 'Lead Time' seconds before each of its hits, for 'Alert Duration' seconds, ending right at impact.",
            choices = { "Off", "On screen", "In chat", "On screen and in chat" }, choicesValues = { NOTIFY_MODE_OFF, NOTIFY_MODE_NOTIFICATION, NOTIFY_MODE_CHAT, NOTIFY_MODE_BOTH },
            getFunc = function() return NormalizeNotifyMode(PvPFPSLimiter.savedVars.criticalDelayedMode) end,
            setFunc = function(value) PvPFPSLimiter.savedVars.criticalDelayedMode = NormalizeNotifyMode(value) end,
            width = "full",
            default = defaults.criticalDelayedMode,
        },
        {
            type = "editbox",
            name = "Delayed Hit Alert Text",
            tooltip = "The warning shown before a delayed hit lands. Use @accountname (or {source}) for the enemy's name and " ..
                "{ability} for the ability's name, anywhere in the text.",
            getFunc = function() return PvPFPSLimiter.savedVars.criticalDelayedText end,
            setFunc = function(value)
                PvPFPSLimiter.savedVars.criticalDelayedText = (value ~= nil and value ~= "") and value or defaults.criticalDelayedText
            end,
            width = "full",
            default = defaults.criticalDelayedText,
            disabled = function() return PvPFPSLimiter.savedVars.criticalDelayedMode == NOTIFY_MODE_OFF end,
        },
        {
            type = "colorpicker",
            name = "Delayed Hit Alert Color",
            tooltip = "Color of the floating text (and, if shown, the fallback on-screen alert) for the delayed-hit alert.",
            getFunc = function()
                local c = PvPFPSLimiter.savedVars.criticalDelayedColor
                return c.r, c.g, c.b
            end,
            setFunc = function(r, g, b)
                PvPFPSLimiter.savedVars.criticalDelayedColor = { r = r, g = g, b = b }
            end,
            width = "full",
            default = defaults.criticalDelayedColor,
            disabled = function() return PvPFPSLimiter.savedVars.criticalDelayedMode == NOTIFY_MODE_OFF end,
        },
        {
            type = "slider",
            name = "Delayed Hit Warning Lead Time (Seconds)",
            tooltip = "How many seconds BEFORE each configured hit the warning appears.",
            min = MIN_CRITICAL_SECONDS,
            max = MAX_CRITICAL_SECONDS,
            step = 0.5,
            getFunc = function() return PvPFPSLimiter.savedVars.criticalDelayedLeadSeconds end,
            setFunc = function(value)
                PvPFPSLimiter.savedVars.criticalDelayedLeadSeconds = ClampNumber(value, MIN_CRITICAL_SECONDS, MAX_CRITICAL_SECONDS)
            end,
            width = "full",
            default = defaults.criticalDelayedLeadSeconds,
            disabled = function() return PvPFPSLimiter.savedVars.criticalDelayedMode == NOTIFY_MODE_OFF end,
        },
        {
            type = "slider",
            name = "Delayed Hit Alert Duration (Seconds)",
            tooltip = "How many seconds the warning stays on screen - timed so it ends exactly at the moment the hit lands.",
            min = MIN_CRITICAL_SECONDS,
            max = MAX_CRITICAL_SECONDS,
            step = 0.5,
            getFunc = function() return PvPFPSLimiter.savedVars.criticalDelayedAlertDurationSeconds end,
            setFunc = function(value)
                PvPFPSLimiter.savedVars.criticalDelayedAlertDurationSeconds = ClampNumber(value, MIN_CRITICAL_SECONDS, MAX_CRITICAL_SECONDS)
            end,
            width = "full",
            default = defaults.criticalDelayedAlertDurationSeconds,
            disabled = function() return PvPFPSLimiter.savedVars.criticalDelayedMode == NOTIFY_MODE_OFF end,
        },
        {
            type = "editbox",
            isMultiline = true,
            isExtraWide = true,
            name = "Delayed-Hit Abilities",
            tooltip = "One ability per line: AbilityName=seconds1,seconds2,... - seconds are CUMULATIVE from the first sign " ..
                "of that ability affecting you, not from each other (e.g. a curse hitting at 3.5s then again 8.5s after " ..
                "that is written as 'Haunting Curse=3.5,12'). Matched by name, not case-sensitive.",
            getFunc = function() return PvPFPSLimiter.savedVars.criticalDelayedAbilityList end,
            setFunc = function(value)
                PvPFPSLimiter.savedVars.criticalDelayedAbilityList = (value ~= nil and value ~= "") and value or defaults.criticalDelayedAbilityList
            end,
            width = "full",
            default = defaults.criticalDelayedAbilityList,
        },
        {
            type = "dropdown",
            name = "Notify While Standing in a Critical AOE/DOT Ultimate",
            tooltip = "For an ultimate that keeps damaging you over time (see the ability list below) - a persistent " ..
                "ground AOE you can walk out of, or a channeled/bleed effect still ticking on you after the initial hit - " ..
                "shows a continuous warning for as long as the hits keep landing, fading out shortly after the last one. " ..
                "Any ultimate listed here is EXCLUDED from the regular 'Hit by an Enemy Ultimate' notification above - " ..
                "it gets only this alert.",
            choices = { "Off", "On screen", "In chat", "On screen and in chat" }, choicesValues = { NOTIFY_MODE_OFF, NOTIFY_MODE_NOTIFICATION, NOTIFY_MODE_CHAT, NOTIFY_MODE_BOTH },
            getFunc = function() return NormalizeNotifyMode(PvPFPSLimiter.savedVars.criticalAoeMode) end,
            setFunc = function(value) PvPFPSLimiter.savedVars.criticalAoeMode = NormalizeNotifyMode(value) end,
            width = "full",
            default = defaults.criticalAoeMode,
        },
        {
            type = "editbox",
            name = "AOE/DOT Critical Alert Text",
            tooltip = "The warning shown while you're standing in a critical AOE/DOT ultimate's damage. Use @accountname (or " ..
                "{source}) for the enemy's name and {ability} for the ability's name, anywhere in the text.",
            getFunc = function() return PvPFPSLimiter.savedVars.criticalAoeText end,
            setFunc = function(value)
                PvPFPSLimiter.savedVars.criticalAoeText = (value ~= nil and value ~= "") and value or defaults.criticalAoeText
            end,
            width = "full",
            default = defaults.criticalAoeText,
            disabled = function() return PvPFPSLimiter.savedVars.criticalAoeMode == NOTIFY_MODE_OFF end,
        },
        {
            type = "colorpicker",
            name = "AOE/DOT Critical Alert Color",
            tooltip = "Color of the floating text (and, if shown, the fallback on-screen alert) for the AOE/DOT critical alert.",
            getFunc = function()
                local c = PvPFPSLimiter.savedVars.criticalAoeColor
                return c.r, c.g, c.b
            end,
            setFunc = function(r, g, b)
                PvPFPSLimiter.savedVars.criticalAoeColor = { r = r, g = g, b = b }
            end,
            width = "full",
            default = defaults.criticalAoeColor,
            disabled = function() return PvPFPSLimiter.savedVars.criticalAoeMode == NOTIFY_MODE_OFF end,
        },
        {
            type = "slider",
            name = "AOE/DOT Alert Grace Period After Last Tick (Seconds)",
            tooltip = "How many seconds the alert stays up after the LAST damage tick before disappearing - should be a " ..
                "bit longer than the ability's own tick rate, or it'll flicker between ticks instead of staying continuously visible.",
            min = MIN_CRITICAL_SECONDS,
            max = MAX_CRITICAL_SECONDS,
            step = 0.5,
            getFunc = function() return PvPFPSLimiter.savedVars.criticalAoeGraceSeconds end,
            setFunc = function(value)
                PvPFPSLimiter.savedVars.criticalAoeGraceSeconds = ClampNumber(value, MIN_CRITICAL_SECONDS, MAX_CRITICAL_SECONDS)
            end,
            width = "full",
            default = defaults.criticalAoeGraceSeconds,
            disabled = function() return PvPFPSLimiter.savedVars.criticalAoeMode == NOTIFY_MODE_OFF end,
        },
        {
            type = "editbox",
            isMultiline = true,
            isExtraWide = true,
            name = "Critical AOE/DOT Ultimate Abilities",
            tooltip = "One ultimate ability name OR numeric ability id per line (commas also work). Names are matched " ..
                "case-insensitively; a line that's purely digits (e.g. 83687) is matched as an ability id instead, which " ..
                "never changes even if the display name does (per-staff-element renaming, a pet/turret-sourced hit, etc). " ..
                "Pre-filled with confirmed ongoing-damage ultimates (ground AOEs, channels, and bleeds) - edit freely to " ..
                "add, remove, or replace any of them.",
            getFunc = function() return PvPFPSLimiter.savedVars.criticalAoeAbilityList end,
            setFunc = function(value)
                PvPFPSLimiter.savedVars.criticalAoeAbilityList = (value ~= nil and value ~= "") and value or defaults.criticalAoeAbilityList
            end,
            width = "full",
            default = defaults.criticalAoeAbilityList,
        },
        {
            type = "slider",
            name = "Critical Alert Text Size",
            tooltip = "Font point size for BOTH critical alert types above - deliberately separate from (and bigger than) " ..
                "the regular 'Notification Text Size' setting. Range raised to 16-200 in v7.12.0 so it can go as large as you want.",
            min = MIN_CRITICAL_TEXT_SIZE,
            max = MAX_CRITICAL_TEXT_SIZE,
            step = 1,
            getFunc = function() return PvPFPSLimiter.savedVars.criticalTextSize end,
            setFunc = function(value)
                PvPFPSLimiter.savedVars.criticalTextSize = ClampNumber(value, MIN_CRITICAL_TEXT_SIZE, MAX_CRITICAL_TEXT_SIZE)
            end,
            width = "full",
            default = defaults.criticalTextSize,
        },
        {
            type = "header",
            name = "Group Leader Marker",
        },
        {
            type = "description",
            text = "An optional, subtle marker that tracks your group leader's on-screen position, to make them easier " ..
                "to keep track of/follow in a chaotic fight.",
        },
        {
            type = "checkbox",
            name = "Show in Cyrodiil",
            tooltip = "Shows the marker while you're in Cyrodiil, grouped, and someone else is the leader. Hidden " ..
                "automatically if you ARE the leader, you're not grouped, or the leader can't currently be found.",
            getFunc = function() return PvPFPSLimiter.savedVars.showLeaderMarkerCyrodiil end,
            setFunc = function(value) PvPFPSLimiter.savedVars.showLeaderMarkerCyrodiil = value end,
            width = "full",
            default = defaults.showLeaderMarkerCyrodiil,
        },
        {
            type = "checkbox",
            name = "Show in Imperial City",
            tooltip = "Shows the marker while you're in the Imperial City, grouped, and someone else is the leader. " ..
                "Hidden automatically if you ARE the leader, you're not grouped, or the leader can't currently be " ..
                "found.",
            getFunc = function() return PvPFPSLimiter.savedVars.showLeaderMarkerImperialCity end,
            setFunc = function(value) PvPFPSLimiter.savedVars.showLeaderMarkerImperialCity = value end,
            width = "full",
            default = defaults.showLeaderMarkerImperialCity,
        },
        {
            type = "checkbox",
            name = "Show in Battlegrounds",
            tooltip = "Shows the marker while you're in a Battleground, grouped, and someone else is the leader. " ..
                "Hidden automatically if you ARE the leader, you're not grouped, or the leader can't currently be " ..
                "found. Independent of the 'Treat Battlegrounds as a PvP Zone' FPS-limit setting above - that one " ..
                "only affects the FPS cap, not this marker.",
            getFunc = function() return PvPFPSLimiter.savedVars.showLeaderMarkerBattlegrounds end,
            setFunc = function(value) PvPFPSLimiter.savedVars.showLeaderMarkerBattlegrounds = value end,
            width = "full",
            default = defaults.showLeaderMarkerBattlegrounds,
        },
        {
            type = "colorpicker",
            name = "Group Leader Marker Color",
            tooltip = "Color of the leader marker (outer perforated ring, inner ring, and center dot). Default is a " ..
                "subtle white - the marker is drawn with real transparency (not fully opaque), so it stays " ..
                "unobtrusive even at full-color brightness settings.",
            getFunc = function()
                local c = PvPFPSLimiter.savedVars.leaderMarkerColor
                return c.r, c.g, c.b
            end,
            setFunc = function(r, g, b)
                PvPFPSLimiter.savedVars.leaderMarkerColor = { r = r, g = g, b = b }
            end,
            width = "full",
            default = defaults.leaderMarkerColor,
            disabled = function()
                local sv = PvPFPSLimiter.savedVars
                return not (sv.showLeaderMarkerCyrodiil or sv.showLeaderMarkerImperialCity or sv.showLeaderMarkerBattlegrounds)
            end,
        },
        {
            type = "slider",
            name = "Group Leader Marker Size",
            tooltip = "Diameter of the OUTER leader marker ring, in pixels (it also gently pulses +/-8% around this " ..
                "size). The far-only inner ring, the far-only center dot, and the turnback indicator are all fixed " ..
                "ratios of this value (55%, 12%, and ~83% respectively).",
            min = MIN_LEADER_MARKER_SIZE,
            max = MAX_LEADER_MARKER_SIZE,
            step = 10,
            getFunc = function() return PvPFPSLimiter.savedVars.leaderMarkerSize end,
            setFunc = function(value)
                PvPFPSLimiter.savedVars.leaderMarkerSize = ClampNumber(value, MIN_LEADER_MARKER_SIZE, MAX_LEADER_MARKER_SIZE)
            end,
            width = "full",
            default = defaults.leaderMarkerSize,
            disabled = function()
                local sv = PvPFPSLimiter.savedVars
                return not (sv.showLeaderMarkerCyrodiil or sv.showLeaderMarkerImperialCity or sv.showLeaderMarkerBattlegrounds)
            end,
        },
        {
            type = "header",
            name = "Quickslots",
        },
        {
            type = "description",
            text = "Adds 8 new keybinds - one per position on ESO's own Quickslot radial wheel (top, top-right, " ..
                "middle-right, bottom-right, bottom, bottom-left, middle-left, top-left, clockwise from the top) " ..
                "- that instantly switch your active Quickslot item to that position, without opening the wheel " ..
                "at all. This panel can only turn the feature on/off and toggle its notification - the actual " ..
                "KEYS are set in ESO's own Settings > Controls > Keybindings (under Controls > Addon Keybinds > Lethal PVP Insights), same as any other addon-defined keybind.",
        },
        {
            type = "checkbox",
            name = "Enable Quickslot Keybinds",
            tooltip = "Turns the 8 Quickslot keybinds on or off. ON by default - each one only does anything " ..
                "once you've actually bound a key to it in Controls, so leaving this on is harmless until you do.",
            getFunc = function() return PvPFPSLimiter.savedVars.quickslotKeybindsEnabled end,
            setFunc = function(value) PvPFPSLimiter.savedVars.quickslotKeybindsEnabled = value end,
            width = "full",
            default = defaults.quickslotKeybindsEnabled,
        },
        {
            type = "checkbox",
            name = "Show Quickslot Swap Notification",
            tooltip = "Prints a chat message naming the item whenever one of the Quickslot keybinds above " ..
                "switches your active Quickslot item.",
            getFunc = function() return PvPFPSLimiter.savedVars.quickslotNotifyEnabled end,
            setFunc = function(value) PvPFPSLimiter.savedVars.quickslotNotifyEnabled = value end,
            width = "full",
            default = defaults.quickslotNotifyEnabled,
            disabled = function() return not PvPFPSLimiter.savedVars.quickslotKeybindsEnabled end,
        },
    }
    return optionsTable
end
local function RegisterSlashCommands()
    PvPFPSLimiter.Slash = function(rawArg)
        local arg, rest = (rawArg or ""):lower():match("^%s*(%S*)%s*(.-)%s*$")
        if arg == "debug" then
            PvPFPSLimiter.savedVars.debug = not PvPFPSLimiter.savedVars.debug
            d(string.format("|c33cc33[LPI]|r Debug messages %s.",
                PvPFPSLimiter.savedVars.debug and "ON" or "OFF"))
        elseif arg == "reapply" then
            ApplyZoneSettings()
            d("|c33cc33[LPI]|r Re-applied FPS limit for current zone.")
        elseif arg == "zonelimits" then
            PvPFPSLimiter.savedVars.zoneFpsLimitsEnabled = not PvPFPSLimiter.savedVars.zoneFpsLimitsEnabled
            d(string.format("|c33cc33[LPI]|r Zone FPS Limits: %s.",
                PvPFPSLimiter.savedVars.zoneFpsLimitsEnabled and "ON" or "OFF"))
            ApplyZoneSettings()
        elseif arg == "pvp" and tonumber(rest) then
            PvPFPSLimiter.savedVars.pvpFpsLimit = ClampFpsLimit(tonumber(rest))
            d(string.format("|c33cc33[LPI]|r PvP zone FPS limit set to %d.", PvPFPSLimiter.savedVars.pvpFpsLimit))
            ApplyZoneSettings()
        elseif arg == "pve" and tonumber(rest) then
            PvPFPSLimiter.savedVars.pveFpsLimit = ClampFpsLimit(tonumber(rest))
            d(string.format("|c33cc33[LPI]|r PvE/default zone FPS limit set to %d.", PvPFPSLimiter.savedVars.pveFpsLimit))
            ApplyZoneSettings()
        elseif arg == "bg" then
            PvPFPSLimiter.savedVars.includeBattlegrounds = not PvPFPSLimiter.savedVars.includeBattlegrounds
            d(string.format("|c33cc33[LPI]|r Treat Battlegrounds as PvP: %s.",
                PvPFPSLimiter.savedVars.includeBattlegrounds and "ON" or "OFF"))
            ApplyZoneSettings()
        elseif arg == "perf" then
            PvPFPSLimiter.savedVars.perfBoostEnabled = not PvPFPSLimiter.savedVars.perfBoostEnabled
            d(string.format("|c33cc33[LPI]|r Performance Boost: %s.",
                PvPFPSLimiter.savedVars.perfBoostEnabled and "ON" or "OFF"))
            ApplyZoneSettings()
        elseif arg == "perfview" and tonumber(rest) then
            local value = tonumber(rest)
            if value < 0.4 then value = 0.4 end
            if value > 2.0 then value = 2.0 end
            PvPFPSLimiter.savedVars.perfBoostViewDistance = value
            d(string.format("|c33cc33[LPI]|r Performance Boost view distance set to %.1f.", value))
            if PvPFPSLimiter.savedVars.perfBoostApplied then
                ApplyPerformanceBoostValues()
            end
        elseif arg == "perfrestore" then
            if PvPFPSLimiter.savedVars.perfBoostApplied then
                RestoreGraphicsSnapshot()
                PvPFPSLimiter.savedVars.perfBoostApplied = false
                d("|c33cc33[LPI]|r Restored your normal graphics settings.")
            else
                d("|c33cc33[LPI]|r Performance Boost isn't currently applied - nothing to restore.")
            end
        elseif arg == "autoaccept" then
            PvPFPSLimiter.savedVars.autoAcceptQueueEnabled = not PvPFPSLimiter.savedVars.autoAcceptQueueEnabled
            d(string.format("|c33cc33[LPI]|r Auto-Accept Campaign Queue: %s.",
                PvPFPSLimiter.savedVars.autoAcceptQueueEnabled and "ON" or "OFF"))
        elseif arg == "notifyblock" then
            PvPFPSLimiter.savedVars.notifyBlockingMode =
                (PvPFPSLimiter.savedVars.notifyBlockingMode == NOTIFY_MODE_OFF) and NOTIFY_MODE_BOTH or NOTIFY_MODE_OFF
            d(string.format("|c33cc33[LPI]|r Notify when target blocks your attack: %s.",
                PvPFPSLimiter.savedVars.notifyBlockingMode))
        elseif arg == "notifyultimate" then
            PvPFPSLimiter.savedVars.notifyUltimateMode =
                (PvPFPSLimiter.savedVars.notifyUltimateMode == NOTIFY_MODE_OFF) and NOTIFY_MODE_BOTH or NOTIFY_MODE_OFF
            d(string.format("|c33cc33[LPI]|r Notify when hit by an enemy ultimate: %s.",
                PvPFPSLimiter.savedVars.notifyUltimateMode))
        elseif arg == "critdelay" then
            PvPFPSLimiter.savedVars.criticalDelayedMode =
                (PvPFPSLimiter.savedVars.criticalDelayedMode == NOTIFY_MODE_OFF) and NOTIFY_MODE_BOTH or NOTIFY_MODE_OFF
            d(string.format("|c33cc33[LPI]|r Critical Alert - delayed hit warning: %s.",
                PvPFPSLimiter.savedVars.criticalDelayedMode))
        elseif arg == "critaoe" then
            PvPFPSLimiter.savedVars.criticalAoeMode =
                (PvPFPSLimiter.savedVars.criticalAoeMode == NOTIFY_MODE_OFF) and NOTIFY_MODE_BOTH or NOTIFY_MODE_OFF
            d(string.format("|c33cc33[LPI]|r Critical Alert - ongoing AOE/DOT ultimate warning: %s.",
                PvPFPSLimiter.savedVars.criticalAoeMode))
        elseif arg == "breakfree" then
            PvPFPSLimiter.savedVars.showBreakFreeAlert = not PvPFPSLimiter.savedVars.showBreakFreeAlert
            UpdateBreakFreeAlert()
            d(string.format("|c33cc33[LPI]|r Break Free Alert: %s.",
                PvPFPSLimiter.savedVars.showBreakFreeAlert and "ON" or "OFF"))
        elseif arg == "blocking" then
            PvPFPSLimiter.savedVars.showBlockingAlert = not PvPFPSLimiter.savedVars.showBlockingAlert
            UpdateBlockingAlertState()
            d(string.format("|c33cc33[LPI]|r Blocking Alert: %s.",
                PvPFPSLimiter.savedVars.showBlockingAlert and "ON" or "OFF"))
        elseif arg == "leadermarker" then
            if IsActiveWorldBattleground() then
                PvPFPSLimiter.savedVars.showLeaderMarkerBattlegrounds = not PvPFPSLimiter.savedVars.showLeaderMarkerBattlegrounds
                d(string.format("|c33cc33[LPI]|r Group Leader Marker in Battlegrounds: %s.",
                    PvPFPSLimiter.savedVars.showLeaderMarkerBattlegrounds and "ON" or "OFF"))
            elseif IsInImperialCity() then
                PvPFPSLimiter.savedVars.showLeaderMarkerImperialCity = not PvPFPSLimiter.savedVars.showLeaderMarkerImperialCity
                d(string.format("|c33cc33[LPI]|r Group Leader Marker in the Imperial City: %s.",
                    PvPFPSLimiter.savedVars.showLeaderMarkerImperialCity and "ON" or "OFF"))
            elseif IsInCyrodiil() then
                PvPFPSLimiter.savedVars.showLeaderMarkerCyrodiil = not PvPFPSLimiter.savedVars.showLeaderMarkerCyrodiil
                d(string.format("|c33cc33[LPI]|r Group Leader Marker in Cyrodiil: %s.",
                    PvPFPSLimiter.savedVars.showLeaderMarkerCyrodiil and "ON" or "OFF"))
            else
                d("|c33cc33[LPI]|r The Group Leader Marker is controlled per zone (Cyrodiil/Imperial City/" ..
                    "Battlegrounds) - you're not in any of those right now, so there's nothing here to toggle. Use " ..
                    "/lpi fps to see all three, or the Settings panel to change any of them directly.")
            end
        elseif arg == "quickslots" then
            PvPFPSLimiter.savedVars.quickslotKeybindsEnabled = not PvPFPSLimiter.savedVars.quickslotKeybindsEnabled
            d(string.format("|c33cc33[LPI]|r Quickslot Keybinds: %s.",
                PvPFPSLimiter.savedVars.quickslotKeybindsEnabled and "ON" or "OFF"))
        elseif arg == "open" then
            PVPDataInsight.Settings:Open()
        elseif arg == "status" or arg == "" then
            d(string.format("|c33cc33[LPI]|r Zone FPS Limits: %s | Zone: %s | PvP limit: %d | PvE limit: %d | BG counts as PvP: %s | CVar currently reads: %s",
                PvPFPSLimiter.savedVars.zoneFpsLimitsEnabled and "ON" or "OFF",
                PvPFPSLimiter.currentlyInPvPZone and "PvP" or "PvE/default",
                PvPFPSLimiter.savedVars.pvpFpsLimit,
                PvPFPSLimiter.savedVars.pveFpsLimit,
                PvPFPSLimiter.savedVars.includeBattlegrounds and "yes" or "no",
                tostring(GetCurrentFpsLimit())))
            d(string.format("|c33cc33[LPI]|r Performance Boost: %s | View distance while boosted: %.1f | Currently applied: %s",
                PvPFPSLimiter.savedVars.perfBoostEnabled and "ON" or "OFF",
                PvPFPSLimiter.savedVars.perfBoostViewDistance,
                PvPFPSLimiter.savedVars.perfBoostApplied and "yes" or "no"))
            d(string.format("|c33cc33[LPI]|r Auto-Accept Campaign Queue: %s",
                PvPFPSLimiter.savedVars.autoAcceptQueueEnabled and "ON" or "OFF"))
            d(string.format("|c33cc33[LPI]|r Notify on target block: %s | Notify on enemy ultimate hit: %s | " ..
                "Notify on stunned: %s | Notify on immobilized: %s | Currently in a duel: %s",
                PvPFPSLimiter.savedVars.notifyBlockingMode,
                PvPFPSLimiter.savedVars.notifyUltimateMode,
                PvPFPSLimiter.savedVars.notifyStunnedMode,
                PvPFPSLimiter.savedVars.notifyImmobilizedMode,
                IsPlayerDuelActive() and "yes" or "no"))
            local delayedList = (PvPFPSLimiter.savedVars.criticalDelayedAbilityList or ""):gsub("\n", "; ")
            local aoeList = (PvPFPSLimiter.savedVars.criticalAoeAbilityList or ""):gsub("\n", "; ")
            d(string.format("|c33cc33[LPI]|r Critical Alert - delayed hit: %s (abilities: %s) | Critical Alert - ongoing AOE/DOT: %s (abilities: %s)",
                PvPFPSLimiter.savedVars.criticalDelayedMode,
                (delayedList ~= "" and delayedList or "none configured"),
                PvPFPSLimiter.savedVars.criticalAoeMode,
                (aoeList ~= "" and aoeList or "none configured")))
            d(string.format("|c33cc33[LPI]|r Group Leader Marker - Cyrodiil: %s | Imperial City: %s | Battlegrounds: %s " ..
                "(color: %.2f,%.2f,%.2f | size: %d)",
                PvPFPSLimiter.savedVars.showLeaderMarkerCyrodiil and "ON" or "OFF",
                PvPFPSLimiter.savedVars.showLeaderMarkerImperialCity and "ON" or "OFF",
                PvPFPSLimiter.savedVars.showLeaderMarkerBattlegrounds and "ON" or "OFF",
                PvPFPSLimiter.savedVars.leaderMarkerColor.r, PvPFPSLimiter.savedVars.leaderMarkerColor.g, PvPFPSLimiter.savedVars.leaderMarkerColor.b,
                PvPFPSLimiter.savedVars.leaderMarkerSize))
            d(string.format("|c33cc33[LPI]|r Break Free Alert: %s (scope: %s | currently active: %s)",
                PvPFPSLimiter.savedVars.showBreakFreeAlert and "ON" or "OFF",
                PvPFPSLimiter.savedVars.breakFreeAlertPvpOnly and "PvP zones/duels only" or "anywhere",
                (next(activeBreakFreeCc) ~= nil) and GetActiveBreakFreeTypeNamesText() or "none"))
            d(string.format("|c33cc33[LPI]|r Blocking Alert: %s (scope: %s | currently blocking: %s)",
                PvPFPSLimiter.savedVars.showBlockingAlert and "ON" or "OFF",
                PvPFPSLimiter.savedVars.blockingAlertPvpOnly and "PvP zones/duels only" or "anywhere",
                IsBlockActive() and "yes" or "no"))
            d(string.format("|c33cc33[LPI]|r Quickslot Keybinds: %s (swap notification: %s) - set the actual keys via Controls > Keybindings.",
                PvPFPSLimiter.savedVars.quickslotKeybindsEnabled and "ON" or "OFF",
                PvPFPSLimiter.savedVars.quickslotNotifyEnabled and "ON" or "OFF"))
        else
            d("|c33cc33[LPI]|r Usage: /lpi [fps|debug|reapply|zonelimits|bg|perf|perfview <0.4-2.0>|perfrestore|autoaccept|notifyblock|notifyultimate|critdelay|critaoe|breakfree|blocking|quickslots|leadermarker|open|pvp <fps>|pve <fps>]")
        end
    end
end
local function OnPlayerActivated(eventCode, initial)
    ApplyZoneSettings()
end
local function OnZoneChanged(eventCode, zoneName, subZoneName, newSubzone, zoneId, subZoneId)
    ApplyZoneSettings()
end
local function MigrateEnabledBooleanToMode(enabledKey, modeKey)
    local sv = PvPFPSLimiter.savedVars
    if sv[enabledKey] ~= nil then
        sv[modeKey] = sv[enabledKey] and NOTIFY_MODE_BOTH or NOTIFY_MODE_OFF
        sv[enabledKey] = nil
    end
end
local function MigrateLeaderMarkerOffByDefault()
    local sv = PvPFPSLimiter.savedVars
    if sv.leaderMarkerOffV1 then return end
    sv.showLeaderMarkerCyrodiil, sv.showLeaderMarkerImperialCity, sv.showLeaderMarkerBattlegrounds = false, false, false
    sv.leaderMarkerOffV1 = true
end
local function MigrateLeaderMarkerEnabledToPerZone()
    local sv = PvPFPSLimiter.savedVars
    if sv.showLeaderMarker ~= nil then
        if sv.showLeaderMarker then
            sv.showLeaderMarkerCyrodiil = true
            sv.showLeaderMarkerImperialCity = true
            sv.showLeaderMarkerBattlegrounds = true
        end
        sv.showLeaderMarker = nil
    end
end
local OLD_CRITICAL_DELAYED_DEFAULT = "Haunting Curse=3.5,12"
local function MigrateCriticalDelayedAbilityListDefault()
    local sv = PvPFPSLimiter.savedVars
    if not sv.criticalDelayedListMigratedV1 then
        if sv.criticalDelayedAbilityList == OLD_CRITICAL_DELAYED_DEFAULT then
            sv.criticalDelayedAbilityList = defaults.criticalDelayedAbilityList
        end
        sv.criticalDelayedListMigratedV1 = true
    end
end
local OLD_CRITICAL_DELAYED_6_ENTRY_DEFAULT =
    "Haunting Curse=3.5,12\nShattering Rocks=1\nFossilize=1\nPetrify=1\nDark Convergence=1,5\nRush of Agony=0.8,2.8"
local function MigrateCriticalDelayedAbilityListDefaultV2()
    local sv = PvPFPSLimiter.savedVars
    if not sv.criticalDelayedListMigratedV2 then
        if sv.criticalDelayedAbilityList == OLD_CRITICAL_DELAYED_6_ENTRY_DEFAULT then
            sv.criticalDelayedAbilityList = defaults.criticalDelayedAbilityList
        end
        sv.criticalDelayedListMigratedV2 = true
    end
end
local function MigrateCriticalDelayedInstantHits()
    local sv = PvPFPSLimiter.savedVars
    if sv.criticalDelayedInstantV1 then return end
    local list = sv.criticalDelayedAbilityList or ""
    for _, name in ipairs({ "Shattering Rocks", "Fossilize", "Petrify" }) do
        list = list:gsub("(%f[^\n%z]" .. name .. "%s*=%s*)1(%s*%f[\n%z])", "%10.01%2")
    end
    sv.criticalDelayedAbilityList = list
    sv.criticalDelayedInstantV1 = true
end
local function MigrateCriticalAoeAbilityListDefault()
    local sv = PvPFPSLimiter.savedVars
    if not sv.criticalAoeListMigratedV1 then
        if sv.criticalAoeAbilityList == "" then
            sv.criticalAoeAbilityList = defaults.criticalAoeAbilityList
        end
        sv.criticalAoeListMigratedV1 = true
    end
end
local OLD_CRITICAL_AOE_19_ENTRY_DEFAULT =
    "Dragonknight Standard\nShifting Standard\nStandard of Might\nNova\nSolar Prison\nSolar Disturbance\nSleet Storm\nNorthern Storm\nPermafrost\nThe Unblinking Eye\nThe Tide King's Gaze\nThe Languid Eye\nMeteor\nIce Comet\nShooting Star\nElemental Storm\nElemental Rage\nEye of the Storm\nRavenous Goliath"
local function MigrateCriticalAoeAbilityListDefaultV2()
    local sv = PvPFPSLimiter.savedVars
    if not sv.criticalAoeListMigratedV2 then
        if sv.criticalAoeAbilityList == OLD_CRITICAL_AOE_19_ENTRY_DEFAULT then
            sv.criticalAoeAbilityList = defaults.criticalAoeAbilityList
        end
        sv.criticalAoeListMigratedV2 = true
    end
end
local OLD_CRITICAL_AOE_28_ENTRY_DEFAULT =
    "Dragonknight Standard\nShifting Standard\nStandard of Might\nNova\nSolar Prison\nSolar Disturbance\nSleet Storm\nNorthern Storm\nPermafrost\nThe Unblinking Eye\nThe Tide King's Gaze\nThe Languid Eye\nMeteor\nIce Comet\nShooting Star\nElemental Storm\nElemental Rage\nEye of the Storm\nRavenous Goliath\nRapid Fire\nBallista\nToxic Barrage\nLacerate\nRend\nThrive in Chaos\nFrozen Colossus\nGlacial Colossus\nPestilent Colossus"
local function MigrateCriticalAoeAbilityListDefaultV3()
    local sv = PvPFPSLimiter.savedVars
    if not sv.criticalAoeListMigratedV3 then
        if sv.criticalAoeAbilityList == OLD_CRITICAL_AOE_28_ENTRY_DEFAULT then
            sv.criticalAoeAbilityList = defaults.criticalAoeAbilityList
        end
        sv.criticalAoeListMigratedV3 = true
    end
end
local OLD_CRITICAL_AOE_32_ENTRY_DEFAULT =
    "Dragonknight Standard\nShifting Standard\nStandard of Might\nNova\nSolar Prison\nSolar Disturbance\nSleet Storm\nNorthern Storm\nPermafrost\nThe Unblinking Eye\nThe Tide King's Gaze\nThe Languid Eye\nMeteor\nIce Comet\nShooting Star\nElemental Storm\nElemental Rage\nEye of the Storm\nRavenous Goliath\nRapid Fire\nBallista\nToxic Barrage\nLacerate\nRend\nThrive in Chaos\nFrozen Colossus\nGlacial Colossus\nPestilent Colossus\nEye of Lightning\n85451\n85462\n83687"
local function MigrateCriticalAoeAbilityListDefaultV4()
    local sv = PvPFPSLimiter.savedVars
    if not sv.criticalAoeListMigratedV4 then
        if sv.criticalAoeAbilityList == OLD_CRITICAL_AOE_32_ENTRY_DEFAULT then
            sv.criticalAoeAbilityList = defaults.criticalAoeAbilityList
        end
        sv.criticalAoeListMigratedV4 = true
    end
end
local OLD_CRITICAL_AOE_40_ENTRY_DEFAULT =
    "Dragonknight Standard\nShifting Standard\nStandard of Might\nNova\nSolar Prison\nSolar Disturbance\nSleet Storm\nNorthern Storm\nPermafrost\nThe Unblinking Eye\nThe Tide King's Gaze\nThe Languid Eye\nMeteor\nIce Comet\nShooting Star\nElemental Storm\nElemental Rage\nEye of the Storm\nRavenous Goliath\nRapid Fire\nBallista\nToxic Barrage\nLacerate\nRend\nThrive in Chaos\nFrozen Colossus\nGlacial Colossus\nPestilent Colossus\nEye of Lightning\n85451\n85462\n83687\n17879\n62310\n40161\n62314\n40160\n80435\n47160\nOnslaught"
local function MigrateCriticalAoeAbilityListDefaultV5()
    local sv = PvPFPSLimiter.savedVars
    if not sv.criticalAoeListMigratedV5 then
        if sv.criticalAoeAbilityList == OLD_CRITICAL_AOE_40_ENTRY_DEFAULT then
            sv.criticalAoeAbilityList = defaults.criticalAoeAbilityList
        end
        sv.criticalAoeListMigratedV5 = true
    end
end
local function MigrateBlockingAlertPvpOnlyDefault()
    local sv = PvPFPSLimiter.savedVars
    if sv.blockingAlertPvpOnlyMigratedV730 then return end
    sv.blockingAlertPvpOnly = true
    sv.blockingAlertPvpOnlyMigratedV730 = true
end
local function EnsureCriticalAbilityListsNotEmpty()
    local sv = PvPFPSLimiter.savedVars
    if sv.criticalDelayedAbilityList == "" then
        sv.criticalDelayedAbilityList = defaults.criticalDelayedAbilityList
        if sv.debug then d("[LPI] Delayed-Hit Abilities list was empty on load - restored to default.") end
    end
    if sv.criticalAoeAbilityList == "" then
        sv.criticalAoeAbilityList = defaults.criticalAoeAbilityList
        if sv.debug then d("[LPI] Critical AOE Ultimate Abilities list was empty on load - restored to default.") end
    end
end
local function OnAddOnLoaded(eventCode, addOnName)
    if addOnName ~= LPI_ADDON then return end
    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)
    local isExistingInstall = type(LPI_PvPTools_SV) == "table" and next(LPI_PvPTools_SV) ~= nil
    if isExistingInstall then
        defaults.zoneFpsLimitsEnabled = true
    end
    PvPFPSLimiter.savedVars = ZO_SavedVars:NewAccountWide("LPI_PvPTools_SV", SAVED_VARS_VERSION, nil, defaults)
    PvPFPSLimiter.defaults = defaults
    MigrateEnabledBooleanToMode("notifyBlockingEnabled", "notifyBlockingMode")
    MigrateEnabledBooleanToMode("notifyUltimateEnabled", "notifyUltimateMode")
    MigrateEnabledBooleanToMode("notifyStunnedEnabled", "notifyStunnedMode")
    MigrateEnabledBooleanToMode("notifyImmobilizedEnabled", "notifyImmobilizedMode")
    MigrateLeaderMarkerEnabledToPerZone()
    MigrateLeaderMarkerOffByDefault()
    MigrateCriticalDelayedAbilityListDefault()
    MigrateCriticalDelayedAbilityListDefaultV2()
    MigrateCriticalAoeAbilityListDefault()
    MigrateCriticalDelayedInstantHits()
    MigrateCriticalAoeAbilityListDefaultV2()
    MigrateCriticalAoeAbilityListDefaultV3()
    MigrateCriticalAoeAbilityListDefaultV4()
    MigrateCriticalAoeAbilityListDefaultV5()
    MigrateBlockingAlertPvpOnlyDefault()
    EnsureCriticalAbilityListsNotEmpty()
    RegisterQuickslotKeybindStrings()
    RegisterSlashCommands()
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_PLAYER_ACTIVATED, OnPlayerActivated)
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ZONE_CHANGED, OnZoneChanged)
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_CAMPAIGN_QUEUE_STATE_CHANGED, OnCampaignQueueStateChanged)
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "Notifications", EVENT_COMBAT_EVENT, OnPvPNotificationCombatEvent)
    EVENT_MANAGER:RegisterForUpdate(ADDON_NAME .. "LeaderMarkerWatchdog", 1000, CheckLeaderMarkerWatchdog)
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "BreakFreeAlert", EVENT_EFFECT_CHANGED, OnPlayerEffectChanged)
    EVENT_MANAGER:AddFilterForEvent(ADDON_NAME .. "BreakFreeAlert", EVENT_EFFECT_CHANGED, REGISTER_FILTER_UNIT_TAG, "player")
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "BreakFreeAlertDeath", EVENT_PLAYER_DEAD, ClearAllActiveBreakFreeCc)
    EVENT_MANAGER:RegisterForUpdate(ADDON_NAME .. "BlockingAlertWatchdog", BLOCKING_ALERT_POLL_MS, UpdateBlockingAlertState)
end
EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
