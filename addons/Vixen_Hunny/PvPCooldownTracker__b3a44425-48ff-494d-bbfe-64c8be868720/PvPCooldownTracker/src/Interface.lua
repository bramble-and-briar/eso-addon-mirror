-- -----------------------------------------------------------------------------
-- PvPCooldownTracker
-- Author:  @VixenHunny
-- Edited: 4/15/2026
--
-- Interface.lua
-- On-screen tracker cards: icon, name, countdown, progress bar, glow, and the
-- floating proc / ready announcement.
-- -----------------------------------------------------------------------------
PvPCooldownTracker = PvPCooldownTracker or {}
PvPCooldownTracker.UI = {}
PvPCooldownTracker.UI.scaleBase = 100

local scaleBase = PvPCooldownTracker.UI.scaleBase
local PCT = PvPCooldownTracker
local WM = WINDOW_MANAGER
local AM = ANIMATION_MANAGER

local CONTAINER_SUFFIX = "_Container"
local TEXTURE_SUFFIX = "_Texture"
local FRAME_SUFFIX = "_Frame"
local LABEL_SUFFIX = "_Label"
local GLOW_SUFFIX = "_Glow"
local NAME_LABEL_SUFFIX = "_NameLabel"
local BAR_BG_SUFFIX = "_BarBG"
local BAR_FILL_SUFFIX = "_BarFill"
local CARD_SUFFIX = "_Card"
local ACCENT_SUFFIX = "_Accent"
local ICON_BG_SUFFIX = "_IconBG"
local FLASH_SUFFIX = "_Flash"

-- Bar layout (unscaled units; the whole card is scaled by the per-set size)
local UI_WIDTH = 340
local UI_HEIGHT = 76
local ICON_SIZE = 56
local ICON_BORDER = 2
local ICON_OFFSET_X = 14
local CONTENT_X = 86
local CONTENT_PAD_RIGHT = 12
local CONTENT_WIDTH = UI_WIDTH - CONTENT_X - CONTENT_PAD_RIGHT
local TIMER_WIDTH = 92
local BAR_HEIGHT = 14
local BAR_OFFSET_BOTTOM = 13
local ACCENT_WIDTH = 4

-- Icon-only layout
local COMPACT_SIZE = 76
local COMPACT_ICON_SIZE = 64

local MISSING_ICON = "/esoui/art/icons/icon_missing.dds"
local GLOW_TEXTURE = "/esoui/art/actionbar/abilityhighlight_round.dds"
local BAR_TEXTURE = "/esoui/art/miscellaneous/progressbar_genericfill.dds"

local GLOW_ALPHA_READY = 0.50
local GLOW_ALPHA_COOLDOWN = 0.12

local FALLBACK = {
    labelColor         = { 0.96, 0.93, 0.88, 1.0 },
    timerColor         = { 1.0, 0.97, 0.91, 1.0 },
    cooldownTint       = { 0.62, 0.60, 0.58, 1.0 },
    glowColor          = { 1.0, 0.55, 0.20, 1.0 },
    barBackgroundColor = { 0.0, 0.0, 0.0, 0.55 },
    barFillColor       = { 0.95, 0.45, 0.15, 1.0 },
    barReadyColor      = { 0.36, 0.80, 0.36, 1.0 },
    cardColor          = { 0.05, 0.05, 0.07, 0.78 },
}

-- -----------------------------------------------------------------------------
-- Colour themes. Picking one overwrites the style colours; players can still
-- fine-tune every colour afterwards in the settings menu.
-- -----------------------------------------------------------------------------
PvPCooldownTracker.UI.Themes = {
    {
        name = "Ember",
        barFillColor  = { 0.95, 0.45, 0.15, 1.0 },
        barReadyColor = { 0.36, 0.80, 0.36, 1.0 },
        glowColor     = { 1.0, 0.55, 0.20, 1.0 },
        labelColor    = { 0.96, 0.93, 0.88, 1.0 },
        timerColor    = { 1.0, 0.97, 0.91, 1.0 },
        cardColor     = { 0.06, 0.05, 0.05, 0.78 },
    },
    {
        name = "Frost",
        barFillColor  = { 0.22, 0.56, 0.96, 1.0 },
        barReadyColor = { 0.45, 0.92, 0.88, 1.0 },
        glowColor     = { 0.40, 0.75, 1.0, 1.0 },
        labelColor    = { 0.90, 0.95, 1.0, 1.0 },
        timerColor    = { 0.96, 0.99, 1.0, 1.0 },
        cardColor     = { 0.04, 0.06, 0.09, 0.78 },
    },
    {
        name = "Venom",
        barFillColor  = { 0.60, 0.30, 0.90, 1.0 },
        barReadyColor = { 0.50, 0.90, 0.30, 1.0 },
        glowColor     = { 0.72, 0.42, 1.0, 1.0 },
        labelColor    = { 0.94, 0.90, 1.0, 1.0 },
        timerColor    = { 0.98, 0.96, 1.0, 1.0 },
        cardColor     = { 0.06, 0.04, 0.09, 0.78 },
    },
    {
        name = "Blood",
        barFillColor  = { 0.80, 0.14, 0.16, 1.0 },
        barReadyColor = { 0.95, 0.88, 0.78, 1.0 },
        glowColor     = { 1.0, 0.25, 0.22, 1.0 },
        labelColor    = { 0.97, 0.92, 0.90, 1.0 },
        timerColor    = { 1.0, 0.96, 0.94, 1.0 },
        cardColor     = { 0.08, 0.03, 0.03, 0.80 },
    },
    {
        name = "Gold",
        barFillColor  = { 0.84, 0.64, 0.18, 1.0 },
        barReadyColor = { 1.0, 0.93, 0.62, 1.0 },
        glowColor     = { 1.0, 0.82, 0.35, 1.0 },
        labelColor    = { 0.98, 0.94, 0.82, 1.0 },
        timerColor    = { 1.0, 0.97, 0.88, 1.0 },
        cardColor     = { 0.07, 0.06, 0.03, 0.78 },
    },
    {
        name = "Mono",
        barFillColor  = { 0.55, 0.57, 0.60, 1.0 },
        barReadyColor = { 0.95, 0.96, 0.98, 1.0 },
        glowColor     = { 0.90, 0.92, 0.95, 1.0 },
        labelColor    = { 0.92, 0.93, 0.95, 1.0 },
        timerColor    = { 1.0, 1.0, 1.0, 1.0 },
        cardColor     = { 0.04, 0.04, 0.05, 0.80 },
    },
}

