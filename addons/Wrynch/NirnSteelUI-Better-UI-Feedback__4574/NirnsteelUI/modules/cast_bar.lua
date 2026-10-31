local ADDON_NAME = "NirnsteelUI"
local EVENT_NAMESPACE = ADDON_NAME .. "_CastBar"

Nirnsteel_UI = Nirnsteel_UI or {}
local Nirnsteel_UI = Nirnsteel_UI
local CastBar = {}
Nirnsteel_UI.CastBar = CastBar

local DEFAULT_SETTINGS =
{
    enabled = true,
    unlocked = false,
    scale = 100,
    width = 400,
    height = 20,
    opacity = 100,
    textMode = "nameAndTime",
    showIcon = true,
    showTicks = true,
    animationIntensity = 85,
}

local DEFAULT_POSITION = { x = 0, y = -180 }
local MIN_WIDTH = 220
local MAX_WIDTH = 620
local MIN_HEIGHT = 18
local MAX_HEIGHT = 48
local MIN_DURATION_MS = 120
local COMPLETE_HOLD_MS = 360
local ENTER_MS = 160
local FADE_OUT_MS = 220
local ICON_PAD = 6
local FRAME_PAD = 3
local TICK_FLASH_MS = 220
local BAR_TEXTURE = "EsoUI/Art/Miscellaneous/progressbar_genericFill_tall.dds"
local BAR_GLOSS_TEXTURE = "EsoUI/Art/Miscellaneous/timerBar_genericFill_gloss.dds"
local BAR_LEADING_EDGE_TEXTURE = "EsoUI/Art/Miscellaneous/progressbar_genericFill_leadingEdge_blunt.dds"
local EDGE_FRAME_TEXTURE = "EsoUI/Art/Miscellaneous/Gamepad/edgeframeGamepadBorder_thin.dds"
local FALLBACK_ICON = "EsoUI/Art/Icons/icon_missing.dds"
local TICK_COUNT = 4

local TEXT_MODE_ALIASES =
{
    ["Name + Time"] = "nameAndTime",
    ["Name Only"] = "nameOnly",
    ["Timer Only"] = "timerOnly",
    Off = "off",
    nameAndTime = "nameAndTime",
    nameOnly = "nameOnly",
    timerOnly = "timerOnly",
    off = "off",
}

local function ClampNumber(value, minValue, maxValue)
    value = tonumber(value) or minValue
    return math.min(math.max(value, minValue), maxValue)
end

local function GetSettings()
    if Nirnsteel_UI.Settings then
        return Nirnsteel_UI.Settings:GetCastBar()
    end

    return DEFAULT_SETTINGS
end

local function GetSettingValue(key)
    local settings = GetSettings()
    local value = settings and settings[key]
    if value == nil then
        return DEFAULT_SETTINGS[key]
    end

    return value
end

local function IsModuleEnabled()
    return not Nirnsteel_UI.Settings or Nirnsteel_UI.Settings:IsCastBarEnabled()
end

local function IsModuleUnlocked()
    return IsModuleEnabled()
        and Nirnsteel_UI.Settings
        and Nirnsteel_UI.Settings:IsCastBarUnlocked()
end

local function GetPosition()
    if Nirnsteel_UI.Settings then
        return Nirnsteel_UI.Settings:GetCastBarPosition()
    end

    return DEFAULT_POSITION
end

local function GetScale()
    return ClampNumber(GetSettingValue("scale"), 70, 160) / 100
end

local function GetConfiguredWidth()
    return ClampNumber(GetSettingValue("width"), MIN_WIDTH, MAX_WIDTH)
end

local function GetConfiguredHeight()
    return ClampNumber(GetSettingValue("height"), MIN_HEIGHT, MAX_HEIGHT)
end

local function GetAlpha()
    return ClampNumber(GetSettingValue("opacity"), 20, 100) / 100
end

local function GetIntensity()
    return ClampNumber(GetSettingValue("animationIntensity"), 0, 160) / 100
end

local function GetTextMode()
    return TEXT_MODE_ALIASES[GetSettingValue("textMode")] or "nameAndTime"
end

local function BuildTextFont(size, outline)
    return string.format("$(BOLD_FONT)|%d|%s", size, outline or "thick-outline")
end

local function ShouldShowIcon()
    return GetSettingValue("showIcon") ~= false
end

local function ShouldShowTicks()
    return GetSettingValue("showTicks") ~= false
end

