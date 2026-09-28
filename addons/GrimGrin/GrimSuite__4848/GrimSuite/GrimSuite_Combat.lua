local GS = GrimSuite
GS.Combat = GS.Combat or {}
local Combat = GS.Combat
local WM = WINDOW_MANAGER
local EM = EVENT_MANAGER

---------------------------------------------------------------------
-- GrimSuite Combat
--
-- Scope for v1.3.0:
--   * Simple GCD metronome
--   * Simplified WeaveDelays
--
-- Deliberately NOT porting:
--   * Combat Metronome resource display
--   * Stack Tracker
--   * Full Light Attack Tracker
--   * CM collectibles/items/synergies
--   * WeaveDelays skill images
---------------------------------------------------------------------

local FONT = "EsoUI/Common/Fonts/Univers57.slug|16|soft-shadow-thick"
local SMALL_FONT = "EsoUI/Common/Fonts/Univers57.slug|14|soft-shadow-thick"
local BORDER = { 0.65, 0.65, 0.65, 0.75 }
local DARK_BORDER = { 0.02, 0.02, 0.02, 0.95 }

Combat.gcdEnd = 0
Combat.gcdStart = 0
Combat.gcdDuration = 1000
Combat.inCombat = false
Combat.layoutUnlocked = false
Combat.hudVisible = true
Combat.settingsPreviewVisible = false

Combat.weave = {
    actions = {},
    max = 10,
    pendingLA = nil,
    previousSkillEnd = nil,
    averageSum = 0,
    averageCount = 0,
    averagePending = {},
    averageMax = 150,
    laTimeout = 1000,
    laGraceMs = 75,
    lastLAConfirmed = nil,
    previousSkillAt = nil,
}

local function MakeBackdrop(name, parent)
    local c = WM:CreateControl(name, parent, CT_BACKDROP)
    c:SetCenterColor(1, 1, 1, 1)
    c:SetEdgeColor(1, 1, 1, 0)
    return c
end

local function SetCleanBorder(control, r, g, b, a)
    if not control then return end
    control:SetEdgeColor(r or BORDER[1], g or BORDER[2], b or BORDER[3], a or BORDER[4])
end

---------------------------------------------------------------------
-- Layout helpers
---------------------------------------------------------------------

local function CenterControl(control, horizontal, vertical, xKey, yKey)
    if not control then return end
    local screenW = GuiRoot:GetWidth()
    local screenH = GuiRoot:GetHeight()

    if horizontal then
        GS.Saved[xKey] = math.floor((screenW - control:GetWidth()) * 0.5 + 0.5)
    end
    if vertical then
        GS.Saved[yKey] = math.floor((screenH - control:GetHeight()) * 0.5 + 0.5)
    end

    Combat:ApplyLayout()
end

local combatDragState = {
    control = nil,
    dragging = false,
    startMouseX = 0,
    startMouseY = 0,
    startLeft = 0,
    startTop = 0,
    onStop = nil,
}

local function UpdateCombatMouseDrag()
    if not combatDragState.dragging or not combatDragState.control then
        return
    end

    if not Combat.layoutUnlocked then
        combatDragState.dragging = false
        combatDragState.control = nil
        combatDragState.onStop = nil
        return
    end

    local x, y = GetUIMousePosition()
    if not x or not y then return end

    local control = combatDragState.control
    local left = combatDragState.startLeft + (x - combatDragState.startMouseX)
    local top = combatDragState.startTop + (y - combatDragState.startMouseY)

    control:ClearAnchors()
    control:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, left, top)
end

local function EnableMouseDrag(control, isUnlocked, onStop)
    if not control then return end

    -- GrimSuite uses LEFT-click drag for every movable control.  Keep native
    -- ESO dragging disabled so there is no right-click movement fallback.
    control:SetMouseEnabled(isUnlocked == true)
    control:SetMovable(false)
    control:SetClampedToScreen(true)

    control:SetHandler("OnMouseDown", function(c, button)
        if button ~= MOUSE_BUTTON_INDEX_LEFT or not Combat.layoutUnlocked then
            return
        end

        local x, y = GetUIMousePosition()
        if not x or not y then return end

        combatDragState.control = c
        combatDragState.dragging = true
        combatDragState.startMouseX = x
        combatDragState.startMouseY = y
        combatDragState.startLeft = c:GetLeft() or 0
        combatDragState.startTop = c:GetTop() or 0
        combatDragState.onStop = onStop
    end)

    control:SetHandler("OnMouseUp", function(c, button)
        if button ~= MOUSE_BUTTON_INDEX_LEFT then
            return
        end

        if combatDragState.control ~= c then
            return
        end

        combatDragState.dragging = false
        combatDragState.control = nil

        local callback = combatDragState.onStop
        combatDragState.onStop = nil
        if callback then
            callback(c)
        end
    end)

    EM:UnregisterForUpdate(GS.name .. "_CombatMouseDrag")
    EM:RegisterForUpdate(GS.name .. "_CombatMouseDrag", 16, UpdateCombatMouseDrag)
end

local function DisableAttributeChildMouse(control)
    if not control then return end
    control:SetMouseEnabled(false)
    local childCount = control.GetNumChildren and control:GetNumChildren() or 0
    for i = 1, childCount do
        local child = control:GetChild(i)
        if child then
            DisableAttributeChildMouse(child)
        end
    end
end

local function EnableAttributeDrag(control, isUnlocked, onStop)
    EnableMouseDrag(control, isUnlocked, onStop)
end

local function SaveGCDPosition(control)
    GS.Saved.gcdX = math.floor((control:GetLeft() or GS.Saved.gcdX) + 0.5)
    GS.Saved.gcdY = math.floor((control:GetTop() or GS.Saved.gcdY) + 0.5)
end

local function SaveWeavePosition(control)
    GS.Saved.weaveX = math.floor((control:GetLeft() or GS.Saved.weaveX) + 0.5)
    GS.Saved.weaveY = math.floor((control:GetTop() or GS.Saved.weaveY) + 0.5)
end

local function SaveAveragePosition(control)
    if not Combat.weaveFrame then return end
    GS.Saved.weaveAverageX = math.floor((control:GetLeft() - Combat.weaveFrame:GetLeft()) + 0.5)
    GS.Saved.weaveAverageY = math.floor((control:GetTop() - Combat.weaveFrame:GetTop()) + 0.5)
    Combat:ApplyLayout()
end

local function SaveAttributesPosition(control)
    local centerX = GuiRoot:GetWidth() * 0.5
    local centerY = GuiRoot:GetHeight() * 0.5
    local cX, cY = control:GetCenter()
    if not cX or not cY then return end
    GS.Saved.attributesX = math.floor((cX - centerX) + 0.5)
    GS.Saved.attributesY = math.floor((cY - centerY) + 0.5)
    Combat:ApplyLayout()
end

local function MakeMouseTransparent(control)
    if control and control.SetMouseEnabled then
        control:SetMouseEnabled(false)
    end
end

local function SetLayoutUnlocked(enabled)
    Combat.layoutUnlocked = enabled == true

    if not Combat.layoutUnlocked then
        combatDragState.dragging = false
        combatDragState.control = nil
        combatDragState.onStop = nil
    end

    EnableMouseDrag(Combat.gcdFrame, Combat.layoutUnlocked, SaveGCDPosition)
    EnableMouseDrag(Combat.weaveFrame, Combat.layoutUnlocked, SaveWeavePosition)
    EnableAttributeDrag(GetControl("GrimSuiteAttributes"), Combat.layoutUnlocked, SaveAttributesPosition)

    if Combat.weaveAverageFrame then
        EnableMouseDrag(Combat.weaveAverageFrame, Combat.layoutUnlocked, SaveAveragePosition)
        Combat.weaveAverageFrame:SetHidden(not Combat.layoutUnlocked)
    end
end