local THEME_COLOR_KEYS = {
    "barFillColor", "barReadyColor", "glowColor", "labelColor", "timerColor", "cardColor",
}

-- Per-set control cache: [setKey] = { container = ..., texture = ..., ... }
local controlCache = {}
-- Per-set animation timelines: [setKey] = { flash = timeline, pulse = timeline }
local timelines = {}

local function GetControl(setKey, suffix)
    return WM:GetControlByName(setKey .. suffix)
end

local function GetSavedVars()
    if PCT.Settings and type(PCT.Settings.EnsureState) == "function" then
        return PCT.Settings.EnsureState()
    end

    if type(PCT.EnsureSavedVariables) == "function" then
        local savedVars = PCT.EnsureSavedVariables()
        return savedVars or {}
    end

    return PCT.savedVars or {}
end

local function IsStateContainer(value)
    if type(PCT.IsStateContainer) == "function" then
        return PCT.IsStateContainer(value)
    end

    local valueType = type(value)
    return value ~= nil and (valueType == "table" or valueType == "userdata")
end

local function GetStyleTable()
    local savedVars = GetSavedVars()
    local style = savedVars.style
    if not IsStateContainer(style) then
        return nil
    end
    return style
end

-- Returns r, g, b, a for a style colour, falling back to the built-in palette.
local function StyleColor(style, key)
    local color = style and style[key]
    if type(color) ~= "table" or tonumber(color[1]) == nil then
        color = FALLBACK[key]
    end
    return tonumber(color[1]) or 1, tonumber(color[2]) or 1, tonumber(color[3]) or 1, tonumber(color[4]) or 1
end

local function Lighten(r, g, b, amount)
    return r + (1 - r) * amount, g + (1 - g) * amount, b + (1 - b) * amount
end

local function IsCompact(style)
    return style ~= nil and style.layout == "icon"
end

local function GetSetSavedVars(setKey)
    local savedVars = GetSavedVars()
    local saved = savedVars.sets and savedVars.sets[setKey]
    if saved == nil and PCT.Settings and type(PCT.Settings.EnsureSetSavedVars) == "function" then
        saved = PCT.Settings.EnsureSetSavedVars(setKey)
    end
    return saved, savedVars
end

local function SetBarColor(barFill, r, g, b, a)
    if type(barFill.SetGradientColors) == "function" then
        local lr, lg, lb = Lighten(r, g, b, 0.35)
        barFill:SetGradientColors(r, g, b, a, lr, lg, lb, a)
    else
        barFill:SetColor(r, g, b, a)
    end
end

local function ApplyNameLabelStyle(nameLabel)
    local savedVars = GetSavedVars()
    local r, g, b, a = StyleColor(GetStyleTable(), "labelColor")
    nameLabel:SetColor(r, g, b, a)
    nameLabel:SetFont(savedVars.labelFont or "$(BOLD_FONT)|18|soft-shadow-thick")
    nameLabel:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    nameLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    nameLabel:SetPixelRoundingEnabled(true)
    if type(nameLabel.SetWrapMode) == "function" and TEXT_WRAP_MODE_ELLIPSIS ~= nil then
        nameLabel:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    end
    if type(nameLabel.SetMaxLineCount) == "function" then
        nameLabel:SetMaxLineCount(1)
    end
end

local function ApplyTimerLabelStyle(label, compact)
    local savedVars = GetSavedVars()
    local r, g, b, a = StyleColor(GetStyleTable(), "timerColor")
    label:SetColor(r, g, b, a)
    label:SetFont(savedVars.timerFont or "$(BOLD_FONT)|22|soft-shadow-thick")
    label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    label:SetHorizontalAlignment(compact and TEXT_ALIGN_CENTER or TEXT_ALIGN_RIGHT)
    label:SetPixelRoundingEnabled(true)
