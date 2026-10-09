TeamShadowsManager = TeamShadowsManager or {}

local TSM = TeamShadowsManager
local Module = {
    zoneId = 1263,
    ghostUnitTypeId = 103349,
    -- The encounter is split into 3 portal sections with 8 Spectres each.
    ghostTotal = 24,
    eyeClockwiseId = 153517,
    eyeCounterClockwiseId = 153518,
    eyeExplodeId = 153662,
    bitterMarrowId = 153423,
    malignantMarrowId = 153421,
    -- Measured Bahsei arena corners (One More Rockgrove Helper):
    -- X 96677..103118, Z 96430..102867, floor Y 42650.
    center = { 99897.5, 42650, 99648.5 },
    roomHalfX = 3220.5,
    roomHalfZ = 3218.5,
    wallInset = 150,
    wallHeight = 285,
    pairsPerWall = 3,
    arrowDimensions = { 720, 240 },
    displayMs = 9000,
    clockwiseTexture = "TeamShadowsManager/textures/bahsei-arrow-cw.dds",
    counterClockwiseTexture = "TeamShadowsManager/textures/bahsei-arrow-ccw.dds",
    worldElements = {},
    insidePortal = false,
    deaths = {},
    seenGhosts = {},
    aliveGhosts = {},
    maxAliveSeen = 0,
    deathCount = 0,
    lastFallbackDeathMs = 0,
    lastBroadcastCounter = nil,
    cycleActive = false,
    currentRemaining = 24,
    callSent = false,
    displayToken = 0,
    lastSignal = {},
}

TSM.BahseiPortal = Module

local EM = EVENT_MANAGER
local EVENT_PREFIX = "TeamShadowsManagerBahsei"

local function NowMs()
    if GetFrameTimeMilliseconds then return GetFrameTimeMilliseconds() end
    if GetGameTimeMilliseconds then return GetGameTimeMilliseconds() end
    return (GetTimeStamp and GetTimeStamp() or 0) * 1000
end

local function IsInRockgrove()
    if not GetUnitZoneIndex or not GetZoneId then return false end
    local zoneIndex = GetUnitZoneIndex("player")
    return zoneIndex and GetZoneId(zoneIndex) == Module.zoneId
end

local function IsEnabled(setting)
    return TSM.savedVars
        and TSM.savedVars.enabled ~= false
        and TSM.savedVars.bahseiRaidOptions ~= false
        and TSM.savedVars[setting] ~= false
end

local function IsGhostName(name)
    name = zo_strlower and zo_strlower(tostring(name or "")) or string.lower(tostring(name or ""))
    name = name:gsub("^%s+", ""):gsub("%s+$", "")
    -- Encounter.log: the Bahsei portal phantom is exactly "Spectre"
    -- (unitTypeId 103349). Exact names avoid counting Burning Specters and pets.
    return name == "spectre"
        or name == "specter"
        or name == "ghost"
        or name == "phantom"
        or name == "wraith"
end

local function SenderName(unitTag)
    local name = GetUnitDisplayName and GetUnitDisplayName(unitTag)
    if name and name ~= "" then return name end
    name = GetUnitName and GetUnitName(unitTag)
    return (name and name ~= "") and name or tostring(unitTag or "joueur")
end

local function Chat(message)
    if d then d("|c66ccffTSM:|r " .. tostring(message)) end
end

local function GetWorldDrawingApi()
    -- CA2 is only a local alias inside Combat Alerts. Third-party addons must
    -- use the public global table created by Combat Alerts itself.
    return CombatAlerts2
end

local function CountKeys(values)
    local count = 0
    for _ in pairs(values or {}) do count = count + 1 end
    return count
end

function Module:ResetPortalState()
    self.insidePortal = false
    self.deaths = {}
    self.seenGhosts = {}
    self.aliveGhosts = {}
    self.maxAliveSeen = 0
    self.deathCount = 0
    self.lastFallbackDeathMs = 0
    self.lastBroadcastCounter = nil
    self.cycleActive = false
    self.currentRemaining = self.ghostTotal
    self.callSent = false
    if self.counterWindow then self.counterWindow:SetHidden(true) end
end

function Module:StartGhostCycle()
    local now = NowMs()
    if self.cycleActive and self.cycleStartedAt and now - self.cycleStartedAt < 5000 then return end
    self:ResetPortalState()
    self.cycleActive = true
    self.cycleStartedAt = now
    self.currentRemaining = self.ghostTotal
    self:UpdateGhostCounter(self.ghostTotal, self.ghostTotal, false)