local function HideNativeAttributeBars()
    ZO_PlayerAttributeHealth:SetHidden(true)
    ZO_PlayerAttributeMagicka:SetHidden(true)
    ZO_PlayerAttributeStamina:SetHidden(true)
end

-- ESO can rebuild/reconfigure HUD controls when scenes change (entering a
-- house is a good example).  GrimSuite's combat widgets are deliberately
-- absolute GuiRoot-positioned controls, so scene changes should never be
-- allowed to leave them at a transient scene position.  Re-apply the saved
-- coordinates after the scene transition has finished.
local function ScheduleLayoutRepair()
    if not Combat.initialized then return end

    EM:UnregisterForUpdate(GS.name .. "_CombatLayoutRepair")
    EM:RegisterForUpdate(GS.name .. "_CombatLayoutRepair", 16, function()
        EM:UnregisterForUpdate(GS.name .. "_CombatLayoutRepair")
        Combat:ApplyLayout()

        -- Some HUD fragments finish their own anchoring one frame later.
        -- Give ESO a little time to finish, then assert our saved layout again.
        zo_callLater(function()
            if Combat.initialized then
                Combat:ApplyLayout()
            end
        end, 150)
    end)
end


---------------------------------------------------------------------
-- GrimSuite Attribute Bars
--
-- First-pass integration of AltAttributes' player resource bars.
-- These bars intentionally have NO relationship to the action bar.
-- Positioning / dragging / settings will be handled separately.
---------------------------------------------------------------------

GSAttributeFakeGloss = ZO_Object:Subclass()

function GSAttributeFakeGloss:New()
    return ZO_Object.New(self)
end

function GSAttributeFakeGloss:SetMinMax() end
function GSAttributeFakeGloss:SetValue() end

local GSAttributeBar = ZO_Object:Subclass()

function GSAttributeBar:New(...)
    local bar = ZO_Object.New(self)
    bar:Initialize(...)
    return bar
end

function GSAttributeBar:Initialize(unitTag, powerType, topLevelCtrl, reversed)
    self.unitTag = unitTag
    self.powerType = powerType
    self.reversed = reversed == true

    local template = self.reversed and "GS_AttributeBarReversed" or "GS_AttributeBar"
    self.control = CreateControlFromVirtual(
        "GrimSuiteAttribute_" .. powerType,
        topLevelCtrl,
        template
    )

    self.control:SetHidden(true)
    self.attrText = self.control:GetNamedChild("Text")
    self.attrTextPercent = self.control:GetNamedChild("Percent")
    self.attrBar = self.control:GetNamedChild("Bar")

    -- Resource totals are centered within their associated bar.
    self.attrText:ClearAnchors()
    self.attrText:SetAnchor(CENTER, self.control, CENTER, 0, 0)

    -- Percentages sit just inside the appropriate outer edge:
    -- Health = left, Magicka (reversed) = right, Stamina = left.
    self.attrTextPercent:ClearAnchors()
    if self.reversed then
        self.attrTextPercent:SetAnchor(RIGHT, self.control, RIGHT, -10, 0)
        self.attrTextPercent:SetHorizontalAlignment(RIGHT)
    else
        self.attrTextPercent:SetAnchor(LEFT, self.control, LEFT, 10, 0)
        self.attrTextPercent:SetHorizontalAlignment(LEFT)
    end

    ZO_StatusBar_SetGradientColor(
        self.attrBar,
        ZO_POWER_BAR_GRADIENT_COLORS[powerType]
    )

    local function OnPowerUpdate(unitTag, powerPoolIndex, updatedPowerType, powerPool, powerPoolMax)
        self:OnPowerUpdate(powerPool, powerPoolMax, false)
    end

    local handler = ZO_MostRecentPowerUpdateHandler:New(
        "GrimSuiteAttribute_" .. powerType,
        OnPowerUpdate
    )
    handler:AddFilterForEvent(REGISTER_FILTER_POWER_TYPE, powerType)
    handler:AddFilterForEvent(REGISTER_FILTER_UNIT_TAG, unitTag)
    self.powerHandler = handler

    self.control:RegisterForEvent(EVENT_PLAYER_ALIVE, function()
        self:Refresh()
    end)

    self:Refresh(true)
end

function GSAttributeBar:Refresh(force)
    if force then
        self:ApplyStyle()
    end

    local power, maxPower = GetUnitPower(self.unitTag, self.powerType)
    self:OnPowerUpdate(power, maxPower, force)
end

function GSAttributeBar:FormatPercent(value, maxValue)
    local percent = 0
    if maxValue ~= 0 then
        percent = (value / maxValue) * 100
    end

    local percentText
    if percent < 10 then
        percentText = ZO_CommaDelimitDecimalNumber(zo_roundToNearest(percent, .1))
        percentText = ZO_FastFormatDecimalNumber(percentText)
    else
        percentText = zo_round(percent)
    end

    return percentText .. "%"
end

function GSAttributeBar:OnPowerUpdate(power, maxPower, force)
    ZO_StatusBar_SmoothTransition(self.attrBar, power, maxPower, force)
    self:UpdateResourceNumbers(power, maxPower)
end

function GSAttributeBar:UpdateResourceNumbers(power, maxPower)
    self.attrText:SetText(
        ZO_AbbreviateAndLocalizeNumber(
            power,
            NUMBER_ABBREVIATION_PRECISION_TENTHS,
            false
        )
    )
    self.attrTextPercent:SetText(self:FormatPercent(power, maxPower))
end

function GSAttributeBar:ApplyStyle()
    local frameLeft = self.reversed and "ZO_PlayerAttributeFrameLeftArrow" or "ZO_PlayerAttributeFrameLeft"
    local frameRight = self.reversed and "ZO_PlayerAttributeFrameRight" or "ZO_PlayerAttributeFrameRightArrow"
    local bgLeft = self.reversed and "ZO_PlayerAttributeBgLeftArrow" or "ZO_PlayerAttributeBgLeft"
    local bgRight = self.reversed and "ZO_PlayerAttributeBgRight" or "ZO_PlayerAttributeBgRightArrow"

    ApplyTemplateToControl(
        self.control:GetNamedChild("FrameLeft"),
        ZO_GetPlatformTemplate(frameLeft)
    )
    ApplyTemplateToControl(
        self.control:GetNamedChild("FrameRight"),
        ZO_GetPlatformTemplate(frameRight)
    )
    ApplyTemplateToControl(
        self.control:GetNamedChild("FrameCenter"),
        ZO_GetPlatformTemplate("ZO_PlayerAttributeFrameCenter")
    )

    ApplyTemplateToControl(
        self.control:GetNamedChild("BgContainerBgLeft"),
        ZO_GetPlatformTemplate(bgLeft)
    )
    ApplyTemplateToControl(
        self.control:GetNamedChild("BgContainerBgRight"),
        ZO_GetPlatformTemplate(bgRight)
    )
    ApplyTemplateToControl(
        self.control:GetNamedChild("BgContainerBgCenter"),
        ZO_GetPlatformTemplate("ZO_PlayerAttributeBgCenter")
    )

    -- Status bars already inherit ZO_PlayerAttributeStatusBar in XML.
    -- Leave that template in place rather than applying it again at runtime.
end

function GSAttributeBar:SetWidth(value)
    self.control:SetWidth(value)
end