end

local function SnapToGrid(position, gridSize)
    -- Round down
    position = math.floor(position)
    gridSize = math.max(1, tonumber(gridSize) or 1)

    -- Return value to closest grid point
    if (position % gridSize >= gridSize / 2) then
        return position + (gridSize - (position % gridSize))
    else
        return position - (position % gridSize)
    end
end

local function SetPosition(key, left, top)
    local context = GetControl(key, CONTAINER_SUFFIX)
    if context == nil then return end
    context:ClearAnchors()
    context:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, left, top)
end

local function SavePosition(key)
    local savedVars = GetSavedVars()
    local context = GetControl(key, CONTAINER_SUFFIX)
    if context == nil then return end
    local top   = context:GetTop()
    local left  = context:GetLeft()

    if savedVars.snapToGrid then
        local gridSize = savedVars.gridSize
        top = SnapToGrid(top, gridSize)
        left = SnapToGrid(left, gridSize)
        SetPosition(key, left, top)
    end

    PCT:Trace(2, "Saving position for <<1>> - Left: <<2>> Top: <<3>>", key, left, top)

    if savedVars.sets and savedVars.sets[key] then
        savedVars.sets[key].x = left
        savedVars.sets[key].y = top
    end
end

-- -----------------------------------------------------------------------------
-- Animations
-- -----------------------------------------------------------------------------
local function GetTimelines(key)
    if timelines[key] == nil then
        timelines[key] = {}
    end
    return timelines[key]
end

-- Quick white flash across the whole card when the proc fires.
local function PlayProcFlash(key)
    local c = controlCache[key]
    if not c or not c.flash then return end

    local set = GetTimelines(key)
    if set.flash == nil then
        local timeline = AM:CreateTimeline()
        local fade = timeline:InsertAnimation(ANIMATION_ALPHA, c.flash, 0)
        fade:SetAlphaValues(1, 0)
        fade:SetDuration(450)
        fade:SetEasingFunction(ZO_EaseOutCubic)
        timeline:SetHandler("OnStop", function() c.flash:SetAlpha(0) end)
        set.flash = timeline
    end

    set.flash:PlayFromStart()
end

-- Glow pulse around the icon when the cooldown is ready again.
local function PlayReadyPulse(key)
    local c = controlCache[key]
    if not c or not c.glow then return end

    local set = GetTimelines(key)
    if set.pulse == nil then
        local timeline = AM:CreateTimeline()
        local pulse = timeline:InsertAnimation(ANIMATION_ALPHA, c.glow, 0)
        pulse:SetAlphaValues(GLOW_ALPHA_READY, 1)
        pulse:SetDuration(280)
        pulse:SetEasingFunction(ZO_EaseOutQuadratic)
        timeline:SetPlaybackType(ANIMATION_PLAYBACK_PING_PONG, 4)
        timeline:SetHandler("OnStop", function()
            local data = PCT.Data.Sets[key]
            c.glow:SetAlpha((data and data.onCooldown) and GLOW_ALPHA_COOLDOWN or GLOW_ALPHA_READY)
        end)
        set.pulse = timeline
    end

    set.pulse:PlayFromStart()
end

local function StopPulse(key)
    local set = timelines[key]
    if set and set.pulse and set.pulse:IsPlaying() then
        set.pulse:Stop()
    end
end

-- -----------------------------------------------------------------------------
-- Floating announcement ("<Set> Cooling Down" / "<Set> Ready!")
-- One shared label, positioned by the Label X/Y settings.
-- -----------------------------------------------------------------------------
local announceWindow, announceLabel, announceTimeline

local function GetAnnounceScale(savedVars)
    local scale = tonumber(savedVars.labelSize) or 1.5
    return math.max(0.5, math.min(4, scale))
end

local function AnchorAnnouncement()
    if not announceWindow then return end
    local savedVars = GetSavedVars()
    local labelLocation = savedVars.LabelLocation or {}

    announceWindow:ClearAnchors()
    announceWindow:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT,
        tonumber(labelLocation.x) or 600, tonumber(labelLocation.y) or 300)
    announceWindow:SetScale(GetAnnounceScale(savedVars))

    announceLabel:ClearAnchors()
    announceLabel:SetAnchor(TOPLEFT, announceWindow, TOPLEFT, 0, 0)
end

