TeamShadowsManager = TeamShadowsManager or {}

local PBT = TeamShadowsManager

local EM = EVENT_MANAGER
local ADDON_NAME = PBT.name
local UPDATE_NAME = ADDON_NAME .. "Countdown"
local SCAN_UPDATE_NAME = ADDON_NAME .. "DeferredScan"
local PORTAL_UPDATE_NAME = ADDON_NAME .. "NahviintaasPortalHP"
local NAHV_TIME_BREACH_ID = 121216
local GROUP_PULL_PREFIX = "PBT_PULL"

local function IsThisAddonLoadedName(addonName)
    return addonName == ADDON_NAME or addonName == PBT.displayName
end

if ZO_CreateStringId then
    ZO_CreateStringId("SI_BINDING_NAME_PBT_GROUP_COUNTDOWN", "Team Shadows Manager: decompte groupe")
    ZO_CreateStringId("SI_BINDING_NAME_PBT_OPEN_SETTINGS", "Team Shadows Manager: ouvrir menu")
    ZO_CreateStringId("SI_BINDING_NAME_PBT_TOGGLE_BOSS_TIMERS", "Team Shadows Manager: ON / OFF timer boss")
    ZO_CreateStringId("SI_BINDING_NAME_PBT_TOGGLE_GROUP_COUNTDOWN", "Team Shadows Manager: ON / OFF decompte")
    ZO_CreateStringId("SI_BINDING_NAME_PBT_RENDEZVOUS", "Team Shadows Manager: placer marker")
    ZO_CreateStringId("SI_BINDING_NAME_PBT_BAHSEI_CALL_REINFORCEMENTS", "Team Shadows Manager: Bahsei, appeler les renforts portail")
end

PBT.isRunning = false
PBT.activeKey = nil
PBT.activeBossName = nil
PBT.endsAt = 0
PBT.lastSecond = nil
PBT.lastScanMs = 0
PBT.triggerLockouts = {}
PBT.zmajaAddKills = 0
PBT.zmajaSpawnStarted = false
PBT.zmajaAddWindowMs = 0
PBT.cloudrestInitMs = 0
PBT.cloudrestPlus = 0
PBT.cloudrestPortalGroup = 0
PBT.cloudrestPortalActive = false
PBT.cloudrestLastPortalTimerMs = 0
PBT.cloudrestPullToken = 0
PBT.lastDummySeenMs = 0
PBT.lastDummyResetMs = 0
PBT.dummyWasInCombat = false
PBT.genericBossCandidates = {}
PBT.asOlmsJumpCount = 0
PBT.asOlmsPhase = 1
PBT.asOlmsLastJumpMs = 0
PBT.falgravnAirborne = false
PBT.falgravnGroundToken = 0
PBT.falgravnBasementAddsKilled = 0
PBT.nahvPortalActive = false
PBT.nahvPortalThreshold = nil
PBT.nahvPortalSkipOk = false
PBT.nahvPortalResultToken = 0
PBT.currentZoneName = nil
PBT.currentZoneId = nil
PBT.narrationLog = {}
PBT.hpThresholdState = {}
PBT.activeDisplayOffset = 0
PBT.lastGroupCountdownSentMs = 0
PBT.savedMarkerIcons = {}
PBT.markerCameraProbe = nil

local function Chat(message)
    if PBT.LocalizeChatMessage then message = PBT.LocalizeChatMessage(message) end
    d(string.format("|cFF3333%s|r: %s", PBT.displayName, tostring(message)))
end

local function NowMs()
    if GetFrameTimeMilliseconds then
        return GetFrameTimeMilliseconds()
    end
    return zo_floor(GetGameTimeMilliseconds and GetGameTimeMilliseconds() or (GetTimeStamp() * 1000))
end

local function NormalizeName(name)
    if type(name) ~= "string" or name == "" then return nil end

    name = zo_strlower(name)
    name = name:gsub("â€™", "'")
    name = name:gsub("Ã©", "e"):gsub("Ã¨", "e"):gsub("Ãª", "e"):gsub("Ã«", "e")
    name = name:gsub("Ã ", "a"):gsub("Ã¢", "a"):gsub("Ã¤", "a")
    name = name:gsub("Ã®", "i"):gsub("Ã¯", "i")
    name = name:gsub("Ã´", "o"):gsub("Ã¶", "o")
    name = name:gsub("Ã¹", "u"):gsub("Ã»", "u"):gsub("Ã¼", "u")
    name = name:gsub("Ã§", "c")
    name = name:gsub("|c%x%x%x%x%x%x", "")
    name = name:gsub("|r", "")
    name = name:gsub("%^.+", "")
    name = name:gsub("^%s+", ""):gsub("%s+$", "")
    name = name:gsub("%s+", " ")

    return name ~= "" and name or nil
end

local function IsEnabled()
    return PBT.savedVars and PBT.savedVars.enabled == true
end

local function BossSpawnTimersEnabled()
    return PBT.savedVars and PBT.savedVars.bossSpawnTimers ~= false
end

local function GroupCountdownEnabled()
    return PBT.savedVars and PBT.savedVars.groupCountdownEnabled ~= false
end

local function RefreshPlayerZone()
    local zoneName
    local zoneId

    if GetUnitZone then
        zoneName = GetUnitZone("player")
    end

    if (not zoneName or zoneName == "") and GetPlayerLocationName then
        zoneName = GetPlayerLocationName()
    end

    if GetUnitZoneIndex and GetZoneId then
        local zoneIndex = GetUnitZoneIndex("player")
        if zoneIndex then
            zoneId = GetZoneId(zoneIndex)
        end
    end

    if not zoneId and GetCurrentMapZoneIndex and GetZoneId then
        local zoneIndex = GetCurrentMapZoneIndex()
        if zoneIndex then
            zoneId = GetZoneId(zoneIndex)
        end
    end

    PBT.currentZoneName = type(zoneName) == "string" and zoneName ~= "" and zoneName or PBT.currentZoneName
    PBT.currentZoneId = zoneId or PBT.currentZoneId
end

local function GetPlayerZoneName()
    if not PBT.currentZoneName then
        RefreshPlayerZone()
    end
    return PBT.currentZoneName
end

local function IsInZoneKey(zoneKey)
    if not zoneKey then return true end

    RefreshPlayerZone()

    local zoneIds = PBT.zoneIds and PBT.zoneIds[zoneKey]
    if zoneIds and PBT.currentZoneId then
        return zoneIds[PBT.currentZoneId] == true
    end

    local zoneName = NormalizeName(PBT.currentZoneName)
    local aliases = PBT.zoneAliases and PBT.zoneAliases[zoneKey]
    if not zoneName or not aliases then return false end

    for _, alias in ipairs(aliases) do
        local normalizedAlias = NormalizeName(alias)
        if normalizedAlias and (zoneName == normalizedAlias or zoneName:find(normalizedAlias, 1, true)) then
            return true
        end
    end

    return false
end

local function GetCurrentTrialKey()
    if not PBT.trials then return nil end

    RefreshPlayerZone()

    for trialKey in pairs(PBT.trials) do
        if IsInZoneKey(trialKey) then
            return trialKey
        end
    end

    return nil
end

function PBT.IsInCurrentZoneKey(zoneKey)
    return IsInZoneKey(zoneKey)
end

function PBT.GetCurrentTrialKey()
    return GetCurrentTrialKey()
end

local function ResolveTimerBossKey(zoneKey, bossNameOrKey)
    local wanted = NormalizeName(bossNameOrKey)
    if not zoneKey or not wanted then return nil end

    for _, boss in ipairs((PBT.timerBossDefinitions and PBT.timerBossDefinitions[zoneKey]) or {}) do
        local candidates = { boss.key, boss.fr, boss.en }
        for _, alias in ipairs(boss.aliases or {}) do
            table.insert(candidates, alias)
        end
        for _, candidate in ipairs(candidates) do
            local normalized = NormalizeName(candidate)
            if normalized and (wanted == normalized or wanted:find(normalized, 1, true) or normalized:find(wanted, 1, true)) then
                return boss.key
            end
        end
    end

    return nil
end

function PBT.GetTimerBossDefinitions(zoneKey)
    return (PBT.timerBossDefinitions and PBT.timerBossDefinitions[zoneKey]) or {}
end

function PBT.IsInstanceTimerEnabled(zoneKey)
    if not zoneKey then return true end
    local settings = PBT.savedVars and PBT.savedVars.instanceTimerEnabled
    return not settings or settings[zoneKey] ~= false
end

function PBT.SetInstanceTimerEnabled(zoneKey, enabled)
    if not PBT.savedVars or not zoneKey then return end
    PBT.savedVars.instanceTimerEnabled = PBT.savedVars.instanceTimerEnabled or {}
    PBT.savedVars.instanceTimerEnabled[zoneKey] = enabled == true
end

function PBT.IsBossTimerEnabled(zoneKey, bossNameOrKey)
    if not zoneKey then return true end
    local bossKey = ResolveTimerBossKey(zoneKey, bossNameOrKey)
    if not bossKey then return true end
    local settings = PBT.savedVars and PBT.savedVars.bossTimerEnabled
    return not settings or settings[zoneKey .. "|" .. bossKey] ~= false
end

function PBT.SetBossTimerEnabled(zoneKey, bossNameOrKey, enabled)
    if not PBT.savedVars or not zoneKey then return end
    local bossKey = ResolveTimerBossKey(zoneKey, bossNameOrKey)
    if not bossKey then return end
    PBT.savedVars.bossTimerEnabled = PBT.savedVars.bossTimerEnabled or {}
    PBT.savedVars.bossTimerEnabled[zoneKey .. "|" .. bossKey] = enabled == true
end

local function AutomaticTimerSelectionEnabled(zoneKey, bossNameOrKey)
    if not BossSpawnTimersEnabled() then return false end
    if zoneKey and not PBT.IsInstanceTimerEnabled(zoneKey) then return false end
    if zoneKey and bossNameOrKey and not PBT.IsBossTimerEnabled(zoneKey, bossNameOrKey) then return false end
    return true
end

local function PlayTickSound(secondsRemaining)
    if not PBT.savedVars or not PBT.savedVars.soundEnabled or not PlaySound then return end

    local sounds = SOUNDS or {}
    local sound

    if secondsRemaining == 0 then
        sound = sounds.DUEL_START or sounds.QUEST_OBJECTIVE_STARTED
    elseif secondsRemaining <= 3 then
        sound = sounds.COUNTDOWN_TICK or sounds.DEFAULT_CLICK
    end

    if sound then
        PlaySound(sound)
    end
end

local function IsLockedOut(key, nowMs, lockoutSeconds)
    local lastTrigger = PBT.triggerLockouts[key]
    local seconds = tonumber(lockoutSeconds) or (PBT.savedVars.lockoutSeconds or PBT.defaults.lockoutSeconds)
    local lockoutMs = seconds * 1000

    return lastTrigger ~= nil and (nowMs - lastTrigger) < lockoutMs
end

local function MarkTriggered(key, nowMs)
    PBT.triggerLockouts[key] = nowMs
end

function PBT.StopCountdown(keepVisible)
    EM:UnregisterForUpdate(UPDATE_NAME)

    PBT.isRunning = false
    PBT.activeKey = nil
    PBT.activeBossName = nil
    PBT.endsAt = 0
    PBT.lastSecond = nil
    PBT.activeDisplayOffset = 0

    if keepVisible or (PBT.savedVars and PBT.savedVars.unlocked) then
        PBT.UI:ShowIdle()
    else
        PBT.UI:Hide()
    end
end

function PBT.StartCountdown(trigger)
    if not IsEnabled() or not trigger or not trigger.seconds then return end

    local key = NormalizeName(trigger.lockoutKey or trigger.bossName)
    if not key then return end

    local nowMs = NowMs()
    local canRestart = trigger.restart == true and PBT.isRunning and PBT.activeKey == key

    if PBT.isRunning and not canRestart then return end
    if not canRestart and IsLockedOut(key, nowMs, trigger.lockoutSeconds) then return end

    if not canRestart then
        MarkTriggered(key, nowMs)
    end

    PBT.isRunning = true
    PBT.activeKey = key
    PBT.activeBossName = trigger.bossName
    PBT.activeDisplayOffset = zo_clamp(tonumber(trigger.displayOffset) or 0, -10, tonumber(trigger.seconds) or 0)
    PBT.endsAt = nowMs + ((trigger.seconds - PBT.activeDisplayOffset) * 1000)
    PBT.lastSecond = nil

    local function Update()
        local remainingMs = PBT.endsAt - NowMs()
        local secondsRemaining = zo_ceil(remainingMs / 1000)

        if secondsRemaining <= 0 then
            if PBT.lastSecond ~= 0 then
                PBT.lastSecond = 0
                PBT.UI:ShowGo(PBT.activeBossName)
                PlayTickSound(0)
            end

            zo_callLater(function()
                if PBT.isRunning and PBT.lastSecond == 0 then
                    PBT.StopCountdown(false)
                end
            end, 900)
            EM:UnregisterForUpdate(UPDATE_NAME)
            return
        end

        if secondsRemaining ~= PBT.lastSecond then
            PBT.lastSecond = secondsRemaining
            PBT.UI:ShowCountdown(PBT.activeBossName, secondsRemaining)
            PlayTickSound(secondsRemaining)
        end
    end

    Update()
    EM:RegisterForUpdate(UPDATE_NAME, 100, Update)
end

function PBT.StartNamedCountdown(name, seconds, lockoutKey)
    if not IsEnabled() or not name or not seconds then return end

    PBT.StartCountdown({
        bossName = name,
        seconds = seconds,
        lockoutKey = lockoutKey or name,
    })
end

local function GetGroupCountdownSeconds(args)
    local seconds = tonumber(args)
    if not seconds then
        seconds = tonumber(PBT.savedVars and PBT.savedVars.groupCountdownSeconds) or PBT.defaults.groupCountdownSeconds
    end

    return zo_clamp(seconds, 0, 20)
end

local function GetGroupCountdownPersonalDelay()
    local delay = tonumber(PBT.savedVars and PBT.savedVars.groupCountdownDpsDelay) or PBT.defaults.groupCountdownDpsDelay
    return zo_clamp(delay, -10, 10)
end

local function GetGroupCountdownDisplayOffset()
    return zo_clamp(-GetGroupCountdownPersonalDelay(), -10, 20)
end

local function GetGroupCountdownLabel()
    return "PULL"
end

local function BroadcastGroupCountdown(seconds)
    if not PBT.savedVars or not PBT.savedVars.groupCountdownBroadcast then return end
    if not IsUnitGrouped or not IsUnitGrouped("player") then return end

    seconds = GetGroupCountdownSeconds(seconds)
    PBT.lastGroupCountdownSentMs = NowMs()

    if LibTeamShadows and LibTeamShadows.BroadcastPull then
        LibTeamShadows.BroadcastPull(seconds)
    end

    -- Chat sending from addon code is blocked by ESO secure execution in several contexts.
    -- Group sharing uses LibGroupBroadcast through LibTeamShadows only.
end

function PBT.StartGroupCountdown(seconds, broadcast, received)
    if not GroupCountdownEnabled() then return end

    if PBT.isRunning and PBT.activeKey == "grouppull" and not received then
        PBT.StopCountdown(false)
        if broadcast then
            BroadcastGroupCountdown(0)
        end
        return
    end

    seconds = GetGroupCountdownSeconds(seconds)
    if seconds <= 0 then
        if PBT.isRunning and PBT.activeKey == "grouppull" then
            PBT.StopCountdown(false)
        end
        return
    end

    PBT.triggerLockouts.groupPull = nil
    if PBT.isRunning and PBT.activeKey ~= "grouppull" then
        PBT.StopCountdown(false)
    end

    PBT.StartCountdown({
        bossName = GetGroupCountdownLabel(),
        seconds = seconds,
        lockoutKey = "groupPull",
        lockoutSeconds = 0,
        restart = true,
        displayOffset = GetGroupCountdownDisplayOffset(),
    })

    if broadcast then
        BroadcastGroupCountdown(seconds)
    end
end

local function ReceiveGroupCountdown(seconds)
    if not GroupCountdownEnabled() then return end
    PBT.StartGroupCountdown(seconds, false, true)
end

function PBT.StartGroupCountdownFromKeybind()
    if not PBT.savedVars then return end
    PBT.savedVars.groupCountdownEnabled = true
    PBT.savedVars.groupCountdownBroadcast = true
    PBT.StartGroupCountdown(PBT.savedVars.groupCountdownSeconds, true)
end

function PBT.OpenSettings()
    if LibAddonMenu2 and LibAddonMenu2.OpenToPanel and PBT.settingsPanel then
        LibAddonMenu2:OpenToPanel(PBT.settingsPanel)
        return
    end

    Chat("menu indisponible: LibAddonMenu-2.0 n'est pas active.")
end

function PBT.OpenManagerWindow()
    if PBT.UI and PBT.UI.ShowManagerWindow then
        PBT.UI:ShowManagerWindow()
    end
end

function PBT.ToggleBossSpawnTimers()
    if not PBT.savedVars then return end

    local enabled = not BossSpawnTimersEnabled()
    PBT.savedVars.bossSpawnTimers = enabled
    PBT.savedVars.useSamuraiTimers = enabled
    Chat(enabled and "timers boss ON." or "timers boss OFF.")