function GSAttributeBar:SetHeight(value)
    local prevHeight = self.attrBar:GetHeight()
    if prevHeight ~= value then
        local mod = value / prevHeight

        local frameLeft = self.control:GetNamedChild("FrameLeft")
        local frameRight = self.control:GetNamedChild("FrameRight")
        local bgLeft = self.control:GetNamedChild("BgContainerBgLeft")
        local bgRight = self.control:GetNamedChild("BgContainerBgRight")

        frameLeft:SetWidth(zo_round(frameLeft:GetWidth() * mod) - 3)
        frameRight:SetWidth(zo_round(frameRight:GetWidth() * mod) - 3)
        bgLeft:SetWidth(zo_round(bgLeft:GetWidth() * mod) - 3)
        bgRight:SetWidth(zo_round(bgRight:GetWidth() * mod) - 3)

        self.control:SetHeight(value)
        -- The frame is the full control height; the fill itself is inset inside it.
        -- Its height is governed by the XML anchors below.

        frameLeft:SetHeight(value)
        frameRight:SetHeight(value)
        bgLeft:SetHeight(value)
        bgRight:SetHeight(value)
        self.control:GetNamedChild("FrameCenter"):SetHeight(value)
        self.control:GetNamedChild("BgContainerBgCenter"):SetHeight(value)

        local fontMod = IsInGamepadPreferredMode() and 1 / 3 or 2 / 3
        local font = "$(GAMEPAD_LIGHT_FONT)|" .. zo_round(value * fontMod) .. "|soft-shadow-thick"
        self.attrText:SetFont(font)
        self.attrTextPercent:SetFont(font)
    end
end

function GSAttributeBar:Show()
    self.control:SetHidden(false)
end

function GSAttributeBar:Hide()
    self.control:SetHidden(true)
end

local GSAttributeHealthBar = GSAttributeBar:Subclass()

function GSAttributeHealthBar:New(...)
    return GSAttributeBar.New(self, ...)
end

function GSAttributeHealthBar:Initialize(unitTag, powerType, topLevelCtrl)
    self.curShield = 0
    self.curHP = 0
    self.maxHP = 0

    GSAttributeBar.Initialize(self, unitTag, powerType, topLevelCtrl, false)

    self.shieldBar = CreateControlFromVirtual(
        "GrimSuiteAttributeShield_" .. powerType,
        self.attrBar,
        "GS_AttributeShieldBar"
    )

    self.shieldBar:SetColor(1, 0.49, 0.13, 0.50)
    self.shieldBar:ClearAnchors()
    self.shieldBar:SetAnchor(TOPLEFT, self.attrBar, TOPLEFT, 0, 3)
    self.shieldBar:SetAnchor(BOTTOMRIGHT, self.attrBar, BOTTOMRIGHT, 0, -3)
    self:OnUpdateShield(0, true)

    local function OnVisualPower(_, unitTag, unitAttributeVisual, statType, attributeType, powerType, oldValue, newValue, oldMaxValue, newMaxValue)
        local value = oldMaxValue == nil and oldValue or newValue
        if unitAttributeVisual == ATTRIBUTE_VISUAL_POWER_SHIELDING then
            self:OnUpdateShield(value, false)
        end
    end

    local function OnVisualPowerRemoved(_, unitTag, unitAttributeVisual)
        if unitAttributeVisual == ATTRIBUTE_VISUAL_POWER_SHIELDING then
            self:OnUpdateShield(0, false)
        end
    end

    topLevelCtrl:RegisterForEvent(EVENT_UNIT_ATTRIBUTE_VISUAL_ADDED, OnVisualPower)
    topLevelCtrl:AddFilterForEvent(EVENT_UNIT_ATTRIBUTE_VISUAL_ADDED, REGISTER_FILTER_UNIT_TAG, unitTag)

    topLevelCtrl:RegisterForEvent(EVENT_UNIT_ATTRIBUTE_VISUAL_UPDATED, OnVisualPower)
    topLevelCtrl:AddFilterForEvent(EVENT_UNIT_ATTRIBUTE_VISUAL_UPDATED, REGISTER_FILTER_UNIT_TAG, unitTag)

    topLevelCtrl:RegisterForEvent(EVENT_UNIT_ATTRIBUTE_VISUAL_REMOVED, OnVisualPowerRemoved)
    topLevelCtrl:AddFilterForEvent(EVENT_UNIT_ATTRIBUTE_VISUAL_REMOVED, REGISTER_FILTER_UNIT_TAG, unitTag)
end

function GSAttributeHealthBar:OnPowerUpdate(health, maxHealth, force)
    self.curHP = health
    self.maxHP = maxHealth

    ZO_StatusBar_SmoothTransition(self.attrBar, health, maxHealth, force)
    self:UpdateResourceNumbers(self.curHP, self.maxHP, self.curShield)
end

function GSAttributeHealthBar:OnUpdateShield(shield, force)
    self.curShield = shield
    ZO_StatusBar_SmoothTransition(self.shieldBar, shield, self.maxHP, force)
    self:UpdateResourceNumbers(self.curHP, self.maxHP, self.curShield)
end

function GSAttributeHealthBar:UpdateResourceNumbers(health, maxHealth, shield)
    if shield and shield > 0 then
        self.attrText:SetText(string.format(
            "%s [%s]",
            ZO_AbbreviateAndLocalizeNumber(
                health,
                NUMBER_ABBREVIATION_PRECISION_LARGEST_UNIT,
                false
            ),
            ZO_AbbreviateAndLocalizeNumber(
                shield,
                NUMBER_ABBREVIATION_PRECISION_LARGEST_UNIT,
                false
            )
        ))
        self.attrTextPercent:SetText(self:FormatPercent(health, maxHealth))
    else
        GSAttributeBar.UpdateResourceNumbers(self, health, maxHealth)
    end
end

function GSAttributeHealthBar:SetHeight(value)
    GSAttributeBar.SetHeight(self, value)
    if self.shieldBar then
        self.shieldBar:ClearAnchors()
        self.shieldBar:SetAnchor(TOPLEFT, self.attrBar, TOPLEFT, 0, 3)
        self.shieldBar:SetAnchor(BOTTOMRIGHT, self.attrBar, BOTTOMRIGHT, 0, -3)
    end
end

function Combat:CreateAttributes()
    if self.attributesInitialized then return end

    local container = GetControl("GrimSuiteAttributes")
    if not container then return end

    -- Hide the game's own resource bars. The GrimSuite copies are
    -- deliberately independent from ZO_ActionBar1.
    HideNativeAttributeBars()

    local height = IsInGamepadPreferredMode() and 96 or 32
    local width = 360

    self.attributeHealth = GSAttributeHealthBar:New(
        "player",
        POWERTYPE_HEALTH,
        container
    )
    self.attributeMagicka = GSAttributeBar:New(
        "player",
        POWERTYPE_MAGICKA,
        container,
        true
    )
    self.attributeStamina = GSAttributeBar:New(
        "player",
        POWERTYPE_STAMINA,
        container,
        false
    )

    for _, bar in ipairs({
        self.attributeHealth,
        self.attributeMagicka,
        self.attributeStamina,
    }) do
        bar:ApplyStyle()
        bar:SetWidth(width)
        bar:SetHeight(height)
        bar:Show()
        DisableAttributeChildMouse(bar.control)
    end

    -- The attribute bars are their own independent movable group.
    -- They are deliberately NOT anchored to ZO_ActionBar1.
    self.attributesInitialized = true
    self:LayoutAttributes()

    container:RegisterForEvent(
        EVENT_GAMEPAD_PREFERRED_MODE_CHANGED,
        function()
            self:LayoutAttributes()
            self:ApplyLayout()
        end
    )

    EM:RegisterForEvent(
        GS.name .. "_AttributesActivated",
        EVENT_PLAYER_ACTIVATED,
        function()
            ZO_PlayerAttributeHealth:SetHidden(true)
            ZO_PlayerAttributeMagicka:SetHidden(true)
            ZO_PlayerAttributeStamina:SetHidden(true)

            self.attributeHealth:Refresh(true)
            self.attributeMagicka:Refresh(true)
            self.attributeStamina:Refresh(true)
            self:LayoutAttributes()
            self:ApplyLayout()
        end
    )

    EnableAttributeDrag(container, self.layoutUnlocked, SaveAttributesPosition)
end