local function Announce(text)
    local savedVars = GetSavedVars()
    local style = GetStyleTable()
    if style and style.showAnnouncements == false then return end
    if PCT.HUDHidden and not PCT.ForceShow then return end

    if announceWindow == nil then
        announceWindow = WM:CreateTopLevelWindow("PvPCooldownTracker_Announce")
        announceWindow:SetDimensions(700, 40)
        announceWindow:SetMouseEnabled(false)
        announceWindow:SetHidden(false)

        announceLabel = WM:CreateControl("PvPCooldownTracker_AnnounceLabel", announceWindow, CT_LABEL)
        announceLabel:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
        announceLabel:SetVerticalAlignment(TEXT_ALIGN_TOP)
        announceLabel:SetPixelRoundingEnabled(true)

        announceTimeline = AM:CreateTimeline()
        local slide = announceTimeline:InsertAnimation(ANIMATION_TRANSLATE, announceLabel, 0)
        slide:SetTranslateOffsets(0, 0, 0, -90)
        slide:SetDuration(1300)
        slide:SetEasingFunction(ZO_EaseOutCubic)

        local fade = announceTimeline:InsertAnimation(ANIMATION_ALPHA, announceLabel, 500)
        fade:SetAlphaValues(1, 0)
        fade:SetDuration(800)
        fade:SetEasingFunction(ZO_EaseInCubic)

        announceTimeline:SetHandler("OnStop", function()
            announceLabel:SetText("")
            announceLabel:SetAlpha(1)
            AnchorAnnouncement()
        end)
    end

    if announceTimeline:IsPlaying() then
        announceTimeline:Stop()
    end

    AnchorAnnouncement()
    announceLabel:SetFont(savedVars.labelFont or "$(BOLD_FONT)|18|soft-shadow-thick")
    announceLabel:SetAlpha(1)
    announceLabel:SetText(text)
    announceTimeline:PlayFromStart()
end

-- -----------------------------------------------------------------------------
-- State visuals
-- -----------------------------------------------------------------------------
local function ShowReady(key, compact)
    local c = controlCache[key]
    if not c then return end
    local style = GetStyleTable()
    local r, g, b, a = StyleColor(style, "barReadyColor")

    c.texture:SetColor(1, 1, 1, 1)
    if type(c.texture.SetDesaturation) == "function" then
        c.texture:SetDesaturation(0)
    end

    SetBarColor(c.barFill, r, g, b, a)
    c.barFill:SetValue(1)

    c.accent:SetCenterColor(r, g, b, 1)
    c.card:SetEdgeColor(r, g, b, 0.45)
    c.iconBg:SetEdgeColor(r, g, b, 0.85)

    c.glow:SetColor(r, g, b, 1)
    local set = timelines[key]
    if not (set and set.pulse and set.pulse:IsPlaying()) then
        c.glow:SetAlpha(GLOW_ALPHA_READY)
    end

    if compact then
        c.label:SetText("")
    else
        local lr, lg, lb = Lighten(r, g, b, 0.25)
        c.label:SetColor(lr, lg, lb, 1)
        c.label:SetText("READY")
    end

    c.state = "ready"
end

local function ShowCooldown(key, set, countdown)
    local c = controlCache[key]
    if not c then return end

    -- Static visuals only need to be applied when the state flips.
    if c.state ~= "cooldown" then
        local style = GetStyleTable()
        local r, g, b, a = StyleColor(style, "barFillColor")
        local tr, tg, tb, ta = StyleColor(style, "cooldownTint")
        local gr, gg, gb = StyleColor(style, "glowColor")

        StopPulse(key)

        c.texture:SetColor(tr, tg, tb, ta)
        if type(c.texture.SetDesaturation) == "function" then
            c.texture:SetDesaturation(0.6)
        end

        SetBarColor(c.barFill, r, g, b, a)
        c.accent:SetCenterColor(r, g, b, 1)
        c.card:SetEdgeColor(r, g, b, 0.35)
        c.iconBg:SetEdgeColor(0, 0, 0, 0.9)

        c.glow:SetColor(gr, gg, gb, 1)
        c.glow:SetAlpha(GLOW_ALPHA_COOLDOWN)

        local lr, lg, lb, la = StyleColor(style, "timerColor")
        c.label:SetColor(lr, lg, lb, la)

        c.state = "cooldown"
    end

    local countdownText
    if countdown < 10 then
        countdownText = string.format("%.1f", countdown)
    else
        countdownText = tostring(math.floor(countdown + 0.5))
    end
    c.label:SetText(countdownText)

    local durationSeconds = math.max(0.1, (tonumber(set.cooldownDurationMs) or 0) / 1000)
    local progress = math.max(0, math.min(1, countdown / durationSeconds))
    c.barFill:SetValue(progress)
end

local function GetCountdown(set)
    return ((tonumber(set.timeOfProc) or 0) + (tonumber(set.cooldownDurationMs) or 0) - GetGameTimeMilliseconds()) / 1000
end