local function IsWeaponAttackName(abilityName)
    if not abilityName or abilityName == "" then
        return false
    end

    local normalizedName = string.lower(abilityName)
    return string.find(normalizedName, "heavy attack", 1, true) ~= nil
        or string.find(normalizedName, "light attack", 1, true) ~= nil
        or string.find(normalizedName, "weapon attack", 1, true) ~= nil
end

local function IsHudSceneShowing()
    local hudShowing = HUD_SCENE and HUD_SCENE:IsShowing()
    local hudUiShowing = HUD_UI_SCENE and HUD_UI_SCENE:IsShowing()
    return hudShowing or hudUiShowing
end

local function FormatCastTime(elapsedMS, durationMS)
    local elapsed = math.max(0, elapsedMS or 0) / 1000
    local duration = math.max(0, durationMS or 0) / 1000
    return string.format("%.1f / %.1f", elapsed, duration)
end

-- One clock owns every animation phase so a previous cast cannot leave effects
-- or delayed callbacks behind when another ability is used.
local function EaseOut(progress)
    return 1 - (1 - zo_clamp(progress, 0, 1)) ^ 3
end

local function ConfigureStatusBar(bar)
    bar:SetTexture(BAR_TEXTURE)
    bar:SetTextureCoords(0, 1, 0, 0.8125)
    bar:EnableLeadingEdge(false)
    bar:SetPixelRoundingEnabled(false)
    bar:SetMinMax(0, 1)
    if bar.SetBarAlignment then
        bar:SetBarAlignment(BAR_ALIGNMENT_NORMAL)
    end
end

local function CreateBackdrop(parent, center, edge, thickness)
    local control = WINDOW_MANAGER:CreateControl(nil, parent, CT_BACKDROP)
    control:SetCenterColor(unpack(center))
    control:SetEdgeColor(unpack(edge))
    control:SetEdgeTexture(EDGE_FRAME_TEXTURE, 128, 16, thickness or 2, 0)
    return control
end

local function CreateTexture(parent, texture, r, g, b, alpha, level)
    local control = WINDOW_MANAGER:CreateControl(nil, parent, CT_TEXTURE)
    if texture then control:SetTexture(texture) end
    control:SetColor(r, g, b, alpha)
    control:SetDrawLayer(DL_OVERLAY)
    control:SetDrawLevel(level or 1)
    return control
end

