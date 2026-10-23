local addonName = "LykeionsAwareWolf"
local hungerIconFilename = "/esoui/art/icons/ability_werewolf_007.dds"

local lastActiveTime = 0
local isCombatActive = false
local reviveUntil = 0
local wasPositivelyActive = false
local slotPressTime = {}
local slotConfirmTime = {}
local db
local SV_NAME = "InsatiableHungerBlocker_SV"
local defaults = {
    timeout = 2000,
    pounceConfirm = true,
    ultimateConfirm = true,
    confirmTimeout = 500,
    holdIndicator = true,
    clawFuryRange = true,
    roarPanel = true,
    prowlPanel = false,
    feedingpriority = true,
}

local POUNCE_ABILITY_ID = 32632
local CARNAGE_ABILITY_ID = 137156
local TRANSFORM_ABILITY_ID = 32455
local RAMPAGE_ABILITY_ID = 267416
local ROAR_ABILITY_ID = 32633
local FEEDING_FRENZY_ABILITY_ID = 131353
local MAJOR_COURAGE_ABILITY_ID = 109966
local RENDING_CLAWS_ABILITY_ID = 58855
local CLAW_FURY_ABILITY_ID = 58864
local BLOODCLAWS_ABILITY_ID = 58879
local INSATIABLE_HUNGER_ABILITY_ID = 33208
local FEEDING_FREEZY_ABILITY_ID = 58775
local PROWL_ABILITY_ID = 252086

local function LocalizeAbilityString(stringId, ...)
    return zo_strformat(GetString(stringId), ...)
end

local function ShouldHideIHSynergy()
    local hasSynergy, _, iconFilename = GetCurrentSynergyInfo()
    return hasSynergy and iconFilename == hungerIconFilename
end

local function IsPositivelyActive()
    return IsUnitDeadOrReincarnating("player") or IsUnitSwimming("player") or GetGameTimeMilliseconds() < reviveUntil
end

local function OnCombatEvent(_, result, _, _, _, _, _, _, targetName)
    if IsUnitInCombat("player") and targetName ~= GetRawUnitName("player") and
       (result == ACTION_RESULT_DAMAGE or result == ACTION_RESULT_CRITICAL_DAMAGE) then
        lastActiveTime = GetGameTimeMilliseconds()
    end
end

local function OnSoulGemResurrectionStart(_, duration)
    reviveUntil = GetGameTimeMilliseconds() + (duration or db.timeout)
end

local function OnSoulGemResurrectionEnd()
    reviveUntil = 0
end

local function RestoreIHSynergyrInfo()
    if ShouldHideIHSynergy() then
        SHARED_INFORMATION_AREA:SetHidden(SYNERGY, isCombatActive)
        if not isCombatActive then
            -- synergy info can be stale while hidden, so reset text and icon
            SYNERGY.action:SetText(LocalizeString("<<1>>", GetAbilityName(INSATIABLE_HUNGER_ABILITY_ID)))
            SYNERGY.icon:SetTexture(hungerIconFilename)
        end
    end
end

local function CombatIdleCheck()
    local now = GetGameTimeMilliseconds()
    local positivelyActive = IsPositivelyActive()
    if positivelyActive or wasPositivelyActive then
        lastActiveTime = now
    end
    wasPositivelyActive = positivelyActive

    local isActivating = (now - lastActiveTime) < db.timeout

    if isCombatActive ~= isActivating then
        isCombatActive = isActivating
        RestoreIHSynergyrInfo()
    end
end

local combatTrackingEnabled
local function SetIdleTrackingEnabled(enabled)
    if combatTrackingEnabled == enabled then
        return
    end
    combatTrackingEnabled = enabled
    if enabled then
        EVENT_MANAGER:RegisterForEvent(addonName, EVENT_COMBAT_EVENT, OnCombatEvent)
        EVENT_MANAGER:AddFilterForEvent(addonName, EVENT_COMBAT_EVENT,
            REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER,
            REGISTER_FILTER_IS_ERROR, false)
        EVENT_MANAGER:RegisterForEvent(addonName, EVENT_START_SOUL_GEM_RESURRECTION,
            OnSoulGemResurrectionStart)
        EVENT_MANAGER:RegisterForEvent(addonName, EVENT_END_SOUL_GEM_RESURRECTION,
            OnSoulGemResurrectionEnd)
    else
        EVENT_MANAGER:UnregisterForEvent(addonName, EVENT_COMBAT_EVENT)
        EVENT_MANAGER:UnregisterForEvent(addonName, EVENT_START_SOUL_GEM_RESURRECTION)
        EVENT_MANAGER:UnregisterForEvent(addonName, EVENT_END_SOUL_GEM_RESURRECTION)
    end
end

local function SetIHTimeout(timeout)
    db.timeout = timeout
    SetIdleTrackingEnabled(timeout > 0)
    EVENT_MANAGER:UnregisterForUpdate(addonName)
    if timeout > 0 then
        EVENT_MANAGER:RegisterForUpdate(addonName, timeout / 2, CombatIdleCheck)
    elseif isCombatActive then
        isCombatActive = false
        RestoreIHSynergyrInfo()
    end
end