-- -----------------------------------------------------------------------------
-- Control creation / layout
-- -----------------------------------------------------------------------------
local function EnsureSetControls(key, set, saved)
    local savedVars = GetSavedVars()
    local style = GetStyleTable()
    local compact = IsCompact(style)
    local showCard = not compact and not (style and style.showCard == false)
    local showName = not compact and not (style and style.showName == false)

    local c = controlCache[key]
    if c == nil then
        c = {}
        c.container = GetControl(key, CONTAINER_SUFFIX) or WM:CreateTopLevelWindow(key .. CONTAINER_SUFFIX)
        c.container:SetHandler("OnMoveStop", function() SavePosition(key) end)

        local function Child(suffix, controlType, parent)
            return GetControl(key, suffix) or WM:CreateControl(key .. suffix, parent or c.container, controlType)
        end

        c.card    = Child(CARD_SUFFIX, CT_BACKDROP)
        c.accent  = Child(ACCENT_SUFFIX, CT_BACKDROP)
        c.glow    = Child(GLOW_SUFFIX, CT_TEXTURE)
        c.iconBg  = Child(ICON_BG_SUFFIX, CT_BACKDROP)
        c.texture = Child(TEXTURE_SUFFIX, CT_TEXTURE)
        c.frame   = Child(FRAME_SUFFIX, CT_TEXTURE)
        c.barBg   = Child(BAR_BG_SUFFIX, CT_BACKDROP)
        c.barFill = Child(BAR_FILL_SUFFIX, CT_STATUSBAR, c.barBg)
        c.label   = Child(LABEL_SUFFIX, CT_LABEL)
        c.name    = Child(NAME_LABEL_SUFFIX, CT_LABEL)
        c.flash   = Child(FLASH_SUFFIX, CT_BACKDROP)

        c.card:SetDrawLayer(DL_BACKGROUND)
        c.accent:SetDrawLayer(DL_BACKGROUND)
        c.accent:SetDrawLevel(1)
        c.glow:SetDrawLayer(DL_BACKGROUND)
        c.glow:SetDrawLevel(2)
        c.iconBg:SetDrawLayer(DL_CONTROLS)
        c.iconBg:SetDrawLevel(0)
        c.texture:SetDrawLayer(DL_CONTROLS)
        c.texture:SetDrawLevel(1)
        c.frame:SetDrawLayer(DL_CONTROLS)
        c.frame:SetDrawLevel(2)
        c.barBg:SetDrawLayer(DL_CONTROLS)
        c.barBg:SetDrawLevel(0)
        c.barFill:SetDrawLayer(DL_CONTROLS)
        c.barFill:SetDrawLevel(1)
        c.label:SetDrawLayer(DL_TEXT)
        c.name:SetDrawLayer(DL_TEXT)
        c.flash:SetDrawLayer(DL_OVERLAY)

        if TEX_BLEND_MODE_ADD ~= nil and type(c.glow.SetBlendMode) == "function" then
            c.glow:SetBlendMode(TEX_BLEND_MODE_ADD)
        end

        controlCache[key] = c
    end

    local width  = compact and COMPACT_SIZE or UI_WIDTH
    local height = compact and COMPACT_SIZE or UI_HEIGHT
    local iconSize = compact and COMPACT_ICON_SIZE or ICON_SIZE

    local container = c.container
    container:SetClampedToScreen(true)
    container:SetDimensions(width, height)
    container:SetMouseEnabled(savedVars.unlocked == true)
    container:SetMovable(savedVars.unlocked == true)
    container:SetAlpha(1)
    container:SetScale(saved.size / scaleBase)
    container:SetHidden(PCT.HUDHidden and not PCT.ForceShow)

    -- Card background + accent stripe
    local cr, cg, cb, ca = StyleColor(style, "cardColor")
    c.card:ClearAnchors()
    c.card:SetAnchor(TOPLEFT, container, TOPLEFT, 0, 0)
    c.card:SetAnchor(BOTTOMRIGHT, container, BOTTOMRIGHT, 0, 0)
    c.card:SetEdgeTexture("", 1, 1, 1)
    c.card:SetCenterColor(cr, cg, cb, ca)
    c.card:SetHidden(not showCard)

    c.accent:ClearAnchors()
    c.accent:SetAnchor(TOPLEFT, container, TOPLEFT, 1, 1)
    c.accent:SetAnchor(BOTTOMLEFT, container, BOTTOMLEFT, 1, -1)
    c.accent:SetWidth(ACCENT_WIDTH)
    c.accent:SetEdgeTexture("", 1, 1, 1)
    c.accent:SetEdgeColor(0, 0, 0, 0)
    c.accent:SetHidden(not showCard)

    -- Icon
    c.iconBg:ClearAnchors()
    c.iconBg:SetDimensions(iconSize + ICON_BORDER * 2, iconSize + ICON_BORDER * 2)
    if compact then
        c.iconBg:SetAnchor(CENTER, container, CENTER, 0, 0)
    else
        c.iconBg:SetAnchor(LEFT, container, LEFT, ICON_OFFSET_X - ICON_BORDER, 0)
    end
    c.iconBg:SetEdgeTexture("", ICON_BORDER, ICON_BORDER, ICON_BORDER)
    c.iconBg:SetCenterColor(0, 0, 0, 0.9)

    c.texture:ClearAnchors()
    c.texture:SetTexture((type(set.texture) == "string" and set.texture ~= "") and set.texture or MISSING_ICON)
    c.texture:SetDimensions(iconSize, iconSize)
    c.texture:SetAnchor(CENTER, c.iconBg, CENTER, 0, 0)

    c.glow:ClearAnchors()
    c.glow:SetTexture(GLOW_TEXTURE)
    c.glow:SetDimensions(iconSize + 30, iconSize + 30)
    c.glow:SetAnchor(CENTER, c.texture, CENTER, 0, 0)

    if set.showFrame then
        c.frame:ClearAnchors()
        if set.procType == "passive" then
            c.frame:SetTexture("/esoui/art/actionbar/passiveabilityframe_round_up.dds")
            c.frame:SetDimensions(iconSize + 5, iconSize + 5)
        else
            c.frame:SetTexture("/esoui/art/actionbar/gamepad/gp_abilityframe64.dds")
            c.frame:SetDimensions(iconSize, iconSize)
        end
        c.frame:SetAnchor(CENTER, c.texture, CENTER, 0, 0)
        c.frame:SetHidden(false)
    else
        c.frame:SetHidden(true)
    end

    -- Progress bar
    local br, bg, bb, ba = StyleColor(style, "barBackgroundColor")
    c.barBg:ClearAnchors()
    c.barBg:SetDimensions(CONTENT_WIDTH, BAR_HEIGHT)
    c.barBg:SetAnchor(BOTTOMLEFT, container, BOTTOMLEFT, CONTENT_X, -BAR_OFFSET_BOTTOM)
    c.barBg:SetEdgeTexture("", 1, 1, 1)
    c.barBg:SetEdgeColor(1, 1, 1, 0.14)
    c.barBg:SetCenterColor(br, bg, bb, ba)
    c.barBg:SetHidden(compact)

    c.barFill:ClearAnchors()
    c.barFill:SetAnchor(TOPLEFT, c.barBg, TOPLEFT, 2, 2)
    c.barFill:SetAnchor(BOTTOMRIGHT, c.barBg, BOTTOMRIGHT, -2, -2)
    c.barFill:SetTexture(BAR_TEXTURE)
    c.barFill:SetMinMax(0, 1)

    -- Countdown
    c.label:ClearAnchors()
    if compact then
        c.label:SetDimensions(COMPACT_SIZE, 30)
        c.label:SetAnchor(CENTER, c.texture, CENTER, 0, 0)
    else
        c.label:SetDimensions(TIMER_WIDTH, 30)
        c.label:SetAnchor(TOPRIGHT, container, TOPRIGHT, -CONTENT_PAD_RIGHT, 10)
    end
    ApplyTimerLabelStyle(c.label, compact)

    -- Name
    c.name:ClearAnchors()
    c.name:SetDimensions(CONTENT_WIDTH - TIMER_WIDTH - 4, 30)
    c.name:SetAnchor(TOPLEFT, container, TOPLEFT, CONTENT_X, 10)
    ApplyNameLabelStyle(c.name)
    c.name:SetText(tostring(key))
    c.name:SetHidden(not showName)

    -- Proc flash overlay
    c.flash:ClearAnchors()
    c.flash:SetAnchor(TOPLEFT, container, TOPLEFT, 0, 0)
    c.flash:SetAnchor(BOTTOMRIGHT, container, BOTTOMRIGHT, 0, 0)
    c.flash:SetEdgeTexture("", 1, 1, 1)
    c.flash:SetEdgeColor(1, 1, 1, 0)
    c.flash:SetCenterColor(1, 1, 1, 0.38)
    local set_timelines = timelines[key]
    if not (set_timelines and set_timelines.flash and set_timelines.flash:IsPlaying()) then
        c.flash:SetAlpha(0)
    end

    SetPosition(key, saved.x, saved.y)

    -- Re-apply the current state with the (possibly new) style.
    c.state = nil
    local countdown = set.onCooldown and GetCountdown(set) or 0
    if set.onCooldown and countdown > 0 then
        ShowCooldown(key, set, countdown)
    else
        ShowReady(key, compact)
    end

    return container