function CastBar:GetRoot()
    if self.root then return self.root end

    local root = WINDOW_MANAGER:CreateTopLevelWindow("Nirnsteel_UI_CastBarRoot")
    root:SetClampedToScreen(true)
    root:SetMouseEnabled(false)
    root:SetMovable(false)
    root:SetDrawTier(DT_HIGH)
    root:SetHidden(true)

    local frame = WINDOW_MANAGER:CreateControl(nil, root, CT_CONTROL)
    frame:SetAnchorFill(root)
    root.frame = frame

    frame.track = CreateBackdrop(frame, { 0.018, 0.026, 0.035, 0.96 }, { 0.32, 0.40, 0.46, 0.95 })
    frame.shadow = CreateBackdrop(frame, { 0, 0, 0, 0.25 }, { 0, 0, 0, 0.65 }, 4)
    frame.shadow:SetAnchor(TOPLEFT, frame.track, TOPLEFT, -3, -2)
    frame.shadow:SetAnchor(BOTTOMRIGHT, frame.track, BOTTOMRIGHT, 3, 4)
    frame.shadow:SetDrawLayer(DL_BACKGROUND)

    frame.well = WINDOW_MANAGER:CreateControl(nil, frame.track, CT_CONTROL)
    frame.well:SetAnchor(TOPLEFT, frame.track, TOPLEFT, FRAME_PAD, FRAME_PAD)
    frame.well:SetAnchor(BOTTOMRIGHT, frame.track, BOTTOMRIGHT, -FRAME_PAD, -FRAME_PAD)

    frame.bar = WINDOW_MANAGER:CreateControl(nil, frame.well, CT_STATUSBAR)
    frame.bar:SetAnchorFill(frame.well)
    ConfigureStatusBar(frame.bar)
    frame.bar:SetDrawLayer(DL_CONTROLS)
    frame.bar:SetDrawLevel(1)

    frame.gloss = WINDOW_MANAGER:CreateControl(nil, frame.well, CT_STATUSBAR)
    frame.gloss:SetAnchorFill(frame.well)
    ConfigureStatusBar(frame.gloss)
    frame.gloss:SetTexture(BAR_GLOSS_TEXTURE)
    frame.gloss:SetColor(0.78, 0.90, 1, 0.16)
    frame.gloss:SetDrawLayer(DL_OVERLAY)
    frame.gloss:SetDrawLevel(0)

    -- The wake stays inside the filled section, never crossing unread progress.
    frame.wake = CreateTexture(frame.well, BAR_GLOSS_TEXTURE, 0.66, 0.88, 1, 1, 1)
    frame.leadingEdge = CreateTexture(frame.well, BAR_LEADING_EDGE_TEXTURE, 0.87, 0.96, 1, 1, 3)
    frame.leadingEdge:SetTextureCoords(0, 1, 0, 0.6)
    frame.leadingEdge:SetHidden(true)
    frame.wake:SetHidden(true)

    frame.chargeSweep = CreateTexture(frame.well, BAR_GLOSS_TEXTURE, 0.72, 0.94, 1, 1, 3)
    frame.chargeSweep:SetHidden(true)
    frame.feedbackFlash = WINDOW_MANAGER:CreateControl(nil, frame.well, CT_STATUSBAR)
    frame.feedbackFlash:SetAnchorFill(frame.well)
    ConfigureStatusBar(frame.feedbackFlash)
    frame.feedbackFlash:SetDrawLayer(DL_OVERLAY)
    frame.feedbackFlash:SetDrawLevel(4)
    frame.feedbackFlash:SetHidden(true)

    frame.castGlow = CreateBackdrop(frame, { 0, 0, 0, 0 }, { 0.34, 0.80, 1, 1 }, 4)
    frame.castGlow:SetAnchor(TOPLEFT, frame.track, TOPLEFT, -4, -4)
    frame.castGlow:SetAnchor(BOTTOMRIGHT, frame.track, BOTTOMRIGHT, 4, 4)
    frame.castGlow:SetDrawLayer(DL_OVERLAY)
    frame.castGlow:SetDrawLevel(0)
    frame.castGlow:SetHidden(true)

    frame.ticks = {}
    for index = 1, TICK_COUNT do
        frame.ticks[index] = CreateTexture(frame.well, nil, 0.65, 0.76, 0.84, 1, 2)
    end

    frame.finishGlow = CreateBackdrop(frame, { 0, 0, 0, 0 }, { 0.93, 0.76, 0.43, 1 }, 3)
    frame.finishGlow:SetAnchor(TOPLEFT, frame.track, TOPLEFT, -2, -2)
    frame.finishGlow:SetAnchor(BOTTOMRIGHT, frame.track, BOTTOMRIGHT, 2, 2)
    frame.finishGlow:SetDrawLayer(DL_OVERLAY)
    frame.finishGlow:SetAlpha(0)
    frame.finishGlow:SetHidden(true)
    frame.finishSweep = CreateTexture(frame.well, BAR_GLOSS_TEXTURE, 1, 0.91, 0.68, 1, 4)
    frame.finishSweep:SetHidden(true)

    frame.iconFrame = CreateBackdrop(frame, { 0.02, 0.026, 0.033, 1 }, { 0.42, 0.52, 0.60, 1 })
    frame.icon = WINDOW_MANAGER:CreateControl(nil, frame.iconFrame, CT_TEXTURE)
    frame.icon:SetAnchor(TOPLEFT, frame.iconFrame, TOPLEFT, 3, 3)
    frame.icon:SetAnchor(BOTTOMRIGHT, frame.iconFrame, BOTTOMRIGHT, -3, -3)
    frame.icon:SetTexture(FALLBACK_ICON)
    frame.icon:SetTextureCoords(0.08, 0.92, 0.08, 0.92)

    frame.iconGlow = CreateBackdrop(frame, { 0, 0, 0, 0 }, { 0.34, 0.80, 1, 1 }, 4)
    frame.iconGlow:SetAnchor(TOPLEFT, frame.iconFrame, TOPLEFT, -3, -3)
    frame.iconGlow:SetAnchor(BOTTOMRIGHT, frame.iconFrame, BOTTOMRIGHT, 3, 3)
    frame.iconGlow:SetDrawLayer(DL_BACKGROUND)
    frame.iconGlow:SetHidden(true)

    -- Keep the lettering readable when highlights pass underneath it.
    frame.textShade = CreateTexture(frame.well, nil, 0, 0, 0, 0.18, 5)
    frame.textShade:SetAnchorFill(frame.well)

    frame.leftLabel = WINDOW_MANAGER:CreateControl(nil, frame, CT_LABEL)
    frame.leftLabel:SetColor(0.88, 0.93, 0.96, 1)
    frame.leftLabel:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    frame.leftLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    frame.leftLabel:SetModifyTextType(MODIFY_TEXT_TYPE_NONE)
    frame.leftLabel:SetMaxLineCount(1)
    frame.leftLabel:SetDrawLayer(DL_OVERLAY)
    frame.leftLabel:SetDrawLevel(6)

    frame.rightLabel = WINDOW_MANAGER:CreateControl(nil, frame, CT_LABEL)
    frame.rightLabel:SetColor(0.65, 0.77, 0.85, 1)
    frame.rightLabel:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    frame.rightLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    frame.rightLabel:SetModifyTextType(MODIFY_TEXT_TYPE_NONE)
    frame.rightLabel:SetMaxLineCount(1)
    frame.rightLabel:SetDrawLayer(DL_OVERLAY)
    frame.rightLabel:SetDrawLevel(6)

    self.root = root
    return root