local function OnCombatStateChange(_, inCombat)
    if inCombat then
        wasPositivelyActive = IsPositivelyActive()
        if wasPositivelyActive then
            lastActiveTime = GetGameTimeMilliseconds()
        end
        isCombatActive = db.timeout > 0 and (GetGameTimeMilliseconds() - lastActiveTime) < db.timeout
        RestoreIHSynergyrInfo()
        if db.timeout > 0 then
            EVENT_MANAGER:RegisterForUpdate(addonName, db.timeout / 2, CombatIdleCheck)
        end
    else
        isCombatActive = false
        reviveUntil = 0
        wasPositivelyActive = false
        lastActiveTime = 0
        EVENT_MANAGER:UnregisterForUpdate(addonName)
        RestoreIHSynergyrInfo()
    end
end

local POUNCE_ABILITY_IDS = { [32632] = true, [39104] = true, [39105] = true }
local TRANSFORM_ABILITY_IDS = { [32455] = true, [39075] = true, [39076] = true }

local function GetConfirmTimeout(slotNum)
    if db.confirmTimeout <= 0 then
        return nil
    end
    local abilityId = GetSlotBoundId(slotNum)
    if POUNCE_ABILITY_IDS[abilityId] and db.pounceConfirm then
        return db.confirmTimeout
    end
    if TRANSFORM_ABILITY_IDS[abilityId] and db.ultimateConfirm and IsPlayerInWerewolfForm() then
        return db.confirmTimeout
    end
    return nil
end

local HOLD_ICON_SIZE = 0.36
local HOLD_ICON_BOTTOM = 1.5
local HOLD_ICON_TOP = 3
local HOLD_FLASH_GOLD = { 1, 0.84, 0 }
local HOLD_STROKE_EDGES = {
    { nRight = 0, nUp = 1, dRight = 1, dUp = 0 }, 
    { nRight = 1, nUp = 0, dRight = 0, dUp = -1 }, 
    { nRight = 0, nUp = -1, dRight = -1, dUp = 0 }, 
    { nRight = -1, nUp = 0, dRight = 0, dUp = 1 }, 
}

local HOLD_FLASH_PADDING = 0.08
local HOLD_STROKE_THICKNESS = HOLD_FLASH_PADDING * 0.6
local HOLD_STROKE_SIDE = HOLD_ICON_SIZE + HOLD_FLASH_PADDING * 2
local HOLD_STROKE_OFFSET = HOLD_STROKE_SIDE / 2 - HOLD_STROKE_THICKNESS / 2
local HOLD_STROKE_START = 0.2
local WORLD_PIXELS_PER_METER = 100
local holdIndicator = {}

local function RiseProgress(elapsed, duration)
    return ZO_EaseOutQuintic(elapsed / (duration * 2))
end

local function SetWorldDimensions(control, width, height)
    control:SetDimensions(width * WORLD_PIXELS_PER_METER, height * WORLD_PIXELS_PER_METER)
end

local function AddHudFragment(control)
    local fragment = ZO_SimpleSceneFragment:New(control)
    HUD_SCENE:AddFragment(fragment)
    HUD_UI_SCENE:AddFragment(fragment)
end

local function CreateWorldCanvas(name, root)
    local canvas = WINDOW_MANAGER:CreateControl(name, root, CT_CONTROL)
    canvas:SetSpace(SPACE_WORLD)
    canvas:SetTransformNormalizedOriginPoint(0.5, 0.5)
    canvas:SetTransformScale(1 / WORLD_PIXELS_PER_METER)
    canvas:SetAnchor(CENTER, GuiRoot, CENTER)
    canvas:SetHidden(false)
    return canvas
end

local function GetCameraPitchYaw()
    local forwardX, forwardY, forwardZ = GetCameraForward(SPACE_WORLD)
    return math.atan2(forwardY, math.sqrt(forwardX * forwardX + forwardZ * forwardZ)),
        math.atan2(forwardX, forwardZ) - math.pi
end

local function PlaceWorldCanvas(canvas, worldX, worldY, worldZ, pitch, yaw)
    canvas:SetTransformOffset(WorldPositionToGuiRender3DPosition(worldX, worldY, worldZ))
    canvas:SetTransformRotation(pitch, yaw, 0)
end

local function CreateHoldTexture(name, canvas)
    local control = WINDOW_MANAGER:CreateControl(name, canvas, CT_TEXTURE)
    control:SetAnchor(CENTER, canvas, CENTER)
    control:SetTextureReleaseOption(RELEASE_TEXTURE_AT_ZERO_REFERENCES)
    control:SetHidden(true)
    return control
end

local function CreateHoldIndicator()
    local root = WINDOW_MANAGER:CreateTopLevelWindow(addonName .. "HoldIndicator")
    root:SetDrawLayer(DL_BACKGROUND)
    root:SetDrawTier(DT_LOW)
    root:SetDrawLevel(0)
    root:SetHidden(false)
    AddHudFragment(root)

    local canvas = CreateWorldCanvas(addonName .. "HoldIndicatorCanvas", root)
    SetWorldDimensions(canvas, HOLD_STROKE_SIDE, HOLD_STROKE_SIDE)
    holdIndicator.canvas = canvas

    local flash = CreateHoldTexture(addonName .. "HoldIndicatorFlash", canvas)
    flash:SetTexture("LykeionsAwareWolf/assets/blank.dds")
    SetWorldDimensions(flash, HOLD_STROKE_SIDE, HOLD_STROKE_SIDE)
    flash:SetDrawLevel(0)
    holdIndicator.flash = flash

    local stroke = {}
    for index = 1, #HOLD_STROKE_EDGES do
        local bar = CreateHoldTexture(addonName .. "HoldIndicatorStroke" .. index, canvas)
        bar:SetTexture("LykeionsAwareWolf/assets/blank.dds")
        bar:SetColor(HOLD_FLASH_GOLD[1], HOLD_FLASH_GOLD[2], HOLD_FLASH_GOLD[3], 1)
        bar:SetDrawLevel(1)
        stroke[index] = bar
    end
    holdIndicator.stroke = stroke

    local icon = CreateHoldTexture(addonName .. "HoldIndicatorIcon", canvas)
    SetWorldDimensions(icon, HOLD_ICON_SIZE, HOLD_ICON_SIZE)
    icon:SetDrawLevel(2)
    holdIndicator.icon = icon