end

function PvPCooldownTracker.UI.Draw(key)
    local set = PCT.Data.Sets[key]
    local container = GetControl(key, CONTAINER_SUFFIX)

    if set == nil then
        -- Entry was removed from the catalog; make sure nothing lingers on screen.
        if container ~= nil then container:SetHidden(true) end
        return
    end

    if set.enabled then
        local saved = GetSetSavedVars(key)
        if saved == nil then return end

        PCT:Trace(2, "Drawing: <<1>>", key)
        container = EnsureSetControls(key, set, saved)

        if container and not PCT.HUDHidden then
            container:SetHidden(false)
        end
    elseif container ~= nil then
        container:SetHidden(true)
    end

    PCT:Trace(2, "Finished DrawUI()")
end

function PvPCooldownTracker.UI:SetCombatStateDisplay()
    PCT:Trace(3, "Setting combat state display, in combat: <<1>>", tostring(PCT.isInCombat))
    local savedVars = GetSavedVars()

    if PCT.isInCombat or (savedVars.showOutsideCombat and not PCT.isDead) then
        PCT.UI.ShowIcon(true)
    else
        PCT.UI.ShowIcon(false)
    end
end

function PvPCooldownTracker.UI.PlaySound(sound)
    if sound and sound.enabled then
        PlaySound(SOUNDS[sound.sound])
    end
end