function Combat:LayoutAttributes()
    local container = GetControl("GrimSuiteAttributes")
    if not container or not self.attributeHealth then return end

    -- Slightly tighten the health-to-resource spacing and nudge the health
    -- bar down a few pixels for a more compact, visually balanced pyramid.
    local gap = IsInGamepadPreferredMode() and 9 or 3
    local healthOffsetY = IsInGamepadPreferredMode() and 4 or 3

    -- Keep the movable hitbox tight to the actual three-bar layout.
    -- Health is 360px wide; Magicka/Stamina extend 5px beyond each side.
    local barHeight = IsInGamepadPreferredMode() and 96 or 32
    container:SetDimensions(730, (barHeight * 2) + gap + healthOffsetY)

    self.attributeHealth.control:ClearAnchors()
    self.attributeHealth.control:SetAnchor(TOP, container, TOP, 0, healthOffsetY)

    self.attributeMagicka.control:ClearAnchors()
    self.attributeMagicka.control:SetAnchor(TOPRIGHT, self.attributeHealth.control, BOTTOM, -5, gap)

    self.attributeStamina.control:ClearAnchors()
    self.attributeStamina.control:SetAnchor(TOPLEFT, self.attributeHealth.control, BOTTOM, 5, gap)
end


---------------------------------------------------------------------
-- GCD Metronome
---------------------------------------------------------------------

function Combat:CreateGCD()
    local frame = WM:CreateTopLevelWindow("GrimSuiteGCD")
    frame:SetDimensions(GS.Saved.gcdWidth, GS.Saved.gcdHeight)
    frame:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, GS.Saved.gcdX, GS.Saved.gcdY)
    frame:SetHandler("OnMoveStop", function(c)
        GS.Saved.gcdX = math.floor(c:GetLeft() + 0.5)
        GS.Saved.gcdY = math.floor(c:GetTop() + 0.5)
    end)

    -- Visual rebuild: a compact dark/glass track with a crisp outer frame.
    -- The underlying GCD/ping timing logic is intentionally unchanged.
    local shadow = MakeBackdrop("GrimSuiteGCD_Shadow", frame)
    shadow:SetAnchorFill(frame)
    shadow:SetCenterColor(0, 0, 0, 0.45)
    shadow:SetEdgeColor(0, 0, 0, 0.95)

    local bg = MakeBackdrop("GrimSuiteGCD_BG", frame)
    -- Keep the background tied to the GCD frame itself so resizing the frame
    -- cannot leave a stale background rectangle at the old saved dimensions.
    bg:SetAnchor(TOPLEFT, frame, TOPLEFT, 1, 1)
    bg:SetAnchor(BOTTOMRIGHT, frame, BOTTOMRIGHT, -1, -1)
    bg:SetCenterColor(0.025, 0.025, 0.025, 0.96)
    bg:SetEdgeColor(0.16, 0.16, 0.16, 0.95)

    local track = MakeBackdrop("GrimSuiteGCD_Bar", frame)
    track:SetAnchor(TOPLEFT, self.gcdFrame, TOPLEFT, 3, 3)
    track:SetDimensions(math.max(1, GS.Saved.gcdWidth - 6), math.max(1, GS.Saved.gcdHeight - 6))
    track:SetCenterColor(0.07, 0.07, 0.07, 0.95)
    track:SetEdgeColor(0.28, 0.28, 0.28, 0.90)

    -- GCD progress remains a shrinking fill.  Keep the established yellow
    -- semantic so this is a visual rebuild, not a behavior change.
    local progress = MakeBackdrop("GrimSuiteGCD_Progress", frame)
    progress:SetAnchor(TOPLEFT, self.gcdFrame, TOPLEFT, 3, 3)
    progress:SetDimensions(0, math.max(1, GS.Saved.gcdHeight - 6))
    progress:SetCenterColor(0.98, 0.78, 0.08, 0.98)
    progress:SetEdgeColor(1.00, 0.93, 0.35, 0.75)

    -- Ping zone stays on the LEFT and above the GCD fill.  Its progression
    -- behavior is deliberately untouched from the validated v2 fix.
    local ping = MakeBackdrop("GrimSuiteGCD_Ping", frame)
    ping:SetAnchor(TOPLEFT, self.gcdFrame, TOPLEFT, 3, 3)
    ping:SetDimensions(0, math.max(1, GS.Saved.gcdHeight - 6))
    ping:SetCenterColor(0.78, 0.035, 0.055, 0.96)
    ping:SetEdgeColor(1.00, 0.24, 0.28, 0.85)

    local label = WM:CreateControl("GrimSuiteGCD_Time", frame, CT_LABEL)
    label:SetFont(SMALL_FONT)
    label:SetAnchor(CENTER, frame, CENTER, 0, 0)
    label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    label:SetColor(1, 1, 1, 1)
    label:SetText("")

    MakeMouseTransparent(bg)
    MakeMouseTransparent(track)
    MakeMouseTransparent(progress)
    MakeMouseTransparent(ping)
    MakeMouseTransparent(label)

    self.gcdFrame = frame
    self.gcdBar = track
    self.gcdPing = ping
    self.gcdProgress = progress
    self.gcdLabel = label
    self.gcdIdle = nil

    self.gcdBar:ClearAnchors()
    self.gcdBar:SetAnchor(TOPLEFT, self.gcdFrame, TOPLEFT, 3, 3)

    EnableMouseDrag(frame, self.layoutUnlocked, SaveGCDPosition)
    frame:SetHidden(false)
end

function Combat:StartGCD(duration)
    duration = tonumber(duration) or 1000
    if duration < 1 then duration = 1 end

    local now = GetFrameTimeMilliseconds()
    self.gcdStart = now
    self.gcdDuration = duration
    self.gcdEnd = now + duration
end

function Combat:UpdateGCD()
    if not self.gcdFrame then return end

    if (not self.hudVisible and not self.settingsPreviewVisible) or not GS.Saved.showGCD then
        self.gcdFrame:SetHidden(true)
        return
    end

    self.gcdFrame:SetHidden(false)

    local now = GetFrameTimeMilliseconds()
    local remaining = self.gcdEnd > 0 and (self.gcdEnd - now) or 0
    if remaining < 0 then remaining = 0 end

    local width = self.gcdFrame:GetWidth()
    local height = self.gcdFrame:GetHeight()

    -- The visible timeline is split into two zones:
    --   RED  = latency window on the far LEFT
    --   YELLOW = the actual GCD portion immediately to the RIGHT of RED
    --
    -- The yellow portion follows the same linear countdown/progress as the
    -- full GCD timeline. Once the remaining time reaches the latency window,
    -- yellow has reached the red zone; from that point the red zone shrinks
    -- toward zero and finishes at the exact same instant as the GCD.
    local innerWidth = math.max(1, width - 6)
    local innerHeight = math.max(1, height - 6)

    local gcdProgress = 0
    if remaining > 0 and self.gcdDuration > 0 then
        gcdProgress = math.max(0, math.min(1, remaining / self.gcdDuration))
    end

    local pingMs = 0
    if remaining > 0 then
        pingMs = math.max(0, math.min(GetLatency(), self.gcdDuration))
    end

    local pingWidth = math.floor((pingMs / math.max(1, self.gcdDuration)) * innerWidth)

    -- The full remaining timeline would occupy gcdProgress * innerWidth.
    -- Reserve the fixed latency zone on the left, so the yellow bar starts
    -- exactly at the right edge of the red zone instead of underneath it.
    -- Once the countdown enters the latency window, the yellow portion is
    -- explicitly forced to zero.  Without this guard, tiny rounding/latency
    -- changes around the boundary can make a 1-3px yellow sliver reappear
    -- while the red zone is already shrinking.
    local fullRemainingWidth = math.floor(gcdProgress * innerWidth)
    local progressWidth = 0
    if remaining > pingMs then
        progressWidth = math.max(0, fullRemainingWidth - pingWidth)
    end

    self.gcdProgress:ClearAnchors()
    self.gcdProgress:SetAnchor(TOPLEFT, self.gcdFrame, TOPLEFT, 3 + pingWidth, 3)
    self.gcdProgress:SetDimensions(math.max(0, progressWidth), innerHeight)

    -- A zero-width backdrop can still render its border for a pixel or two.
    -- Hide the yellow control completely once it reaches the ping boundary so
    -- the red-to-yellow handoff has no persistent yellow sliver.
    self.gcdProgress:SetHidden(progressWidth <= 0)

    -- Keep the red latency zone on the far LEFT at full width until the
    -- countdown reaches the ping window.  During that final latency interval,
    -- shrink the red zone linearly to zero so both zones finish together.
    local visiblePingWidth = pingWidth
    if pingMs > 0 and remaining <= pingMs then
        visiblePingWidth = math.floor((remaining / pingMs) * pingWidth)
    elseif remaining <= 0 then
        visiblePingWidth = 0
    end

    self.gcdPing:ClearAnchors()
    self.gcdPing:SetAnchor(TOPLEFT, self.gcdFrame, TOPLEFT, 3, 3)
    self.gcdPing:SetDimensions(math.max(0, visiblePingWidth), innerHeight)

    local idle = remaining <= 0
    if idle ~= self.gcdIdle then
        self.gcdIdle = idle
        if idle then
            self.gcdLabel:SetText("READY")
        else
            self.gcdLabel:SetText(string.format("%.2f", remaining / 1000))
        end
    elseif not idle then
        -- The countdown itself is animated, so only the numeric text changes.
        self.gcdLabel:SetText(string.format("%.2f", remaining / 1000))
    end