end

function CastBar:GetMover()
    if self.mover then
        return self.mover
    end

    local mover = WINDOW_MANAGER:CreateTopLevelWindow("Nirnsteel_UI_CastBarMover")
    mover:SetClampedToScreen(true)
    mover:SetMouseEnabled(true)
    mover:SetMovable(false)
    mover:SetDrawTier(DT_HIGH)
    mover:SetHidden(true)

    local backdrop = WINDOW_MANAGER:CreateControl(nil, mover, CT_BACKDROP)
    backdrop:SetAnchorFill(mover)
    backdrop:SetCenterColor(0.02, 0.02, 0.02, 0.38)
    backdrop:SetEdgeColor(0.12, 0.88, 1.00, 0.92)
    backdrop:SetEdgeTexture("", 1, 1, 2)

    local label = WINDOW_MANAGER:CreateControl(nil, mover, CT_LABEL)
    label:SetAnchor(CENTER, mover, CENTER, 0, 0)
    label:SetFont("ZoFontGameBold")
    label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    label:SetText("Nirnsteel Cast Bar")
    label:SetColor(0.74, 0.96, 1.00, 1)

    mover:SetHandler("OnMouseDown", function(control, button)
        if button == MOUSE_BUTTON_INDEX_LEFT then
            control:SetMovable(true)
            control:StartMoving()
        else
            control:SetMovable(false)
        end
    end)

    mover:SetHandler("OnMouseUp", function(control, button)
        if button == MOUSE_BUTTON_INDEX_LEFT then
            control:StopMovingOrResizing()
        end
        control:SetMovable(false)
    end)

    mover:SetHandler("OnMoveStop", function(control)
        control:SetMovable(false)
        local x = control:GetLeft() + (control:GetWidth() * 0.5) - (GuiRoot:GetWidth() * 0.5)
        local y = control:GetTop() + (control:GetHeight() * 0.5) - (GuiRoot:GetHeight() * 0.5)
        if Nirnsteel_UI.Settings then
            Nirnsteel_UI.Settings:SetCastBarPosition(x, y)
        end
        self:ApplyLayout()
    end)

    self.mover = mover
    return mover
end

function CastBar:ApplyTheme()
    local themes = Nirnsteel_UI.Themes
    if not themes or not self.root then return end
    local frame = self.root.frame
    frame.shadow:SetHidden(themes:IsMinimal())
    if self.phase == "complete" then
        themes:StyleRim(frame.track, "rim", 0.64, 0.55, 0.37, 1)
        themes:StyleRim(frame.iconFrame, "highlight", 0.77, 0.65, 0.43, 1)
    else
        themes:StyleRim(frame.track, "rim", 0.32, 0.40, 0.46, 0.95)
        themes:StyleRim(frame.iconFrame, "highlight", 0.42, 0.52, 0.60, 1)
    end
    frame.track:SetCenterColor(themes:Color("recess", 0.018, 0.026, 0.035, 0.96))
    frame.iconFrame:SetCenterColor(themes:Color("recess", 0.02, 0.026, 0.033, 1))
    themes:ApplySocket(frame.iconFrame)
    if Nirnsteel_UI.BarVisuals and Nirnsteel_UI.BarVisuals.ApplyRpgBorder then
        Nirnsteel_UI.BarVisuals:ApplyRpgBorder(frame.track, themes:GetId() == "bronze",
            frame.track:GetWidth(), frame.track:GetHeight(), 1)
    end
end