function PvPCooldownTracker:SetAppearance(x, y, setKey)
    if setKey == nil then return end

    local saved = GetSetSavedVars(setKey)
    if saved == nil then return end

    PCT:Trace(3, "Setting appearance for <<1>> X: <<2>> Y: <<3>>", setKey, x, y)

    local set = PCT.Data.Sets[setKey]
    if not set then return end

    if set.enabled then
        EnsureSetControls(setKey, set, saved)
    else
        local container = GetControl(setKey, CONTAINER_SUFFIX)
        if container ~= nil then
            container:SetScale(saved.size / scaleBase)
            SetPosition(setKey, saved.x, saved.y)
        end
    end

    AnchorAnnouncement()

    PCT:Trace(3, "SetAppearance complete")
end

function PvPCooldownTracker:Check_Cooldown(setKey)
    local set = PCT.Data.Sets[setKey]
    return set ~= nil and set.onCooldown == true
end

function PvPCooldownTracker.UI.Update(setKey)
    local set = PCT.Data.Sets[setKey]
    if not set then
        EVENT_MANAGER:UnregisterForUpdate(PCT.name .. setKey .. "Count")
        return
    end

    local saved, savedVars = GetSetSavedVars(setKey)
    if not saved then return end

    if controlCache[setKey] == nil then
        if not set.enabled then return end
        EnsureSetControls(setKey, set, saved)
    end

    local compact = IsCompact(GetStyleTable())

    if PCT.first_run[setKey] or set.justProcced then
        PCT.first_run[setKey] = nil
        set.justProcced = false
        PlayProcFlash(setKey)
        Announce(string.format("|c%s%s Cooling Down|r", tostring(savedVars.set_active), setKey))
    end

    if not set.onCooldown then
        EVENT_MANAGER:UnregisterForUpdate(PCT.name .. setKey .. "Count")
        ShowReady(setKey, compact)
        return
    end

    local countdown = GetCountdown(set)
    if countdown <= 0 then
        set.onCooldown = false
        EVENT_MANAGER:UnregisterForUpdate(PCT.name .. setKey .. "Count")

        ShowReady(setKey, compact)
        PlayReadyPulse(setKey)
        Announce(string.format("|c%s%s Ready!|r", tostring(savedVars.cooldown_expired), setKey))

        if saved.sounds then
            PCT.UI.PlaySound(saved.sounds.onReady)
        end
        return
    end

    ShowCooldown(setKey, set, countdown)
end

-- -----------------------------------------------------------------------------
-- Style helpers used by the settings menu
-- -----------------------------------------------------------------------------

-- Redraws every enabled tracker with the current style.
function PvPCooldownTracker.UI.RefreshAll()
    for key, set in pairs(PCT.Data.Sets) do
        if set.enabled then
            local saved = GetSetSavedVars(key)
            if saved then
                PCT:SetAppearance(saved.x, saved.y, key)
            end
        end
    end
    PCT.UI:SetCombatStateDisplay()
end

function PvPCooldownTracker.UI.GetThemeNames()
    local names = {}
    for i, theme in ipairs(PCT.UI.Themes) do
        names[i] = theme.name
    end
    return names
end

function PvPCooldownTracker.UI.ApplyTheme(themeName)
    local style = GetStyleTable()
    if style == nil then return false end

    for _, theme in ipairs(PCT.UI.Themes) do
        if theme.name == themeName then
            for _, colorKey in ipairs(THEME_COLOR_KEYS) do
                local color = theme[colorKey]
                style[colorKey] = { color[1], color[2], color[3], color[4] }
            end
            style.theme = theme.name
            PCT.UI.RefreshAll()
            return true
        end
    end

    return false
end

-- Applies the lock state to every tracker that has been drawn.
function PvPCooldownTracker.UI.SetUnlocked(unlocked)
    local savedVars = GetSavedVars()
    savedVars.unlocked = unlocked == true
    for key in pairs(PCT.Data.Sets) do
        local container = GetControl(key, CONTAINER_SUFFIX)
        if container ~= nil then
            container:SetMouseEnabled(savedVars.unlocked)
            container:SetMovable(savedVars.unlocked)
        end
    end
end