end

---------------------------------------------------------------------
-- Simplified WeaveDelays
---------------------------------------------------------------------

local function Clamp(v, lo, hi)
    return math.max(lo, math.min(v, hi))
end

local function DelayColor(delay)
    if delay <= 35 then
        return 0.35, 0.80, 1.00, 1
    elseif delay <= 100 then
        return 0.15, 0.85, 0.20, 1
    elseif delay <= 200 then
        return 0.95, 0.55, 0.10, 1
    else
        return 0.90, 0.12, 0.10, 1
    end
end

function Combat:CreateWeaveBar()
    local frame = WM:CreateTopLevelWindow("GrimSuiteWeave")
    frame:SetDimensions(GS.Saved.weaveWidth, GS.Saved.weaveHeight)
    frame:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, GS.Saved.weaveX, GS.Saved.weaveY)
    frame:SetHandler("OnMoveStop", function(c)
        GS.Saved.weaveX = math.floor(c:GetLeft() + 0.5)
        GS.Saved.weaveY = math.floor(c:GetTop() + 0.5)
    end)

    -- The average remains independently movable, but is now presented as a
    -- compact status pill instead of bare floating text.
    local averageFrame = WM:CreateTopLevelWindow("GrimSuiteWeave_Avg")
    averageFrame:SetDimensions(116, 24)
    averageFrame:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT,
        GS.Saved.weaveX + GS.Saved.weaveAverageX,
        GS.Saved.weaveY + GS.Saved.weaveAverageY)
    EnableMouseDrag(averageFrame, self.layoutUnlocked, SaveAveragePosition)
    averageFrame:SetHidden(not self.layoutUnlocked)

    local averageBg = MakeBackdrop("GrimSuiteWeave_AvgBG", averageFrame)
    averageBg:SetAnchorFill(averageFrame)
    averageBg:SetCenterColor(0.025, 0.025, 0.025, 0.94)
    averageBg:SetEdgeColor(0.28, 0.28, 0.28, 0.95)

    local averageAccent = MakeBackdrop("GrimSuiteWeave_AvgAccent", averageFrame)
    averageAccent:SetAnchor(TOPLEFT, averageFrame, TOPLEFT, 1, 1)
    averageAccent:SetDimensions(3, 22)
    averageAccent:SetCenterColor(0.78, 0.035, 0.055, 1)
    averageAccent:SetEdgeColor(1.00, 0.24, 0.28, 0.75)

    local averageLabel = WM:CreateControl("GrimSuiteWeave_AvgLabel", averageFrame, CT_LABEL)
    averageLabel:SetAnchorFill(averageFrame)
    averageLabel:SetFont(SMALL_FONT)
    averageLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    averageLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    averageLabel:SetColor(0.95, 0.95, 0.95, 1)
    averageLabel:SetText("")
    averageLabel:SetMouseEnabled(false)

    MakeMouseTransparent(averageBg)
    MakeMouseTransparent(averageAccent)

    local shadow = MakeBackdrop("GrimSuiteWeave_Shadow", frame)
    shadow:SetAnchorFill(frame)
    shadow:SetCenterColor(0, 0, 0, 0.45)
    shadow:SetEdgeColor(0, 0, 0, 0.95)

    local bar = MakeBackdrop("GrimSuiteWeave_BG", frame)
    bar:SetAnchor(TOPLEFT, frame, TOPLEFT, 1, 1)
    bar:SetDimensions(math.max(1, GS.Saved.weaveWidth - 2), math.max(1, GS.Saved.weaveHeight - 2))
    bar:SetCenterColor(0.025, 0.025, 0.025, 0.96)
    bar:SetEdgeColor(0.16, 0.16, 0.16, 0.95)

    self.weaveFrame = frame
    self.weaveAverageFrame = averageFrame
    self.weaveAverage = averageLabel
    MakeMouseTransparent(bar)

    self.weaveBar = bar
    self.weaveSlots = {}
    EnableMouseDrag(frame, self.layoutUnlocked, SaveWeavePosition)

    local barWidth = math.max(1, GS.Saved.weaveWidth - 4)
    local barHeight = GS.Saved.weaveHeight
    local slotW = barWidth / self.weave.max
    local slotH = math.max(8, barHeight - 8)
    for i = 1, self.weave.max do
        local slot = MakeBackdrop("GrimSuiteWeave_Slot"..i, frame)
        slot:SetDimensions(math.max(1, slotW - 3), slotH)
        slot:SetAnchor(TOPLEFT, bar, TOPLEFT, 2 + (i-1)*slotW, 3)
        slot:SetCenterColor(0.055, 0.055, 0.055, 0.92)
        slot:SetEdgeColor(0.20, 0.20, 0.20, 0.95)
        self.weaveSlots[i] = slot
        MakeMouseTransparent(slot)

        local delayLabel = WM:CreateControl("GrimSuiteWeave_Delay"..i, slot, CT_LABEL)
        delayLabel:SetAnchor(CENTER, slot, CENTER, 2, -1)
        delayLabel:SetFont(SMALL_FONT)
        delayLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        delayLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        delayLabel:SetColor(1, 1, 1, 0.95)
        delayLabel:SetText("")
        MakeMouseTransparent(delayLabel)
        slot.delayLabel = delayLabel

        -- Vertical LA status marker: green = confirmed LA, red = missed LA.
        -- IMPORTANT: make this a SIBLING of the slot rather than a child of the
        -- slot backdrop.  ESO's backdrop draw order can otherwise leave the
        -- marker visually buried under the slot fill/border.
        -- The marker sits inside the LEFT side of the colored slot, fills it
        -- vertically, and is about 2px wider than the original indicator.
        local la = MakeBackdrop("GrimSuiteWeave_LA"..i, frame)
        la:SetAnchor(TOPLEFT, slot, TOPLEFT, 1, 1)
        la:SetDimensions(6, math.max(1, slotH - 2))
        la:SetDrawLayer(DL_OVERLAY)
        la:SetDrawTier(DT_HIGH)
        la:SetCenterColor(0.15, 0.85, 0.20, 1)
        la:SetEdgeColor(0.60, 1.00, 0.65, 0.45)
        MakeMouseTransparent(la)
        self.weaveSlots[i].la = la
    end

    frame:SetHidden(false)
end