function CastBar:ApplyLayout()
    local root = self:GetRoot()
    local mover = self:GetMover()
    local frame = root.frame
    local width, height = GetConfiguredWidth(), GetConfiguredHeight()
    local textMode = GetTextMode()
    local iconSize = height
    local barLeft = ShouldShowIcon() and (iconSize + ICON_PAD) or 0
    local trackWidth = width - barLeft
    local timerWidth = math.min(100, math.max(86, math.floor(trackWidth * 0.43)))
    local labelInset = FRAME_PAD + 5
    local labelHeight = height - 4
    local nameFontSize = zo_clamp(height - 6, 12, 18)
    local timerFontSize = zo_clamp(height - 7, 11, 16)
    local position = GetPosition()

    root:SetDimensions(width, height)
    root:SetScale(GetScale())
    root:ClearAnchors()
    root:SetAnchor(CENTER, GuiRoot, CENTER, position.x, position.y)

    mover:SetDimensions(width, height)
    mover:SetScale(GetScale())
    mover:ClearAnchors()
    mover:SetAnchor(CENTER, GuiRoot, CENTER, position.x, position.y)
    mover:SetHidden(not IsModuleUnlocked())

    frame.track:ClearAnchors()
    frame.track:SetAnchor(LEFT, frame, LEFT, barLeft, 0)
    frame.track:SetDimensions(trackWidth, height)
    self.trackWidth = trackWidth - FRAME_PAD * 2
    self.trackHeight = height - FRAME_PAD * 2

    frame.iconFrame:ClearAnchors()
    frame.iconFrame:SetDimensions(iconSize, iconSize)
    frame.iconFrame:SetAnchor(LEFT, frame, LEFT, 0, 0)
    frame.iconFrame:SetHidden(not ShouldShowIcon())

    frame.leftLabel:ClearAnchors()
    frame.leftLabel:SetAnchor(LEFT, frame.track, LEFT, labelInset, 2)
    frame.leftLabel:SetDimensions(textMode == "nameOnly" and trackWidth - labelInset * 2
        or trackWidth - timerWidth - labelInset * 2 - 8, labelHeight)
    frame.leftLabel:SetFont(BuildTextFont(nameFontSize))
    frame.rightLabel:ClearAnchors()
    frame.rightLabel:SetAnchor(RIGHT, frame.track, RIGHT, -labelInset, 2)
    frame.rightLabel:SetDimensions(textMode == "timerOnly" and trackWidth - labelInset * 2 or timerWidth, labelHeight)
    frame.rightLabel:SetFont(BuildTextFont(timerFontSize))
    frame.leftLabel:SetHidden(textMode == "off" or textMode == "timerOnly")
    frame.rightLabel:SetHidden(textMode == "off" or textMode == "nameOnly")
    frame.textShade:SetHidden(textMode == "off")

    for index, tick in ipairs(frame.ticks) do
        tick:ClearAnchors()
        tick:SetAnchor(CENTER, frame.well, LEFT, self.trackWidth * index / (TICK_COUNT + 1), 0)
        tick:SetDimensions(1, self.trackHeight)
        tick:SetHidden(not ShouldShowTicks())
    end
    self:UpdateText(self.elapsedMS or 0)
    if self.phase then self:UpdateAnimation() else root:SetAlpha(GetAlpha()) end
    self:ApplyTheme()
end

function CastBar:UpdateText(elapsedMS)
    local frame = self:GetRoot().frame
    local textMode = GetTextMode()
    frame.leftLabel:SetText((textMode == "off" or textMode == "timerOnly") and "" or (self.abilityName or ""))
    frame.rightLabel:SetText((textMode == "off" or textMode == "nameOnly") and ""
        or FormatCastTime(elapsedMS or 0, self.durationMS or 0))
end

function CastBar:ResetFeedback()
    local frame = self:GetRoot().frame
    frame.wake:SetHidden(true)
    frame.leadingEdge:SetHidden(true)
    frame.chargeSweep:SetHidden(true)
    frame.feedbackFlash:SetHidden(true)
    frame.castGlow:SetHidden(true)
    frame.iconGlow:SetHidden(true)
    frame.finishSweep:SetHidden(true)
    frame.finishGlow:SetHidden(true)
    frame.finishGlow:SetAlpha(0)
    frame.iconGlow:SetEdgeColor(0.34, 0.80, 1, 1)
    frame.track:SetEdgeColor(0.32, 0.40, 0.46, 0.95)
    frame.iconFrame:SetEdgeColor(0.42, 0.52, 0.60, 1)
    frame.rightLabel:SetColor(0.82, 0.92, 0.98, 1)
    frame.bar:SetGradientColors(0.16, 0.32, 0.44, 1, 0.50, 0.73, 0.85, 1)
    self:ApplyTheme()
end