end

function Module:FinishGhostCycle()
    self.insidePortal = false
    self.cycleActive = false
    self:HideGhostCounter()
end

function Module:HideGhostCounter()
    if self.counterWindow then self.counterWindow:SetHidden(true) end
end

function Module:BroadcastGhostCounter(remaining, total)
    if not self.insidePortal or not IsEnabled("bahseiGhostCounter") then return false end
    local signature = tostring(remaining) .. "/" .. tostring(total)
    if self.lastBroadcastCounter == signature then return false end
    self.lastBroadcastCounter = signature
    if TSM.GroupShare and TSM.GroupShare.SendBahseiSignal then
        return TSM.GroupShare:SendBahseiSignal("COUNT", remaining, total)
    end
    return false
end

function Module:TrackGhost(name, unitId)
    if not self.insidePortal or not IsGhostName(name) then return end
    if not IsEnabled("bahseiGhostCounter") and not IsEnabled("bahseiGhostCall") then return end
    unitId = tonumber(unitId) or 0
    if unitId <= 0 then return end
    local key = tostring(unitId)
    self.seenGhosts[key] = true
    if not self.deaths[key] then self.aliveGhosts[key] = true end
    self.maxAliveSeen = math.max(self.maxAliveSeen, CountKeys(self.aliveGhosts))

    local remaining = math.max(0, self.ghostTotal - self.deathCount)
    self:UpdateGhostCounter(remaining, self.ghostTotal, false)
end

function Module:UpdateGhostCounter(remaining, total, broadcast)
    total = tonumber(total) or self.ghostTotal
    remaining = zo_clamp(tonumber(remaining) or total, 0, total)
    self.currentRemaining = remaining
    if broadcast then self:BroadcastGhostCounter(remaining, total) end
    if not IsEnabled("bahseiGhostCounter") then
        self:HideGhostCounter()
        return
    end
    if not self.counterWindow then
        local wm = WINDOW_MANAGER
        local window = wm:CreateTopLevelWindow("TeamShadowsManagerBahseiCounter")
        window:SetDimensions(360, 56)
        window:SetAnchor(TOP, GuiRoot, TOP, 0, 175)
        window:SetMouseEnabled(false)
        window:SetMovable(false)
        window:SetDrawLayer(DL_OVERLAY)
        window:SetDrawTier(DT_HIGH)
        window:SetHidden(true)

        local backdrop = wm:CreateControl(nil, window, CT_BACKDROP)
        backdrop:SetAnchorFill(window)
        backdrop:SetCenterColor(0.02, 0.02, 0.02, 0.82)
        backdrop:SetEdgeColor(0.72, 0.52, 0.18, 1)
        backdrop:SetEdgeTexture("EsoUI/Art/Tooltips/UI-SliderBackdrop.dds", 12, 2, 2)

        local label = wm:CreateControl(nil, window, CT_LABEL)
        label:SetAnchorFill(window)
        label:SetFont("ZoFontWinH3")
        label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        label:SetColor(1, 0.82, 0.30, 1)
        self.counterWindow, self.counterLabel = window, label
    end
    local text = TSM.GetString and TSM.GetString("bahsei_ghost_counter", remaining, total)
        or string.format("FANTÔMES : %d/%d", remaining, total)
    self.counterLabel:SetText(text)
    self.counterWindow:SetHidden(false)
end

function Module:RemoveWallArrows()
    self.displayToken = self.displayToken + 1
    local worldApi = GetWorldDrawingApi()
    if worldApi and worldApi.WorldElementRemove then
        for _, elementId in ipairs(self.worldElements) do
            pcall(worldApi.WorldElementRemove, elementId)
        end
    end
    self.worldElements = {}
end