end

local function HideHoldStroke()
    for _, segment in ipairs(holdIndicator.stroke) do
        segment:SetHidden(true)
    end
end

local function StopHoldIndicator()
    holdIndicator.startedAt = nil
    holdIndicator.retractAt = nil
    EVENT_MANAGER:UnregisterForUpdate(addonName .. "_HoldIndicator")
    if holdIndicator.icon then
        holdIndicator.icon:SetHidden(true)
    end
    if holdIndicator.stroke then
        HideHoldStroke()
    end
    if holdIndicator.flash then
        holdIndicator.flash:SetHidden(true)
    end
end

local function RetractHoldIndicator()
    local eased = RiseProgress(GetGameTimeMilliseconds() - holdIndicator.startedAt, holdIndicator.duration)
    holdIndicator.retractFromY = HOLD_ICON_BOTTOM + (HOLD_ICON_TOP - HOLD_ICON_BOTTOM) * eased
    holdIndicator.retractFromAlpha = eased
    holdIndicator.retractAt = GetGameTimeMilliseconds()
    holdIndicator.startedAt = nil
    HideHoldStroke()
end

local function PlaceHoldStroke(progress, alpha)
    local drawn = progress * #HOLD_STROKE_EDGES
    for index, edge in ipairs(HOLD_STROKE_EDGES) do
        local bar = holdIndicator.stroke[index]
        local fraction = math.max(0, math.min(1, drawn - (index - 1)))
        if fraction > 0 then
            local length = HOLD_STROKE_SIDE * fraction
            local along = length / 2 - HOLD_STROKE_SIDE / 2
            local offsetX = edge.nRight * HOLD_STROKE_OFFSET + edge.dRight * along
            local offsetY = -(edge.nUp * HOLD_STROKE_OFFSET + edge.dUp * along)
            if edge.dRight ~= 0 then
                SetWorldDimensions(bar, length, HOLD_STROKE_THICKNESS)
            else
                SetWorldDimensions(bar, HOLD_STROKE_THICKNESS, length)
            end
            bar:SetAnchorOffsets(offsetX * WORLD_PIXELS_PER_METER, offsetY * WORLD_PIXELS_PER_METER)
            bar:SetAlpha(alpha)
            bar:SetHidden(false)
        else
            bar:SetHidden(true)
        end
    end
end

local function UpdateHoldIndicator()
    local indicator = holdIndicator
    if not indicator.startedAt and not indicator.retractAt then
        StopHoldIndicator()
        return
    end

    local _, worldX, worldY, worldZ = GetUnitRawWorldPosition("player")
    if not worldX then
        StopHoldIndicator()
        return
    end

    local pitch, yaw = GetCameraPitchYaw()
    local canvas = indicator.canvas
    local icon = indicator.icon
    if indicator.retractAt then
        local progress = (GetGameTimeMilliseconds() - indicator.retractAt) / 150
        if progress >= 1 then
            StopHoldIndicator()
            return
        end
        icon:SetAlpha(indicator.retractFromAlpha * (1 - progress))
        SetWorldDimensions(icon, HOLD_ICON_SIZE, HOLD_ICON_SIZE)
        PlaceWorldCanvas(canvas, worldX, worldY + (indicator.retractFromY +
            (HOLD_ICON_BOTTOM - indicator.retractFromY) * progress) * WORLD_PIXELS_PER_METER, worldZ, pitch, yaw)
        icon:SetHidden(false)
        HideHoldStroke()
        return
    end

    local elapsed = GetGameTimeMilliseconds() - indicator.startedAt
    local duration = indicator.duration

    if elapsed < duration then
        local eased = RiseProgress(elapsed, duration)
        local height = HOLD_ICON_BOTTOM + (HOLD_ICON_TOP - HOLD_ICON_BOTTOM) * eased
        icon:SetAlpha(eased)
        SetWorldDimensions(icon, HOLD_ICON_SIZE, HOLD_ICON_SIZE)
        PlaceWorldCanvas(canvas, worldX, worldY + height * WORLD_PIXELS_PER_METER, worldZ, pitch, yaw)
        icon:SetHidden(false)

        local strokeElapsed = elapsed - duration * HOLD_STROKE_START
        PlaceHoldStroke(ZO_EaseOutQuadratic(math.max(0, strokeElapsed) / (duration * (1 - HOLD_STROKE_START))), eased)
        return
    end

    HideHoldStroke()

    if indicator.confirmWindow then
        RetractHoldIndicator()
        return
    end

    local heartbeatProgress = (elapsed - duration) / 500
    if heartbeatProgress >= 1 then
        StopHoldIndicator()
        return
    end

    icon:SetAlpha(1 - heartbeatProgress)
    local iconSize = HOLD_ICON_SIZE +
        (0.8 - HOLD_ICON_SIZE) * ZO_EaseOutQuintic(heartbeatProgress)
    local iconY = HOLD_ICON_BOTTOM + (HOLD_ICON_TOP - HOLD_ICON_BOTTOM) * RiseProgress(duration, duration)
    SetWorldDimensions(icon, iconSize, iconSize)
    PlaceWorldCanvas(canvas, worldX, worldY + iconY * WORLD_PIXELS_PER_METER, worldZ, pitch, yaw)

    local flash = indicator.flash
    local flashProgress = (elapsed - duration) / 300
    if flashProgress < 1 then
        flash:SetColor(1 + (HOLD_FLASH_GOLD[1] - 1) * flashProgress,
            1 + (HOLD_FLASH_GOLD[2] - 1) * flashProgress,
            1 + (HOLD_FLASH_GOLD[3] - 1) * flashProgress, 1 - flashProgress)
        SetWorldDimensions(flash, iconSize + HOLD_FLASH_PADDING * 2, iconSize + HOLD_FLASH_PADDING * 2)
        flash:SetHidden(false)
    else
        flash:SetHidden(true)
    end