function CastBar:SetProgress(progress)
    local frame = self:GetRoot().frame
    progress = zo_clamp(progress, 0, 1)
    frame.bar:SetValue(progress)
    frame.gloss:SetValue(progress)
    for index, tick in ipairs(frame.ticks) do
        local threshold = index / (TICK_COUNT + 1)
        -- Derive each pulse from the deadline: no queued flashes after a hitch.
        local age = (self.elapsedMS or 0) - (self.durationMS or 0) * threshold
        local pulse = self.phase == "casting" and age >= 0 and age < TICK_FLASH_MS
            and (1 - age / TICK_FLASH_MS) or 0
        tick:SetAlpha(zo_clamp((progress >= threshold and 0.40 or 0.16) + pulse * 0.60 * GetIntensity(), 0, 1))
        tick:SetDimensions(1 + 3 * pulse * GetIntensity(), self.trackHeight)
    end
end

function CastBar:Hide(immediate)
    local root = self:GetRoot()
    self.active = false
    if immediate then
        self.castId = (self.castId or 0) + 1
        self.phase = nil
        self.previewActive = nil
        root:SetHandler("OnUpdate", nil)
        root:SetAlpha(0)
        root:SetHidden(true)
        self:ResetFeedback()
    elseif self.phase ~= "exit" and not root:IsHidden() then
        self.phase = "exit"
        self.phaseStartMS = GetFrameTimeMilliseconds()
        self.exitAlpha = root:GetAlpha()
        self:ResetFeedback()
    end
end

function CastBar:Complete(castId)
    if (castId and castId ~= self.castId) or self.phase ~= "casting" then return end
    self.active = false
    self.phase = "complete"
    -- Use the cast deadline so low frame rates cannot lengthen the celebration.
    self.phaseStartMS = self.endMS
    self.elapsedMS = self.durationMS
    self:SetProgress(1)
    self:UpdateText(self.durationMS)
    local frame = self:GetRoot().frame
    frame.wake:SetHidden(true)
    frame.leadingEdge:SetHidden(true)
    frame.chargeSweep:SetHidden(true)
    frame.castGlow:SetHidden(true)
    frame.bar:SetGradientColors(0.35, 0.30, 0.20, 1, 0.86, 0.73, 0.46, 1)
    frame.track:SetEdgeColor(0.64, 0.55, 0.37, 1)
    frame.iconFrame:SetEdgeColor(0.77, 0.65, 0.43, 1)
    frame.iconGlow:SetEdgeColor(1, 0.78, 0.38, 1)
    frame.rightLabel:SetColor(0.92, 0.81, 0.58, 1)
    self:ApplyTheme()
end