function Module:PlaceWallArrows(clockwise, center, halfX, halfZ)
    local worldApi = GetWorldDrawingApi()
    if not worldApi or not worldApi.WorldTexturePlace then
        if not self.warnedMissingWorldDrawing then
            self.warnedMissingWorldDrawing = true
            Chat(TSM.GetString and TSM.GetString("bahsei_world_drawing_missing") or
                "Flèches Bahsei indisponibles : Combat Alerts n'est pas actif.")
        end
        return
    end

    self:RemoveWallArrows()
    local redTexture = clockwise and self.clockwiseTexture or self.counterClockwiseTexture
    local greenTexture = clockwise and self.counterClockwiseTexture or self.clockwiseTexture
    local centerX, centerY, centerZ = unpack(center or self.center)
    halfX = tonumber(halfX) or (self.roomHalfX - self.wallInset)
    halfZ = tonumber(halfZ) or (self.roomHalfZ - self.wallInset)

    -- The room is square, not circular. Three pairs are distributed along
    -- each wall, 1.5 m inside the measured arena boundary.
    local wallPoints = {}
    for index = 1, self.pairsPerWall do
        local ratio = ((index - 0.5) / self.pairsPerWall) * 2 - 1
        wallPoints[#wallPoints + 1] = { centerX + halfX * ratio, centerZ - halfZ }
        wallPoints[#wallPoints + 1] = { centerX + halfX, centerZ + halfZ * ratio }
        wallPoints[#wallPoints + 1] = { centerX - halfX * ratio, centerZ + halfZ }
        wallPoints[#wallPoints + 1] = { centerX - halfX, centerZ - halfZ * ratio }
    end

    for _, point in ipairs(wallPoints) do
        local wallX, wallZ = point[1], point[2]

        local redId = worldApi.WorldTexturePlace({
            pos = { wallX, centerY + self.wallHeight, wallZ },
            texture = redTexture,
            size = self.arrowDimensions,
            color = 0xFF2525E6,
            disableDepthBuffers = true,
            playerFacing = true,
        })
        local greenId = worldApi.WorldTexturePlace({
            pos = { wallX, centerY + self.wallHeight, wallZ },
            texture = greenTexture,
            size = self.arrowDimensions,
            color = 0x25FF52E6,
            disableDepthBuffers = true,
            playerFacing = true,
        })
        if redId then self.worldElements[#self.worldElements + 1] = redId end
        if greenId then self.worldElements[#self.worldElements + 1] = greenId end
    end

    local token = self.displayToken
    zo_callLater(function()
        if Module.displayToken == token then Module:RemoveWallArrows() end
    end, self.displayMs)
    return true
end

function Module:ShowWallArrows(clockwise)
    if not IsInRockgrove() or not IsEnabled("bahseiWallArrows") or self.insidePortal then return false end
    return self:PlaceWallArrows(clockwise, self.center,
        self.roomHalfX - self.wallInset, self.roomHalfZ - self.wallInset)
end

function Module:ShowPreviewArrows()
    if not TSM.savedVars or TSM.savedVars.enabled == false then return false end
    if not GetUnitRawWorldPosition then return false end

    local zone, x, y, z = GetUnitRawWorldPosition("player")
    if not zone or zone == 0 or not x or not y or not z then return false end

    -- Preview keeps Bahsei's exact measured square; only its center follows
    -- the player so it can be inspected anywhere outside the trial.
    local shown = self:PlaceWallArrows(true, { x, y, z },
        self.roomHalfX - self.wallInset, self.roomHalfZ - self.wallInset)
    if shown then
        Chat(TSM.GetString and TSM.GetString("bahsei_preview_shown") or
            "Aperçu des flèches Bahsei affiché pendant 9 secondes.")
    end
    return shown
end

function Module:ShowCallAlert(sender, remaining)
    if not self.alertWindow then
        local wm = WINDOW_MANAGER
        local window = wm:CreateTopLevelWindow("TeamShadowsManagerBahseiAlert")
        window:SetDimensions(900, 150)
        window:SetAnchor(CENTER, GuiRoot, CENTER, 0, -155)
        window:SetMouseEnabled(false)
        window:SetMovable(false)
        window:SetDrawLayer(DL_OVERLAY)
        window:SetDrawTier(DT_HIGH)
        window:SetHidden(true)

        local backdrop = wm:CreateControl(nil, window, CT_BACKDROP)
        backdrop:SetAnchorFill(window)
        backdrop:SetCenterColor(0.02, 0.02, 0.02, 0.90)
        backdrop:SetEdgeColor(0.12, 1, 0.30, 1)
        backdrop:SetEdgeTexture("EsoUI/Art/Tooltips/UI-SliderBackdrop.dds", 16, 2, 2)

        local label = wm:CreateControl(nil, window, CT_LABEL)
        label:SetAnchorFill(window)
        label:SetFont("ZoFontWinH1")
        label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        label:SetColor(0.20, 1, 0.35, 1)

        self.alertWindow, self.alertLabel = window, label
    end

    local text = TSM.GetString and TSM.GetString("bahsei_descend_alert", remaining, sender)
        or string.format("DESCENDEZ AU PORTAIL — %d FANTÔMES", remaining)
    self.alertLabel:SetText(text)
    self.alertWindow:SetHidden(false)
    if PlaySound and SOUNDS then PlaySound(SOUNDS.CHAMPION_POINTS_COMMITTED) end

    self.alertToken = (self.alertToken or 0) + 1
    local token = self.alertToken
    zo_callLater(function()
        if Module.alertToken == token and Module.alertWindow then Module.alertWindow:SetHidden(true) end
    end, 6000)
end

function Module:SendReinforcementCall(manual)
    if self.callSent and not manual then return false end
    local remaining = manual
        and zo_clamp(tonumber(self.currentRemaining) or self.ghostTotal, 0, self.ghostTotal)
        or zo_clamp(tonumber(TSM.savedVars and TSM.savedVars.bahseiGhostThreshold) or 5, 1, self.ghostTotal - 1)
    local sent, reason = false, "protocol_unavailable"
    if TSM.GroupShare and TSM.GroupShare.SendBahseiSignal then
        sent, reason = TSM.GroupShare:SendBahseiSignal(manual and "MANUAL" or "GHOSTS", remaining)
    end
    if sent then
        self.callSent = true
        self:ShowCallAlert(GetUnitDisplayName and GetUnitDisplayName("player") or "", remaining)
        Chat(TSM.GetString and TSM.GetString("bahsei_call_sent", remaining) or
            string.format("Appel portail envoyé : %d fantômes restants.", remaining))
        return true
    end
    Chat((TSM.GetString and TSM.GetString("bahsei_call_failed") or "Appel portail non envoyé") ..
        " (" .. tostring(reason or "inconnu") .. ").")
    return false
end

function Module:ManualCall()
    if not IsInRockgrove() then
        Chat(TSM.GetString and TSM.GetString("bahsei_not_in_rockgrove") or "Commande disponible uniquement à Rochebosque.")
        return false
    end
    return self:SendReinforcementCall(true)
end

function Module:OnGroupSignal(unitTag, payload)
    if not IsInRockgrove() or not IsEnabled("bahseiGhostReceive") then return end
    local signal, remaining, total = payload:match("^TSMB1|([A-Z0-9_]+)|(%d+)|(%d+)$")
    if not signal then signal, remaining = payload:match("^TSMB1|([A-Z0-9_]+)|(%d+)$") end
    remaining = tonumber(remaining)
    total = tonumber(total)
    if signal == "DEAD" then
        if not self.cycleActive or not remaining or remaining <= 0 then return end
    elseif signal == "COUNT" then
        if not self.cycleActive or not IsEnabled("bahseiGhostCounter") or not remaining or not total
            or total ~= self.ghostTotal or remaining < 0 or remaining > total
        then return end
    elseif signal == "CLEAR" then
        self:HideGhostCounter()
        return
    elseif signal ~= "GHOSTS" and signal ~= "MANUAL" then
        return
    elseif not remaining or remaining < 0 or remaining > self.ghostTotal then
        return
    end

    local signature = tostring(unitTag) .. "|" .. payload
    local now = NowMs()
    if self.lastSignal[signature] and now - self.lastSignal[signature] < 10000 then return end
    self.lastSignal[signature] = now
    if signal == "DEAD" then
        self:ApplyGhostDeath("unit:" .. tostring(remaining), false)
    elseif signal == "COUNT" then
        -- Snapshots are only allowed to move the counter forward. This also
        -- repairs missed death packets without letting a late portal entrant
        -- reset everybody from 5 back to 24.
        local current = tonumber(self.currentRemaining) or self.ghostTotal
        if remaining < current then
            self.deathCount = math.max(self.deathCount, total - remaining)
            self:UpdateGhostCounter(remaining, total, false)
        end
    else
        self:ShowCallAlert(SenderName(unitTag), remaining)
    end
end

function Module:ApplyGhostDeath(key, localDeath)
    if not self.cycleActive then
        self.cycleActive = true
        self.currentRemaining = self.ghostTotal
    end
    if self.deaths[key] then return false end
    self.deaths[key] = true
    local aliveBefore = CountKeys(self.aliveGhosts)
    self.aliveGhosts[key] = nil
    self.deathCount = self.deathCount + 1
    local total = self.ghostTotal
    local threshold = zo_clamp(tonumber(TSM.savedVars.bahseiGhostThreshold) or 5, 1, total - 1)
    local remaining = math.max(0, total - self.deathCount)
    self:UpdateGhostCounter(remaining, total, false)
    local aliveAfter = CountKeys(self.aliveGhosts)
    local observedTransition = self.maxAliveSeen > threshold and aliveBefore > threshold and aliveAfter <= threshold
    if localDeath and self.insidePortal and IsEnabled("bahseiGhostCall")
        and (remaining <= threshold or observedTransition) and not self.callSent
    then
        self:SendReinforcementCall(false)
    end
    return true
end

function Module:RecordGhostDeath(targetName, targetUnitId)
    if not self.insidePortal or not IsGhostName(targetName) then return end
    if not IsEnabled("bahseiGhostCounter") and not IsEnabled("bahseiGhostCall") then return end

    targetUnitId = tonumber(targetUnitId) or 0
    local key
    if targetUnitId > 0 then
        key = "unit:" .. tostring(targetUnitId)
    else
        local now = NowMs()
        if now - self.lastFallbackDeathMs < 350 then return end
        self.lastFallbackDeathMs = now
        key = "fallback:" .. tostring(now)
    end
    if not self:ApplyGhostDeath(key, true) then return end

    if targetUnitId > 0 and TSM.GroupShare and TSM.GroupShare.SendBahseiSignal then
        TSM.GroupShare:SendBahseiSignal("DEAD", targetUnitId)
    end
    self:BroadcastGhostCounter(self.currentRemaining, self.ghostTotal)
end

local function OnDirection(_, result, _, _, _, _, _, _, _, _, _, _, _, _, _, _, abilityId)
    if result ~= ACTION_RESULT_EFFECT_GAINED then return end
    if abilityId == Module.eyeClockwiseId then
        Module:StartGhostCycle()
        Module:ShowWallArrows(true)
    elseif abilityId == Module.eyeCounterClockwiseId then
        Module:StartGhostCycle()
        Module:ShowWallArrows(false)
    elseif abilityId == Module.eyeExplodeId then
        Module:FinishGhostCycle()
    end
end

local function OnGhostCombat(_, result, _, _, _, _, sourceName, _, targetName, _, _, _, _, _, sourceUnitId, targetUnitId)
    Module:TrackGhost(sourceName, sourceUnitId)
    Module:TrackGhost(targetName, targetUnitId)
    if result == ACTION_RESULT_DIED or result == ACTION_RESULT_DIED_XP then
        Module:RecordGhostDeath(targetName, targetUnitId)
    end
end

local function OnPortalEffect(_, changeType, _, _, unitTag, _, _, _, _, _, _, _, _, _, _, abilityId)
    if unitTag ~= "player" then return end
    if abilityId == Module.bitterMarrowId then
        if changeType == EFFECT_RESULT_GAINED then
            if not Module.cycleActive then Module:StartGhostCycle() end
            Module.insidePortal = true
            Module:UpdateGhostCounter(Module.currentRemaining, Module.ghostTotal, false)
            Module:RemoveWallArrows()
        elseif changeType == EFFECT_RESULT_FADED then
            Module.insidePortal = false
        end
    elseif abilityId == Module.malignantMarrowId and changeType == EFFECT_RESULT_GAINED then
        Module:ResetPortalState()
    end
end

function Module:Initialize()
    EM:RegisterForEvent(EVENT_PREFIX .. "Direction", EVENT_COMBAT_EVENT, OnDirection)
    EM:RegisterForEvent(EVENT_PREFIX .. "Deaths", EVENT_COMBAT_EVENT, OnGhostCombat)
    EM:RegisterForEvent(EVENT_PREFIX .. "Effects", EVENT_EFFECT_CHANGED, OnPortalEffect)
    EM:RegisterForEvent(EVENT_PREFIX .. "Combat", EVENT_PLAYER_COMBAT_STATE, function(_, inCombat)
        if not inCombat then
            Module:RemoveWallArrows()
            Module:ResetPortalState()
        end
    end)
    EM:RegisterForEvent(EVENT_PREFIX .. "Zone", EVENT_PLAYER_ACTIVATED, function()
        Module:RemoveWallArrows()
        Module:ResetPortalState()
    end)
    if EM.AddFilterForEvent then
        EM:AddFilterForEvent(EVENT_PREFIX .. "Direction", EVENT_COMBAT_EVENT, REGISTER_FILTER_IS_ERROR, false)
        EM:AddFilterForEvent(EVENT_PREFIX .. "Deaths", EVENT_COMBAT_EVENT, REGISTER_FILTER_IS_ERROR, false)
        EM:AddFilterForEvent(EVENT_PREFIX .. "Effects", EVENT_EFFECT_CHANGED, REGISTER_FILTER_UNIT_TAG, "player")
    end
end