end

function PBT.ToggleGroupCountdown()
    if not PBT.savedVars then return end

    PBT.savedVars.groupCountdownEnabled = not GroupCountdownEnabled()
    if not PBT.savedVars.groupCountdownEnabled and PBT.isRunning and PBT.activeKey == "grouppull" then
        PBT.StopCountdown(false)
    end
    Chat(PBT.savedVars.groupCountdownEnabled and "décompte personnalisé ON." or "décompte personnalisé OFF.")
end

local function RefreshLibTeamShadowsOptions()
    if not LibTeamShadows then return end
    if LibTeamShadows.SetRendezvousOptIn then
        LibTeamShadows.SetRendezvousOptIn(PBT.savedVars and PBT.savedVars.groupRendezvousReceive ~= false)
    end
    if LibTeamShadows.SetAcceptLeadOnly then
        LibTeamShadows.SetAcceptLeadOnly(false)
    end
    if LibTeamShadows.SetMarkerSize then
        LibTeamShadows.SetMarkerSize(PBT.savedVars and PBT.savedVars.groupBeaconSize or PBT.defaults.groupBeaconSize)
    end
    if LibTeamShadows.SetMarkerHeight then
        LibTeamShadows.SetMarkerHeight(PBT.savedVars and PBT.savedVars.groupBeaconHeight or PBT.defaults.groupBeaconHeight)
    end
    if LibTeamShadows.SetMarkerDuration then
        LibTeamShadows.SetMarkerDuration((PBT.savedVars and PBT.savedVars.groupBeaconDuration or PBT.defaults.groupBeaconDuration) * 1000)
    end
end

local function RegisterLibTeamShadowsHandlers()
    if not LibTeamShadows or not LibTeamShadows.RegisterHandler then return end

    LibTeamShadows.RegisterHandler(ADDON_NAME, function(command, payload)
        if command ~= "pull" then return end
        if not payload then return end

        local seconds = tonumber(payload.seconds)
        if not seconds then return end

        if seconds <= 0 then
            if PBT.isRunning and PBT.activeKey == "grouppull" then
                PBT.StopCountdown(false)
            end
            return
        end

        ReceiveGroupCountdown(seconds)
    end)
end
local function GetBeaconLabelId()
    if not PBT.savedVars then return 1 end

    local label = PBT.savedVars.groupBeaconLabel or PBT.defaults.groupBeaconLabel
    if label == "auto" then
        local markers = PBT.savedVars.groupBeaconSavedMarkers or {}
        local number = (#markers % 10) + 1
        PBT.savedVars.groupBeaconNextNumber = number + 1
        if PBT.savedVars.groupBeaconNextNumber > 10 then
            PBT.savedVars.groupBeaconNextNumber = 1
        end
        return number
    end

    return PBT.beaconLabelIds[label] or 1
end

local function GetBeaconOptions()
    if not PBT.savedVars then return 1, {} end

    local textureId = zo_clamp(tonumber(PBT.savedVars.groupBeaconTextureId) or PBT.defaults.groupBeaconTextureId, 1, 23)
    return textureId, {
        labelId = GetBeaconLabelId(),
        customLabel = (PBT.savedVars.groupBeaconCustomLabel and PBT.savedVars.groupBeaconCustomLabel ~= "" and PBT.savedVars.groupBeaconCustomLabel) or nil,
        size = zo_clamp(tonumber(PBT.savedVars.groupBeaconSize) or PBT.defaults.groupBeaconSize, 24, 160),
        heightOffset = zo_clamp(tonumber(PBT.savedVars.groupBeaconHeight) or PBT.defaults.groupBeaconHeight, -40, 80),
        durationMs = zo_clamp(tonumber(PBT.savedVars.groupBeaconDuration) or PBT.defaults.groupBeaconDuration, 1, 60) * 1000,
    }
end

local function BuildSavedMarkerOptions(marker)
    marker = marker or {}

    return {
        labelId = marker.labelId,
        size = marker.size,
        heightOffset = zo_clamp(tonumber(marker.heightOffset) or tonumber(PBT.savedVars and PBT.savedVars.groupBeaconHeight) or PBT.defaults.groupBeaconHeight, -40, 80),
        durationMs = marker.durationMs,
        textureId = marker.textureId,
        customLabel = marker.customLabel,
        color = marker.color,
    }
end


local function BuildBeaconMarker(zone, wX, wY, wZ, textureId, options)
    if not zone or not wX or not wY or not wZ then return nil end

    textureId = textureId or 1
    options = options or {}

    return {
        zone = zone,
        x = wX,
        y = wY,
        z = wZ,
        textureId = textureId,
        labelId = options.labelId,
        size = options.size,
        heightOffset = options.heightOffset,
        customLabel = options.customLabel,
        color = options.color,
        durationMs = options.durationMs,
    }
end

local function BuildMarkerFromCurrentPosition(textureId, options)
    if not PBT.savedVars or not GetUnitRawWorldPosition then return nil end

    local zone, wX, wY, wZ = GetUnitRawWorldPosition("player")
    if not zone or not wX or not wY or not wZ then return nil end

    return BuildBeaconMarker(zone, wX, wY, wZ, textureId, options)
end

local function EnsureMarkerCameraProbe()
    if PBT.markerCameraProbe then return PBT.markerCameraProbe end
    if not WINDOW_MANAGER or not GuiRoot then return nil end

    local probe = WINDOW_MANAGER:CreateControl("TeamShadowsManagerMarkerCameraProbe", GuiRoot, CT_CONTROL)
    probe:SetAnchorFill(GuiRoot)
    probe:Create3DRenderSpace()
    probe:SetHidden(true)

    PBT.markerCameraProbe = probe
    return probe
end

local function BuildMarkerFromCameraTarget(textureId, options)
    if not PBT.savedVars or not GetUnitRawWorldPosition then return nil end
    if not Set3DRenderSpaceToCurrentCamera or not GuiRender3DPositionToWorldPosition then return nil end

    local zone, playerX, playerY, playerZ = GetUnitRawWorldPosition("player")
    if not zone or not playerX or not playerY or not playerZ then return nil end

    local probe = EnsureMarkerCameraProbe()
    if not probe then return nil end

    Set3DRenderSpaceToCurrentCamera(probe:GetName())
    local cameraX, cameraY, cameraZ = GuiRender3DPositionToWorldPosition(probe:Get3DRenderSpaceOrigin())
    local forwardX, forwardY, forwardZ = probe:Get3DRenderSpaceForward()
    if not cameraX or not cameraY or not cameraZ or not forwardX or not forwardY or not forwardZ then return nil end

    -- ESO does not expose the ground-target hit point. This reconstructs it by
    -- intersecting the camera ray with the player's current floor height.
    if math.abs(forwardY) < 0.0001 then return nil end

    local t = (playerY - cameraY) / forwardY
    if t <= 0 then return nil end

    local targetX = cameraX + (forwardX * t)
    local targetY = playerY
    local targetZ = cameraZ + (forwardZ * t)
    local dx = targetX - playerX
    local dz = targetZ - playerZ
    local horizontalDistance = math.sqrt((dx * dx) + (dz * dz))

    if horizontalDistance < 100 or horizontalDistance > 3500 then
        return nil
    end

    return BuildBeaconMarker(zone, zo_round(targetX), zo_round(targetY), zo_round(targetZ), textureId, options)
end

local function SaveMarker(marker)
    if not PBT.savedVars or not marker then return nil end

    PBT.savedVars.groupBeaconSavedMarkers = PBT.savedVars.groupBeaconSavedMarkers or {}
    table.insert(PBT.savedVars.groupBeaconSavedMarkers, marker)

    if PBT.SyncActiveMarkerSet then PBT.SyncActiveMarkerSet() end
    return #PBT.savedVars.groupBeaconSavedMarkers
end

function PBT.PlaceMarkerFromReticle()
    if not PBT.savedVars or PBT.savedVars.groupBeaconPlacementEnabled ~= true then
        Chat("placement marker OFF.")
        return false
    end

    RefreshLibTeamShadowsOptions()

    return PBT.SaveCurrentMarker()
end

function PBT.SendGroupRendezvous()
    return PBT.PlaceMarkerFromReticle()
end

function PBT.SaveCurrentMarker()
    local textureId, options = GetBeaconOptions()
    local marker = BuildMarkerFromCameraTarget(textureId, options) or BuildMarkerFromCurrentPosition(textureId, options)
    if not marker then
        Chat("position joueur indisponible.")
        return false
    end

    local index = SaveMarker(marker)
    PBT.RefreshSavedMarkers()

    if PBT.UI and PBT.UI.RefreshManagerWindow then
        PBT.UI:RefreshManagerWindow()
    end

    Chat(string.format("marker %d enregistre.", index or 0))
    return true
end

function PBT.ClearDisplayedSavedMarkers()
    if not PBT.savedMarkerIcons then
        PBT.savedMarkerIcons = {}
        return
    end

    for _, icon in ipairs(PBT.savedMarkerIcons) do
        if LibTeamShadows and LibTeamShadows.DiscardWorldMarker then
            LibTeamShadows.DiscardWorldMarker(icon)
        end
    end

    PBT.savedMarkerIcons = {}
end

function PBT.RefreshSavedMarkers()
    PBT.ClearDisplayedSavedMarkers()

    if not PBT.savedVars or not LibTeamShadows or not LibTeamShadows.PlaceWorldMarker then return end
    if not GetUnitRawWorldPosition then return end

    local currentZone = GetUnitRawWorldPosition("player")
    local markers = PBT.savedVars.groupBeaconSavedMarkers or {}
    local displayMode = PBT.savedVars.groupBeaconDisplayMode or "all"
    local displayLabel = PBT.savedVars.groupBeaconDisplayLabel or "all"
    local displayLabelId = PBT.beaconLabelIds[displayLabel or ""] or tonumber(displayLabel)

    for _, marker in ipairs(markers) do
        local labelMatches = displayMode ~= "filter" or displayLabel == "all" or tonumber(marker and marker.labelId) == tonumber(displayLabelId)
        if marker and marker.zone == currentZone and labelMatches then
            local options = BuildSavedMarkerOptions(marker)
            options.persistent = true

            local icon = LibTeamShadows.PlaceWorldMarker(marker, options)
            if icon then
                table.insert(PBT.savedMarkerIcons, icon)
            end
        end
    end
end

local function SerializeMarkers(markers)
    local parts = { "TSM1" }

    for _, marker in ipairs(markers) do
        if marker and marker.zone and marker.x and marker.y and marker.z then
            local color = marker.color or {}
            parts[#parts + 1] = table.concat({
                tostring(marker.zone),
                tostring(marker.x),
                tostring(marker.y),
                tostring(marker.z),
                tostring(marker.textureId or 1),
                tostring(marker.labelId or 1),
                tostring(marker.size or PBT.defaults.groupBeaconSize),
                tostring(marker.heightOffset or PBT.defaults.groupBeaconHeight),
                tostring(marker.durationMs or (PBT.defaults.groupBeaconDuration * 1000)),
                tostring(marker.customLabel or ""),
                tostring(color.r or color[1] or ""),
                tostring(color.g or color[2] or ""),
                tostring(color.b or color[3] or ""),
            }, ",")
        end
    end

    return table.concat(parts, ";")
end

function PBT.ExportSavedMarkers()
    local markers = PBT.savedVars and PBT.savedVars.groupBeaconSavedMarkers or {}
    return SerializeMarkers(markers)
end

function PBT.GetSavedMarkerSetName()
    local markers = PBT.savedVars and PBT.savedVars.groupBeaconSavedMarkers or {}
    local marker = markers[1]
    if not marker or not marker.zone then
        return "Aucune instance importee"
    end

    if GetZoneNameById then
        local name = GetZoneNameById(marker.zone)
        if name and name ~= "" then
            return zo_strformat("<<1>>", name)
        end
    end

    return "Zone " .. tostring(marker.zone)
end

local function GetCurrentZoneId()
    if GetUnitRawWorldPosition then
        local zone = GetUnitRawWorldPosition("player")
        return tonumber(zone)
    end
    return nil
end

local raidMarkerDirectory = {
    { zoneKey = "free", name = "Zone libre / actuelle" },
    { zoneKey = "aetherianArchive", name = "Aetherian Archive" },
    { zoneKey = "sanctumOphidia", name = "Sanctum Ophidia" },
    { zoneKey = "helRaCitadel", name = "Hel Ra Citadel" },
    { zoneKey = "mawOfLorkhaj", name = "Maw of Lorkhaj" },
    { zoneKey = "hallsOfFabrication", name = "Halls of Fabrication" },
    { zoneKey = "asylumSanctorium", name = "Asylum Sanctorium" },
    { zoneKey = "cloudrest", name = "Cloudrest" },
    { zoneKey = "sunspire", name = "Sunspire" },
    { zoneKey = "kynesAegis", name = "Kyne's Aegis" },
    { zoneKey = "rockgrove", name = "Rockgrove" },
    { zoneKey = "dreadsailReef", name = "Dreadsail Reef" },
    { zoneKey = "sanitysEdge", name = "Sanity's Edge" },
    { zoneKey = "lucentCitadel", name = "Lucent Citadel" },
    { zoneKey = "osseinCage", name = "Ossein Cage" },
}

local raidMarkerDirectoryByKey = {}
for _, entry in ipairs(raidMarkerDirectory) do
    raidMarkerDirectoryByKey[entry.zoneKey] = entry
end

local function IsValidMarkerDirectoryKey(zoneKey)
    zoneKey = tostring(zoneKey or "")
    return raidMarkerDirectoryByKey[zoneKey] ~= nil or zoneKey:match("^zone_%d+$") ~= nil
end

local function GetCurrentMarkerDirectoryKey()
    local currentTrialKey = GetCurrentTrialKey and GetCurrentTrialKey() or nil
    if currentTrialKey and raidMarkerDirectoryByKey[currentTrialKey] then return currentTrialKey end
    local zoneId = GetCurrentZoneId()
    if zoneId then return "zone_" .. tostring(zoneId) end
    return "free"
end

local function GetPrimaryZoneIdForKey(zoneKey)
    local dynamicZoneId = tostring(zoneKey or ""):match("^zone_(%d+)$")
    if dynamicZoneId then return dynamicZoneId end
    if zoneKey == "free" then return nil end
    local ids = PBT.zoneIds and PBT.zoneIds[zoneKey]
    if type(ids) ~= "table" then return nil end
    for zoneId in pairs(ids) do
        return tostring(zoneId)
    end
    return nil
end

local function GetSelectedMarkerDirectoryKey()
    local selected = PBT.savedVars and PBT.savedVars.groupBeaconDirectoryKey
    if selected and selected ~= "" and IsValidMarkerDirectoryKey(selected) then
        return selected
    end

    local currentKey = GetCurrentMarkerDirectoryKey()
    if PBT.savedVars then PBT.savedVars.groupBeaconDirectoryKey = currentKey end
    return currentKey
end


local function GetMarkerSetForRead(zoneKey, slot)
    local sets = PBT.savedVars and PBT.savedVars.groupBeaconMarkerSets
    if not sets then return nil end

    local zoneSets = sets[zoneKey]
    if zoneSets and zoneSets.markers and zoneSets.slots and zoneSets.slots[slot] then
        local namedSet = zoneSets.markers[zoneSets.slots[slot]]
        if namedSet then return namedSet end
    end

    local set = zoneSets and zoneSets[slot]
    if set then return set end

    local legacyZoneId = GetPrimaryZoneIdForKey(zoneKey)
    if legacyZoneId and sets[legacyZoneId] then
        local legacySets = sets[legacyZoneId]
        if legacySets.markers and legacySets.slots and legacySets.slots[slot] then
            local namedSet = legacySets.markers[legacySets.slots[slot]]
            if namedSet then return namedSet end
        end
        return legacySets[slot]
    end

    return nil
end

local function GetMarkerSetSlot()
    return zo_clamp(tonumber(PBT.savedVars and PBT.savedVars.groupBeaconMarkerSetSlot) or 1, 1, 3)
end

local function CopyTable(source)
    if type(source) ~= "table" then return source end
    local target = {}
    for key, value in pairs(source) do
        target[key] = CopyTable(value)
    end
    return target
end

local function CleanMarkerSetName(slot, name)
    slot = zo_clamp(tonumber(slot) or 1, 1, 3)
    name = tostring(name or "")
    if name == "" or name == ("Liste " .. tostring(slot)) or name == ("Pack " .. tostring(slot)) then
        return "Pack " .. tostring(slot)
    end
    return name
end

local function GetMarkerSetZoneStorage(zoneKey)
    if not PBT.savedVars then return nil end
    PBT.savedVars.groupBeaconMarkerSets = PBT.savedVars.groupBeaconMarkerSets or {}
    PBT.savedVars.groupBeaconMarkerSets[zoneKey] = PBT.savedVars.groupBeaconMarkerSets[zoneKey] or {}

    local storage = PBT.savedVars.groupBeaconMarkerSets[zoneKey]
    storage.markers = storage.markers or {}
    storage.slots = storage.slots or {}
    return storage
end