function CastBar:UpdateAnimation()
    local root = self:GetRoot()
    if not self.phase then return end
    if not IsModuleEnabled() or (not self.previewActive and not IsHudSceneShowing()) then
        self:Hide(true)
        return
    end

    local frame = root.frame
    local now = GetFrameTimeMilliseconds()
    local intensity = GetIntensity()
    local width, height = self.trackWidth, self.trackHeight
    if self.phase == "casting" then
        self.elapsedMS = zo_clamp(now - self.startMS, 0, self.durationMS)
        local progress = self.elapsedMS / self.durationMS
        self:SetProgress(progress)
        self:UpdateText(self.elapsedMS)
        local entrance = intensity == 0 and 1 or EaseOut(self.elapsedMS / ENTER_MS)
        root:SetAlpha(GetAlpha() * (0.55 + 0.45 * entrance))
        local filledWidth = width * progress
        local breath = 0.5 + 0.5 * math.sin(self.elapsedMS / 1000 * math.pi * 2 / 0.85)
        local edgeWidth = math.min(3 + (3 + breath * 3) * intensity, filledWidth)
        frame.leadingEdge:SetHidden(filledWidth < 1)
        frame.leadingEdge:SetDimensions(edgeWidth, height)
        frame.leadingEdge:ClearAnchors()
        frame.leadingEdge:SetAnchor(LEFT, frame.well, LEFT, math.max(0, filledWidth - edgeWidth), 0)
        frame.leadingEdge:SetAlpha(zo_clamp(0.82 + breath * 0.18 * intensity, 0, 1))

        local wakeWidth = math.min(filledWidth, 48 + intensity * (20 + breath * 12))
        frame.wake:SetDimensions(wakeWidth, height)
        frame.wake:ClearAnchors()
        frame.wake:SetAnchor(LEFT, frame.well, LEFT, filledWidth - wakeWidth, 0)
        frame.wake:SetAlpha(zo_clamp((0.30 + 0.22 * breath) * intensity, 0, 1))
        frame.wake:SetHidden(intensity == 0 or filledWidth < 1)

        local startPulse = (1 - zo_clamp(self.elapsedMS / 280, 0, 1)) ^ 2
        frame.castGlow:SetHidden(intensity == 0)
        frame.castGlow:SetAlpha(zo_clamp((0.22 + breath * 0.26 + startPulse * 0.55) * intensity, 0, 1))
        frame.iconGlow:SetHidden(intensity == 0 or not ShouldShowIcon())
        frame.iconGlow:SetAlpha(zo_clamp((0.28 + breath * 0.32 + startPulse * 0.40) * intensity, 0, 1))
        frame.feedbackFlash:SetHidden(intensity == 0 or startPulse == 0)
        frame.feedbackFlash:SetValue(progress)
        frame.feedbackFlash:SetColor(0.65, 0.91, 1, 1)
        frame.feedbackFlash:SetAlpha(zo_clamp(startPulse * 0.55 * intensity, 0, 1))

        -- Repeating light travels through the charge, beneath the outlined text.
        local sweepProgress = (self.elapsedMS % 900) / 900
        local sweepWidth = math.min(filledWidth, 38 + intensity * 18)
        frame.chargeSweep:SetDimensions(sweepWidth, height)
        frame.chargeSweep:ClearAnchors()
        frame.chargeSweep:SetAnchor(LEFT, frame.well, LEFT, (filledWidth - sweepWidth) * sweepProgress, 0)
        frame.chargeSweep:SetAlpha(zo_clamp(math.sin(sweepProgress * math.pi) * 0.46 * intensity, 0, 1))
        frame.chargeSweep:SetHidden(intensity == 0 or filledWidth < 1)
        if progress >= 1 then self:Complete(self.castId) end
    end

    if self.phase == "complete" then
        local elapsed = math.max(0, now - self.phaseStartMS)
        local progress = zo_clamp(elapsed / COMPLETE_HOLD_MS, 0, 1)
        root:SetAlpha(GetAlpha())
        local impact = (1 - zo_clamp(elapsed / 180, 0, 1)) ^ 2
        frame.feedbackFlash:SetHidden(intensity == 0 or impact == 0)
        frame.feedbackFlash:SetValue(1)
        frame.feedbackFlash:SetColor(1, 0.87, 0.54, 1)
        frame.feedbackFlash:SetAlpha(zo_clamp(impact * 0.72 * intensity, 0, 1))
        frame.finishGlow:SetHidden(intensity == 0)
        local expansion = 2 + 9 * EaseOut(progress) * intensity
        frame.finishGlow:ClearAnchors()
        frame.finishGlow:SetAnchor(TOPLEFT, frame.track, TOPLEFT, -expansion, -expansion)
        frame.finishGlow:SetAnchor(BOTTOMRIGHT, frame.track, BOTTOMRIGHT, expansion, expansion)
        frame.finishGlow:SetAlpha(zo_clamp((1 - progress) * 0.95 * intensity, 0, 1))
        frame.iconGlow:SetHidden(intensity == 0 or not ShouldShowIcon())
        frame.iconGlow:SetAlpha(zo_clamp((1 - progress) * intensity, 0, 1))
        local sweepWidth = math.min(width, 72)
        frame.finishSweep:SetDimensions(sweepWidth, height)
        frame.finishSweep:ClearAnchors()
        frame.finishSweep:SetAnchor(LEFT, frame.well, LEFT, (width - sweepWidth) * EaseOut(progress), 0)
        frame.finishSweep:SetAlpha(zo_clamp(math.sin(progress * math.pi) * 0.72 * intensity, 0, 1))
        frame.finishSweep:SetHidden(intensity == 0)
        if elapsed >= COMPLETE_HOLD_MS then
            self.phase = "exit"
            self.phaseStartMS = self.endMS + COMPLETE_HOLD_MS
            self.exitAlpha = GetAlpha()
            frame.finishGlow:SetHidden(true)
            frame.finishSweep:SetHidden(true)
            frame.feedbackFlash:SetHidden(true)
            frame.iconGlow:SetHidden(true)
        end
    end

    if self.phase == "exit" then
        local progress = zo_clamp((now - self.phaseStartMS) / FADE_OUT_MS, 0, 1)
        root:SetAlpha(math.min(self.exitAlpha or GetAlpha(), GetAlpha()) * (1 - EaseOut(progress)))
        if progress >= 1 then self:Hide(true) end
    end
end

