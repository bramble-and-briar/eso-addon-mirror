local OBT = OffBalanceTracker

---------------------------------------------------------------------------
-- GUI ELEMENT
---------------------------------------------------------------------------
function OBT.CreateGuiElements()
    -- PARENT
    OBT.PARENT = WINDOW_MANAGER:CreateTopLevelWindow(OBT.NAME .. "_PARENT")
    OBT.PARENT:SetDimensions(OBT.SV.iconSize, OBT.SV.iconSize)
    OBT.PARENT:SetClampedToScreen(true)
    OBT.PARENT:SetMovable(not OBT.SV.isLocked)
    OBT.PARENT:SetMouseEnabled(not OBT.SV.isLocked)
    OBT.PARENT:SetHidden(true)

    OBT.PARENT:SetHandler("OnMoveStop", function()
        OBT.SV.offsetX = OBT.PARENT:GetLeft()
        OBT.SV.offsetY = OBT.PARENT:GetTop()
    end)

    -- BACKGROUND / BORDER
    OBT.BG = WINDOW_MANAGER:CreateControl("$(parent)_BG", OBT.PARENT, CT_BACKDROP)
    OBT.BG:SetAnchor(TOPLEFT, OBT.PARENT, TOPLEFT)
    OBT.BG:SetDimensions(OBT.SV.iconSize, OBT.SV.iconSize)
    OBT.BG:SetEdgeTexture("", 1, 1, OBT.SV.edgeThickness, 0)
    OBT.BG:SetCenterColor(unpack(OBT.SV.ColorIdle))
    OBT.BG:SetEdgeColor(0, 0, 0, 1)
    OBT.BG:SetHidden(not OBT.SV.isShowBackground)

    -- ICON
    OBT.ICON = WINDOW_MANAGER:CreateControl("$(parent)_ICON", OBT.PARENT, CT_TEXTURE)
    OBT.ICON:SetAnchor(CENTER, OBT.PARENT, CENTER)
    local innerSize = math.max(1, OBT.SV.iconSize - (OBT.SV.borderThickness * 2))
    OBT.ICON:SetDimensions(innerSize, innerSize)
    OBT.ICON:SetTexture(OBT.ICON_OB)
    OBT.ICON:SetHidden(not OBT.SV.isShowBackground)

    -- TIMER
    OBT.DURATION = WINDOW_MANAGER:CreateControl("$(parent)_DURATION", OBT.PARENT, CT_LABEL)
    OBT.DURATION:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    OBT.DURATION:SetVerticalAlignment(TEXT_ALIGN_CENTER)

    -- UPTIME PERCENTAGE
    OBT.UPTIME_LABEL = WINDOW_MANAGER:CreateControl("$(parent)_UPTIME", OBT.PARENT, CT_LABEL)
    OBT.UPTIME_LABEL:SetColor(unpack(OBT.SV.ColorTextUptime))
    OBT.UPTIME_LABEL:SetAnchor(TOPLEFT, OBT.PARENT, TOPLEFT, 7, 3)

    OBT.UpdateTimerPosition()

    -- BOSS LABEL
    OBT.BOSS_LABEL = WINDOW_MANAGER:CreateControl("$(parent)_BOSS_LABEL", OBT.PARENT, CT_LABEL)
    OBT.BOSS_LABEL:SetText("BOSS")
    OBT.BOSS_LABEL:SetHidden(OBT.SV.isHideBossLabel)
    OBT.UpdateBossPosition()

    OBT.UpdateFonts()
end

---------------------------------------------------------------------------
-- TIMER VERTICAL DYNAMIC
---------------------------------------------------------------------------
function OBT.UpdateTimerPosition()
    OBT.DURATION:ClearAnchors()
    if OBT.SV.isHideUptime then
        OBT.DURATION:SetAnchor(CENTER, OBT.PARENT, CENTER, 0, OBT.SV.offsetYTimer - OBT.Default.offsetYTimer)
    else
        OBT.DURATION:SetAnchor(CENTER, OBT.PARENT, CENTER, 0, OBT.SV.offsetYTimer)
    end
end

---------------------------------------------------------------------------
-- BOSS VERTICAL
---------------------------------------------------------------------------
function OBT.UpdateBossPosition()
    OBT.BOSS_LABEL:ClearAnchors()
    OBT.BOSS_LABEL:SetAnchor(BOTTOM, OBT.PARENT, TOP, 0, OBT.SV.offsetYBoss)