local function GetMarkerPackName(slot)
    slot = zo_clamp(tonumber(slot) or GetMarkerSetSlot(), 1, 3)
    local zoneKey = GetSelectedMarkerDirectoryKey()
    local storage = GetMarkerSetZoneStorage(zoneKey)
    local key = storage and storage.slots and storage.slots[slot]
    local set = key and storage.markers and storage.markers[key]
    return CleanMarkerSetName(slot, set and set.name or key)
end


function PBT.SaveCurrentMarkerSet(name)
    if not PBT.savedVars then return false, "variables non pretes" end

    local markers = PBT.savedVars.groupBeaconSavedMarkers or {}
    if #markers == 0 then return false, "aucun marker a sauver" end

    local zone = markers[1] and markers[1].zone or GetCurrentZoneId()
    local zoneKey = GetSelectedMarkerDirectoryKey()
    local slot = GetMarkerSetSlot()
    local cleanName = CleanMarkerSetName(slot, name or GetMarkerPackName(slot))
    local storage = GetMarkerSetZoneStorage(zoneKey)

    storage.markers[cleanName] = {
        name = cleanName,
        slot = slot,
        zone = zone,
        markers = CopyTable(markers),
    }
    storage.slots[slot] = cleanName
    storage[slot] = nil
    PBT.savedVars.groupBeaconMarkerSetName = cleanName

    return true, "pack " .. tostring(slot) .. " enregistre"
end

-- Write-through: mirror the working marker list into the active pack
-- slot whenever that slot holds a stored pack. Without this, every
-- edit lived only in groupBeaconSavedMarkers and was silently wiped
-- the next time ActivateCurrentMarkerSet re-copied the stale stored
-- pack over the working list.
function PBT.SyncActiveMarkerSet()
    if not PBT.savedVars then return end
    if PBT.temporaryGroupMarkerShare then return end

    local slot = GetMarkerSetSlot()
    local zoneKey = GetSelectedMarkerDirectoryKey()
    local sets = PBT.savedVars.groupBeaconMarkerSets
    local storage = sets and sets[zoneKey]
    local key = storage and storage.slots and storage.slots[slot]
    if not key or not storage.markers or not storage.markers[key] then return end

    storage.markers[key].markers = CopyTable(PBT.savedVars.groupBeaconSavedMarkers or {})
end

function PBT.LoadCurrentMarkerSet(slot)
    if not PBT.savedVars then return false, "variables non pretes" end

    slot = zo_clamp(tonumber(slot) or GetMarkerSetSlot(), 1, 3)
    local zoneKey = GetSelectedMarkerDirectoryKey()
    local set = GetMarkerSetForRead(zoneKey, slot)

    if not set or not set.markers then return false, "pack vide" end

    PBT.savedVars.groupBeaconMarkerSetSlot = slot
    PBT.savedVars.groupBeaconSavedMarkers = CopyTable(set.markers)
    PBT.savedVars.groupBeaconImportedName = set.name
    PBT.savedVars.groupBeaconMarkerSetName = set.name
    PBT.RefreshSavedMarkers()
    return true, "pack " .. tostring(slot) .. " charge"
end