end

local function StartHoldIndicator(iconPath, holdDuration, confirmWindow)
    if not db.holdIndicator then
        return
    end
    holdIndicator.duration = holdDuration
    holdIndicator.confirmWindow = confirmWindow or false
    holdIndicator.startedAt = GetGameTimeMilliseconds()
    holdIndicator.retractAt = nil
    holdIndicator.icon:SetTexture(iconPath)
    EVENT_MANAGER:RegisterForUpdate(addonName .. "_HoldIndicator", 16, UpdateHoldIndicator)
    UpdateHoldIndicator()
end

local function FlashHoldIndicator()
    if not holdIndicator.startedAt then
        return
    end
    holdIndicator.confirmWindow = false
    holdIndicator.startedAt = GetGameTimeMilliseconds() - holdIndicator.duration
end

local ROAR_BUFF_IDS = { 131353, 109966 }
local PROWL_BUFF_IDS = { PROWL_ABILITY_ID }
local PANEL_ICON_SIZE = 48
local PANEL_ICON_PADDING = 4
local PANEL_DECIMAL_SECONDS = 2.5
local roarPanel, prowlPanel

local function CreateBuffPanel(options)
    local panel = { buffs = {}, controls = {}, unlocked = false }

    local function IsVisible()
        return panel.unlocked or (db[options.dbKey] and (not options.condition or options.condition()))
    end

    local function UpdatePanelNumber()
        local now = GetGameTimeSeconds()
        for index, buff in ipairs(panel.buffs) do
            local control = panel.controls[index]
            local remain = buff.endTime - now
            if remain > 0 then
                if remain < PANEL_DECIMAL_SECONDS then
                    control.timer:SetText(string.format("%.1f", remain))
                else
                    control.timer:SetText(zo_ceil(remain))
                end
                control.icon:SetAlpha(1)
                control.sweep:StartCooldown(math.floor(remain * 1000), math.floor(buff.duration * 1000),
                    CD_TYPE_RADIAL, CD_TIME_TYPE_TIME_REMAINING, false)
            elseif buff.active and buff.duration <= 0 then
                control.timer:SetText("")
                control.icon:SetAlpha(1)
                control.sweep:StartCooldown(0, 1000, CD_TYPE_RADIAL, CD_TIME_TYPE_TIME_REMAINING, false)
            else
                control.timer:SetText("")
                control.icon:SetAlpha(0.5)
                control.sweep:StartCooldown(0, 1000, CD_TYPE_RADIAL, CD_TIME_TYPE_TIME_REMAINING, false)
            end
        end
    end

    local function Refresh()
        panel.fragment:Refresh()
        EVENT_MANAGER:UnregisterForUpdate(options.updateName)
        if IsVisible() then
            UpdatePanelNumber()
            EVENT_MANAGER:RegisterForUpdate(options.updateName, 100, UpdatePanelNumber)
        end
    end

    local function OnBuffChanged(_, changeType, _, _, unitTag, beginTime, endTime, _, _, _, _, _, _, _, _, abilityId)
        if unitTag ~= "player" then
            return
        end
        for _, buff in ipairs(panel.buffs) do
            if buff.abilityId == abilityId then
                if changeType == EFFECT_RESULT_FADED then
                    buff.endTime = 0
                    buff.active = false
                else
                    buff.endTime = endTime
                    buff.duration = endTime - beginTime
                    buff.active = true
                end
            end
        end
    end

    local control = WINDOW_MANAGER:CreateTopLevelWindow(addonName .. options.controlName)
    control:SetDimensions(PANEL_ICON_SIZE + PANEL_ICON_PADDING * 2,
        #options.buffIds * (PANEL_ICON_SIZE + PANEL_ICON_PADDING))
    control:SetClampedToScreen(true)
    control:SetMovable(true)
    control:SetMouseEnabled(true)
    control:SetAnchor(CENTER, GuiRoot, CENTER)
    control:SetHidden(true)
    panel.control = control

    panel.fragment = ZO_SimpleSceneFragment:New(control)
    panel.fragment:SetConditional(IsVisible)
    HUD_SCENE:AddFragment(panel.fragment)
    HUD_UI_SCENE:AddFragment(panel.fragment)

    local panelName = addonName .. options.controlName
    for index, abilityId in ipairs(options.buffIds) do
        local icon = WINDOW_MANAGER:CreateControl(panelName .. "Icon" .. index, control, CT_TEXTURE)
        icon:SetDimensions(PANEL_ICON_SIZE, PANEL_ICON_SIZE)
        icon:SetAnchor(TOPLEFT, control, TOPLEFT, PANEL_ICON_PADDING,
            PANEL_ICON_PADDING + (index - 1) * (PANEL_ICON_SIZE + PANEL_ICON_PADDING))
        icon:SetTexture(GetAbilityIcon(abilityId))

        local sweep = WINDOW_MANAGER:CreateControl(panelName .. "Sweep" .. index, control, CT_COOLDOWN)
        sweep:SetAnchorFill(icon)
        sweep:SetFillColor(0, 0, 0, 0.6)

        local timer = WINDOW_MANAGER:CreateControl(panelName .. "Timer" .. index, control, CT_LABEL)
        timer:SetFont("$(BOLD_FONT)|" .. 20 .. "|thick-outline")
        timer:SetDimensions(PANEL_ICON_SIZE, PANEL_ICON_SIZE)
        timer:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        timer:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        timer:SetAnchor(CENTER, icon, CENTER, 0, 6)

        panel.controls[index] = { icon = icon, sweep = sweep, timer = timer }
        table.insert(panel.buffs, { abilityId = abilityId, endTime = 0, duration = 0, active = false })

        local eventName = panelName .. "Buff" .. abilityId
        EVENT_MANAGER:RegisterForEvent(eventName, EVENT_EFFECT_CHANGED, OnBuffChanged)
        EVENT_MANAGER:AddFilterForEvent(eventName, EVENT_EFFECT_CHANGED, REGISTER_FILTER_ABILITY_ID, abilityId)
    end

    if LibCombatAlerts and LibCombatAlerts.MoveableControl then
        local handler = LibCombatAlerts.MoveableControl:New(control)
        panel.moveHandler = handler
        if db[options.positionKey .. "Position"] then
            handler:UpdatePosition(db[options.positionKey .. "Position"])
        end
        handler:SetSnap(20)
        handler:RegisterCallback(addonName, LibCombatAlerts.EVENT_CONTROL_MOVE_STOP, function(position)
            db[options.positionKey .. "Position"] = position
        end)
    else
        control:SetHandler("OnMoveStop", function(self)
            db[options.positionKey .. "Left"], db[options.positionKey .. "Top"] = self:GetLeft(), self:GetTop()
        end)
    end

    panel.refresh = Refresh
    panel.setUnlocked = function(unlocked)
        panel.unlocked = unlocked
        if panel.moveHandler then
            panel.moveHandler:ToggleGamepadMove(unlocked and ZO_IsConsoleOrGameCoreUI())
        end
        Refresh()
    end

    return panel
end

local CLAW_EDGE_TEXTURE = "esoui/art/miscellaneous/listitem_divider.dds"
local CLAW_EDGE_HEIGHT = 0.15
local CLAW_FADE_IN_MS = 180
local CLAW_FADE_OUT_MS = 180
local CLAW_FURY_MAX_DURATION_MS = 4666
local CLAW_MORPH_DURATION_MS = 1500
local clawSector = { edges = {}, active = false, startedAt = 0, expiresAt = 0 }

local function GetClampValue(value)
    return math.max(0, math.min(1, value))
end

local function CreateClawSector()
    local root = WINDOW_MANAGER:CreateTopLevelWindow(addonName .. "ClawSector")
    root:SetDrawLayer(DL_BACKGROUND)
    root:SetDrawTier(DT_LOW)
    root:SetDrawLevel(0)
    root:SetHidden(false)
    AddHudFragment(root)
    clawSector.control = root

    for edge = 1, 2 do
        local canvas = CreateWorldCanvas(addonName .. "ClawEdge" .. edge, root)
        canvas:SetDimensions(WORLD_PIXELS_PER_METER, WORLD_PIXELS_PER_METER)

        local bar = WINDOW_MANAGER:CreateControl(addonName .. "ClawEdgeTexture" .. edge, canvas, CT_TEXTURE)
        bar:SetAnchor(CENTER, canvas, CENTER)
        bar:SetTexture(CLAW_EDGE_TEXTURE)
        bar:SetColor(1, 1, 1, 1)
        bar:SetTextureReleaseOption(RELEASE_TEXTURE_AT_ZERO_REFERENCES)
        bar:SetHidden(true)

        clawSector.edges[edge] = { canvas = canvas, bar = bar }
    end
end


local function StopClawSector()
    clawSector.active = false
    clawSector.expiresAt = 0
    EVENT_MANAGER:UnregisterForUpdate(addonName .. "_ClawSector")
    for _, edge in ipairs(clawSector.edges) do
        edge.bar:SetHidden(true)
    end
end

local function UpdateClawSector()
    local now = GetGameTimeMilliseconds()
    local remaining = clawSector.expiresAt - now
    if remaining <= 0 then
        StopClawSector()
        return
    end

    local _, worldX, worldY, worldZ = GetUnitRawWorldPosition("player")
    if not worldX then
        StopClawSector()
        return
    end

    local fadeIn = GetClampValue((now - clawSector.startedAt) / CLAW_FADE_IN_MS)
    local fadeOut = GetClampValue((CLAW_FADE_OUT_MS - remaining) / CLAW_FADE_OUT_MS)
    local alpha = fadeIn * (1 - fadeOut)
    local heading = GetPlayerCameraHeading() + math.pi
    local halfAngle = math.rad(90) / 2
    local length = 10
    local distance = length / 2

    for edge = 1, 2 do
        local angle = (edge == 1) and (heading + halfAngle) or (heading - halfAngle)
        local controls = clawSector.edges[edge]

        if alpha > 0.002 then
            PlaceWorldCanvas(controls.canvas,
                worldX + math.sin(angle) * distance * WORLD_PIXELS_PER_METER,
                worldY + CLAW_EDGE_HEIGHT * WORLD_PIXELS_PER_METER,
                worldZ + math.cos(angle) * distance * WORLD_PIXELS_PER_METER,
                -math.pi / 2, angle - math.pi / 2)
            SetWorldDimensions(controls.bar, length, 0.5)
            controls.bar:SetAlpha(alpha)
            controls.bar:SetHidden(false)
        else
            controls.bar:SetHidden(true)
        end
    end
end

local function StartClawSector(durationMs)
    if not db.clawFuryRange then
        return
    end
    local now = GetGameTimeMilliseconds()
    if not clawSector.active then
        clawSector.active = true
        clawSector.startedAt = now
    end
    clawSector.expiresAt = now + durationMs
    EVENT_MANAGER:RegisterForUpdate(addonName .. "_ClawSector", 12, UpdateClawSector)
    UpdateClawSector()
end

local function OnSlotAbilityUsed(_, slotIndex)
    local abilityId = GetSlotBoundId(slotIndex)
    if abilityId == CLAW_FURY_ABILITY_ID then
        StartClawSector(CLAW_FURY_MAX_DURATION_MS)
    elseif abilityId == RENDING_CLAWS_ABILITY_ID or abilityId == BLOODCLAWS_ABILITY_ID then
        StartClawSector(CLAW_MORPH_DURATION_MS)
    end
end

local function OnClawFuryEffect(_, changeType, _, _, unitTag, beginTime, endTime)
    if unitTag ~= "player" then
        return
    end
    if changeType == EFFECT_RESULT_FADED then
        if clawSector.active then
            clawSector.expiresAt = math.min(clawSector.expiresAt, GetGameTimeMilliseconds() + CLAW_FADE_OUT_MS)
        end
        return
    end
    if endTime * 1000 <= GetGameTimeMilliseconds() then
        return
    end
    if not clawSector.active then
        StartClawSector(CLAW_FURY_MAX_DURATION_MS)
    end
    if clawSector.active then
        clawSector.startedAt = math.min(clawSector.startedAt, beginTime * 1000)
        clawSector.expiresAt = endTime * 1000
    end
end

local clawRangeTrackingEnabled
local function SetClawRangeTrackingEnabled(enabled)
    if clawRangeTrackingEnabled == enabled then
        return
    end
    clawRangeTrackingEnabled = enabled
    if enabled then
        EVENT_MANAGER:RegisterForEvent(addonName, EVENT_ACTION_SLOT_ABILITY_USED, OnSlotAbilityUsed)
        EVENT_MANAGER:RegisterForEvent(addonName, EVENT_EFFECT_CHANGED, OnClawFuryEffect)
        EVENT_MANAGER:AddFilterForEvent(addonName, EVENT_EFFECT_CHANGED, REGISTER_FILTER_ABILITY_ID, CLAW_FURY_ABILITY_ID)
    else
        EVENT_MANAGER:UnregisterForEvent(addonName, EVENT_ACTION_SLOT_ABILITY_USED)
        EVENT_MANAGER:UnregisterForEvent(addonName, EVENT_EFFECT_CHANGED)
    end
end

local function OnPlayerInit()
    EVENT_MANAGER:UnregisterForEvent(addonName, EVENT_PLAYER_ACTIVATED)

    if db.feedingpriority then
        SetSynergyPriorityOverride(FEEDING_FREEZY_ABILITY_ID, 4)
    end
    EVENT_MANAGER:RegisterForEvent(addonName, EVENT_PLAYER_COMBAT_STATE, OnCombatStateChange)
    SetIdleTrackingEnabled(db.timeout > 0)

    ZO_PreHook(SYNERGY, "OnSynergyAbilityChanged", function()
        if ShouldHideIHSynergy() and isCombatActive then
            SHARED_INFORMATION_AREA:SetHidden(SYNERGY, true)
            return true
        end
    end)

    CreateHoldIndicator()
    roarPanel = CreateBuffPanel({
        controlName = "RoarPanel",
        dbKey = "roarPanel",
        updateName = addonName .. "_RoarPanel",
        positionKey = "roarPanel",
        buffIds = ROAR_BUFF_IDS,
        condition = IsPlayerInWerewolfForm,
    })
    prowlPanel = CreateBuffPanel({
        controlName = "ProwlPanel",
        dbKey = "prowlPanel",
        updateName = addonName .. "_ProwlPanel",
        positionKey = "prowlPanel",
        buffIds = PROWL_BUFF_IDS,
        condition = IsPlayerInWerewolfForm,
    })
    CreateClawSector()

    SetClawRangeTrackingEnabled(db.clawFuryRange)

    -- this part of implement is based on the best practices used in NoAccidentalStealing by Shinni
    ZO_PreHook("ZO_ActionBar_OnActionButtonDown", function(slotNum)
        slotPressTime[slotNum] = GetGameTimeMilliseconds()
        local confirmTimeout = GetConfirmTimeout(slotNum)
        if confirmTimeout then
            StartHoldIndicator(GetAbilityIcon(GetSlotBoundId(slotNum)), confirmTimeout)
        end
    end)

    ZO_PreHook("ZO_ActionBar_OnActionButtonUp", function(slotNum)
        slotPressTime[slotNum] = nil
        if holdIndicator.startedAt and
            GetGameTimeMilliseconds() - holdIndicator.startedAt < holdIndicator.duration then
            RetractHoldIndicator()
        end
    end)

    ZO_PreHook("ZO_ActionBar_CanUseActionSlots", function()
        if (not db.pounceConfirm and not db.ultimateConfirm) then return end
        local trace = debug.traceback()
        local slotNum = tonumber(trace:match("ACTION_BUTTON_(%d)"))
        if not slotNum then return end
        local confirmTimeout = GetConfirmTimeout(slotNum)
        if not confirmTimeout then return end
        local now = GetGameTimeMilliseconds()

        if trace:find("GAMEPAD_ACTION_BUTTON_") then
            local lastPress = slotConfirmTime[slotNum]
            if lastPress and now - lastPress <= confirmTimeout then
                slotConfirmTime[slotNum] = nil
                FlashHoldIndicator()
                return
            end
            slotConfirmTime[slotNum] = now
            StartHoldIndicator(GetAbilityIcon(GetSlotBoundId(slotNum)), confirmTimeout, true)
            return true
        end

        local pressTime = slotPressTime[slotNum]
        if not pressTime or now - pressTime > confirmTimeout then return end
        ZO_Alert(UI_ALERT_CATEGORY_ERROR, SOUNDS.NEGATIVE_CLICK, SI_RESPECRESULT10)
        ZO_ActionBar_OnActionButtonUp(slotNum)
        return true
    end)

    EVENT_MANAGER:RegisterForEvent(addonName, EVENT_WEREWOLF_STATE_CHANGED, function()
        roarPanel.refresh()
        prowlPanel.refresh()
    end)

    roarPanel.refresh()
    prowlPanel.refresh()
end

local function GetPlatformText(pcText, gamepadText)
    return IsInGamepadPreferredMode() and gamepadText or pcText
end

local function CreateMenu()
    local panelData = {
        type = "panel",
        name = "Lykeion's Aware Wolf",
        displayName = "|c2e5c8cL|r|c365f87y|r|c3f6282k|r|c47657de|r|c4f6778i|r|c586a74o|r|c606d6fn|r|c68706a'|r|c717365s|r|c797660 |r|c81785bA|r|c897b56w|r|c927e51a|r|c9a814cr|r|ca28447e|r|cab8743 |r|cb3893eW|r|cbb8c39o|r|cc48f34l|r|ccc922ff|r",
        author = "|c215895Lykeion|r",
        version = "|ccc922f2.3|r",
        slashCommand = "/law",
        registerForRefresh = true,
        registerForDefaults = true,
    }

    local optionsData = {
        {
            type = "description",
            text = "|c999999" .. GetString(LAW_MENU_DESCRIPTION) .. "|r",
        },
        {
            type = "checkbox",
            name = LocalizeAbilityString(LAW_CONFIRM_POUNCE, GetAbilityName(POUNCE_ABILITY_ID)),
            tooltip = LocalizeAbilityString(LAW_CONFIRM_POUNCE_TOOLTIP, GetAbilityName(POUNCE_ABILITY_ID),
                GetAbilityName(CARNAGE_ABILITY_ID)),
            default = defaults.pounceConfirm,
            getFunc = function()
                return db.pounceConfirm
            end,
            setFunc = function(value)
                db.pounceConfirm = value
            end,
        },
        {
            type = "checkbox",
            name = LocalizeAbilityString(LAW_CONFIRM_ULTIMATE, GetAbilityName(TRANSFORM_ABILITY_ID)),
            tooltip = LocalizeAbilityString(LAW_CONFIRM_ULTIMATE_TOOLTIP, GetAbilityName(TRANSFORM_ABILITY_ID),
                GetAbilityName(RAMPAGE_ABILITY_ID)),
            default = defaults.ultimateConfirm,
            getFunc = function()
                return db.ultimateConfirm
            end,
            setFunc = function(value)
                db.ultimateConfirm = value
            end,
        },
        {
            type = "slider",
            name = GetString(LAW_CONFIRM_TIMEOUT),
            tooltip = GetString(LAW_CONFIRM_TIMEOUT_TOOLTIP),
            min = 100,
            max = 900,
            step = 100,
            default = defaults.confirmTimeout,
            getFunc = function()
                return db.confirmTimeout
            end,
            setFunc = function(value)
                db.confirmTimeout = value
            end,
        },
        {
            type = "checkbox",
            name = GetString(LAW_POUNCE_INDICATOR),
            tooltip = GetString(LAW_POUNCE_INDICATOR_TOOLTIP),
            default = defaults.holdIndicator,
            disabled = function()
                return db.confirmTimeout == 0 or (not db.pounceConfirm and not db.ultimateConfirm)
            end,
            getFunc = function()
                return db.holdIndicator
            end,
            setFunc = function(value)
                db.holdIndicator = value
            end,
        },
        {
            type = "checkbox",
            name = LocalizeAbilityString(LAW_ROAR_PANEL, GetAbilityName(ROAR_ABILITY_ID)),
            tooltip = GetPlatformText(
                LocalizeAbilityString(LAW_ROAR_PANEL_TOOLTIP, GetAbilityName(FEEDING_FRENZY_ABILITY_ID), GetAbilityName(MAJOR_COURAGE_ABILITY_ID)),
                LocalizeAbilityString(LAW_ROAR_PANEL_TOOLTIP_GAMEPAD, GetAbilityName(FEEDING_FRENZY_ABILITY_ID), GetAbilityName(MAJOR_COURAGE_ABILITY_ID))),
            default = defaults.roarPanel,
            getFunc = function()
                return db.roarPanel
            end,
            setFunc = function(value)
                db.roarPanel = value
                roarPanel.refresh()
            end,
        },
        {
            type = "checkbox",
            name = LocalizeAbilityString(LAW_CLAW_FURY_RANGE, GetAbilityName(RENDING_CLAWS_ABILITY_ID)),
            tooltip = LocalizeAbilityString(LAW_CLAW_FURY_RANGE_TOOLTIP, GetAbilityName(RENDING_CLAWS_ABILITY_ID)),
            default = defaults.clawFuryRange,
            getFunc = function()
                return db.clawFuryRange
            end,
            setFunc = function(value)
                db.clawFuryRange = value
                SetClawRangeTrackingEnabled(value)
                if not value then
                    StopClawSector()
                end
            end,
        },
        {
            type = "slider",
            name = LocalizeAbilityString(LAW_TIMEOUT, GetAbilityName(INSATIABLE_HUNGER_ABILITY_ID)),
            tooltip = LocalizeAbilityString(LAW_TIMEOUT_TOOLTIP, GetAbilityName(INSATIABLE_HUNGER_ABILITY_ID)),
            min = 0,
            max = 3000,
            step = 500,
            default = defaults.timeout,
            getFunc = function()
                return db.timeout
            end,
            setFunc = function(value)
                SetIHTimeout(value)
            end,
        },
        {
            type = "checkbox",
            name = LocalizeAbilityString(LAW_FEEDING_PRIORITY, GetAbilityName(FEEDING_FRENZY_ABILITY_ID)),
            tooltip = LocalizeAbilityString(LAW_FEEDING_PRIORITY_TOOLTIP, GetAbilityName(FEEDING_FRENZY_ABILITY_ID)),
            default = defaults.feedingpriority,
            getFunc = function()
                return db.feedingpriority
            end,
            setFunc = function(value)
                db.feedingpriority = value
                if value then
                    SetSynergyPriorityOverride(FEEDING_FREEZY_ABILITY_ID, 4)
                else
                    ClearSynergyPriorityOverride(FEEDING_FREEZY_ABILITY_ID)
                end
            end,
        },
                {
            type = "checkbox",
            name = LocalizeAbilityString(LAW_PROWL_PANEL, GetAbilityName(PROWL_ABILITY_ID)),
            tooltip = GetPlatformText(
                LocalizeAbilityString(LAW_PROWL_PANEL_TOOLTIP, GetAbilityName(PROWL_ABILITY_ID)),
                LocalizeAbilityString(LAW_PROWL_PANEL_TOOLTIP_GAMEPAD, GetAbilityName(PROWL_ABILITY_ID))),
            default = defaults.prowlPanel,
            getFunc = function()
                return db.prowlPanel
            end,
            setFunc = function(value)
                db.prowlPanel = value
                prowlPanel.refresh()
            end,
        },
    }

    local panelControl = LibAddonMenu2:RegisterAddonPanel(addonName .. "Options", panelData)
    LibAddonMenu2:RegisterOptionControls(addonName .. "Options", optionsData)

    CALLBACK_MANAGER:RegisterCallback("LAM-PanelClosed", function(panel)
        if panel == panelControl then
            roarPanel.setUnlocked(false)
            prowlPanel.setUnlocked(false)
        end
    end)
end

local function OnLoaded(_, name)
    if name ~= addonName then return end
    EVENT_MANAGER:UnregisterForEvent(addonName, EVENT_ADD_ON_LOADED)
    EVENT_MANAGER:RegisterForEvent(addonName, EVENT_PLAYER_ACTIVATED, OnPlayerInit)

    local worldName = GetWorldName()
    db = ZO_SavedVars:NewAccountWide(SV_NAME, 1, nil, defaults, worldName)
    CreateMenu()

    if ZO_IsConsoleOrGameCoreUI() then
        local function AddPanelMoveCommand(slash, panel)
            SLASH_COMMANDS[slash] = function()
                panel.setUnlocked(not panel.unlocked)
                CHAT_ROUTER:AddSystemMessage(string.format(GetString(LAW_PANEL_MOVE_MSG),
                    GetString(panel.unlocked and LAW_ENABLED or LAW_DISABLED)))
            end
        end
        AddPanelMoveCommand("/awroar", roarPanel)
        AddPanelMoveCommand("/awprowl", prowlPanel)
    end
end

EVENT_MANAGER:RegisterForEvent(addonName, EVENT_ADD_ON_LOADED, OnLoaded)