function Combat:AddWeave(delay, laMissed, windowStart, windowEnd)
    -- Keep real low positive delays. Values at/before the GCD end represent
    -- no wasted time and are shown as 0 ms instead of being forced to 1 ms.
    delay = Clamp(tonumber(delay) or 1000, 0, 950)

    table.insert(self.weave.actions, {
        delay = delay,
        laMissed = laMissed == true,
        windowStart = windowStart,
        windowEnd = windowEnd,
    })
    if #self.weave.actions > self.weave.max then
        table.remove(self.weave.actions, 1)
    end

    -- Keep a true rolling average over the most recent averageMax skill delays.
    table.insert(self.weave.averagePending, delay)
    self.weave.averageSum = self.weave.averageSum + delay
    if #self.weave.averagePending > self.weave.averageMax then
        self.weave.averageSum = self.weave.averageSum - table.remove(self.weave.averagePending, 1)
    end
    self.weave.averageCount = #self.weave.averagePending

    self:UpdateWeave()
end

function Combat:UpdateWeave()
    if not self.weaveFrame then return end

    if not GS.Saved.showWeave then
        self.weaveFrame:SetHidden(true)
        if self.weaveAverageFrame then self.weaveAverageFrame:SetHidden(true) end
        return
    end

    self.weaveFrame:SetHidden(false)
    if self.weaveAverageFrame then self.weaveAverageFrame:SetHidden(false) end

    for i = 1, self.weave.max do
        local slot = self.weaveSlots[i]
        local entry = self.weave.actions[#self.weave.actions - self.weave.max + i]
        local delay = entry and entry.delay

        if delay then
            local r,g,b,a = DelayColor(delay)
            slot:SetCenterColor(r * 0.72, g * 0.72, b * 0.72, 0.92)
            slot:SetEdgeColor(r, g, b, 0.95)
            if slot.delayLabel then
                if GS.Saved.showWeaveMs then
                    slot.delayLabel:SetText(string.format("%d", math.floor(delay + 0.5)))
                    slot.delayLabel:SetColor(1, 1, 1, 0.98)
                else
                    slot.delayLabel:SetText("")
                end
            end
            if slot.la then
                if entry.laMissed then
                    slot.la:SetCenterColor(0.90, 0.12, 0.10, 1)
                    slot.la:SetEdgeColor(1.00, 0.30, 0.28, 0.75)
                else
                    slot.la:SetCenterColor(0.15, 0.85, 0.20, 1)
                    slot.la:SetEdgeColor(0.60, 1.00, 0.65, 0.55)
                end
            end
        else
            slot:SetCenterColor(0.055, 0.055, 0.055, 0.92)
            slot:SetEdgeColor(0.20, 0.20, 0.20, 0.95)
            if slot.delayLabel then
                slot.delayLabel:SetText("")
            end
            if slot.la then
                slot.la:SetCenterColor(0.10, 0.10, 0.10, 0.65)
                slot.la:SetEdgeColor(0.20, 0.20, 0.20, 0.45)
            end
        end
    end

    if self.weave.averageCount > 0 then
        self.weaveAverage:SetText(string.format("AVG  %d ms", math.floor((self.weave.averageSum / self.weave.averageCount) + 0.5)))
    else
        self.weaveAverage:SetText("AVG  -- ms")
    end
end

---------------------------------------------------------------------
-- Action / combat events
---------------------------------------------------------------------

function Combat:OnCombatState(_, inCombat)
    self.inCombat = inCombat == true

    -- Keep timing state strictly scoped to the current combat encounter.
    -- The visible 10-slot history and rolling average are intentionally preserved.
    if not self.inCombat then
        self.weave.pendingLA = nil
        self.weave.previousSkillAt = nil
        self.weave.previousSkillEnd = nil
        self.weave.lastLAConfirmed = nil
    end

    self:UpdateWeave()
end

function Combat:OnSlotUsed(_, slotId)
    -- Ignore all skill-slot events outside combat so they cannot seed or
    -- contaminate the next combat encounter's first measured interval.
    if not self.inCombat then
        return
    end

    -- Slot 1 is the light attack button. We do not count the button press
    -- itself as a successful LA; OnCombatEvent confirms that the LA actually
    -- produced a combat result.
    if slotId == 1 then
        return
    end

    if slotId < 3 then return end

    local now = GetFrameTimeMilliseconds()

    -- GCD baseline is 1s. Cast/channel time is included when it exceeds
    -- the baseline. Fatecarver also adds 0.3s per Crux consumed (up to 3).
    local boundId = GetSlotBoundId(slotId)
    local _, castTime, channelTime = GetAbilityCastInfo(boundId)
    local baseDuration = math.max(1000, (castTime or 0) + (channelTime or 0))

    -- Crux is a shared player effect tracked by the Action Bar. Read the
    -- current count at the moment the ability is used, before the consume
    -- event can remove the stacks. Only Fatecarver consumes Crux for this
    -- GCD adjustment.
    local cruxConsumed = 0
    if boundId and boundId > 0 and GetAbilityName then
        local ok, name = pcall(GetAbilityName, boundId)
        if ok and name then
            name = zo_strlower(tostring(name))
            if string.find(name, "exhausting fatecarver", 1, true) then
                local crux = 0
                local tracked = GS.ActionBar and GS.ActionBar.effectStacks
                if tracked and tracked[184220] then
                    crux = tonumber(tracked[184220].stack) or 0
                end
                cruxConsumed = math.max(0, math.min(3, crux))
            end
        end
    end

    local duration = baseDuration + (cruxConsumed * 300)

    if self.weave.previousSkillEnd then
        local delay = now - self.weave.previousSkillEnd

        -- Every skill-to-skill interval is recorded. LA compliance is a
        -- separate binary flag: did a confirmed LA occur during this interval?
        local intervalStart = self.weave.previousSkillAt
        local laMissed = true
        if self.weave.lastLAConfirmed
            and intervalStart
            and self.weave.lastLAConfirmed > intervalStart
            and self.weave.lastLAConfirmed <= now then
            laMissed = false
        end

        -- Store the interval bounds so a ranged LA whose combat event arrives
        -- shortly after the next skill can retroactively confirm this entry.
        self:AddWeave(delay, laMissed, intervalStart, now)

        -- This LA confirmation has now been consumed by this skill interval.
        self.weave.lastLAConfirmed = nil
    end

    self.weave.previousSkillAt = now
    self.weave.previousSkillEnd = now + duration

    self:StartGCD(duration)
end

function Combat:OnCombatEvent(_, result, _, _, _, actionSlotType, sourceName)
    if not self.inCombat then return end
    if sourceName ~= GetRawUnitName("player") then return end

    if actionSlotType == ACTION_SLOT_TYPE_LIGHT_ATTACK then
        if result == ACTION_RESULT_DAMAGE
        or result == ACTION_RESULT_CRITICAL_DAMAGE
        or result == ACTION_RESULT_HEAL
        or result == ACTION_RESULT_CRITICAL_HEAL
        or result == ACTION_RESULT_BLOCKED
        or result == ACTION_RESULT_DODGED
        or result == ACTION_RESULT_ABSORBED then

            local laTime = GetFrameTimeMilliseconds()
            local actions = self.weave.actions

            -- Ranged LA damage can arrive after the next skill is already
            -- pressed. If it falls inside the grace window of a recent
            -- interval, correct that history entry instead of counting it
            -- as a miss.
            for i = #actions, 1, -1 do
                local entry = actions[i]
                if entry.windowStart and entry.windowEnd then
                    if laTime > entry.windowStart
                        and laTime <= entry.windowEnd + self.weave.laGraceMs then
                        if entry.laMissed then
                            entry.laMissed = false
                            self:UpdateWeave()
                        end
                        return
                    elseif laTime > entry.windowEnd + self.weave.laGraceMs then
                        break
                    end
                end
            end

            -- If the LA arrived before the next skill, hold it for the
            -- current interval. OnSlotUsed() consumes it on the next skill.
            if self.weave.previousSkillAt and laTime > self.weave.previousSkillAt then
                self.weave.lastLAConfirmed = laTime
            end
        end
    end
end

function Combat:Update()
    -- GCD is continuously animated; weave history is event-driven.
    self:UpdateGCD()
end

function Combat:ApplyLayout()
    if self.gcdFrame then
        self.gcdFrame:SetDimensions(GS.Saved.gcdWidth, GS.Saved.gcdHeight)
        self.gcdFrame:ClearAnchors()
        self.gcdFrame:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, GS.Saved.gcdX, GS.Saved.gcdY)
        if self.gcdProgress then
            self.gcdProgress:SetHeight(math.max(1, GS.Saved.gcdHeight - 6))
        end
        if self.gcdPing then
            self.gcdPing:SetHeight(math.max(1, GS.Saved.gcdHeight - 6))
        end
        if self.gcdBar then
            self.gcdBar:SetDimensions(math.max(1, GS.Saved.gcdWidth - 6), math.max(1, GS.Saved.gcdHeight - 6))
        end
    end

    if self.weaveFrame then
        self.weaveFrame:SetDimensions(GS.Saved.weaveWidth, GS.Saved.weaveHeight)
        self.weaveFrame:ClearAnchors()
        self.weaveFrame:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, GS.Saved.weaveX, GS.Saved.weaveY)
        if self.weaveAverageFrame then
            self.weaveAverageFrame:ClearAnchors()
            self.weaveAverageFrame:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT,
                GS.Saved.weaveX + GS.Saved.weaveAverageX,
                GS.Saved.weaveY + GS.Saved.weaveAverageY)
            EnableMouseDrag(self.weaveAverageFrame, self.layoutUnlocked, SaveAveragePosition)
            self.weaveAverageFrame:SetHidden(not self.layoutUnlocked)
        end

        local bar = self.weaveBar
        if bar then
            local barHeight = GS.Saved.weaveHeight
            bar:SetDimensions(math.max(1, GS.Saved.weaveWidth - 2), math.max(1, barHeight - 2))
            local innerWidth = math.max(1, GS.Saved.weaveWidth - 4)
            local slotW = innerWidth / self.weave.max
            local slotH = math.max(8, barHeight - 8)
            for i = 1, self.weave.max do
                local slot = self.weaveSlots[i]
                slot:SetDimensions(math.max(1, slotW - 3), slotH)
                slot:ClearAnchors()
                slot:SetAnchor(TOPLEFT, bar, TOPLEFT, 2 + (i-1)*slotW, 3)
                if slot.la then
                    slot:SetClampedToScreen(true)
                    -- Keep the LA result marker as a vertical strip on the
                    -- inside-left of the delay slot.  This must match the
                    -- dimensions/anchor used when the bar is created; the
                    -- old horizontal 3px marker here was undoing the visual
                    -- rebuild every time ApplyLayout() ran.
                    slot.la:SetDimensions(6, math.max(1, slotH - 2))
                    slot.la:ClearAnchors()
                    slot.la:SetAnchor(TOPLEFT, slot, TOPLEFT, 1, 1)
                end
                if slot.delayLabel then
                    slot.delayLabel:ClearAnchors()
                    slot.delayLabel:SetAnchor(CENTER, slot, CENTER, 2, -1)
                end
            end
        end
    end

    if self.attributesInitialized then
        local attributes = GetControl("GrimSuiteAttributes")
        if attributes then
            attributes:ClearAnchors()
            attributes:SetAnchor(
                CENTER,
                GuiRoot,
                CENTER,
                GS.Saved.attributesX or 0,
                GS.Saved.attributesY or 0
            )
            EnableAttributeDrag(attributes, self.layoutUnlocked, SaveAttributesPosition)
        end
    end