function PBT.ActivateCurrentMarkerSet(slot)
    if not PBT.savedVars then return false, "variables non pretes" end

    if PBT.temporaryGroupMarkerShare then
        PBT.temporaryGroupMarkerShare = nil
        PBT.savedVars.groupShareTemporaryBackup = nil
    end

    slot = zo_clamp(tonumber(slot) or GetMarkerSetSlot(), 1, 3)
    PBT.savedVars.groupBeaconMarkerSetSlot = slot

    local set = GetMarkerSetForRead(GetSelectedMarkerDirectoryKey(), slot)
    if set and set.markers then
        PBT.savedVars.groupBeaconSavedMarkers = CopyTable(set.markers)
        PBT.savedVars.groupBeaconImportedName = set.name
        PBT.savedVars.groupBeaconMarkerSetName = CleanMarkerSetName(slot, set.name)
        PBT.savedVars.groupBeaconNextNumber = (#PBT.savedVars.groupBeaconSavedMarkers % 10) + 1
        PBT.RefreshSavedMarkers()
        return true, "pack " .. tostring(slot) .. " charge"
    end

    PBT.savedVars.groupBeaconSavedMarkers = {}
    PBT.savedVars.groupBeaconImportedName = ""
    PBT.savedVars.groupBeaconMarkerSetName = GetMarkerPackName(slot)
    PBT.savedVars.groupBeaconNextNumber = 1
    PBT.RefreshSavedMarkers()
    return true, "pack " .. tostring(slot) .. " vide"
end

function PBT.ExportCurrentMarkerSet(slot)
    if not PBT.savedVars then return "" end

    slot = zo_clamp(tonumber(slot) or GetMarkerSetSlot(), 1, 3)
    local set = GetMarkerSetForRead(GetSelectedMarkerDirectoryKey(), slot)
    if set and set.markers then
        return SerializeMarkers(set.markers)
    end

    return SerializeMarkers(PBT.savedVars.groupBeaconSavedMarkers or {})
end

function PBT.ImportCurrentMarkerSet(text)
    if not PBT.ImportSavedMarkers then return false, "import indisponible" end

    local ok, message = PBT.ImportSavedMarkers(text)
    if not ok then return ok, message end

    return PBT.SaveCurrentMarkerSet(GetMarkerPackName(GetMarkerSetSlot()))
end

function PBT.DeleteCurrentMarkerSet(slot)
    if not PBT.savedVars then return false, "variables non pretes" end

    slot = zo_clamp(tonumber(slot) or GetMarkerSetSlot(), 1, 3)
    local zoneKey = GetSelectedMarkerDirectoryKey()
    local storage = PBT.savedVars.groupBeaconMarkerSets and PBT.savedVars.groupBeaconMarkerSets[zoneKey]
    if storage then
        local key = storage.slots and storage.slots[slot]
        if key and storage.markers then storage.markers[key] = nil end
        if storage.slots then storage.slots[slot] = nil end
        storage[slot] = nil
    end
    local legacyZoneId = GetPrimaryZoneIdForKey(zoneKey)
    if legacyZoneId and PBT.savedVars.groupBeaconMarkerSets and PBT.savedVars.groupBeaconMarkerSets[legacyZoneId] then
        local legacyStorage = PBT.savedVars.groupBeaconMarkerSets[legacyZoneId]
        local key = legacyStorage.slots and legacyStorage.slots[slot]
        if key and legacyStorage.markers then legacyStorage.markers[key] = nil end
        if legacyStorage.slots then legacyStorage.slots[slot] = nil end
        legacyStorage[slot] = nil
    end

    PBT.savedVars.groupBeaconSavedMarkers = {}
    PBT.savedVars.groupBeaconMarkerSetName = CleanMarkerSetName(slot, nil)
    PBT.savedVars.groupBeaconImportedName = ""
    if PBT.RefreshSavedMarkers then PBT.RefreshSavedMarkers() end

    return true, "pack " .. tostring(slot) .. " supprime"
end

function PBT.GetCurrentMarkerSetInfo(slot)
    if not PBT.savedVars then return nil end

    slot = zo_clamp(tonumber(slot) or GetMarkerSetSlot(), 1, 3)
    local set = GetMarkerSetForRead(GetSelectedMarkerDirectoryKey(), slot)
    if set then
        set.name = CleanMarkerSetName(slot, set.name)
    end
    return set
end

function PBT.GetMarkerPackName(slot)
    return GetMarkerPackName(slot)
end

function PBT.RenameMarkerPack(slot, name)
    if not PBT.savedVars then return false, "variables non pretes" end

    slot = zo_clamp(tonumber(slot) or GetMarkerSetSlot(), 1, 3)
    local newName = CleanMarkerSetName(slot, name)
    local zoneKey = GetSelectedMarkerDirectoryKey()
    local storage = GetMarkerSetZoneStorage(zoneKey)
    local oldKey = storage.slots[slot]

    if oldKey == newName then
        return true, "pack renomme"
    end

    local existing = oldKey and storage.markers[oldKey] or GetMarkerSetForRead(zoneKey, slot) or { markers = {} }
    if oldKey then
        storage.markers[oldKey] = nil
    end
    existing.name = newName
    existing.slot = slot
    existing.markers = existing.markers or {}
    storage.markers[newName] = existing
    storage.slots[slot] = newName
    storage[slot] = nil

    if GetMarkerSetSlot() == slot then
        PBT.savedVars.groupBeaconMarkerSetName = newName
    end

    return true, "pack renomme"
end

function PBT.GetMarkerDirectoryEntries()
    return raidMarkerDirectory
end

function PBT.SetMarkerDirectory(zoneKey)
    if not PBT.savedVars or not IsValidMarkerDirectoryKey(zoneKey) then return false end
    PBT.savedVars.groupBeaconDirectoryKey = zoneKey
    return true
end

function PBT.GetMarkerDirectoryKey()
    return GetSelectedMarkerDirectoryKey()
end

function PBT.GetMarkerDirectoryName()
    local key = GetSelectedMarkerDirectoryKey()
    local dynamicZoneId = tostring(key):match("^zone_(%d+)$")
    if dynamicZoneId then
        local zoneName = GetZoneNameById and zo_strformat("<<1>>", GetZoneNameById(tonumber(dynamicZoneId)) or "") or ""
        return zoneName ~= "" and zoneName or ("Zone " .. dynamicZoneId)
    end
    if key == "free" then
        local zoneId = GetCurrentZoneId()
        if zoneId and GetZoneNameById then
            local zoneName = zo_strformat("<<1>>", GetZoneNameById(zoneId) or "")
            if zoneName and zoneName ~= "" then
                return PBT.GetString and PBT.GetString("free_zone_prefix", zoneName) or ("Libre - " .. zoneName)
            end
        end
        return PBT.GetLocalizedZoneName and PBT.GetLocalizedZoneName("free", "Zone libre / actuelle") or "Zone libre / actuelle"
    end
    local entry = raidMarkerDirectoryByKey[key]
    local fallback = entry and entry.name or "Raid"
    return PBT.GetLocalizedZoneName and PBT.GetLocalizedZoneName(key, fallback) or fallback
end

function PBT.GetMarkerDirectoryNameForKey(zoneKey)
    local dynamicZoneId = tostring(zoneKey or ""):match("^zone_(%d+)$")
    if dynamicZoneId then
        local zoneName = GetZoneNameById and zo_strformat("<<1>>", GetZoneNameById(tonumber(dynamicZoneId)) or "") or ""
        return zoneName ~= "" and zoneName or ("Zone " .. dynamicZoneId)
    end
    local entry = raidMarkerDirectoryByKey[tostring(zoneKey or "")]
    local fallback = entry and entry.name or "Zone inconnue"
    return PBT.GetLocalizedZoneName and PBT.GetLocalizedZoneName(zoneKey, fallback) or fallback
end

function PBT.SelectMarkerDirectoryForCurrentZone()
    if not PBT.savedVars then return nil, false end
    RefreshPlayerZone()
    local targetKey = GetCurrentMarkerDirectoryKey()
    local currentKey = GetSelectedMarkerDirectoryKey()
    if currentKey == targetKey then return targetKey, false end

    if PBT.SyncActiveMarkerSet then PBT.SyncActiveMarkerSet() end
    if targetKey:match("^zone_%d+$") and PBT.savedVars.groupBeaconMarkerSets[targetKey] == nil then
        local legacyStorage = PBT.savedVars.groupBeaconMarkerSets.free
        local currentZoneId = tonumber(targetKey:match("^zone_(%d+)$"))
        local legacyMatches = false
        if legacyStorage and legacyStorage.markers then
            for _, set in pairs(legacyStorage.markers) do
                if set.markers and set.markers[1] and tonumber(set.markers[1].zone) == currentZoneId then
                    legacyMatches = true
                    break
                end
            end
        end
        if legacyMatches then PBT.savedVars.groupBeaconMarkerSets[targetKey] = CopyTable(legacyStorage) end
    end
    PBT.savedVars.groupBeaconDirectoryKey = targetKey
    if PBT.ActivateCurrentMarkerSet then
        PBT.ActivateCurrentMarkerSet(PBT.savedVars.groupBeaconMarkerSetSlot)
    end
    return targetKey, true
end

local function GetElmsMarkerStyle(iconKey)
    iconKey = tonumber(iconKey) or 1

    local labelId = 1
    local customLabel = nil
    local textureId = 1
    local color = nil

    if iconKey >= 1 and iconKey <= 10 then
        labelId = iconKey
    elseif iconKey == 18 then
        labelId = PBT.beaconLabelIds.OT or 10
        textureId = 9
    elseif iconKey == 21 then
        labelId = PBT.beaconLabelIds.MT or 9
        textureId = 8
    elseif iconKey >= 24 and iconKey <= 27 then
        labelId = iconKey - 23
        textureId = 2
    elseif iconKey >= 29 and iconKey <= 32 then
        labelId = iconKey - 28
        textureId = 4
    elseif iconKey >= 34 and iconKey <= 37 then
        labelId = iconKey - 33
        textureId = 5
    elseif iconKey >= 40 and iconKey <= 43 then
        labelId = iconKey - 39
        textureId = 1
    elseif iconKey >= 45 and iconKey <= 70 then
        labelId = 1
        customLabel = string.char(64 + (iconKey - 44))
    elseif iconKey == 14 or iconKey == 15 or iconKey == 23 then
        textureId = 2
    elseif iconKey == 16 or iconKey == 28 then
        textureId = 4
    elseif iconKey == 17 or iconKey == 33 then
        textureId = 5
    elseif iconKey == 19 or iconKey == 38 then
        textureId = 6
    elseif iconKey == 20 or iconKey == 39 then
        textureId = 1
    elseif iconKey == 22 or iconKey == 44 then
        textureId = 3
    end

    return textureId, zo_clamp(labelId or 1, 1, 14), customLabel, color
end

local function ImportElmsMarkers(text)
    local imported = {}

    for zone, x, y, z, iconKey in text:gmatch("/(%d+)//(%d+),(%d+),(%d+),(%d+)/") do
        local textureId, labelId, customLabel, color = GetElmsMarkerStyle(iconKey)
        imported[#imported + 1] = {
            zone = tonumber(zone),
            x = tonumber(x),
            y = tonumber(y),
            z = tonumber(z),
            textureId = textureId,
            labelId = labelId,
            customLabel = customLabel,
            color = color,
            size = 112,
            heightOffset = PBT.savedVars and PBT.savedVars.groupBeaconHeight or PBT.defaults.groupBeaconHeight,
            durationMs = (PBT.savedVars and PBT.savedVars.groupBeaconDuration or PBT.defaults.groupBeaconDuration) * 1000,
        }
    end

    return imported
end

local function ParseTSMMarkerCode(text, strict)
    local imported = {}
    if type(text) ~= "string" or text == "" then return nil, "texte vide" end
    if strict and (#text > 6000 or not text:find("^TSM1[;]")) then return nil, "code TSM1 invalide" end

    if text:find("^TSM1") then
        local first = true

        for chunk in text:gmatch("[^;]+") do
            if first then
                first = false
            else
                local fields = {}
                for field in (chunk .. ","):gmatch("([^,]*),") do
                    fields[#fields + 1] = field
                    if #fields >= 13 then break end
                end

                local separatorCount = select(2, chunk:gsub(",", ""))
                if strict and (#fields ~= 13 or separatorCount ~= 12) then return nil, "marker incomplet" end

                local marker = {
                    zone = tonumber(fields[1]),
                    x = tonumber(fields[2]),
                    y = tonumber(fields[3]),
                    z = tonumber(fields[4]),
                    textureId = zo_clamp(tonumber(fields[5]) or 1, 1, 23),
                    labelId = tonumber(fields[6]) or 1,
                    size = zo_clamp(tonumber(fields[7]) or PBT.defaults.groupBeaconSize, 24, 160),
                    heightOffset = zo_clamp(tonumber(fields[8]) or PBT.defaults.groupBeaconHeight, -40, 80),
                    durationMs = zo_clamp(tonumber(fields[9]) or (PBT.defaults.groupBeaconDuration * 1000), 1000, 60000),
                    customLabel = fields[10] ~= "" and fields[10] or nil,
                }

                local cr, cg, cb = tonumber(fields[11]), tonumber(fields[12]), tonumber(fields[13])
                if cr and cg and cb then
                    marker.color = {
                        r = zo_clamp(cr, 0, 1),
                        g = zo_clamp(cg, 0, 1),
                        b = zo_clamp(cb, 0, 1),
                    }
                end

                if marker.zone and marker.x and marker.y and marker.z then
                    if strict then
                        local numbers = { marker.zone, marker.x, marker.y, marker.z, marker.textureId, marker.labelId, marker.size, marker.heightOffset, marker.durationMs }
                        for _, value in ipairs(numbers) do
                            if value ~= value or value == math.huge or value == -math.huge then return nil, "valeur numerique invalide" end
                        end
                        if marker.zone < 1 or marker.zone > 100000 or math.abs(marker.x) > 10000000 or math.abs(marker.y) > 10000000 or math.abs(marker.z) > 10000000 then
                            return nil, "position invalide"
                        end
                        if tonumber(fields[5]) ~= marker.textureId or marker.textureId % 1 ~= 0 or marker.labelId < 1 or marker.labelId > 14 or marker.labelId % 1 ~= 0 then
                            return nil, "style de marker invalide"
                        end
                        local rawSize, rawHeight, rawDuration = tonumber(fields[7]), tonumber(fields[8]), tonumber(fields[9])
                        if not rawSize or rawSize < 24 or rawSize > 160 or not rawHeight or rawHeight < -40 or rawHeight > 80 or
                            not rawDuration or rawDuration < 1000 or rawDuration > 60000 then
                            return nil, "reglage de marker invalide"
                        end
                        if marker.customLabel and (#marker.customLabel > 24 or marker.customLabel:find("[,;\r\n]")) then
                            return nil, "nom personnalise invalide"
                        end
                        if (fields[11] == "") ~= (fields[12] == "") or (fields[12] == "") ~= (fields[13] == "") then
                            return nil, "couleur incomplete"
                        end
                        if fields[11] ~= "" and (not cr or not cg or not cb) then return nil, "couleur invalide" end
                        if cr and (cr < 0 or cr > 1 or cg < 0 or cg > 1 or cb < 0 or cb > 1) then
                            return nil, "couleur invalide"
                        end
                    end
                    imported[#imported + 1] = marker
                    if strict and #imported > 100 then return nil, "trop de markers" end
                elseif strict then
                    return nil, "position manquante"
                end
            end
        end
    end

    if #imported == 0 then return nil, "aucun marker trouve" end
    return imported
end

function PBT.ValidateMarkerShareCode(text)
    local markers, message = ParseTSMMarkerCode(text, true)
    if not markers then return false, message end
    return true, markers
end

function PBT.ImportSavedMarkers(text)
    if not PBT.savedVars then return false, "variables non pretes" end
    if type(text) ~= "string" or text == "" then return false, "texte vide" end

    local imported, message
    if text:find("^TSM1") then
        imported, message = ParseTSMMarkerCode(text, false)
    else
        imported = ImportElmsMarkers(text)
    end

    if not imported or #imported == 0 then return false, message or "aucun marker trouve" end

    PBT.savedVars.groupBeaconSavedMarkers = imported
    PBT.savedVars.groupBeaconNextNumber = (#imported % 10) + 1
    PBT.savedVars.groupBeaconImportedName = PBT.GetSavedMarkerSetName()
    PBT.RefreshSavedMarkers()
    return true, tostring(#imported) .. " markers importes"
end

function PBT.GetCurrentMarkerShareData()
    if not PBT.savedVars then return nil, "variables non pretes" end
    local slot = GetMarkerSetSlot()
    local code = PBT.ExportCurrentMarkerSet(slot)
    local valid = PBT.ValidateMarkerShareCode(code)
    if not valid then return nil, "le pack selectionne est vide ou invalide" end
    return {
        directoryKey = GetSelectedMarkerDirectoryKey(),
        packName = GetMarkerPackName(slot),
        code = code,
    }
end

local function FindMatchingMarkerSet(directoryKey, code)
    if type(code) ~= "string" then return nil end
    for slot = 1, 3 do
        local set = GetMarkerSetForRead(directoryKey, slot)
        if set and set.markers and SerializeMarkers(set.markers) == code then return slot, set end
    end
    return nil
end

function PBT.GetGroupMarkerShareDestination(directoryKey, code)
    if not IsValidMarkerDirectoryKey(directoryKey) then return nil, false end
    local matchingSlot = FindMatchingMarkerSet(directoryKey, code)
    if matchingSlot then return matchingSlot, false, true end
    for slot = 1, 3 do
        if not GetMarkerSetForRead(directoryKey, slot) then return slot, false, false end
    end
    return 1, true, false
end

local function CleanReceivedPackName(name, slot)
    name = tostring(name or ""):gsub("[%c]", " "):sub(1, 40)
    name = name:gsub("^%s+", ""):gsub("%s+$", "")
    return CleanMarkerSetName(slot, name)
end

function PBT.AcceptGroupMarkerShare(share, persist, replacementConfirmed)
    if not PBT.savedVars or type(share) ~= "table" then return false, "partage invalide" end
    local directoryKey = tostring(share.directoryKey or "")
    if not IsValidMarkerDirectoryKey(directoryKey) then return false, "destination incompatible" end
    local valid, markers = PBT.ValidateMarkerShareCode(share.code)
    if not valid then return false, markers end

    if persist then
        local slot, replaces, alreadyStored = PBT.GetGroupMarkerShareDestination(directoryKey, share.code)
        if not slot then return false, "destination incompatible" end
        if replaces and not replacementConfirmed then return false, "confirmation de remplacement requise" end

        if alreadyStored then
            local set = GetMarkerSetForRead(directoryKey, slot)
            PBT.savedVars.groupBeaconDirectoryKey = directoryKey
            PBT.savedVars.groupBeaconMarkerSetSlot = slot
            PBT.savedVars.groupBeaconSavedMarkers = CopyTable(set.markers)
            PBT.savedVars.groupBeaconImportedName = set.name
            PBT.savedVars.groupBeaconMarkerSetName = CleanMarkerSetName(slot, set.name)
            PBT.savedVars.groupBeaconNextNumber = (#set.markers % 10) + 1
            PBT.temporaryGroupMarkerShare = nil
            PBT.savedVars.groupShareTemporaryBackup = nil
            PBT.RefreshSavedMarkers()
            return true, "pack deja enregistre dans l'emplacement " .. tostring(slot)
        end

        local storage = GetMarkerSetZoneStorage(directoryKey)
        local oldKey = storage.slots[slot]
        if oldKey and storage.markers then storage.markers[oldKey] = nil end
        local name = CleanReceivedPackName(share.packName, slot)
        if storage.markers[name] and storage.slots[slot] ~= name then
            name = CleanReceivedPackName(name .. " (" .. tostring(slot) .. ")", slot)
        end
        storage.markers[name] = { name = name, slot = slot, zone = markers[1].zone, markers = CopyTable(markers) }
        storage.slots[slot] = name
        storage[slot] = nil
        PBT.savedVars.groupBeaconDirectoryKey = directoryKey
        PBT.savedVars.groupBeaconMarkerSetSlot = slot
        PBT.savedVars.groupBeaconSavedMarkers = CopyTable(markers)
        PBT.savedVars.groupBeaconImportedName = name
        PBT.savedVars.groupBeaconMarkerSetName = name
        PBT.savedVars.groupBeaconNextNumber = (#markers % 10) + 1
        PBT.temporaryGroupMarkerShare = nil
        PBT.savedVars.groupShareTemporaryBackup = nil
        PBT.RefreshSavedMarkers()
        return true, "pack accepte et enregistre dans l'emplacement " .. tostring(slot)
    end

    if not PBT.temporaryGroupMarkerShare then
        PBT.temporaryGroupMarkerShare = {
            directoryKey = PBT.savedVars.groupBeaconDirectoryKey,
            slot = PBT.savedVars.groupBeaconMarkerSetSlot,
            markers = CopyTable(PBT.savedVars.groupBeaconSavedMarkers or {}),
            importedName = PBT.savedVars.groupBeaconImportedName,
            markerSetName = PBT.savedVars.groupBeaconMarkerSetName,
            nextNumber = PBT.savedVars.groupBeaconNextNumber,
        }
        PBT.savedVars.groupShareTemporaryBackup = CopyTable(PBT.temporaryGroupMarkerShare)
    end
    PBT.savedVars.groupBeaconDirectoryKey = directoryKey
    PBT.savedVars.groupBeaconSavedMarkers = CopyTable(markers)
    PBT.savedVars.groupBeaconImportedName = CleanReceivedPackName(share.packName, 1)
    PBT.savedVars.groupBeaconMarkerSetName = PBT.savedVars.groupBeaconImportedName
    PBT.savedVars.groupBeaconNextNumber = (#markers % 10) + 1
    PBT.RefreshSavedMarkers()
    return true, "pack accepte jusqu'a la deconnexion"
end

function PBT.RestoreTemporaryGroupMarkerShare()
    local backup = PBT.temporaryGroupMarkerShare or (PBT.savedVars and PBT.savedVars.groupShareTemporaryBackup)
    if not backup or not PBT.savedVars then return end
    PBT.savedVars.groupBeaconDirectoryKey = backup.directoryKey
    PBT.savedVars.groupBeaconMarkerSetSlot = backup.slot
    PBT.savedVars.groupBeaconSavedMarkers = CopyTable(backup.markers or {})
    PBT.savedVars.groupBeaconImportedName = backup.importedName
    PBT.savedVars.groupBeaconMarkerSetName = backup.markerSetName
    PBT.savedVars.groupBeaconNextNumber = backup.nextNumber
    PBT.savedVars.groupShareTemporaryBackup = nil
    PBT.temporaryGroupMarkerShare = nil
end

function PBT.ShareSavedMarker(index)
    if not PBT.savedVars then return false end
    RefreshLibTeamShadowsOptions()

    local markers = PBT.savedVars.groupBeaconSavedMarkers or {}
    local marker = markers[tonumber(index or 0)]
    if not marker then
        Chat("marker introuvable.")
        return false
    end

    if LibTeamShadows.PlaceWorldMarker then
        PBT.RefreshSavedMarkers()
        Chat("partage direct des markers desactive: utilise Exporter / Importer.")
        return true
    end

    Chat("marker non affiche: LibTeamShadows doit etre actif.")
    return false
end

function PBT.ShareAllSavedMarkers()
    if not PBT.savedVars then return end

    local markers = PBT.savedVars.groupBeaconSavedMarkers or {}
    if #markers == 0 then
        Chat("aucun marker enregistre.")
        return
    end

    if PBT.UI and PBT.UI.markerImportBox and PBT.ExportSavedMarkers then
        PBT.UI.markerImportBox:SetText(PBT.ExportSavedMarkers() or "")
        PBT.UI:SelectManagerTab("import")
        Chat("code export prepare: copie/colle le code chez les autres joueurs.")
    else
        Chat("ouvre l'onglet Import puis clique Exporter pour partager la liste.")
    end
end

function PBT.ClearSavedMarkers()
    if not PBT.savedVars then return end
    PBT.savedVars.groupBeaconSavedMarkers = {}
    PBT.savedVars.groupBeaconNextNumber = 1
    PBT.savedVars.groupBeaconImportedName = nil
    if PBT.SyncActiveMarkerSet then PBT.SyncActiveMarkerSet() end
    PBT.ClearDisplayedSavedMarkers()
    Chat("markers enregistres effaces.")
end

function PBT.UpdateSavedMarker(index, changes)
    if not PBT.savedVars or type(changes) ~= "table" then return false end

    local marker = (PBT.savedVars.groupBeaconSavedMarkers or {})[tonumber(index or 0)]
    if not marker then return false end

    if changes.textureId then
        marker.textureId = zo_clamp(tonumber(changes.textureId) or marker.textureId or 1, 1, 23)
        marker.color = nil
    end
    if changes.labelId then
        marker.labelId = zo_clamp(tonumber(changes.labelId) or marker.labelId or 1, 1, 14)
        marker.customLabel = nil
    end
    if changes.customLabel ~= nil then
        local text = tostring(changes.customLabel or ""):gsub("^%s+", ""):gsub("%s+$", "")
        marker.customLabel = text ~= "" and text or nil
    end
    if changes.heightOffset then
        marker.heightOffset = zo_clamp(tonumber(changes.heightOffset) or marker.heightOffset or 0, -40, 80)
    end
    if changes.size then
        marker.size = zo_clamp(tonumber(changes.size) or marker.size or PBT.defaults.groupBeaconSize, 24, 160)
    end
    if changes.durationMs then
        marker.durationMs = zo_clamp(tonumber(changes.durationMs) or marker.durationMs or 8000, 1000, 60000)
    end
    if changes.color then
        marker.color = {
            r = zo_clamp(tonumber(changes.color.r) or 1, 0, 1),
            g = zo_clamp(tonumber(changes.color.g) or 1, 0, 1),
            b = zo_clamp(tonumber(changes.color.b) or 1, 0, 1),
        }
    end

    if PBT.SyncActiveMarkerSet then PBT.SyncActiveMarkerSet() end
    PBT.RefreshSavedMarkers()
    return true
end

function PBT.DeleteSavedMarker(index)
    if not PBT.savedVars then return false end

    local markers = PBT.savedVars.groupBeaconSavedMarkers or {}
    index = tonumber(index or 0)
    if not index or not markers[index] then return false end

    table.remove(markers, index)
    PBT.savedVars.groupBeaconSavedMarkers = markers
    PBT.savedVars.groupBeaconNextNumber = (#markers % 10) + 1
    if PBT.SyncActiveMarkerSet then PBT.SyncActiveMarkerSet() end
    PBT.RefreshSavedMarkers()
    return true
end

function PBT.StartPracticeTimer()
    local seconds = PBT.savedVars and tonumber(PBT.savedVars.practiceSeconds) or 6
    PBT.triggerLockouts.practiceDummy = nil
    PBT.StartNamedCountdown("Training Dummy", seconds, "practiceDummy")
end

local function FindBossTrigger(name)
    local normalized = NormalizeName(name)
    if not normalized then return nil end

    local customAliases = PBT.savedVars and PBT.savedVars.customAliases
    if customAliases and customAliases[normalized] and PBT.bossLookup[customAliases[normalized]] then
        return PBT.bossLookup[customAliases[normalized]]
    end

    if PBT.bossLookup[normalized] then
        return PBT.bossLookup[normalized]
    end

    for bossName, trigger in pairs(PBT.bossLookup) do
        if normalized:find(bossName, 1, true) or bossName:find(normalized, 1, true) then
            return trigger
        end
    end

    return nil
end

local function ApplyTimerOverride(trigger)
    local overrides = PBT.savedVars and PBT.savedVars.timerOverrides
    if not overrides or not trigger or not trigger.key or not tonumber(overrides[trigger.key]) then
        return trigger
    end

    return {
        key = trigger.key,
        trialName = trigger.trialName,
        bossName = trigger.bossName,
        seconds = tonumber(overrides[trigger.key]),
        lockoutSeconds = trigger.lockoutSeconds,
        bossUnitTrigger = trigger.bossUnitTrigger,
        zoneKey = trigger.zoneKey,
        manualOnly = trigger.manualOnly,
    }
end

function PBT.TryStartForName(name)
    if not PBT.savedVars or PBT.savedVars.bossNameTimers ~= true then
        return false
    end

    local trigger = FindBossTrigger(name)
    if trigger then
        if trigger.manualOnly == true then
            return false
        end
        -- A name alone is never sufficient: it must belong to the current
        -- instance. This prevents common names such as Frost Atronach from
        -- starting an Infinite Archive timer elsewhere.
        if trigger.zoneKey and not IsInZoneKey(trigger.zoneKey) then
            return false
        end
        if not AutomaticTimerSelectionEnabled(trigger.zoneKey, trigger.key or trigger.bossName) then
            return false
        end
        if PBT.savedVars and PBT.savedVars.useSamuraiTimers and trigger.key == "z'maja" then
            return false
        end
        if trigger.key == "saint olms the just" then
            return false
        end

        PBT.StartCountdown(ApplyTimerOverride(trigger))
        return true
    end

    return false
end

local function TrySpecificBossUnitTimer(name)
    local trigger = FindBossTrigger(name)
    if not trigger or trigger.bossUnitTrigger ~= true then return false end
    if trigger.zoneKey and not IsInZoneKey(trigger.zoneKey) then return false end
    if not AutomaticTimerSelectionEnabled(trigger.zoneKey, trigger.key or trigger.bossName) then return false end

    PBT.StartCountdown(ApplyTimerOverride(trigger))
    return true
end

function PBT.ScanBossUnits()
    if not IsEnabled() or PBT.isRunning then return end
    if not PBT.savedVars then return end

    for i = 1, 6 do
        local unitTag = "boss" .. tostring(i)
        if DoesUnitExist(unitTag) then
            local name = GetUnitName(unitTag)
            if TrySpecificBossUnitTimer(name) then
                return
            end

            if PBT.savedVars.bossUnitDetection then
                if PBT.TryStartForName(name) then
                    return
                end

                if PBT.TryGenericCinematicTimer(unitTag, name) then
                    return
                end
            end
        end
    end
end

local monsterChannels = {
    [CHAT_CHANNEL_MONSTER_EMOTE] = true,
    [CHAT_CHANNEL_MONSTER_SAY] = true,
    [CHAT_CHANNEL_MONSTER_WHISPER] = true,
    [CHAT_CHANNEL_MONSTER_YELL] = true,
}


local function DialogueMatches(text, data)
    if not data or type(text) ~= "string" then return false end

    local patterns = data.patterns or { data.pattern }
    local normalizedText = NormalizeName(text) or text

    for _, pattern in ipairs(patterns) do
        if type(pattern) == "string" and pattern ~= "" then
            if data.plain then
                local normalizedPattern = NormalizeName(pattern) or pattern
                if normalizedText:find(normalizedPattern, 1, true) then
                    return true
                end
            elseif text:find(pattern) then
                return true
            end
        end
    end

    return false
end

local function CaptureNarrationLine(text)
    if not PBT.savedVars or not PBT.savedVars.narrationDebug or type(text) ~= "string" or text == "" then return end

    local line = string.format("%s | %s", GetPlayerZoneName() or "zone ?", text)
    table.insert(PBT.narrationLog, 1, line)
    while #PBT.narrationLog > 20 do
        table.remove(PBT.narrationLog)
    end
    Chat("narration: " .. text)
end

local function OnMonsterChat(_, channelType, _, text)
    if not PBT.savedVars then return end
    if type(text) ~= "string" then return end

    local seconds = text:match(GROUP_PULL_PREFIX .. ":(%d+)")
    if seconds then
        if GroupCountdownEnabled() then
            ReceiveGroupCountdown(seconds)
        end
        return
    end

    if not monsterChannels[channelType] then return end

    CaptureNarrationLine(text)

    if not BossSpawnTimersEnabled() or not PBT.savedVars.useSamuraiTimers then return end

    for index, data in ipairs(PBT.samuraiNarrationTimers or {}) do
        if (not data.zoneKey or IsInZoneKey(data.zoneKey))
            and AutomaticTimerSelectionEnabled(data.zoneKey, data.displayName)
            and DialogueMatches(text, data)
        then
            PBT.StartCountdown({
                bossName = data.displayName,
                seconds = data.seconds,
                lockoutKey = data.lockoutKey or ("samuraiLine" .. tostring(index)),
                lockoutSeconds = data.lockoutSeconds,
            })
            return
        end
    end
end


local function TrySamuraiAbilityTimer(result, abilityId, hitValue)
    local data = PBT.samuraiAbilityTimers and PBT.samuraiAbilityTimers[abilityId]
    if not data or not PBT.savedVars then return false end
    if not BossSpawnTimersEnabled() then return false end
    if data.setting and not PBT.savedVars[data.setting] then return false end
    if data.zoneKey and not IsInZoneKey(data.zoneKey) then return false end
    if not AutomaticTimerSelectionEnabled(data.zoneKey, data.displayName) then return false end
    if data.results and not data.results[result] then return false end
    if data.maxHitValue and tonumber(hitValue or 0) > data.maxHitValue then return false end
    if data.minHitValue and tonumber(hitValue or 0) < data.minHitValue then return false end

    if data.markState == "falgravnAirborne" then
        if result == ACTION_RESULT_BEGIN or result == ACTION_RESULT_EFFECT_GAINED then
            PBT.falgravnAirborne = true
            PBT.falgravnBasementAddsKilled = 0
            PBT.falgravnGroundToken = (PBT.falgravnGroundToken or 0) + 1
        end
        return true
    end

    if not data.seconds then return true end

    PBT.StartCountdown({
        bossName = data.displayName,
        seconds = data.seconds,
        lockoutKey = data.lockoutKey or ("ability" .. tostring(abilityId)),
        lockoutSeconds = data.lockoutSeconds,
        restart = data.restart,
    })
    return true
end

local CLOUDREST_ZMAJA_INIT_ID = 105890
local CLOUDREST_ZMAJA_PLUS_ID = 105541
local CLOUDREST_ZMAJA_PORTAL_CAST_ID = 103946
local CLOUDREST_ZMAJA_SHADOW_REALM_ID = 108045
local CLOUDREST_ZMAJA_DIALOGUE_ID = 109077
local CLOUDREST_ZMAJA_PORTAL_DONE_IDS = {
    [104057] = true, -- Remove Shadow Realm
    [104792] = true, -- PC Win Shadow Realm
}

local function TryCloudrestZmajaPortalTimer(result, abilityId)
    if not abilityId or not PBT.savedVars then return false end
    if not IsInZoneKey("cloudrest") or not AutomaticTimerSelectionEnabled("cloudrest", "zmaja") then return false end

    local nowMs = NowMs()

    if abilityId == CLOUDREST_ZMAJA_DIALOGUE_ID and result == ACTION_RESULT_EFFECT_GAINED and not IsUnitInCombat("player") then
        PBT.StartNamedCountdown("Z'Maja", 7.840, "zmajaInitialDialogue")
        return true
    end

    if abilityId == CLOUDREST_ZMAJA_INIT_ID then
        PBT.cloudrestInitMs = nowMs
        PBT.cloudrestPlus = 0
        PBT.cloudrestPortalGroup = 0
        PBT.cloudrestPortalActive = false
        PBT.cloudrestLastPortalTimerMs = 0
        PBT.cloudrestPullToken = (PBT.cloudrestPullToken or 0) + 1
        return true
    end

    if abilityId == CLOUDREST_ZMAJA_PLUS_ID and result == ACTION_RESULT_EFFECT_GAINED then
        if (PBT.cloudrestInitMs or 0) + 10000 > nowMs then
            PBT.cloudrestPlus = (PBT.cloudrestPlus or 0) + 1
        end
        return true
    end

    if abilityId == CLOUDREST_ZMAJA_PORTAL_CAST_ID then
        PBT.cloudrestPortalActive = true
        PBT.cloudrestPortalGroup = (PBT.cloudrestPortalGroup or 0) + 1
        if PBT.cloudrestPortalGroup > 2 then
            PBT.cloudrestPortalGroup = 1
        end
        PBT.cloudrestLastPortalTimerMs = 0
        return true
    end

    if CLOUDREST_ZMAJA_PORTAL_DONE_IDS[abilityId] and result == ACTION_RESULT_EFFECT_FADED and PBT.cloudrestPortalActive then
        PBT.cloudrestPortalActive = false
        return false
    end

    return false
end

local function TrySamuraiDeathNameTimer(targetName)
    local normalized = NormalizeName(targetName)
    if not normalized or not PBT.savedVars then return false end
    if not BossSpawnTimersEnabled() then return false end

    for index, data in ipairs(PBT.samuraiDeathNameTimers or {}) do
        if (not data.setting or PBT.savedVars[data.setting])
            and (not data.zoneKey or IsInZoneKey(data.zoneKey))
            and AutomaticTimerSelectionEnabled(data.zoneKey, data.displayName)
            and (not data.requireState or PBT[data.requireState] == true)
        then
            for _, name in ipairs(data.names or {}) do
                if normalized == name or normalized:find(name, 1, true) then
                    if data.markState then
                        PBT[data.markState] = true
                        if data.stateToken then
                            PBT[data.stateToken] = (PBT[data.stateToken] or 0) + 1
                        end
                    end

                    if data.countRequired then
                        local counterKey = data.counterKey or ("deathCount" .. tostring(index))
                        PBT[counterKey] = (PBT[counterKey] or 0) + 1
                        if PBT[counterKey] < data.countRequired then
                            return true
                        end
                    end

                    if data.seconds then
                        PBT.StartCountdown({
                            bossName = data.displayName,
                            seconds = data.seconds,
                            lockoutKey = data.lockoutKey or ("deathName" .. tostring(index)),
                            lockoutSeconds = data.lockoutSeconds,
                            restart = data.restart,
                        })
                    end

                    if data.clearStateAfterMs and data.requireState then
                        local tokenKey = data.stateToken or "falgravnGroundToken"
                        PBT[tokenKey] = (PBT[tokenKey] or 0) + 1
                        local token = PBT[tokenKey]
                        zo_callLater(function()
                            if PBT[tokenKey] == token then
                                PBT[data.requireState] = false
                                if data.counterKey then
                                    PBT[data.counterKey] = 0
                                end
                            end
                        end, data.clearStateAfterMs)
                    end

                    return true
                end
            end
        end
    end

    return false
end

local AS_OLMS_JUMP_START = 98535
local AS_OLMS_PHASES = {
    [98615] = 2,
    [98677] = 3,
    [98678] = 4,
    [98679] = 5,
}

local function ResetAsOlms()
    PBT.asOlmsJumpCount = 0
    PBT.asOlmsPhase = 1
    PBT.asOlmsLastJumpMs = 0
    PBT.falgravnAirborne = false
    PBT.falgravnGroundToken = 0
    PBT.falgravnBasementAddsKilled = 0
    PBT.hofAfterTriplets = false
    PBT.hofTripletsToken = 0
end

local function TryAsOlmsFourthLanding(result, abilityId)
    if not PBT.savedVars or not PBT.savedVars.asOlmsFourthLanding then return false end
    if not IsInZoneKey("asylumSanctorium") then return false end
    if not AutomaticTimerSelectionEnabled("asylumSanctorium", "olms") then return false end
    if result ~= ACTION_RESULT_BEGIN and result ~= ACTION_RESULT_EFFECT_GAINED then return false end

    local phase = AS_OLMS_PHASES[abilityId]
    if phase then
        PBT.asOlmsPhase = phase
        PBT.asOlmsJumpCount = 0
        PBT.asOlmsLastJumpMs = 0
        return false
    end

    if abilityId ~= AS_OLMS_JUMP_START then
        return false
    end

    local nowMs = NowMs()
    if nowMs - (PBT.asOlmsLastJumpMs or 0) < 2500 then
        return false
    end

    PBT.asOlmsLastJumpMs = nowMs
    PBT.asOlmsJumpCount = PBT.asOlmsJumpCount + 1

    if PBT.asOlmsJumpCount == 1 then
        local seconds = tonumber(PBT.savedVars.asOlmsLandingSeconds) or PBT.defaults.asOlmsLandingSeconds
        PBT.StartNamedCountdown("Olms 4th Landing", seconds, "asOlmsPhase" .. tostring(PBT.asOlmsPhase))
        return true
    end

    return false
end

local function IsInsidePlayerHouse()
    if not GetCurrentZoneHouseId then return false end
    return (tonumber(GetCurrentZoneHouseId()) or 0) > 0
end

local trainingDummyNameFragments = {
    -- Generic English and French names.
    "target dummy",
    "training dummy",
    "trial dummy",
    "entrainement",
    "mannequin",
    "cible d'entrainement",

    -- All target families observed in Encounter.log.
    "target skeleton",
    "target iron atronach",
    "target bone goliath",
    "target centurion",
    "target ogrim",
    "target tho'at replicanum",
    "the precursor",

    -- Localized equivalents and legacy names.
    "atronach de fer",
    "squelette cible",
    "goliath d'os cible",
    "centurion cible",
    "ogrim cible",
    "tho'at cible",
    "replique de tho'at",
    "réplique de tho'at",
    "le precurseur",
    "le précurseur",
}

local function IsTrainingDummyName(name)
    local normalized = NormalizeName(name)
    if not normalized then return false end

    for _, fragment in ipairs(trainingDummyNameFragments) do
        if normalized:find(fragment, 1, true) then return true end
    end
    return false
end

local function MarkDummyCombatFromName(name)
    if not IsInsidePlayerHouse() then return end
    if not IsTrainingDummyName(name) then return end

    PBT.lastDummySeenMs = NowMs()
    PBT.dummyWasInCombat = true
end

local trashNameFragments = {
    "add",
    "archer",
    "assassin",
    "atronach",
    "behemoth",
    "colossus",
    "creeper",
    "fabricant",
    "factotum",
    "gargoyle",
    "guardian",
    "harpy",
    "knight",
    "mage",
    "protector",
    "sentinel",
    "shaman",
    "soldier",
    "spider",
    "totem",
    "warrior",
    "watcher",
    "araignee",
    "gardien",
    "protecteur",
    "sentinelle",
    "soldat",
    "guerrier",
}

local function IsBossUnitTag(unitTag)
    return type(unitTag) == "string" and unitTag:find("^boss%d+$") ~= nil
end

local function IsHardOrBossDifficulty(unitTag)
    if not GetUnitDifficulty or not unitTag or not DoesUnitExist(unitTag) then
        return false
    end

    local difficulty = GetUnitDifficulty(unitTag)
    return difficulty == MONSTER_DIFFICULTY_HARD
        or difficulty == MONSTER_DIFFICULTY_DEADLY
end

local function LooksLikeTrash(name)
    local normalized = NormalizeName(name)
    if not normalized then return true end

    for _, fragment in ipairs(trashNameFragments) do
        if normalized:find(fragment, 1, true) then
            return true
        end
    end

    return false
end

local function HasBossHealth(unitTag)
    local current, max = GetUnitPower(unitTag, POWERTYPE_HEALTH)
    return max and max > 0 and current and current > 0
end

local function IsEligibleGenericBoss(unitTag, name)
    if not name or name == "" or not HasBossHealth(unitTag) then
        return false
    end

    if IsBossUnitTag(unitTag) then
        if GetUnitDifficulty and IsHardOrBossDifficulty(unitTag) then
            return IsHardOrBossDifficulty(unitTag)
        end
        return not LooksLikeTrash(name)
    end

    if unitTag == "reticleover" and PBT.savedVars and PBT.savedVars.worldBossTimers then
        return IsHardOrBossDifficulty(unitTag) and not LooksLikeTrash(name)
    end

    return false
end

function PBT.TryGenericCinematicTimer(unitTag, name)
    if not PBT.savedVars
        or not PBT.savedVars.genericCinematicTimers
        or IsUnitInCombat("player")
        or not IsEligibleGenericBoss(unitTag, name)
    then
        return false
    end

    local currentTrialKey = GetCurrentTrialKey()
    if currentTrialKey and not PBT.IsInstanceTimerEnabled(currentTrialKey) then
        return false
    end

    local key = NormalizeName(name)
    if not key then return false end

    local nowMs = NowMs()
    local candidate = PBT.genericBossCandidates[key]
    if not candidate or nowMs - candidate.firstSeen > 6000 then
        PBT.genericBossCandidates[key] = {
            firstSeen = nowMs,
            seen = 1,
        }
        zo_callLater(function()
            PBT.ScanBossUnits()
        end, 1200)
        return false
    end

    candidate.seen = candidate.seen + 1
    if candidate.seen < 2 or nowMs - candidate.firstSeen < 1000 then
        zo_callLater(function()
            PBT.ScanBossUnits()
        end, 1200)
        return false
    end

    PBT.StartNamedCountdown(
        zo_strformat("<<1>>", name),
        tonumber(PBT.savedVars.genericCinematicSeconds) or PBT.defaults.genericCinematicSeconds,
        "generic:" .. key
    )
    return true
end

local function StartPracticeFromDummyReset()
    local nowMs = NowMs()

    if not IsInsidePlayerHouse() then
        PBT.dummyWasInCombat = false
        return false
    end

    if not PBT.savedVars
        or not PBT.savedVars.autoPracticeOnDummyReset
        or PBT.isRunning
        or not PBT.dummyWasInCombat
        or nowMs - (PBT.lastDummyResetMs or 0) < 1000
    then
        return false
    end

    PBT.lastDummyResetMs = nowMs
    PBT.dummyWasInCombat = false
    PBT.StartPracticeTimer()
    return true
end

local function ScanReticleBoss()
    if not IsEnabled() or PBT.isRunning then return end
    if not PBT.savedVars or not PBT.savedVars.worldBossTimers then return end

    if DoesUnitExist("reticleover") then
        local name = GetUnitName("reticleover")
        if PBT.TryStartForName(name) then return end
        PBT.TryGenericCinematicTimer("reticleover", name)
    end
end

function PBT.QueueScan(delayMs)
    local nowMs = NowMs()
    if nowMs - (PBT.lastScanMs or 0) < 500 then return end

    PBT.lastScanMs = nowMs
    EM:UnregisterForUpdate(SCAN_UPDATE_NAME)
    EM:RegisterForUpdate(SCAN_UPDATE_NAME, delayMs or 250, function()
        EM:UnregisterForUpdate(SCAN_UPDATE_NAME)
        PBT.ScanBossUnits()
    end)
end

local function OnBossesChanged()
    RefreshPlayerZone()
    if not PBT.savedVars then return end
    PBT.QueueScan(150)
end

local function IsPlayerUnitTag(unitTag)
    if unitTag == "player" then return true end
    if unitTag and AreUnitsEqual then
        return AreUnitsEqual("player", unitTag)
    end
    return false
end

local function IsNahviintaasName(name)
    local normalized = NormalizeName(name)
    return normalized == "nahviintaas" or (normalized and normalized:find("nahviintaas", 1, true) ~= nil)
end

local function GetNahviintaasBossUnitTag()
    for i = 1, 6 do
        local unitTag = "boss" .. tostring(i)
        if DoesUnitExist(unitTag) and IsNahviintaasName(GetUnitName(unitTag)) then
            return unitTag
        end
    end

    return nil
end

local function GetNahviintaasHpPercent()
    local unitTag = GetNahviintaasBossUnitTag()
    if not unitTag then return nil end

    local current, max = GetUnitPower(unitTag, POWERTYPE_HEALTH)
    if not current or not max or max <= 0 then return nil end

    return (current / max) * 100
end

local function GetNextNahviintaasPortalThreshold(percent)
    if not percent then return nil end
    if percent > 70 then return 70 end
    if percent > 50 then return 50 end
    return nil
end

local function ShowNahvPortalResult(text, r, g, b)
    if not PBT.UI or not PBT.UI.ShowPortalStatus then return end

    PBT.UI:ShowPortalStatus(text, r, g, b)
    PBT.nahvPortalResultToken = (PBT.nahvPortalResultToken or 0) + 1
    local token = PBT.nahvPortalResultToken

    zo_callLater(function()
        if PBT.nahvPortalResultToken == token and not PBT.nahvPortalActive and PBT.UI and PBT.UI.HidePortalStatus then
            PBT.UI:HidePortalStatus()
        end
    end, 2200)
end

local function UpdateNahvPortalStatus()
    if not PBT.nahvPortalActive or not IsEnabled() or not PBT.savedVars or not PBT.savedVars.nahvPortalHpWarning then
        EM:UnregisterForUpdate(PORTAL_UPDATE_NAME)
        if PBT.UI and PBT.UI.HidePortalStatus then
            PBT.UI:HidePortalStatus()
        end
        return
    end

    local percent = GetNahviintaasHpPercent()
    if not percent then
        PBT.UI:ShowPortalStatus("PORTAIL: boss ?", 1, 0.75, 0.1)
        return
    end

    if not PBT.nahvPortalThreshold then
        PBT.nahvPortalThreshold = GetNextNahviintaasPortalThreshold(percent)
    end

    local threshold = PBT.nahvPortalThreshold
    if not threshold then
        PBT.UI:ShowPortalStatus("PORTAIL: plus de seuil", 0.8, 0.8, 0.8)
        return
    end

    local delta = percent - threshold
    if delta <= 0 then
        PBT.nahvPortalSkipOk = true
        PBT.UI:ShowPortalStatus(string.format("SKIP %d%% OK", threshold), 0.1, 1, 0.1)
        return
    end

    if delta <= 3 then
        PBT.UI:ShowPortalStatus(string.format("PORTAIL %d%%: %.1f%%", threshold, delta), 1, 0.9, 0.05)
    else
        PBT.UI:ShowPortalStatus(string.format("PORTAIL %d%%: %.1f%%", threshold, delta), 1, 1, 1)
    end
end

local function StartNahvPortalStatus()
    if not PBT.savedVars or not PBT.savedVars.nahvPortalHpWarning then return end
    if not AutomaticTimerSelectionEnabled("sunspire", "nahviintaas") then return end

    PBT.nahvPortalActive = true
    PBT.nahvPortalSkipOk = false
    PBT.nahvPortalThreshold = GetNextNahviintaasPortalThreshold(GetNahviintaasHpPercent())
    UpdateNahvPortalStatus()
    EM:UnregisterForUpdate(PORTAL_UPDATE_NAME)
    EM:RegisterForUpdate(PORTAL_UPDATE_NAME, 250, UpdateNahvPortalStatus)
end

local function StopNahvPortalStatus(showResult)
    if not PBT.nahvPortalActive then return end

    local threshold = PBT.nahvPortalThreshold
    local skipOk = PBT.nahvPortalSkipOk

    PBT.nahvPortalActive = false
    PBT.nahvPortalThreshold = nil
    PBT.nahvPortalSkipOk = false
    EM:UnregisterForUpdate(PORTAL_UPDATE_NAME)

    if showResult and threshold then
        if skipOk then
            ShowNahvPortalResult(string.format("SKIP %d%% OK", threshold), 0.1, 1, 0.1)
        else
            ShowNahvPortalResult(string.format("PAS SKIP %d%%", threshold), 1, 0.05, 0.05)
        end
    elseif PBT.UI and PBT.UI.HidePortalStatus then
        PBT.UI:HidePortalStatus()
    end
end

local function UnitNameMatchesList(unitName, names)
    local normalized = NormalizeName(unitName)
    if not normalized then return false end

    for _, name in ipairs(names or {}) do
        local candidate = NormalizeName(name)
        if candidate and (normalized == candidate or normalized:find(candidate, 1, true)) then
            return true
        end
    end

    return false
end

local function ShowShortStatus(text, color)
    if not PBT.UI or not PBT.UI.ShowPortalStatus then return end

    local r, g, b = 1, 1, 1
    if color then
        r, g, b = color[1] or r, color[2] or g, color[3] or b
    end

    PBT.UI:ShowPortalStatus(text, r, g, b)
    PBT.nahvPortalResultToken = (PBT.nahvPortalResultToken or 0) + 1
    local token = PBT.nahvPortalResultToken

    zo_callLater(function()
        if PBT.nahvPortalResultToken == token and not PBT.nahvPortalActive and PBT.UI and PBT.UI.HidePortalStatus then
            PBT.UI:HidePortalStatus()
        end
    end, 2500)
end

local function TryHpThresholdAnnouncement(unitTag, powerValue, powerMax)
    if not IsEnabled() or not PBT.savedVars or not PBT.savedVars.useSamuraiTimers then return end
    if not unitTag or not powerValue or not powerMax or powerMax <= 0 then return end
    if not DoesUnitExist(unitTag) then return end

    local unitName = GetUnitName(unitTag)
    if not unitName or unitName == "" then return end

    local percent = (powerValue / powerMax) * 100
    for _, data in ipairs(PBT.hpThresholdAnnouncements or {}) do
        if (not data.zoneKey or IsInZoneKey(data.zoneKey))
            and AutomaticTimerSelectionEnabled(data.zoneKey, unitName)
            and UnitNameMatchesList(unitName, data.bossNames)
        then
            for _, threshold in ipairs(data.thresholds or {}) do
                local key = string.format("%s:%s:%s", data.zoneKey or "zone", NormalizeName(unitName) or unitName, tostring(threshold.percent))
                if percent <= threshold.percent and not PBT.hpThresholdState[key] then
                    PBT.hpThresholdState[key] = true
                    ShowShortStatus(string.format("%s %d%%", threshold.text, threshold.percent), threshold.color)
                    return
                end
            end
        end
    end
end

local function OnPowerUpdate(_, unitTag, _, powerType, powerValue, powerMax)
    if powerType and powerType ~= POWERTYPE_HEALTH and powerType ~= COMBAT_MECHANIC_FLAGS_HEALTH then return end
    TryHpThresholdAnnouncement(unitTag, powerValue, powerMax)
end

local function OnEffectChanged(_, changeType, _, effectName, unitTag, _, endTime, stackCount, iconName, _, _, _, _, _, _, abilityId)
    if abilityId == NAHV_TIME_BREACH_ID and IsPlayerUnitTag(unitTag) then
        if changeType == EFFECT_RESULT_GAINED or changeType == EFFECT_RESULT_UPDATED then
            if PBT.nahvPortalActive then
                UpdateNahvPortalStatus()
            else
                StartNahvPortalStatus()
            end
        elseif changeType == EFFECT_RESULT_FADED then
            StopNahvPortalStatus(true)
        end
        return
    end

    if abilityId == CLOUDREST_ZMAJA_SHADOW_REALM_ID and changeType == EFFECT_RESULT_FADED then
        TryCloudrestZmajaPortalTimer(ACTION_RESULT_EFFECT_FADED, abilityId)
        return
    end

    if PBT.isRunning or not IsEnabled() then return end

    if unitTag and unitTag:find("boss", 1, true) then
        if PBT.savedVars then
            PBT.QueueScan(250)
        end
        return
    end

    if PBT.savedVars and PBT.savedVars.bossUnitDetection then
        PBT.TryStartForName(effectName)
    end
end

local function OnCombatEvent(_, result, _, abilityName, _, _, sourceName, sourceType, targetName, targetType, hitValue, _, _, _, _, _, abilityId)
    if not IsEnabled() then return end

    MarkDummyCombatFromName(sourceName)
    MarkDummyCombatFromName(targetName)

    if abilityId and TryAsOlmsFourthLanding(result, abilityId) then
        return
    end

    if abilityId and TryCloudrestZmajaPortalTimer(result, abilityId) then
        return
    end

    if abilityId and TrySamuraiAbilityTimer(result, abilityId, hitValue) then
        return
    end

    if result == ACTION_RESULT_DIED and TrySamuraiDeathNameTimer(targetName) then
        return
    end

    if PBT.isRunning then return end

    if PBT.savedVars and PBT.savedVars.bossUnitDetection then
        if PBT.TryStartForName(targetName) or PBT.TryStartForName(sourceName) then
            return
        end

        if abilityName and FindBossTrigger(abilityName) then
            PBT.QueueScan(250)
        end
    end
end



local function PrintTimerList()
    local currentTrialKey = GetCurrentTrialKey()
    if not currentTrialKey then
        Chat("timers actifs: aucune instance reconnue ici.")
        return
    end

    Chat("timers actifs pour cette instance:")

    for trialKey, trial in pairs(PBT.trials) do
        if trialKey == currentTrialKey then
            d(string.format("|cFFFFFF%s|r", trial.name))
            for normalizedName, data in pairs(trial.bosses) do
                local seconds = data.seconds
                local overrides = PBT.savedVars and PBT.savedVars.timerOverrides
                if overrides and tonumber(overrides[normalizedName]) then
                seconds = tonumber(overrides[normalizedName])
                end
                d(string.format("  %s = %ss  (%s)", data.displayName, tostring(seconds), normalizedName))
            end
        end
    end
end

local function ResolveBossKey(name)
    local trigger = FindBossTrigger(name)
    return trigger and trigger.key or nil
end

local function HandleTimer(args)
    args = args or ""

    local bossName, secondsText = args:match("^(.-)%s+(%d+)$")
    local seconds = tonumber(secondsText)

    if not bossName or not seconds then
        Chat("utilisation: /tsm timer z'maja 21")
        return
    end

    local bossKey = ResolveBossKey(bossName)
    if not bossKey then
        Chat("boss inconnu. Utilise /tsm timers pour voir les cles, ou /tsm alias pour ajouter un nom.")
        return
    end

    seconds = zo_clamp(seconds, 1, 60)
    PBT.savedVars.timerOverrides[bossKey] = seconds
    Chat(string.format("%s regle sur %ss.", PBT.bossLookup[bossKey].bossName, seconds))
end

local function StartBossKeyTimer(bossKey)
    local trigger = PBT.bossLookup and PBT.bossLookup[bossKey]
    if not trigger then return false end

    local seconds = trigger.seconds
    local overrides = PBT.savedVars and PBT.savedVars.timerOverrides
    if overrides and tonumber(overrides[bossKey]) then
        seconds = tonumber(overrides[bossKey])
    end

    PBT.StartCountdown({
        key = bossKey,
        trialName = trigger.trialName,
        bossName = trigger.bossName,
        seconds = seconds,
        lockoutSeconds = trigger.lockoutSeconds,
    })

    return true
end

local function HandleInfiniteArchive(args)
    args = args or ""
    local bossKey = ResolveBossKey(args)

    if not bossKey or not PBT.bossLookup[bossKey] or PBT.bossLookup[bossKey].trialName ~= "Infinite Archive" then
        Chat("utilisation: /tsm ia tho'at replicanum | frost atronach | mantikora | dragon | marauder bittog")
        return
    end

    StartBossKeyTimer(bossKey)
end

local function HandleAlias(args)
    args = args or ""

    local bossKeyText, alias = args:match("^(.-)%s*=%s*(.+)$")
    if not bossKeyText or bossKeyText == "" then
        bossKeyText, alias = args:match("^(%S+)%s+(.+)$")
    end

    if not bossKeyText or not alias then
        Chat("utilisation: /tsm alias z'maja = Nom exact vu en jeu")
        return
    end

    local bossKey = ResolveBossKey(bossKeyText)
    local normalizedAlias = NormalizeName(alias)

    if not bossKey or not normalizedAlias then
        Chat("boss ou alias invalide.")
        return
    end

    PBT.savedVars.customAliases[normalizedAlias] = bossKey
    Chat(string.format("alias ajoute: %s -> %s.", alias, PBT.bossLookup[bossKey].bossName))
end





local function ResetMenuButton()
    if not PBT.savedVars or not PBT.UI or not PBT.UI.ApplyMenuButtonSettings then return end

    PBT.savedVars.menuButtonEnabled = true
    PBT.savedVars.menuButtonX = 0
    PBT.savedVars.menuButtonY = 0
    PBT.savedVars.menuButtonSize = PBT.savedVars.menuButtonSize or PBT.defaults.menuButtonSize
    PBT.UI:ApplyMenuButtonSettings()
    Chat("bouton menu logo remis au centre.")
end

local function HandleGeneric(args)
    local seconds = tonumber(args)
    if not seconds then
        Chat("utilisation: /tsm generic 8")
        return
    end

    PBT.savedVars.genericCinematicSeconds = zo_clamp(seconds, 1, 60)
    Chat(string.format("timer generique boss regle sur %ss.", PBT.savedVars.genericCinematicSeconds))
end

local function HandleAsOlms(args)
    local seconds = tonumber(args)
    if not seconds then
        Chat("utilisation: /tsm olms 10")
        return
    end

    PBT.savedVars.asOlmsLandingSeconds = zo_clamp(seconds, 1, 60)
    Chat(string.format("vAS Olms 1er saut -> 4e atterrissage regle sur %ss.", PBT.savedVars.asOlmsLandingSeconds))
end

local function ToggleNarrationDebug()
    if not PBT.savedVars then return end
    PBT.savedVars.narrationDebug = not PBT.savedVars.narrationDebug
    Chat(PBT.savedVars.narrationDebug and "capture narration activee." or "capture narration desactivee.")
end

local function PrintNarrationLog()
    Chat("dernieres narrations:")
    for i, line in ipairs(PBT.narrationLog or {}) do
        d(string.format("%02d. %s", i, line))
    end
end

local function PrintBossUnits()
    Chat("boss detectes par le client:")

    for i = 1, 6 do
        local unitTag = "boss" .. tostring(i)
        if DoesUnitExist(unitTag) then
            d(string.format("%s = %s", unitTag, GetUnitName(unitTag) or ""))
        else
            d(string.format("%s = absent", unitTag))
        end
    end
end

local function PrintZoneName()
    RefreshPlayerZone()
    Chat(string.format("zone ESO: %s / id %s", GetPlayerZoneName() or "inconnue", tostring(PBT.currentZoneId or "?")))
end




local function TestVisualAnnouncement()
    if not PBT.UI then return end

    if PBT.isRunning then
        PBT.StopCountdown(false)
    end

    PBT.UI:ApplySettings()
    PBT.UI:ShowCountdown("TEST", 3)

    zo_callLater(function()
        if PBT.UI then PBT.UI:ShowCountdown("TEST", 2) end
    end, 1000)

    zo_callLater(function()
        if PBT.UI then PBT.UI:ShowCountdown("TEST", 1) end
    end, 2000)

    zo_callLater(function()
        if PBT.UI then PBT.UI:ShowGo("TEST") end
    end, 3000)

    zo_callLater(function()
        if PBT.UI and not PBT.isRunning and not PBT.portalStatusActive then
            if PBT.savedVars and PBT.savedVars.unlocked then
                PBT.UI:ShowIdle()
            else
                PBT.UI:Hide()
            end
        end
    end, 4200)
end

local nativeRaidTimers = {
    { zoneKey = "cloudrest", name = "Cloudrest", cases = "Z'Maja pull apres Shadow Realm" },
    { zoneKey = "hallsOfFabrication", name = "Halls of Fabrication", cases = "Hunter-Killer, Pinnacle, Triplets" },
    { zoneKey = "asylumSanctorium", name = "Asylum Sanctorium", cases = "Olms 4e atterrissage" },
    { zoneKey = "mawOfLorkhaj", name = "Maw of Lorkhaj", cases = "Zhaj'hassa, Rakkhat" },
    { zoneKey = "aetherianArchive", name = "Aetherian Archive", cases = "Varlariel" },
    { zoneKey = "sunspire", name = "Sunspire", cases = "Lokkestiiz, Yolnahkriin, Nahviintaas" },
    { zoneKey = "kynesAegis", name = "Kyne's Aegis", cases = "Falgravn retour sous-sol" },
    { zoneKey = "dreadsailReef", name = "Dreadsail Reef", cases = "Taleria execute" },
    { zoneKey = "sanitysEdge", name = "Sanity's Edge", cases = "Yaseyla HP" },
    { zoneKey = "rockgrove", name = "Rockgrove", cases = "Bahsei HM: /tsm bahsei" },
    { zoneKey = "infiniteArchive", name = "Infinite Archive", cases = "Timers manuels" },
}

local function GetNativeRaidTimersForCurrentInstance()
    local currentTrialKey = GetCurrentTrialKey()
    local list = {}

    if not currentTrialKey then
        return list
    end

    for _, raid in ipairs(nativeRaidTimers) do
        if raid.zoneKey == currentTrialKey then
            table.insert(list, raid)
        end
    end

    return list
end

function PBT.GetNativeRaidTimersForCurrentInstance()
    return GetNativeRaidTimersForCurrentInstance()
end


local function ResetEncounterState()
    PBT.zmajaAddKills = 0
    PBT.zmajaSpawnStarted = false
    PBT.zmajaAddWindowMs = 0
    PBT.cloudrestInitMs = 0
    PBT.cloudrestPlus = 0
    PBT.cloudrestPortalGroup = 0
    PBT.cloudrestPortalActive = false
    PBT.cloudrestLastPortalTimerMs = 0
    PBT.cloudrestPullToken = (PBT.cloudrestPullToken or 0) + 1
    PBT.genericBossCandidates = {}
    ResetAsOlms()
    PBT.falgravnAirborne = false
    PBT.falgravnGroundToken = (PBT.falgravnGroundToken or 0) + 1
    PBT.falgravnBasementAddsKilled = 0
    PBT.hofAfterTriplets = false
    PBT.hofTripletsToken = (PBT.hofTripletsToken or 0) + 1
    PBT.hpThresholdState = {}
    StopNahvPortalStatus(false)
end


local function RegisterSettingsPanel()
    local LAM = LibAddonMenu2
    if not LAM or not PBT.savedVars then return end

    local panelData = {
        type = "panel",
        name = PBT.displayName,
        displayName = PBT.displayName,
        author = "TeamFF - EyrOn",
        version = PBT.version,
        registerForRefresh = true,
        registerForDefaults = true,
    }

    local options = {
        {
            type = "header",
            name = "Team Shadows Manager",
        },
        {
            type = "description",
            text = function()
                local authorLabel = PBT.GetLanguage and PBT.GetLanguage() == "en" and "Author" or "Auteur"
                return "Version " .. tostring(PBT.version) .. "  -  " .. authorLabel .. ": TeamFF - EyrOn"
            end,
            width = "full",
        },
        {
            type = "header",
            name = "Reglages generiques",
        },
                {
                    type = "checkbox",
                    name = "Addon active",
                    getFunc = function() return PBT.savedVars.enabled end,
                    setFunc = function(value) PBT.savedVars.enabled = value end,
                    default = PBT.defaults.enabled,
                },
                {
                    type = "checkbox",
                    name = "Fenetre deverrouillee",
                    getFunc = function() return PBT.savedVars.unlocked end,
                    setFunc = function(value) PBT.UI:SetUnlocked(value) end,
                    default = PBT.defaults.unlocked,
                },
                {
                    type = "checkbox",
                    name = "Bouton menu logo",
                    tooltip = "Affiche ton logo à l'écran. Clic gauche : ouvre la fenêtre indépendante Team Shadows Manager.",
                    getFunc = function() return PBT.savedVars.menuButtonEnabled ~= false end,
                    setFunc = function(value)
                        PBT.savedVars.menuButtonEnabled = value
                        PBT.UI:ApplyMenuButtonSettings()
                    end,
                    default = PBT.defaults.menuButtonEnabled,
                },
                {
                    type = "slider",
                    name = "Taille bouton logo",
                    tooltip = "Taille du bouton logo visible à l'écran.",
                    min = 28,
                    max = 96,
                    step = 2,
                    getFunc = function() return PBT.savedVars.menuButtonSize end,
                    setFunc = function(value)
                        PBT.savedVars.menuButtonSize = value
                        PBT.UI:ApplyMenuButtonSettings()
                    end,
                    default = PBT.defaults.menuButtonSize,
                },
                {
                    type = "header",
                    name = "Sons",
                },
                {
                    type = "checkbox",
                    name = "Sons du compte à rebours",
                    getFunc = function() return PBT.savedVars.soundEnabled end,
                    setFunc = function(value) PBT.savedVars.soundEnabled = value end,
                    default = PBT.defaults.soundEnabled,
                },
                {
                    type = "checkbox",
                    name = "ON / OFF timers boss",
                    tooltip = "Active uniquement les timers automatiques des boss qui apparaissent, reviennent après une invulnérabilité ou ont une narration longue.",
                    getFunc = function() return PBT.savedVars.bossSpawnTimers end,
                    setFunc = function(value)
                        PBT.savedVars.bossSpawnTimers = value
                        PBT.savedVars.useSamuraiTimers = value
                    end,
                    default = PBT.defaults.bossSpawnTimers,
                },
                {
                    type = "header",
                    name = function() return PBT.GetString("bahsei_settings") end,
                },
                {
                    type = "checkbox",
                    name = function() return PBT.GetString("rockgrove_options_enabled") end,
                    getFunc = function() return PBT.savedVars.bahseiRaidOptions ~= false end,
                    setFunc = function(value)
                        PBT.savedVars.bahseiRaidOptions = value
                        if not value and PBT.BahseiPortal then
                            PBT.BahseiPortal:RemoveWallArrows()
                            PBT.BahseiPortal:ResetPortalState()
                        end
                    end,
                    default = PBT.defaults.bahseiRaidOptions,
                },
                {
                    type = "checkbox",
                    name = function() return PBT.GetString("bahsei_wall_arrows") end,
                    tooltip = function() return PBT.GetString("bahsei_wall_arrows_tooltip") end,
                    getFunc = function() return PBT.savedVars.bahseiWallArrows ~= false end,
                    setFunc = function(value)
                        PBT.savedVars.bahseiWallArrows = value
                        if not value and PBT.BahseiPortal then PBT.BahseiPortal:RemoveWallArrows() end
                    end,
                    default = PBT.defaults.bahseiWallArrows,
                },
                {
                    type = "checkbox",
                    name = function() return PBT.GetString("bahsei_ghost_counter_enabled") end,
                    getFunc = function() return PBT.savedVars.bahseiGhostCounter ~= false end,
                    setFunc = function(value)
                        PBT.savedVars.bahseiGhostCounter = value
                        if not value and PBT.BahseiPortal then PBT.BahseiPortal:HideGhostCounter() end
                    end,
                    default = PBT.defaults.bahseiGhostCounter,
                },
                {
                    type = "checkbox",
                    name = function() return PBT.GetString("bahsei_ghost_call") end,
                    tooltip = function() return PBT.GetString("bahsei_ghost_call_tooltip") end,
                    getFunc = function() return PBT.savedVars.bahseiGhostCall ~= false end,
                    setFunc = function(value) PBT.savedVars.bahseiGhostCall = value end,
                    default = PBT.defaults.bahseiGhostCall,
                },
                {
                    type = "checkbox",
                    name = function() return PBT.GetString("bahsei_ghost_receive") end,
                    getFunc = function() return PBT.savedVars.bahseiGhostReceive ~= false end,
                    setFunc = function(value) PBT.savedVars.bahseiGhostReceive = value end,
                    default = PBT.defaults.bahseiGhostReceive,
                },
                {
                    type = "slider",
                    name = function() return PBT.GetString("bahsei_ghost_threshold") end,
                    min = 1,
                    max = 23,
                    step = 1,
                    getFunc = function() return PBT.savedVars.bahseiGhostThreshold end,
                    setFunc = function(value)
                        PBT.savedVars.bahseiGhostThreshold = math.min(value, 23)
                    end,
                    default = PBT.defaults.bahseiGhostThreshold,
                },
                {
                    type = "header",
                    name = "Décompte personnalisé",
                },
                {
                    type = "checkbox",
                    name = "ON / OFF décompte personnalisé",
                    tooltip = "Active le décompte groupe lancé par raccourci ou depuis le gestionnaire.",
                    getFunc = function() return PBT.savedVars.groupCountdownEnabled end,
                    setFunc = function(value) PBT.savedVars.groupCountdownEnabled = value end,
                    default = PBT.defaults.groupCountdownEnabled,
                },
                {
                    type = "slider",
                    name = "Décompte groupe",
                    tooltip = "Durée envoyée à tout le groupe par le raid lead.",
                    min = 0,
                    max = 20,
                    step = 1,
                    getFunc = function() return PBT.savedVars.groupCountdownSeconds end,
                    setFunc = function(value) PBT.savedVars.groupCountdownSeconds = value end,
                    default = PBT.defaults.groupCountdownSeconds,
                },
                {
                    type = "slider",
                    name = "Mon délai",
                    tooltip = "Corrige uniquement ton affichage local. -2 affiche ton GO 2 secondes plus tôt. +2 affiche ton GO 2 secondes plus tard.",
                    min = -10,
                    max = 10,
                    step = 0.1,
                    getFunc = function() return PBT.savedVars.groupCountdownDpsDelay end,
                    setFunc = function(value) PBT.savedVars.groupCountdownDpsDelay = value end,
                    default = PBT.defaults.groupCountdownDpsDelay,
                },
                {
                    type = "description",
                    text = "Le décompte groupe est commun. Mon délai ne modifie que ton écran.",
                },
                {
                    type = "header",
                    name = "Diffusion groupe",
                },
                {
                    type = "checkbox",
                    name = "Diffuser le décompte au groupe",
                    tooltip = "Envoie le décompte aux joueurs qui utilisent Team Shadows Manager.",
                    getFunc = function() return PBT.savedVars.groupCountdownBroadcast end,
                    setFunc = function(value) PBT.savedVars.groupCountdownBroadcast = value end,
                    default = PBT.defaults.groupCountdownBroadcast,
                },
                {
                    type = "header",
                    name = "Markers",
                },
                {
                    type = "checkbox",
                    name = "Recevoir les markers",
                    tooltip = "Désactivé pour le moment : les markers se partagent par Exporter / Importer pour éviter les pings instables.",
                    getFunc = function() return PBT.savedVars.groupRendezvousReceive ~= false end,
                    setFunc = function(value)
                        PBT.savedVars.groupRendezvousReceive = value
                        RefreshLibTeamShadowsOptions()
                    end,
                    default = PBT.defaults.groupRendezvousReceive,
                },
                {
                    type = "dropdown",
                    name = "Icone marker",
                    tooltip = "Texture Team Shadows affichee au sol par le marker.",
                    choices = { "Carre rouge", "Carre bleu", "Carre jaune", "Carre vert", "Carre orange", "Carre rose", "Marker bleu clair", "Carre MT", "Carre OT", "Fleche", "Fleche verte", "Shadow", "Buche", "Fish", "Hyxtra", "Lexi", "Og", "Ogu", "Ray-me", "Ronce", "Selegnar", "Sla-anesh", "Tim" },
                    choicesValues = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23 },
                    getFunc = function() return PBT.savedVars.groupBeaconTextureId end,
                    setFunc = function(value)
                        PBT.savedVars.groupBeaconTextureId = value
                    end,
                    default = PBT.defaults.groupBeaconTextureId,
                },
                {
                    type = "dropdown",
                    name = "Texte marker",
                    tooltip = "Auto numerote les markers de 1 a 10, ou force un role precis.",
                    choices = { "Auto 1-10", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "H1", "H2", "MT", "OT" },
                    choicesValues = { "auto", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "H1", "H2", "MT", "OT" },
                    getFunc = function() return PBT.savedVars.groupBeaconLabel end,
                    setFunc = function(value)
                        PBT.savedVars.groupBeaconLabel = value
                    end,
                    default = PBT.defaults.groupBeaconLabel,
                },
                {
                    type = "slider",
                    name = "Taille marker",
                    tooltip = "Taille du carre visible dans le monde.",
                    min = 24,
                    max = 160,
                    step = 4,
                    getFunc = function() return PBT.savedVars.groupBeaconSize end,
                    setFunc = function(value)
                        PBT.savedVars.groupBeaconSize = value
                        RefreshLibTeamShadowsOptions()
                    end,
                    default = PBT.defaults.groupBeaconSize,
                },
                {
                    type = "slider",
                    name = "Duree marker",
                    tooltip = "Temps d'affichage du marker.",
                    min = 1,
                    max = 60,
                    step = 1,
                    getFunc = function() return PBT.savedVars.groupBeaconDuration end,
                    setFunc = function(value)
                        PBT.savedVars.groupBeaconDuration = value
                        RefreshLibTeamShadowsOptions()
                    end,
                    default = PBT.defaults.groupBeaconDuration,
                },
                {
                    type = "button",
                    name = "Placer marker vise",
                    tooltip = "Vise le sol avec le reticule puis valide pour enregistrer le marker.",
                    func = PBT.SendGroupRendezvous,
                    width = "full",
                },
        {
            type = "header",
            name = "Annonce visuelle",
        },
                {
                    type = "description",
                    text = "Reglages de l'affichage de l'annonce au centre de l'ecran.",
                },
                {
                    type = "button",
                    name = "Test annonce 3 sec",
                    tooltip = "Affiche une demo 3, 2, 1, GO avec les couleurs actuelles.",
                    func = TestVisualAnnouncement,
                    width = "full",
                },
                {
                    type = "slider",
                    name = "Taille UI",
                    width = "full",
                    min = 50,
                    max = 250,
                    step = 5,
                    getFunc = function() return zo_round((PBT.savedVars.scale or 1) * 100) end,
                    setFunc = function(value)
                        PBT.SetScale(value / 100)
                    end,
                    default = PBT.defaults.scale * 100,
                },
                {
                    type = "description",
                    text = "Apercu: PULL 3 / GO",
                    width = "full",
                },
                {
                    type = "description",
                    text = "Regle l'intensite du rouge et du vert du chiffre du timer.",
                },
                {
                    type = "slider",
                    name = "Intensite rouge",
                    width = "full",
                    min = 0,
                    max = 100,
                    step = 1,
                    getFunc = function() return zo_round((PBT.savedVars.color.r or 1) * 100) end,
                    setFunc = function(value)
                        local color = PBT.savedVars.color
                        PBT.SetColor(value / 100, color.g, color.b)
                    end,
                    default = PBT.defaults.color.r * 100,
                },
                {
                    type = "description",
                    text = "Apercu: PULL 3 / GO",
                    width = "full",
                },
                {
                    type = "slider",
                    name = "Intensite vert",
                    width = "full",
                    min = 0,
                    max = 100,
                    step = 1,
                    getFunc = function() return zo_round((PBT.savedVars.color.g or 0) * 100) end,
                    setFunc = function(value)
                        local color = PBT.savedVars.color
                        PBT.SetColor(color.r, value / 100, color.b)
                    end,
                    default = PBT.defaults.color.g * 100,
                },
                {
                    type = "description",
                    text = "Apercu: PULL 3 / GO",
                    width = "full",
                },
                {
                    type = "button",
                    name = "Remettre rouge par defaut",
                    func = function()
                        PBT.SetColor(PBT.defaults.color.r, PBT.defaults.color.g, PBT.defaults.color.b)
                    end,
                    width = "full",
                },
        {
            type = "header",
            name = "Mannequin",
        },
                {
                    type = "slider",
                    name = "Timer mannequin",
                    tooltip = "Duree du countdown lance apres une sortie de combat contre un mannequin.",
                    min = 1,
                    max = 60,
                    step = 1,
                    getFunc = function() return PBT.savedVars.practiceSeconds end,
                    setFunc = function(value) PBT.savedVars.practiceSeconds = value end,
                    default = PBT.defaults.practiceSeconds,
                },
                {
                    type = "checkbox",
                    name = "Auto timer apres reset mannequin",
                    tooltip = "Lance le timer mannequin a la sortie de combat si le combat precedent etait contre un mannequin.",
                    getFunc = function() return PBT.savedVars.autoPracticeOnDummyReset end,
                    setFunc = function(value) PBT.savedVars.autoPracticeOnDummyReset = value end,
                    default = PBT.defaults.autoPracticeOnDummyReset,
                },
        {
            type = "header",
            name = "Timers prebuff boss",
        },
        {
            type = "description",
            text = function() return PBT.GetString("boss_timer_details") end,
            width = "full",
        },
    }

    local function LocalizeOptionFields(entries)
        for _, option in ipairs(entries or {}) do
            if option.name == "Icone marker" then
                PBT.markerTextureDropdownOption = option
                option.choices = PBT.MarkerTextureLabels and PBT.MarkerTextureLabels[PBT.GetLanguage()] or option.choices
            end
            for _, field in ipairs({ "name", "tooltip", "text", "warning" }) do
                local source = option[field]
                if type(source) == "string" and PBT.HasLocalizedLiteral and PBT.HasLocalizedLiteral(source) then
                    option[field] = function() return PBT.LocalizeLiteral(source) end
                end
            end
        end
    end
    LocalizeOptionFields(options)

    PBT.settingsPanel = LAM:RegisterAddonPanel("TeamShadowsManagerOptions", panelData)
    LAM:RegisterOptionControls("TeamShadowsManagerOptions", options)
end

-- /tsm seul ouvre le manager ; les sous-commandes redonnent accès aux outils
-- texte (overrides de timers, alias, debug narration...) qui n'avaient plus
-- aucun point d'entrée depuis le passage à l'interface custom.
local function HandleManagerSlash(args)
    args = tostring(args or "")
    local command, rest = args:match("^(%S*)%s*(.-)$")
    command = string.lower(command or "")

    if command == "" then
        PBT.OpenManagerWindow()
    elseif command == "timers" or command == "list" then
        PrintTimerList()
    elseif command == "timer" then
        HandleTimer(rest)
    elseif command == "alias" then
        HandleAlias(rest)
    elseif command == "ia" then
        HandleInfiniteArchive(rest)
    elseif command == "generic" then
        HandleGeneric(rest)
    elseif command == "bahsei" or command == "portail" or command == "portal" then
        local bahseiAction = string.lower(tostring(rest or "")):gsub("^%s+", ""):gsub("%s+$", "")
        if bahseiAction == "test" or bahseiAction == "preview" or bahseiAction == "apercu" then
            if PBT.BahseiPortal then PBT.BahseiPortal:ShowPreviewArrows() end
        elseif PBT.BahseiPortal then
            PBT.BahseiPortal:ManualCall()
        end
    elseif command == "olms" then
        HandleAsOlms(rest)
    elseif command == "narration" then
        ToggleNarrationDebug()
    elseif command == "narrationlog" then
        PrintNarrationLog()
    elseif command == "boss" then
        PrintBossUnits()
    elseif command == "zone" then
        PrintZoneName()
    elseif command == "resetbouton" or command == "resetbutton" then
        ResetMenuButton()
    else
        Chat("commandes: /tsm (manager) | timers | timer <boss> <s> | alias <boss> = <nom> | ia <boss> | generic <s> | olms <s> | bahsei | bahsei test | narration | narrationlog | boss | zone | resetbouton")
    end
end

local function RegisterSlashCommands()
    SLASH_COMMANDS["/tsm"] = HandleManagerSlash
end

local function RegisterEvents()
    EM:RegisterForEvent(ADDON_NAME .. "Zone", EVENT_PLAYER_ACTIVATED, function()
        RefreshPlayerZone()
        if not IsInsidePlayerHouse() then
            PBT.dummyWasInCombat = false
        end
        zo_callLater(function()
            if PBT.UI and PBT.UI.managerWindow and not PBT.UI.managerWindow:IsHidden() and PBT.SelectMarkerDirectoryForCurrentZone then
                PBT.SelectMarkerDirectoryForCurrentZone()
                PBT.UI:RefreshManagerWindow()
            end
            if PBT.RefreshSavedMarkers then
                PBT.RefreshSavedMarkers()
            end
        end, 1200)
    end)
    EM:RegisterForEvent(ADDON_NAME, EVENT_BOSSES_CHANGED, OnBossesChanged)
    EM:RegisterForEvent(ADDON_NAME, EVENT_POWER_UPDATE, OnPowerUpdate)
    EM:RegisterForEvent(ADDON_NAME, EVENT_EFFECT_CHANGED, OnEffectChanged)
    EM:RegisterForEvent(ADDON_NAME, EVENT_COMBAT_EVENT, OnCombatEvent)
    EM:RegisterForEvent(ADDON_NAME, EVENT_CHAT_MESSAGE_CHANNEL, OnMonsterChat)
    EM:RegisterForEvent(ADDON_NAME .. "ReticleBoss", EVENT_RETICLE_TARGET_CHANGED, function()
        zo_callLater(ScanReticleBoss, 300)
    end)
    EM:RegisterForEvent(ADDON_NAME .. "CombatState", EVENT_PLAYER_COMBAT_STATE, function(_, inCombat)
        if not inCombat then
            if PBT.dummyWasInCombat then
                StartPracticeFromDummyReset()
            end
            ResetEncounterState()
        end
    end)

    if EM.AddFilterForEvent then
        EM:AddFilterForEvent(ADDON_NAME, EVENT_COMBAT_EVENT, REGISTER_FILTER_IS_ERROR, false)
    end
end

local function OnAddonLoaded(_, addonName)
    if not IsThisAddonLoadedName(addonName) then return end

    EM:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)

    -- SavedVariables are server-dependent (NA / EU / PTS) so profiles no
    -- longer overwrite each other. One-time migration copies the old
    -- shared "Default" profile into the current server's profile.
    local worldName = GetWorldName()
    if worldName == nil or worldName == "" then worldName = "Default" end
    local rawSavedVars = _G[PBT.savedVariableName]
    if rawSavedVars and rawSavedVars["Default"] and worldName ~= "Default" and rawSavedVars[worldName] == nil then
        rawSavedVars[worldName] = ZO_DeepTableCopy(rawSavedVars["Default"])
    end

    PBT.savedVars = ZO_SavedVars:NewAccountWide(
        PBT.savedVariableName,
        PBT.savedVariableVersion,
        nil,
        PBT.defaults,
        worldName
    )

    PBT.savedVars.language = PBT.savedVars.language == "en" and "en" or "fr"
    PBT.pendingLanguage = PBT.savedVars.language
    if PBT.RefreshBindingStrings then PBT.RefreshBindingStrings() end

    PBT.savedVars.timerOverrides = PBT.savedVars.timerOverrides or {}
    PBT.savedVars.customAliases = PBT.savedVars.customAliases or {}
    PBT.savedVars.instanceTimerEnabled = type(PBT.savedVars.instanceTimerEnabled) == "table" and PBT.savedVars.instanceTimerEnabled or {}
    PBT.savedVars.bossTimerEnabled = type(PBT.savedVars.bossTimerEnabled) == "table" and PBT.savedVars.bossTimerEnabled or {}
    PBT.savedVars.goColor = PBT.savedVars.goColor or PBT.defaults.goColor
    PBT.savedVars.practiceSeconds = tonumber(PBT.savedVars.practiceSeconds) or PBT.defaults.practiceSeconds
    if PBT.savedVars.practiceLogCalibrationApplied ~= true then
        if PBT.savedVars.practiceSeconds == 6 then
            PBT.savedVars.practiceSeconds = PBT.defaults.practiceSeconds
        end
        PBT.savedVars.practiceLogCalibrationApplied = true
    end
    if PBT.savedVars.bossSpawnTimers == nil then
        PBT.savedVars.bossSpawnTimers = PBT.defaults.bossSpawnTimers
    end
    if PBT.savedVars.groupCountdownEnabled == nil then
        PBT.savedVars.groupCountdownEnabled = PBT.defaults.groupCountdownEnabled
    end
    if PBT.savedVars.menuButtonEnabled == nil then
        PBT.savedVars.menuButtonEnabled = PBT.defaults.menuButtonEnabled
    end
    PBT.savedVars.menuButtonSize = tonumber(PBT.savedVars.menuButtonSize) or PBT.defaults.menuButtonSize
    PBT.savedVars.menuButtonSize = zo_clamp(PBT.savedVars.menuButtonSize, 28, 96)
    PBT.savedVars.menuButtonX = tonumber(PBT.savedVars.menuButtonX) or PBT.defaults.menuButtonX
    PBT.savedVars.menuButtonY = tonumber(PBT.savedVars.menuButtonY) or PBT.defaults.menuButtonY
    PBT.savedVars.managerWindowX = tonumber(PBT.savedVars.managerWindowX) or PBT.defaults.managerWindowX
    PBT.savedVars.managerWindowY = tonumber(PBT.savedVars.managerWindowY) or PBT.defaults.managerWindowY
    PBT.savedVars.groupCountdownSeconds = tonumber(PBT.savedVars.groupCountdownSeconds) or PBT.defaults.groupCountdownSeconds
    PBT.savedVars.groupCountdownSeconds = zo_clamp(PBT.savedVars.groupCountdownSeconds, 0, 20)
    PBT.savedVars.groupCountdownDpsDelay = tonumber(PBT.savedVars.groupCountdownDpsDelay) or PBT.defaults.groupCountdownDpsDelay
    PBT.savedVars.groupCountdownDpsDelay = zo_clamp(PBT.savedVars.groupCountdownDpsDelay, -10, 10)
    if PBT.savedVars.groupCountdownBroadcast == nil then
        PBT.savedVars.groupCountdownBroadcast = PBT.defaults.groupCountdownBroadcast
    end
    if PBT.savedVars.groupRendezvousReceive == nil then
        PBT.savedVars.groupRendezvousReceive = PBT.defaults.groupRendezvousReceive
    end
    PBT.savedVars.groupBeaconSavedMarkers = PBT.savedVars.groupBeaconSavedMarkers or {}
    PBT.savedVars.groupBeaconColor = PBT.savedVars.groupBeaconColor or PBT.defaults.groupBeaconColor
    PBT.savedVars.groupBeaconTextureId = zo_clamp(tonumber(PBT.savedVars.groupBeaconTextureId) or PBT.defaults.groupBeaconTextureId, 1, 23)
    PBT.savedVars.groupBeaconColor.r = zo_clamp(tonumber(PBT.savedVars.groupBeaconColor.r) or PBT.defaults.groupBeaconColor.r, 0, 1)
    PBT.savedVars.groupBeaconColor.g = zo_clamp(tonumber(PBT.savedVars.groupBeaconColor.g) or PBT.defaults.groupBeaconColor.g, 0, 1)
    PBT.savedVars.groupBeaconColor.b = zo_clamp(tonumber(PBT.savedVars.groupBeaconColor.b) or PBT.defaults.groupBeaconColor.b, 0, 1)
    if not PBT.beaconLabelIds[PBT.savedVars.groupBeaconLabel or ""] and PBT.savedVars.groupBeaconLabel ~= "auto" then
        PBT.savedVars.groupBeaconLabel = PBT.defaults.groupBeaconLabel
    end
    PBT.savedVars.groupBeaconCustomLabel = tostring(PBT.savedVars.groupBeaconCustomLabel or "")
    PBT.savedVars.groupBeaconNextNumber = zo_clamp(tonumber(PBT.savedVars.groupBeaconNextNumber) or PBT.defaults.groupBeaconNextNumber, 1, 10)
    PBT.savedVars.groupBeaconMarkerSets = PBT.savedVars.groupBeaconMarkerSets or {}
    PBT.savedVars.groupBeaconMarkerSetSlot = zo_clamp(tonumber(PBT.savedVars.groupBeaconMarkerSetSlot) or 1, 1, 3)
    PBT.savedVars.groupBeaconMarkerSetName = tostring(PBT.savedVars.groupBeaconMarkerSetName or "")
    if type(PBT.savedVars.groupShareTemporaryBackup) == "table" then
        PBT.RestoreTemporaryGroupMarkerShare()
    else
        PBT.savedVars.groupShareTemporaryBackup = nil
    end
    if PBT.savedVars.groupBeaconDisplayMode ~= "filter" then
        PBT.savedVars.groupBeaconDisplayMode = "all"
    end
    if not PBT.beaconLabelIds[PBT.savedVars.groupBeaconDisplayLabel or ""] and PBT.savedVars.groupBeaconDisplayLabel ~= "all" then
        PBT.savedVars.groupBeaconDisplayLabel = "all"
    end
    PBT.savedVars.groupBeaconSize = zo_clamp(tonumber(PBT.savedVars.groupBeaconSize) or PBT.defaults.groupBeaconSize, 24, 160)
    PBT.savedVars.groupBeaconHeight = zo_clamp(tonumber(PBT.savedVars.groupBeaconHeight) or PBT.defaults.groupBeaconHeight, -40, 80)
    if PBT.savedVars.groupBeaconHeightDefaultZeroApplied ~= true then
        PBT.savedVars.groupBeaconHeight = 0
        for _, marker in ipairs(PBT.savedVars.groupBeaconSavedMarkers or {}) do
            if tonumber(marker.heightOffset) == 4.5 then
                marker.heightOffset = 0
            end
        end
        PBT.savedVars.groupBeaconHeightDefaultZeroApplied = true
    end
    if PBT.savedVars.groupBeaconHeightCalibrationApplied ~= true then
        PBT.savedVars.groupBeaconHeight = PBT.defaults.groupBeaconHeight
        for _, marker in ipairs(PBT.savedVars.groupBeaconSavedMarkers or {}) do
            marker.heightOffset = PBT.defaults.groupBeaconHeight
        end
        PBT.savedVars.groupBeaconHeightCalibrationApplied = true
    end
    PBT.savedVars.groupBeaconDuration = zo_clamp(tonumber(PBT.savedVars.groupBeaconDuration) or PBT.defaults.groupBeaconDuration, 1, 60)
    if PBT.savedVars.autoPracticeOnDummyReset == nil then
        PBT.savedVars.autoPracticeOnDummyReset = PBT.defaults.autoPracticeOnDummyReset
    end
    if PBT.savedVars.bossNameTimers == nil then
        PBT.savedVars.bossNameTimers = PBT.defaults.bossNameTimers
    end
    if PBT.savedVars.bossUnitDetection == nil then
        PBT.savedVars.bossUnitDetection = PBT.defaults.bossUnitDetection
    end
    if PBT.savedVars.genericCinematicTimers == nil then
        PBT.savedVars.genericCinematicTimers = PBT.defaults.genericCinematicTimers
    end
    if PBT.savedVars.worldBossTimers == nil then
        PBT.savedVars.worldBossTimers = PBT.defaults.worldBossTimers
    end
    if PBT.savedVars.asOlmsFourthLanding == nil then
        PBT.savedVars.asOlmsFourthLanding = PBT.defaults.asOlmsFourthLanding
    end
    PBT.savedVars.asOlmsLandingSeconds = tonumber(PBT.savedVars.asOlmsLandingSeconds) or PBT.defaults.asOlmsLandingSeconds
    if PBT.savedVars.asOlmsLogCalibrationApplied ~= true then
        if PBT.savedVars.asOlmsLandingSeconds == 30 then
            PBT.savedVars.asOlmsLandingSeconds = PBT.defaults.asOlmsLandingSeconds
        end
        PBT.savedVars.asOlmsLogCalibrationApplied = true
    end
    if PBT.savedVars.disableLateBossUnitTriggersApplied ~= true then
        PBT.savedVars.bossUnitDetection = false
        PBT.savedVars.genericCinematicTimers = false
        PBT.savedVars.worldBossTimers = false
        PBT.savedVars.disableLateBossUnitTriggersApplied = true
    end
    PBT.savedVars.genericCinematicSeconds = tonumber(PBT.savedVars.genericCinematicSeconds) or PBT.defaults.genericCinematicSeconds
    if PBT.savedVars.useSamuraiTimers == nil then
        PBT.savedVars.useSamuraiTimers = PBT.defaults.useSamuraiTimers
    end
    PBT.savedVars.useSamuraiTimers = PBT.savedVars.bossSpawnTimers ~= false
    if PBT.savedVars.showMechanicTimers == nil then
        PBT.savedVars.showMechanicTimers = PBT.defaults.showMechanicTimers
    end
    if PBT.savedVars.nahvPortalHpWarning == nil then
        PBT.savedVars.nahvPortalHpWarning = PBT.defaults.nahvPortalHpWarning
    end
    if PBT.savedVars.bahseiRaidOptions == nil then
        PBT.savedVars.bahseiRaidOptions = PBT.defaults.bahseiRaidOptions
    end
    if PBT.savedVars.bahseiWallArrows == nil then
        PBT.savedVars.bahseiWallArrows = PBT.defaults.bahseiWallArrows
    end
    if PBT.savedVars.bahseiGhostCounter == nil then
        PBT.savedVars.bahseiGhostCounter = PBT.defaults.bahseiGhostCounter
    end
    if PBT.savedVars.bahseiGhostCall == nil then
        PBT.savedVars.bahseiGhostCall = PBT.defaults.bahseiGhostCall
    end
    if PBT.savedVars.bahseiGhostReceive == nil then
        PBT.savedVars.bahseiGhostReceive = PBT.defaults.bahseiGhostReceive
    end
    -- Encounter.log confirms eight portal phantoms (unitTypeId 103349).
    PBT.savedVars.bahseiGhostTotal = 24
    PBT.savedVars.bahseiGhostThreshold = zo_clamp(tonumber(PBT.savedVars.bahseiGhostThreshold) or PBT.defaults.bahseiGhostThreshold, 1, 23)
    if PBT.savedVars.narrationDebug == nil then
        PBT.savedVars.narrationDebug = false
    end

    if PBT.savedVars.hofSunspireCalibrationResetV2 ~= true then
        local overrides = PBT.savedVars.timerOverrides or {}
        overrides["pinnacle factotum"] = nil
        overrides["reclaimer reducer reactor"] = nil
        overrides["lokkestiiz"] = nil
        overrides["yolnahkriin"] = nil
        overrides["nahviintaas"] = nil
        PBT.savedVars.bossNameTimers = false
        PBT.savedVars.bossUnitDetection = false
        PBT.savedVars.genericCinematicTimers = false
        PBT.savedVars.worldBossTimers = false
        PBT.savedVars.hofSunspireCalibrationResetV2 = true
    end

    if PBT.savedVars.curatedMechanicTimersV3 ~= true then
        local overrides = PBT.savedVars.timerOverrides or {}
        overrides["hunter-killer fabricants"] = nil
        overrides["pinnacle factotum"] = nil
        overrides["reclaimer reducer reactor"] = nil
        overrides["zhaj'hassa the forgotten"] = nil
        overrides["rakkhat"] = nil
        overrides["nahviintaas"] = nil
        PBT.savedVars.bossNameTimers = false
        PBT.savedVars.bossUnitDetection = false
        PBT.savedVars.genericCinematicTimers = false
        PBT.savedVars.worldBossTimers = false
        PBT.savedVars.curatedMechanicTimersV3 = true
    end

    PBT.BuildBossLookup()
    PBT.UI:Initialize()
    PBT.UI:ApplySettings()
    RefreshPlayerZone()
    RegisterSlashCommands()
    RegisterSettingsPanel()
    RegisterEvents()
    RefreshLibTeamShadowsOptions()
    RegisterLibTeamShadowsHandlers()
    if PBT.GroupShare and PBT.GroupShare.Initialize then
        PBT.GroupShare:Initialize()
    end
    if PBT.BahseiPortal and PBT.BahseiPortal.Initialize then
        PBT.BahseiPortal:Initialize()
    end
    zo_callLater(function()
        if PBT.RefreshSavedMarkers then
            PBT.RefreshSavedMarkers()
        end
    end, 1600)
    zo_callLater(function()
        if PBT.UI and PBT.UI.ShowMarkerReadyAlert then
            PBT.UI:ShowMarkerReadyAlert()
            zo_callLater(function()
                if PBT.UI and not PBT.isRunning and not (PBT.savedVars and PBT.savedVars.unlocked) then
                    PBT.UI:Hide()
                end
            end, 1800)
        end
    end, 2200)

    if PBT.savedVars.bossUnitDetection then
        zo_callLater(function()
            PBT.QueueScan(100)
        end, 1200)
    end
end

EM:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, OnAddonLoaded)