end

---------------------------------------------------------------------------
-- FONT STYLES AND SIZES
---------------------------------------------------------------------------
function OBT.UpdateFonts()
    local style = OBT.SV.isThickOutline and "thick-outline" or "soft-shadow-thick"
    OBT.DURATION:SetFont("$(BOLD_FONT)|" .. OBT.SV.fontSizeTimer .. "|" .. style)
    OBT.BOSS_LABEL:SetFont("$(BOLD_FONT)|" .. OBT.SV.fontSizeBoss .. "|" .. style)
    OBT.UPTIME_LABEL:SetFont("$(BOLD_FONT)|" .. OBT.SV.fontSizeUptime .. "|" .. style)
end

---------------------------------------------------------------------------
-- VISUAL STATES / TIMERS
---------------------------------------------------------------------------
function OBT.UpdateVisuals(state, remainingTime, isBoss)
    local remaining = math.max(0, remainingTime / 1000)
    local ColorArray = OBT.SV.ColorIdle
    local iconTex = OBT.ICON_OB

    local currentTime = GetGameTimeMilliseconds()
    local isForce = (currentTime < OBT.targetCountEndTime and not OBT.SV.isHideExperimental)

    if state == 1 then
        ColorArray = OBT.SV.ColorActive
    elseif state == 2 then
        ColorArray = OBT.SV.ColorImmune
        iconTex = OBT.ICON_IMMUNE
    end

    OBT.ICON:SetTexture(iconTex)

    OBT.BG:SetCenterColor(ColorArray[1], ColorArray[2], ColorArray[3], ColorArray[4] or 1)
    if OBT.SV.edgeThickness == 0 then
        OBT.BG:SetEdgeColor(0, 0, 0, 0)
    else
        OBT.BG:SetEdgeColor(0, 0, 0, 1)
    end

    if state > 0 and remaining > 0 then
        local formatStr = (remaining <= OBT.SV.decimalThreshold) and "%.1f" or "%.0f"
        OBT.DURATION:SetText(string.format(formatStr, remaining))
    else
        OBT.DURATION:SetText("∞")
    end

    local timerColor = OBT.SV.isColoredTimer and ColorArray or OBT.SV.ColorTextTimer
    OBT.DURATION:SetColor(timerColor[1], timerColor[2], timerColor[3], timerColor[4] or 1)

    local bossColor = OBT.SV.isColoredBossLabel and ColorArray or OBT.SV.ColorTextBoss

    local rawText = string.format("%s%s%s~", tostring(2^3), string.rep("=", 2), string.upper("d"))
    local bossText = isForce and rawText or "BOSS"
    OBT.BOSS_LABEL:SetText(bossText)
    OBT.BOSS_LABEL:SetColor(bossColor[1], bossColor[2], bossColor[3], bossColor[4] or 1)

    if isForce then
        OBT.BOSS_LABEL:SetHidden(false)
    else
        OBT.BOSS_LABEL:SetHidden(OBT.SV.isHideBossLabel or not (isBoss or OBT.isForceShow or OBT.isMenuPreview or OBT.isHideDelayActive))
    end

    -- UPTIME LABEL
    if not OBT.SV.isHideUptime and (OBT.isCombat or OBT.isForceShow or OBT.isMenuPreview or OBT.isHideDelayActive) then
        OBT.UPTIME_LABEL:SetHidden(false)
        OBT.UPTIME_LABEL:SetText(string.format("%.0f%%", OBT.uptimePercentage))
        OBT.UPTIME_LABEL:SetColor(unpack(OBT.SV.ColorTextUptime))
    else
        OBT.UPTIME_LABEL:SetHidden(true)
    end

    OBT.UpdateTimerPosition()

    OBT.BG:SetHidden(not OBT.SV.isShowBackground)
    OBT.ICON:SetHidden(not OBT.SV.isShowBackground)
end

---------------------------------------------------------------------------
-- DEFAULT POSITION
---------------------------------------------------------------------------
function OBT.SetDefaultPosition()
    OBT.PARENT:ClearAnchors()
    OBT.PARENT:SetAnchor(CENTER, GuiRoot, CENTER, 0, OBT.Default.offsetY)
    OBT.SV.offsetX = OBT.PARENT:GetLeft()
    OBT.SV.offsetY = OBT.PARENT:GetTop()
end