function CastBar:StartCast(abilityId, abilityName, iconTexture, durationMS, preview)
    durationMS = tonumber(durationMS) or 0
    if durationMS < MIN_DURATION_MS or not IsModuleEnabled() or (not preview and not IsHudSceneShowing()) then return end

    self:Hide(true)
    -- Settings hide the HUD scenes; only the sample cast may run there.
    self.previewActive = preview == true or nil
    self.castId = (self.castId or 0) + 1
    self.abilityId = abilityId
    self.abilityName = abilityName and abilityName ~= "" and abilityName or "Unknown Ability"
    self.iconTexture = iconTexture and iconTexture ~= "" and iconTexture or FALLBACK_ICON
    self.durationMS = durationMS
    self.elapsedMS = 0
    self.startMS = GetFrameTimeMilliseconds()
    self.endMS = self.startMS + durationMS
    self:ApplyLayout()
    self.active = true
    self.phase = "casting"
    local root = self:GetRoot()
    root.frame.icon:SetTexture(self.iconTexture)
    root:SetHidden(false)
    root:SetHandler("OnUpdate", function() self:UpdateAnimation() end)
    self:UpdateAnimation()
end

function CastBar:OnActionSlotAbilityUsed(actionSlotIndex)
    if not IsModuleEnabled() or not IsHudSceneShowing() or not actionSlotIndex then
        return
    end

    local slotType = GetSlotType(actionSlotIndex)
    if slotType ~= ACTION_TYPE_ABILITY and slotType ~= ACTION_TYPE_CRAFTED_ABILITY then
        return
    end

    local abilityId = GetSlotBoundId(actionSlotIndex)
    if not abilityId or abilityId == 0 then
        return
    end

    local abilityName = GetSlotName(actionSlotIndex)
    if IsWeaponAttackName(abilityName) then
        return
    end

    local channeled, durationMS = GetAbilityCastInfo(abilityId, nil, "player")
    if channeled == nil or not durationMS or durationMS <= 0 then
        return
    end

    local iconTexture = GetSlotTexture(actionSlotIndex)
    self:StartCast(abilityId, abilityName, iconTexture, durationMS)
end

function CastBar:SetSettingsPreviewActive(active)
    if active then
        self:Preview()
    else
        self:Hide(true)
    end
end

function CastBar:Preview()
    self:StartCast(0, "Nirnsteel Power", FALLBACK_ICON, 3200, true)
end

function CastBar:UpdateVisibility()
    if not IsModuleEnabled() or (not self.previewActive and not IsHudSceneShowing()) then
        self:Hide(true)
    end
end

function CastBar:RegisterEvents()
    if self.eventsRegistered then
        return
    end

    EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE, EVENT_ACTION_SLOT_ABILITY_USED, function(_, actionSlotIndex)
        self:OnActionSlotAbilityUsed(actionSlotIndex)
    end)
    EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE .. "_Activated", EVENT_PLAYER_ACTIVATED, function()
        self:ApplyLayout()
        self:UpdateVisibility()
    end)
    EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE .. "_ScreenResized", EVENT_SCREEN_RESIZED, function()
        self:ApplyLayout()
    end)
    EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE .. "_Gamepad", EVENT_GAMEPAD_PREFERRED_MODE_CHANGED, function()
        self:ApplyLayout()
    end)

    if HUD_SCENE then
        HUD_SCENE:RegisterCallback("StateChange", function()
            self:UpdateVisibility()
        end)
    end

    if HUD_UI_SCENE then
        HUD_UI_SCENE:RegisterCallback("StateChange", function()
            self:UpdateVisibility()
        end)
    end

    self.eventsRegistered = true
end

function CastBar:RefreshSettings()
    self:RegisterEvents()
    self:ApplyLayout()

    if not IsModuleEnabled() then
        self:Hide(true)
        self:GetMover():SetHidden(true)
    else
        self:GetMover():SetHidden(not IsModuleUnlocked())
    end
end

local DEBUG_COMMANDS =
{
    ["/nscastbar"] = function()
        CastBar:Preview()
    end,
}

local function IsDebugModeEnabled()
    return Nirnsteel_UI.Settings and Nirnsteel_UI.Settings:IsDebugModeEnabled()
end

local function RegisterDebugCommands()
    for command, handler in pairs(DEBUG_COMMANDS) do
        SLASH_COMMANDS[command] = IsDebugModeEnabled() and handler or nil
    end
end

function CastBar:RefreshDebugCommands()
    RegisterDebugCommands()
end

local function OnAddOnLoaded(_, addonName)
    if addonName ~= ADDON_NAME then
        return
    end

    EVENT_MANAGER:UnregisterForEvent(EVENT_NAMESPACE .. "_Loaded", EVENT_ADD_ON_LOADED)
    CastBar:RefreshSettings()
    RegisterDebugCommands()
end

EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE .. "_Loaded", EVENT_ADD_ON_LOADED, OnAddOnLoaded)