end

function Combat:CreateSettings()
    local LAM = LibAddonMenu2

    local panelName = "GrimSuiteSettings"
    LAM:RegisterAddonPanel(panelName, {
        type = "panel",
        name = "GrimSuite",
        displayName = "GrimSuite",
        author = "@GrimGrin94",
        version = GS.version,
        registerForRefresh = true,
        registerForDefaults = true,
    })

    LAM:RegisterOptionControls(panelName, {
        { type="header", name="UI Layout", width="full" },
        { type="description", text="Unlock the bars to drag them with your mouse. Lock them again when finished.", width="full" },
        { type="checkbox", name="Unlock UI For Mouse Dragging", getFunc=function() return self.layoutUnlocked end, setFunc=function(v) SetLayoutUnlocked(v); self:ApplyLayout() end, default=false },

        { type="header", name="Player Attribute Bars", width="full" },
        { type="description", text="Move the Health, Magicka, and Stamina pyramid independently of the action bar.", width="full" },
        { type="slider", name="Horizontal Position (X)", min=-1920, max=1920, step=1, getFunc=function() return GS.Saved.attributesX or 0 end, setFunc=function(v) GS.Saved.attributesX=v; self:ApplyLayout() end, default=GS.SV.attributesX, width="full" },
        { type="slider", name="Vertical Position (Y)", min=-1080, max=1080, step=1, getFunc=function() return GS.Saved.attributesY or 0 end, setFunc=function(v) GS.Saved.attributesY=v; self:ApplyLayout() end, default=GS.SV.attributesY, width="full" },
        { type="button", name="Center Horizontally", func=function()
            local attributes = GetControl("GrimSuiteAttributes")
            if attributes then
                local y = GS.Saved.attributesY or 0
                GS.Saved.attributesX = 0
                attributes:ClearAnchors()
                attributes:SetAnchor(CENTER, GuiRoot, CENTER, 0, y)
                self:ApplyLayout()
            end
        end, width="half" },

        { type="header", name="GCD Metronome", width="full" },
        { type="checkbox", name="Show GCD Metronome", getFunc=function() return GS.Saved.showGCD end, setFunc=function(v) GS.Saved.showGCD=v; self:UpdateGCD() end, default=GS.SV.showGCD },
        { type="slider", name="Horizontal Position (X)", min=0, max=3840, step=1, getFunc=function() return GS.Saved.gcdX end, setFunc=function(v) GS.Saved.gcdX=v; self:ApplyLayout() end, default=GS.SV.gcdX, width="full" },
        { type="slider", name="Vertical Position (Y)", min=0, max=2160, step=1, getFunc=function() return GS.Saved.gcdY end, setFunc=function(v) GS.Saved.gcdY=v; self:ApplyLayout() end, default=GS.SV.gcdY, width="full" },
        { type="button", name="Center Horizontally", func=function() CenterControl(self.gcdFrame, true, false, "gcdX", "gcdY") end, width="half" },
        { type="button", name="Center Vertically", func=function() CenterControl(self.gcdFrame, false, true, "gcdX", "gcdY") end, width="half" },
        { type="slider", name="Horizontal Size (Width)", min=100, max=1000, step=1, getFunc=function() return GS.Saved.gcdWidth end, setFunc=function(v) GS.Saved.gcdWidth=v; self:ApplyLayout() end, default=GS.SV.gcdWidth, width="full" },
        { type="slider", name="Vertical Size (Height)", min=8, max=80, step=1, getFunc=function() return GS.Saved.gcdHeight end, setFunc=function(v) GS.Saved.gcdHeight=v; self:ApplyLayout() end, default=GS.SV.gcdHeight, width="full" },

        { type="header", name="Skill Delay History", width="full" },
        { type="checkbox", name="Show Skill Delay History", getFunc=function() return GS.Saved.showWeave end, setFunc=function(v) GS.Saved.showWeave=v; self:UpdateWeave() end, default=GS.SV.showWeave },
        { type="checkbox", name="Show Delay Values (ms)", getFunc=function() return GS.Saved.showWeaveMs end, setFunc=function(v) GS.Saved.showWeaveMs=v; self:UpdateWeave() end, default=GS.SV.showWeaveMs },
        { type="slider", name="Horizontal Position (X)", min=0, max=3840, step=1, getFunc=function() return GS.Saved.weaveX end, setFunc=function(v) GS.Saved.weaveX=v; self:ApplyLayout() end, default=GS.SV.weaveX, width="full" },
        { type="slider", name="Vertical Position (Y)", min=0, max=2160, step=1, getFunc=function() return GS.Saved.weaveY end, setFunc=function(v) GS.Saved.weaveY=v; self:ApplyLayout() end, default=GS.SV.weaveY, width="full" },
        { type="button", name="Center Horizontally", func=function() CenterControl(self.weaveFrame, true, false, "weaveX", "weaveY") end, width="half" },
        { type="button", name="Center Vertically", func=function() CenterControl(self.weaveFrame, false, true, "weaveX", "weaveY") end, width="half" },
        { type="slider", name="Horizontal Size (Width)", min=100, max=1000, step=1, getFunc=function() return GS.Saved.weaveWidth end, setFunc=function(v) GS.Saved.weaveWidth=v; self:ApplyLayout() end, default=GS.SV.weaveWidth, width="full" },
        { type="slider", name="Vertical Size (Height)", min=20, max=100, step=1, getFunc=function() return GS.Saved.weaveHeight end, setFunc=function(v) GS.Saved.weaveHeight=v; self:ApplyLayout() end, default=GS.SV.weaveHeight, width="full" },
        { type="header", name="Average Display", width="full" },
        { type="description", text="Move the rolling delay average independently from the delay history bar.", width="full" },
        { type="slider", name="Average Horizontal Position", min=-200, max=1000, step=1, getFunc=function() return GS.Saved.weaveAverageX end, setFunc=function(v) GS.Saved.weaveAverageX=v; self:ApplyLayout() end, default=GS.SV.weaveAverageX, width="full" },
        { type="slider", name="Average Vertical Position", min=-200, max=500, step=1, getFunc=function() return GS.Saved.weaveAverageY end, setFunc=function(v) GS.Saved.weaveAverageY=v; self:ApplyLayout() end, default=GS.SV.weaveAverageY, width="full" },
    })