-- Stacks every enabled tracker into a tidy column (wrapping into more columns
-- when the screen runs out), starting at the default tracker position.
function PvPCooldownTracker.UI.ArrangeColumn()
    local savedVars = GetSavedVars()
    local compact = IsCompact(GetStyleTable())
    local keys = {}
    for key, set in pairs(PCT.Data.Sets) do
        if set.enabled then
            keys[#keys + 1] = key
        end
    end
    table.sort(keys, function(a, b) return string.lower(a) < string.lower(b) end)

    local origin = savedVars.TextureLocation or {}
    local startX = tonumber(origin.x) or 640
    local startY = tonumber(origin.y) or 300
    local screenW, screenH = GuiRoot:GetWidth(), GuiRoot:GetHeight()
    local gap = 6
    local x, y = startX, startY
    local columnWidth = 0

    for _, key in ipairs(keys) do
        local saved = GetSetSavedVars(key)
        if saved then
            local scale = (tonumber(saved.size) or 64) / scaleBase
            local width  = (compact and COMPACT_SIZE or UI_WIDTH) * scale
            local height = (compact and COMPACT_SIZE or UI_HEIGHT) * scale

            if y + height > screenH and y > startY then
                y = startY
                x = x + columnWidth + gap
                columnWidth = 0
            end
            if x + width > screenW then
                x = math.max(0, screenW - width)
            end

            saved.x = math.floor(x)
            saved.y = math.floor(y)
            PCT:SetAppearance(saved.x, saved.y, key)

            y = y + height + gap
            columnWidth = math.max(columnWidth, width)
        end
    end

    return #keys
end

-- Suggests a free-ish spot for a newly added tracker so it does not land on
-- top of the ones already on screen.
function PvPCooldownTracker.UI.GetNextFreePosition(excludeKey)
    local savedVars = GetSavedVars()
    local origin = savedVars.TextureLocation or {}
    local x = tonumber(origin.x) or 640
    local y = tonumber(origin.y) or 300
    local scale = (tonumber(savedVars.size) or 64) / scaleBase
    local step = math.floor(UI_HEIGHT * scale + 6)
    local screenH = GuiRoot:GetHeight()

    local lowest = nil
    for key, set in pairs(PCT.Data.Sets) do
        if set.enabled and key ~= excludeKey then
            local saved = savedVars.sets and savedVars.sets[key]
            if saved and tonumber(saved.y) and (lowest == nil or saved.y > lowest) then
                lowest = saved.y
            end
        end
    end

    if lowest ~= nil then
        y = lowest + step
        if y + step > screenH then
            y = tonumber(origin.y) or 300
        end
    end

    return x, y
end

function PvPCooldownTracker.UI.ToggleHUD()
    local hudScene = SCENE_MANAGER:GetScene("hud")
    hudScene:RegisterCallback("StateChange", function(oldState, newState)

        -- Don't change states if display should be forced to show
        if PCT.ForceShow then return end

        -- Transitioning to a menu/non-HUD
        if newState == SCENE_HIDDEN and SCENE_MANAGER:GetNextScene():GetName() ~= "hudui" then
            PCT:Trace(3, "Hiding HUD")
            PCT.HUDHidden = true
            PCT.UI:SetCombatStateDisplay()
        end

        -- Transitioning to a HUD/non-menu
        if newState == SCENE_SHOWING then
            PCT:Trace(3, "Showing HUD")
            PCT.HUDHidden = false
            PCT.UI:SetCombatStateDisplay()
        end
    end)

    PCT:Trace(2, "Finished ToggleHUD()")
end

function PvPCooldownTracker.UI.ShowIcon(shouldShow)

    for key, set in pairs(PCT.Data.Sets) do
        local context = WM:GetControlByName(key .. "_Container")
        if context ~= nil then
            if PCT.ForceShow and set.enabled then
                context:SetHidden(false)
            elseif (shouldShow and set.enabled and not PCT.HUDHidden) then
                context:SetHidden(false)
            else
                context:SetHidden(true)
            end
        end
    end

end

function PvPCooldownTracker.UI.SlashCommand(command)
    local prefix = PCT.prefix or "[PCT] "
    local savedVars = GetSavedVars()

    if savedVars == nil
        and PCT.Settings
        and type(PCT.Settings.EnsureState) == "function"
    then
        savedVars = PCT.Settings.EnsureState()
    end

    local function SetDebug(level, name)
        d(prefix .. string.format("Setting debug level to %d (%s)", level, name))
        PCT.debugMode = level
        if savedVars ~= nil then
            savedVars.debugMode = level
        end
    end

    -- Debug Options ----------------------------------------------------------
    if command == "debug 0" then
        SetDebug(0, "Off")
    elseif command == "debug 1" then
        SetDebug(1, "Low")
    elseif command == "debug 2" then
        SetDebug(2, "Medium")
    elseif command == "debug 3" then
        SetDebug(3, "High")

    -- Unfiltered Events
    elseif command == "all on" then
        d(prefix .. "Registering unfiltered events, setting debug mode to 1")
        PCT.debugMode = 1
        if savedVars ~= nil then
            savedVars.debugMode = 1
        end
        PCT.Tracking.RegisterUnfiltered()
    elseif command == "all off" then
        d(prefix .. "Unregistering unfiltered events, setting debug mode to 0")
        PCT.Tracking.UnregisterUnfiltered()
        PCT.debugMode = 0
        if savedVars ~= nil then
            savedVars.debugMode = 0
        end

    -- Recently seen procs (see ProcCapture.lua)
    elseif command == "procs" then
        local capture = PCT.ProcCapture
        local recent = capture and capture.GetRecent() or {}
        if #recent == 0 then
            d(prefix .. "No procs recorded yet. Fight something, then try again.")
        else
            d(prefix .. string.format("Recent procs (%d):", #recent))
            for i = 1, math.min(#recent, 15) do
                d("  " .. capture.DescribeRecord(recent[i]))
            end
            d(prefix .. "Add one from Settings > Add a Proc.")
        end

    -- Default ----------------------------------------------------------------
    else
        d(prefix .. "Commands: procs | debug 0-3 | all on | all off")
    end
end