end

function Combat:SetSettingsPreviewVisible(visible)
    self.settingsPreviewVisible = visible == true

    if self.settingsPreviewVisible then
        self:ApplyLayout()

        if self.gcdFrame then
            self.gcdFrame:SetHidden(not GS.Saved.showGCD)
        end

        if self.weaveFrame then
            self.weaveFrame:SetHidden(not GS.Saved.showWeave)
        end

        if self.weaveAverageFrame then
            self.weaveAverageFrame:SetHidden(not GS.Saved.showWeave)
        end

        self:UpdateGCD()
        self:UpdateWeave()
    else
        if self.gcdFrame then
            self.gcdFrame:SetHidden(not (self.hudVisible and GS.Saved.showGCD))
        end

        if self.weaveFrame then
            self.weaveFrame:SetHidden(not (self.hudVisible and GS.Saved.showWeave))
        end

        if self.weaveAverageFrame then
            self.weaveAverageFrame:SetHidden(not (self.hudVisible and GS.Saved.showWeave))
        end
    end
end

function Combat:Initialize()
    self:CreateAttributes()
    self:CreateGCD()
    self:CreateWeaveBar()
    self:CreateSettings()

    if CALLBACK_MANAGER and not self.settingsPreviewCallbacksRegistered then
        self.settingsPreviewCallbacksRegistered = true

        CALLBACK_MANAGER:RegisterCallback("LAM-PanelOpened", function(panel)
            local openedName = panel and panel:GetName()
            self:SetSettingsPreviewVisible(openedName == "GrimSuiteSettings")
        end)

        CALLBACK_MANAGER:RegisterCallback("LAM-PanelClosed", function(panel)
            local closedName = panel and panel:GetName()
            if closedName == "GrimSuiteSettings" then
                self:SetSettingsPreviewVisible(false)
            end
        end)
    end

    EM:RegisterForEvent(GS.name .. "_CombatState", EVENT_PLAYER_COMBAT_STATE, function(...)
        self:OnCombatState(...)
    end)

    -- Hide GrimSuite's custom HUD widgets whenever ESO enters a menu scene.
    -- They are HUD-only: ESC, inventory, map, skills, character sheet, etc.
    -- On returning to the gameplay HUD, restore them and re-assert their
    -- saved positions.
    if SCENE_MANAGER then
        SCENE_MANAGER:RegisterCallback("SceneStateChanged", function(scene, oldState, newState)
            if newState ~= SCENE_SHOWING and newState ~= SCENE_SHOWN then
                return
            end

            local hudScene = (scene == HUD_SCENE or scene == HUD_UI_SCENE)
            self.hudVisible = hudScene

            if GS.ActionBar and GS.ActionBar.SetHUDVisible then
                GS.ActionBar:SetHUDVisible(hudScene)
            end

            if self.gcdFrame then
                self.gcdFrame:SetHidden(not hudScene)
            end

            if self.weaveFrame then
                self.weaveFrame:SetHidden(not hudScene or not GS.Saved.showWeave)
            end

            if self.weaveAverageFrame then
                self.weaveAverageFrame:SetHidden(not hudScene or not GS.Saved.showWeave)
            end

            local attributes = GetControl("GrimSuiteAttributes")
            if attributes then
                attributes:SetHidden(not hudScene)
            end

            if hudScene then
                if self.gcdFrame then
                    self.gcdFrame:SetHidden(not GS.Saved.showGCD)
                end
                ScheduleLayoutRepair()
            end
        end)
    end

    -- Player activation is also a native UI rebuild point.  Repair after ESO
    -- has finished constructing the HUD rather than relying on /reloadui.
    EM:RegisterForEvent(GS.name .. "_CombatActivated", EVENT_PLAYER_ACTIVATED, function()
        zo_callLater(function()
            if self.initialized then
                self:ApplyLayout()
            end
        end, 100)
    end)

    EM:RegisterForEvent(GS.name .. "_SlotUsed", EVENT_ACTION_SLOT_ABILITY_USED, function(...)
        self:OnSlotUsed(...)
    end)

    EM:RegisterForEvent(GS.name .. "_CombatEvent", EVENT_COMBAT_EVENT, function(...)
        self:OnCombatEvent(...)
    end)
    EM:AddFilterForEvent(
        GS.name .. "_CombatEvent",
        EVENT_COMBAT_EVENT,
        REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE,
        COMBAT_UNIT_TYPE_PLAYER
    )

    EM:RegisterForUpdate(GS.name .. "_Update", 1000 / 60, function()
        self:Update()
    end)

    SLASH_COMMANDS["/grimsuite"] = function(cmd)
        cmd = string.lower(cmd or "")
        if cmd == "gcd" then
            GS.Saved.showGCD = not GS.Saved.showGCD
            d("GrimSuite GCD: " .. tostring(GS.Saved.showGCD))
        elseif cmd == "weave" then
            GS.Saved.showWeave = not GS.Saved.showWeave
            d("GrimSuite WeaveDelays: " .. tostring(GS.Saved.showWeave))
        elseif cmd == "attrs" then
            SetLayoutUnlocked(not self.layoutUnlocked)
            d("GrimSuite UI dragging: " .. tostring(self.layoutUnlocked))
        elseif cmd == "reset" then
            self.weave.actions = {}
            self.weave.pendingLA = nil
            self.weave.previousSkillAt = nil
            self.weave.previousSkillEnd = nil
            self.weave.lastLAConfirmed = nil
            self.gcdIdle = nil
            self.weave.averageSum = 0
            self.weave.averageCount = 0
            self.weave.averagePending = {}
            self:UpdateWeave()
        else
            d("/grimsuite gcd - toggle GCD metronome")
            d("/grimsuite weave - toggle WeaveDelays")
            d("/grimsuite attrs - toggle UI dragging")
            d("/grimsuite reset - clear weave history")
        end
    end

    self:Update()
    d("GrimSuite Combat " .. GS.version .. " loaded: GCD + skill delay + static LA status + layout menu")
end
