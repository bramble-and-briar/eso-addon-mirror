-- =========================================================
-- MugShot - TargetFrameView  (UI/TargetFrameView.lua)
-- Creates and manages the custom target frame UI:
--   - 3 equal lines of 30px (total 90px height)
--   - Lines 1 & 2: 2x2 Quadrants (Left/Right swapping)
--   - Line 3: Privileged debuffs (5 slots, paired & single, swappable)
--   - Full-bleed vivid health bar, shield overlay, portrait & badges
--   - Buffs / debuffs container cleanly below the frame
-- =========================================================

local MugShot = MugShot

local TargetFrameView = {}
TargetFrameView.__index = TargetFrameView

-- Localized functions for Lua 5.1 bytecode speed (Code65536 / Baertram pattern)
local math_max      = math.max
local math_floor    = math.floor
local math_ceil     = math.ceil
local string_format = string.format
local tostring      = tostring
local pairs         = pairs
local ipairs        = ipairs
local unpack        = unpack or table.unpack
local Style         = MugShot.Style
local C             = MugShot.Constants
local Q             = C.QUADRANTS
local V             = C.VALUES

local PlaySound = PlaySound or function() end
local SOUNDS    = SOUNDS or {}

-- ESO Standard DrawLayer constants
local DL_BACKGROUND = _G.DL_BACKGROUND or 0
local DL_CONTROLS   = _G.DL_CONTROLS   or 1
local DL_TEXT       = _G.DL_TEXT       or 2
local DL_OVERLAY    = _G.DL_OVERLAY    or 3

local function ShallowCopy(t)
    return ZO_ShallowTableCopy(t)
end

-- ── Quadrant Configurations (3 Equal Lines, Left & Right) ──
local QUADRANT_CONFIG = {
    [Q.LINE1_LEFT] = {
        point     = TOPLEFT,
        relPoint  = TOPLEFT,
        offsetX   = 8,
        offsetY   = 6,
        hAlign    = TEXT_ALIGN_LEFT,
        vAlign    = TEXT_ALIGN_CENTER,
        lineIndex = 1,
    },
    [Q.LINE1_RIGHT] = {
        point     = TOPRIGHT,
        relPoint  = TOPRIGHT,
        offsetX   = -8,
        offsetY   = 6,
        hAlign    = TEXT_ALIGN_RIGHT,
        vAlign    = TEXT_ALIGN_CENTER,
        lineIndex = 1,
    },
    [Q.LINE2_LEFT] = {
        point     = TOPLEFT,
        relPoint  = TOPLEFT,
        offsetX   = 8,
        offsetY   = 38,
        hAlign    = TEXT_ALIGN_LEFT,
        vAlign    = TEXT_ALIGN_CENTER,
        lineIndex = 2,
    },
    [Q.LINE2_RIGHT] = {
        point     = TOPRIGHT,
        relPoint  = TOPRIGHT,
        offsetX   = -8,
        offsetY   = 38,
        hAlign    = TEXT_ALIGN_RIGHT,
        vAlign    = TEXT_ALIGN_CENTER,
        lineIndex = 2,
    },
    [Q.LINE3_LEFT] = {
        point     = TOPLEFT,
        relPoint  = TOPLEFT,
        offsetX   = 8,
        offsetY   = 70,
        hAlign    = TEXT_ALIGN_LEFT,
        vAlign    = TEXT_ALIGN_CENTER,
        lineIndex = 3,
    },
    [Q.LINE3_RIGHT] = {
        point     = TOPRIGHT,
        relPoint  = TOPRIGHT,
        offsetX   = -8,
        offsetY   = 70,
        hAlign    = TEXT_ALIGN_RIGHT,
        vAlign    = TEXT_ALIGN_CENTER,
        lineIndex = 3,
    },
}

-- Short Debuff Tag Mapping (Referenced from data-driven Constants)
local SHORT_DEBUFF_NAMES = MugShot.Constants.SHORT_DEBUFF_NAMES

-- ── Constructor ───────────────────────────────────────────
function TargetFrameView.New()
    local self = setmetatable({}, TargetFrameView)
    self._lastNumRows        = nil
    self._lastHealthPercent  = nil
    self._lastShieldPercent  = nil
    self._lastPercentText    = nil
    self._lastHealthText     = nil
    self._inMoveMode         = false
    self._moveModeTarget     = "enemy"
    self._selectedLine       = nil
    self._selectedQuadrant   = nil
    self._currentQuadrants   = nil
    self._selectedPrivileged = nil
    self._activePrivileged   = nil
    self._lastRaceIcon       = nil
    self._lastAllianceIcon   = nil
    self._lastAllianceBase   = nil
    self._lastAllianceColor  = nil
    self._lastIsPlayer       = false
    self._lastReaction       = nil
    self._controller         = nil
    self:_Build()
    self:ApplyLayout()
    self:RegisterDialogs()
    return self
end

-- ── _Build ────────────────────────────────────────────────
function TargetFrameView:_Build()
    local wm = WINDOW_MANAGER

    -- ── Root Frame ────────────────────────────────────────
    local frame = wm:CreateTopLevelWindow("MugShot_TargetFrame")
    frame:SetDimensions(Style.FRAME_WIDTH, Style.FRAME_HEIGHT + Style.EFFECT_SLOT_SIZE + 6)
    frame:SetAnchor(TOP, GuiRoot, TOP, 0, 88)
    frame:SetMovable(true)
    frame:SetMouseEnabled(true)
    frame:SetClampedToScreen(true)
    frame:SetHidden(true)

    -- ── Main Bar Container (Health & Shield) ──────────────
    local barContainer = CreateControl("MugShot_BarContainer", frame, CT_CONTROL)
    barContainer:SetDimensions(Style.BAR_BG_WIDTH, Style.BAR_BG_HEIGHT)
    barContainer:SetAnchor(TOPLEFT, frame, TOPLEFT, 0, 0)
    barContainer:SetMouseEnabled(true)

    -- Bar background (dark unfilled portion + solid border)
    local barBg = CreateControl("MugShot_BarBG", barContainer, CT_BACKDROP)
    barBg:ClearAnchors()
    barBg:SetAnchorFill(barContainer)
    barBg:SetCenterTexture("")
    barBg:SetEdgeTexture("", Style.BORDER_THICKNESS, Style.BORDER_THICKNESS, Style.BORDER_THICKNESS)
    barBg:SetCenterColor(Style.BAR_BG_COLOR.r, Style.BAR_BG_COLOR.g, Style.BAR_BG_COLOR.b, Style.BAR_BG_COLOR.a)
    barBg:SetEdgeColor(Style.BORDER_COLOR_PLAYER.r, Style.BORDER_COLOR_PLAYER.g, Style.BORDER_COLOR_PLAYER.b, Style.BORDER_COLOR_PLAYER.a)
    barBg:SetMouseEnabled(true)
    barBg:SetDrawLayer(0)

    -- Health bar (full-bleed CT_TEXTURE inside barContainer, 100% opaque and vivid)
    local healthBar = CreateControl("MugShot_HealthBar", barContainer, CT_TEXTURE)
    healthBar:SetDimensions(Style.BAR_WIDTH, Style.BAR_HEIGHT)
    healthBar:SetAnchor(TOPLEFT, barContainer, TOPLEFT, Style.BORDER_THICKNESS, Style.BORDER_THICKNESS)
    healthBar:SetTexture(Style.BAR_TEXTURE)
    healthBar:SetColor(1.0, 0.0, 0.0, 1.0)
    healthBar:SetMouseEnabled(true)
    healthBar:SetDrawLayer(1)

    self._currentBarWidth   = Style.BAR_WIDTH
    self._lastHealthPercent = 0
    self._lastShieldPercent = 0

    healthBar.SetValue = function(ctrl, val)
        local pct = val or 0
        if pct < 0 then pct = 0 elseif pct > 1 then pct = 1 end
        ctrl.value = pct
        self._lastHealthPercent = pct
        local barW = self._currentBarWidth or Style.BAR_WIDTH
        ctrl:SetDimensions(math_floor(barW * pct + 0.5), Style.BAR_HEIGHT)
    end

    -- Damage shield overlay bar (superposed CT_TEXTURE over health bar)
    local shieldBar = CreateControl("MugShot_ShieldBar", barContainer, CT_TEXTURE)
    shieldBar:SetDimensions(0, Style.BAR_HEIGHT)
    shieldBar:SetAnchor(TOPLEFT, barContainer, TOPLEFT, Style.BORDER_THICKNESS, Style.BORDER_THICKNESS)
    shieldBar:SetTexture(Style.BAR_TEXTURE)
    local sc = Style.SHIELD_COLOR
    shieldBar:SetColor(sc.r, sc.g, sc.b, sc.a)
    shieldBar:SetHidden(true)
    shieldBar:SetMouseEnabled(true)
    shieldBar:SetDrawLayer(2)

    shieldBar.SetValue = function(ctrl, val)
        local pct = val or 0
        if pct < 0 then pct = 0 elseif pct > 1 then pct = 1 end
        ctrl.value = pct
        self._lastShieldPercent = pct
        local barW = self._currentBarWidth or Style.BAR_WIDTH
        ctrl:SetDimensions(math_floor(barW * pct + 0.5), Style.BAR_HEIGHT)
    end

    -- ── Quadrants Labels (Line 1 & Line 2) ────────────────
    -- Percentage label: e.g. "70%", "100%"
    local percentageLabel = CreateControl("MugShot_PercentageLabel", barContainer, CT_LABEL)
    percentageLabel:SetAnchor(TOPLEFT, barContainer, TOPLEFT, 8, 4)
    percentageLabel:SetFont(Style.FONT_PERCENTAGE)
    percentageLabel:SetColor(Style.TEXT_COLOR_WHITE.r, Style.TEXT_COLOR_WHITE.g, Style.TEXT_COLOR_WHITE.b, Style.TEXT_COLOR_WHITE.a)
    percentageLabel:SetText("")
    percentageLabel:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    percentageLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    percentageLabel:SetDrawLayer(3)

    -- Health text label: e.g. "2.1M / 3.0M", "24.3K / 24.3K [3.6K]"
    local healthLabel = CreateControl("MugShot_HealthLabel", barContainer, CT_LABEL)
    healthLabel:SetAnchor(TOPRIGHT, barContainer, TOPRIGHT, -8, 4)
    healthLabel:SetFont(Style.FONT_HEALTH)
    healthLabel:SetColor(Style.TEXT_COLOR_WHITE.r, Style.TEXT_COLOR_WHITE.g, Style.TEXT_COLOR_WHITE.b, Style.TEXT_COLOR_WHITE.a)
    healthLabel:SetText("")
    healthLabel:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    healthLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    healthLabel:SetDrawLayer(3)

    -- Target name label: e.g. "Target Iron Atronach, Trial", "@nycthemere"
    local targetNameLabel = CreateControl("MugShot_TargetNameLabel", barContainer, CT_LABEL)
    targetNameLabel:SetAnchor(TOPLEFT, barContainer, TOPLEFT, 8, 34)
    targetNameLabel:SetFont(Style.FONT_NAME)
    targetNameLabel:SetColor(Style.TEXT_COLOR_WHITE.r, Style.TEXT_COLOR_WHITE.g, Style.TEXT_COLOR_WHITE.b, Style.TEXT_COLOR_WHITE.a)
    targetNameLabel:SetText("")
    targetNameLabel:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    targetNameLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    targetNameLabel:SetDrawLayer(3)
    if targetNameLabel.SetWrapMode and TEXT_WRAP_MODE_ELLIPSIS then
        targetNameLabel:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    end

    -- ── Quadrant Controls (3 Equal Lines, 6 Quadrants in Move Mode) ──
    self.quadrantControls = {}
    local halfW = math_floor(Style.BAR_WIDTH / 2)
    local lineH = Style.LINE_HEIGHT

    local qLayoutSpecs = {
        [Q.LINE1_LEFT]   = { x = Style.BORDER_THICKNESS,         y = Style.BORDER_THICKNESS },
        [Q.LINE1_RIGHT]  = { x = Style.BORDER_THICKNESS + halfW, y = Style.BORDER_THICKNESS },
        [Q.LINE2_LEFT]   = { x = Style.BORDER_THICKNESS,         y = Style.BORDER_THICKNESS + lineH },
        [Q.LINE2_RIGHT]  = { x = Style.BORDER_THICKNESS + halfW, y = Style.BORDER_THICKNESS + lineH },
        [Q.LINE3_LEFT]   = { x = Style.BORDER_THICKNESS,         y = Style.BORDER_THICKNESS + lineH * 2 },
        [Q.LINE3_RIGHT]  = { x = Style.BORDER_THICKNESS + halfW, y = Style.BORDER_THICKNESS + lineH * 2 },
    }

    for qKey, spec in pairs(qLayoutSpecs) do
        local qCtrl = CreateControl("MugShot_Quadrant_" .. qKey, barContainer, CT_BACKDROP)
        qCtrl._quadrantKey = qKey
        qCtrl:SetAnchor(TOPLEFT, barContainer, TOPLEFT, spec.x, spec.y)
        qCtrl:SetDimensions(halfW, lineH)
        qCtrl:SetCenterTexture("")
        qCtrl:SetEdgeTexture("", Style.GRID_BORDER_THICKNESS, Style.GRID_BORDER_THICKNESS, Style.GRID_BORDER_THICKNESS)
        qCtrl:SetCenterColor(0, 0, 0, 0)
        qCtrl:SetEdgeColor(Style.QUADRANT_BORDER.r, Style.QUADRANT_BORDER.g, Style.QUADRANT_BORDER.b, Style.QUADRANT_BORDER.a)
        qCtrl:SetMouseEnabled(true)
        qCtrl:SetDrawLayer(DL_OVERLAY)
        qCtrl:SetDrawLevel(1)
        qCtrl:SetHidden(true)
        self.quadrantControls[qKey] = qCtrl
    end

    -- ── Line Swapping Handles ([L1], [L2], [L3] on left of bar) ─
    self.lineHandles = {}
    for lineIdx = 1, 3 do
        local lHandle = CreateControl("MugShot_LineHandle_" .. lineIdx, barContainer, CT_BACKDROP)
        lHandle._lineIndex = lineIdx
        lHandle:SetDimensions(24, lineH - 2)
        lHandle:SetAnchor(TOPRIGHT, barContainer, TOPLEFT, -4, Style.BORDER_THICKNESS + (lineIdx - 1) * lineH + 1)
        lHandle:SetCenterTexture("")
        lHandle:SetEdgeTexture("", Style.GRID_BORDER_THICKNESS, Style.GRID_BORDER_THICKNESS, Style.GRID_BORDER_THICKNESS)
        lHandle:SetCenterColor(0.04, 0.05, 0.08, 0.85)
        lHandle:SetEdgeColor(Style.QUADRANT_BORDER.r, Style.QUADRANT_BORDER.g, Style.QUADRANT_BORDER.b, Style.QUADRANT_BORDER.a)
        lHandle:SetMouseEnabled(true)
        lHandle:SetDrawLayer(DL_OVERLAY)
        lHandle:SetDrawLevel(2)
        lHandle:SetHidden(true)

        local lText = CreateControl("MugShot_LineHandleText_" .. lineIdx, lHandle, CT_LABEL)
        lText:SetDimensions(24, lineH - 2)
        lText:SetAnchor(CENTER, lHandle, CENTER, 0, 0)
        lText:SetFont("$(BOLD_FONT)|12|soft-shadow-thick")
        lText:SetColor(1.0, 1.0, 1.0, 1.0)
        lText:SetText("L" .. lineIdx)
        lText:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        lText:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        lText:SetDrawLayer(DL_OVERLAY)
        lText:SetDrawLevel(3)

        lHandle._label = lText
        self.lineHandles[lineIdx] = lHandle
    end

    -- ── Portrait Box (MugShot!) on the right ──────────────
    local portraitBg = CreateControl("MugShot_PortraitBG", frame, CT_BACKDROP)
    portraitBg:ClearAnchors()
    portraitBg:SetDimensions(Style.PORTRAIT_BG_SIZE, Style.PORTRAIT_BG_SIZE)
    portraitBg:SetAnchor(TOPLEFT, barContainer, TOPRIGHT, -Style.BORDER_THICKNESS, 0)
    portraitBg:SetCenterTexture("")
    portraitBg:SetEdgeTexture("", Style.BORDER_THICKNESS, Style.BORDER_THICKNESS, Style.BORDER_THICKNESS)
    portraitBg:SetCenterColor(Style.PORTRAIT_BG_COLOR.r, Style.PORTRAIT_BG_COLOR.g, Style.PORTRAIT_BG_COLOR.b, Style.PORTRAIT_BG_COLOR.a)
    portraitBg:SetEdgeColor(Style.BORDER_COLOR_PLAYER.r, Style.BORDER_COLOR_PLAYER.g, Style.BORDER_COLOR_PLAYER.b, Style.BORDER_COLOR_PLAYER.a)
    portraitBg:SetMouseEnabled(true)
    portraitBg:SetDrawLayer(DL_BACKGROUND)

    local portrait = CreateControl("MugShot_Portrait", portraitBg, CT_TEXTURE)
    portrait:SetDimensions(Style.PORTRAIT_SIZE, Style.PORTRAIT_SIZE)
    portrait:SetAnchor(CENTER, portraitBg, CENTER, 0, 0)
    portrait:SetHidden(true)
    portrait:SetDrawLayer(DL_CONTROLS)

    -- Race badge on top-right of portrait
    local raceIcon = CreateControl("MugShot_RaceIcon", portraitBg, CT_TEXTURE)
    raceIcon:SetDimensions(Style.BADGE_SIZE, Style.BADGE_SIZE)
    raceIcon:SetAnchor(CENTER, portrait, TOPRIGHT, 0, 0)
    raceIcon:SetHidden(true)
    raceIcon:SetMouseEnabled(true)
    raceIcon:SetDrawLayer(DL_OVERLAY)
    raceIcon:SetDrawLevel(1)

    -- Race toggle button overlay (yellow 'X' or '+')
    local raceToggleBtn = CreateControl("MugShot_RaceToggleBtn", portraitBg, CT_LABEL)
    raceToggleBtn:SetDimensions(Style.BADGE_TOGGLE_SIZE, Style.BADGE_TOGGLE_SIZE)
    raceToggleBtn:SetAnchor(CENTER, raceIcon, TOPRIGHT, -2, 2)
    raceToggleBtn:SetFont(Style.FONT_BADGE_TOGGLE)
    raceToggleBtn:SetColor(Style.BADGE_TOGGLE_TEXT.r, Style.BADGE_TOGGLE_TEXT.g, Style.BADGE_TOGGLE_TEXT.b, Style.BADGE_TOGGLE_TEXT.a)
    raceToggleBtn:SetText("X")
    raceToggleBtn:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    raceToggleBtn:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    raceToggleBtn:SetDrawLayer(DL_OVERLAY)
    raceToggleBtn:SetDrawLevel(2)
    raceToggleBtn:SetMouseEnabled(true)
    raceToggleBtn:SetHidden(true)

    -- Alliance composite badge on bottom-right of portrait
    -- 1. Base flag (ava_flagneutral.dds tinted with high-contrast alliance color)
    local allianceBase = CreateControl("MugShot_AllianceBase", portraitBg, CT_TEXTURE)
    allianceBase:SetDimensions(Style.ALLIANCE_BASE_WIDTH or 28, Style.ALLIANCE_BASE_HEIGHT or 40)
    allianceBase:SetAnchor(CENTER, portrait, BOTTOMRIGHT, 0, 0)
    allianceBase:SetTexture(MugShot.Constants.ALLIANCE_FLAG_BASE)
    if Style.ALLIANCE_BASE_COORDS then
        allianceBase:SetTextureCoords(unpack(Style.ALLIANCE_BASE_COORDS))
    end
    allianceBase:SetHidden(true)
    allianceBase:SetMouseEnabled(true)
    allianceBase:SetDrawLayer(DL_OVERLAY)
    allianceBase:SetDrawLevel(1)

    -- 2. Crest badge on top (alliancebadge_<alliance>.dds in neutral white, centered in rectangular field)
    local allianceIcon = CreateControl("MugShot_AllianceIcon", portraitBg, CT_TEXTURE)
    allianceIcon:SetDimensions(Style.ALLIANCE_ICON_SIZE or 20, Style.ALLIANCE_ICON_SIZE or 20)
    allianceIcon:SetAnchor(CENTER, allianceBase, CENTER, 0, Style.ALLIANCE_ICON_OFFSET_Y or -4)
    allianceIcon:SetHidden(true)
    allianceIcon:SetMouseEnabled(true)
    allianceIcon:SetDrawLayer(DL_OVERLAY)
    allianceIcon:SetDrawLevel(2)

    -- Alliance toggle button overlay (yellow 'X' or '+')
    local allianceToggleBtn = CreateControl("MugShot_AllianceToggleBtn", portraitBg, CT_LABEL)
    allianceToggleBtn:SetDimensions(Style.BADGE_TOGGLE_SIZE, Style.BADGE_TOGGLE_SIZE)
    allianceToggleBtn:SetAnchor(CENTER, allianceBase, TOPRIGHT, -2, 2)
    allianceToggleBtn:SetFont(Style.FONT_BADGE_TOGGLE)
    allianceToggleBtn:SetColor(Style.BADGE_TOGGLE_TEXT.r, Style.BADGE_TOGGLE_TEXT.g, Style.BADGE_TOGGLE_TEXT.b, Style.BADGE_TOGGLE_TEXT.a)
    allianceToggleBtn:SetText("X")
    allianceToggleBtn:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    allianceToggleBtn:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    allianceToggleBtn:SetDrawLayer(DL_OVERLAY)
    allianceToggleBtn:SetDrawLevel(3)
    allianceToggleBtn:SetMouseEnabled(true)
    allianceToggleBtn:SetHidden(true)

    -- ── Privileged Debuffs Container (Line 3 inside barContainer) ───────
    local privilegedContainer = CreateControl("MugShot_PrivilegedContainer", barContainer, CT_CONTROL)
    privilegedContainer:SetDimensions(Style.BAR_WIDTH, Style.LINE_HEIGHT)
    privilegedContainer:SetAnchor(TOPLEFT, barContainer, TOPLEFT, Style.BORDER_THICKNESS, Style.BORDER_THICKNESS + Style.LINE_HEIGHT * 2)
    privilegedContainer:SetDrawLayer(DL_OVERLAY)
    privilegedContainer:SetDrawLevel(1)
    privilegedContainer:SetMouseEnabled(true)
    privilegedContainer:SetHidden(true)
    self.privilegedContainer = privilegedContainer

    self.privilegedSlots = {}
    local slotWidth  = Style.PRIVILEGED_SLOT_WIDTH
    local slotHeight = Style.PRIVILEGED_SLOT_HEIGHT
    local slotGap    = Style.PRIVILEGED_SLOT_GAP or 2
    local startX     = 1

    for i = 1, 5 do
        local slotX = startX + (i - 1) * (slotWidth + slotGap)
        local pBg = CreateControl("MugShot_PrivilegedSlot_" .. i, privilegedContainer, CT_BACKDROP)
        pBg._slotIndex = i
        pBg:SetDimensions(slotWidth, slotHeight)
        pBg:SetAnchor(TOPLEFT, privilegedContainer, TOPLEFT, slotX, 1)
        pBg:SetCenterTexture("")
        pBg:SetEdgeTexture("", Style.GRID_BORDER_THICKNESS, Style.GRID_BORDER_THICKNESS, Style.GRID_BORDER_THICKNESS)
        pBg:SetCenterColor(Style.SLOT_BG_COLOR.r, Style.SLOT_BG_COLOR.g, Style.SLOT_BG_COLOR.b, Style.SLOT_BG_COLOR.a)
        pBg:SetEdgeColor(Style.DEBUFF_GHOST_BORDER.r, Style.DEBUFF_GHOST_BORDER.g, Style.DEBUFF_GHOST_BORDER.b, Style.DEBUFF_GHOST_BORDER.a)
        pBg:SetDrawLayer(DL_OVERLAY)
        pBg:SetDrawLevel(1)
        pBg:SetMouseEnabled(true)
        pBg:SetHidden(true)

        -- Header tag centered at top with clean margin
        local pHeader = CreateControl("MugShot_PrivilegedHeader_" .. i, pBg, CT_LABEL)
        pHeader:SetDimensions(slotWidth - 4, 13)
        pHeader:SetAnchor(TOPLEFT, pBg, TOPLEFT, 2, 2)
        pHeader:SetFont(Style.FONT_DEBUFF_HEADER)
        pHeader:SetColor(1, 1, 1, 1)
        pHeader:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        pHeader:SetVerticalAlignment(TEXT_ALIGN_TOP)
        pHeader:SetDrawLayer(DL_OVERLAY)
        pHeader:SetDrawLevel(2)

        -- Paired: Major M on left half (inset 4px from left border to prevent clipping)
        local pMajorBadge = CreateControl("MugShot_PrivilegedMajorBadge_" .. i, pBg, CT_LABEL)
        pMajorBadge:SetDimensions(10, 13)
        pMajorBadge:SetAnchor(TOPLEFT, pBg, TOPLEFT, 4, 15)
        pMajorBadge:SetFont(Style.FONT_DEBUFF_BADGE)
        pMajorBadge:SetColor(Style.DEBUFF_MAJOR_COLOR.r, Style.DEBUFF_MAJOR_COLOR.g, Style.DEBUFF_MAJOR_COLOR.b, Style.DEBUFF_MAJOR_COLOR.a)
        pMajorBadge:SetText("M")
        pMajorBadge:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        pMajorBadge:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        pMajorBadge:SetDrawLayer(DL_OVERLAY)
        pMajorBadge:SetDrawLevel(2)

        local pMajorTimer = CreateControl("MugShot_PrivilegedMajorTimer_" .. i, pBg, CT_LABEL)
        pMajorTimer:SetDimensions(14, 13)
        pMajorTimer:SetAnchor(TOPLEFT, pBg, TOPLEFT, 14, 15)
        pMajorTimer:SetFont(Style.FONT_DEBUFF_TIMER)
        pMajorTimer:SetColor(Style.TEXT_COLOR_WHITE.r, Style.TEXT_COLOR_WHITE.g, Style.TEXT_COLOR_WHITE.b, Style.TEXT_COLOR_WHITE.a)
        pMajorTimer:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        pMajorTimer:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        pMajorTimer:SetDrawLayer(DL_OVERLAY)
        pMajorTimer:SetDrawLevel(2)

        -- Paired: Minor m on right half (inset 4px from right border)
        local pMinorBadge = CreateControl("MugShot_PrivilegedMinorBadge_" .. i, pBg, CT_LABEL)
        pMinorBadge:SetDimensions(9, 13)
        pMinorBadge:SetAnchor(TOPLEFT, pBg, TOPLEFT, 31, 15)
        pMinorBadge:SetFont(Style.FONT_DEBUFF_BADGE)
        pMinorBadge:SetColor(Style.DEBUFF_MINOR_COLOR.r, Style.DEBUFF_MINOR_COLOR.g, Style.DEBUFF_MINOR_COLOR.b, Style.DEBUFF_MINOR_COLOR.a)
        pMinorBadge:SetText("m")
        pMinorBadge:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        pMinorBadge:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        pMinorBadge:SetDrawLayer(DL_OVERLAY)
        pMinorBadge:SetDrawLevel(2)

        local pMinorTimer = CreateControl("MugShot_PrivilegedMinorTimer_" .. i, pBg, CT_LABEL)
        pMinorTimer:SetDimensions(14, 13)
        pMinorTimer:SetAnchor(TOPLEFT, pBg, TOPLEFT, 40, 15)
        pMinorTimer:SetFont(Style.FONT_DEBUFF_TIMER)
        pMinorTimer:SetColor(Style.TEXT_COLOR_WHITE.r, Style.TEXT_COLOR_WHITE.g, Style.TEXT_COLOR_WHITE.b, Style.TEXT_COLOR_WHITE.a)
        pMinorTimer:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        pMinorTimer:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        pMinorTimer:SetDrawLayer(DL_OVERLAY)
        pMinorTimer:SetDrawLevel(2)

        -- Single debuff timer centered below header (standardized 11pt font)
        local pSingleTimer = CreateControl("MugShot_PrivilegedSingleTimer_" .. i, pBg, CT_LABEL)
        pSingleTimer:SetDimensions(slotWidth - 4, 13)
        pSingleTimer:SetAnchor(TOPLEFT, pBg, TOPLEFT, 2, 15)
        pSingleTimer:SetFont(Style.FONT_DEBUFF_SINGLE)
        pSingleTimer:SetColor(Style.TEXT_COLOR_CYAN.r, Style.TEXT_COLOR_CYAN.g, Style.TEXT_COLOR_CYAN.b, Style.TEXT_COLOR_CYAN.a)
        pSingleTimer:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        pSingleTimer:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        pSingleTimer:SetDrawLayer(DL_OVERLAY)
        pSingleTimer:SetDrawLevel(2)

        self.privilegedSlots[i] = {
            bg          = pBg,
            header      = pHeader,
            majorBadge  = pMajorBadge,
            majorTimer  = pMajorTimer,
            minorBadge  = pMinorBadge,
            minorTimer  = pMinorTimer,
            singleTimer = pSingleTimer,
            label       = pHeader,
            timer       = pSingleTimer,
        }
    end

    -- ── Buffs / Debuffs Container below frame ─────────────
    local effectContainer = CreateControl("MugShot_EffectContainer", frame, CT_CONTROL)
    effectContainer:SetDimensions(Style.FRAME_WIDTH, Style.EFFECT_SLOT_SIZE)
    effectContainer:SetAnchor(TOPLEFT, barContainer, BOTTOMLEFT, 0, 6)
    effectContainer:SetMouseEnabled(true)
    effectContainer:SetDrawLayer(DL_CONTROLS)
    self.effectContainer = effectContainer

    -- ── Move Mode Target Toggle Button (Ennemi / Joueur) ───
    local moveTargetBtn = CreateControl("MugShot_MoveTargetBtn", frame, CT_LABEL)
    moveTargetBtn:SetAnchor(TOPLEFT, effectContainer, BOTTOMLEFT, 0, 6)
    moveTargetBtn:SetDimensions(Style.FRAME_WIDTH, 20)
    moveTargetBtn:SetFont("$(BOLD_FONT)|13|soft-shadow-thick")
    moveTargetBtn:SetColor(Style.QUADRANT_SELECTED.r, Style.QUADRANT_SELECTED.g, Style.QUADRANT_SELECTED.b, 1.0)
    moveTargetBtn:SetText((MugShot.GetText and MugShot.GetText("PREVIEW_ENEMY_BTN")) or "[Preview: ENEMY (Click for Player)]")
    moveTargetBtn:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    moveTargetBtn:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    moveTargetBtn:SetMouseEnabled(true)
    moveTargetBtn:SetDrawLayer(DL_OVERLAY)
    moveTargetBtn:SetDrawLevel(2)
    moveTargetBtn:SetHidden(true)
    self.moveTargetBtn = moveTargetBtn

    -- ── Move Mode Instructions ───────────────────────────
    local moveInstructionsLabel = CreateControl("MugShot_MoveInstructions", frame, CT_LABEL)
    moveInstructionsLabel:SetAnchor(TOPLEFT, moveTargetBtn, BOTTOMLEFT, -20, 4)
    moveInstructionsLabel:SetDimensions(Style.FRAME_WIDTH + 40, 16)
    moveInstructionsLabel:SetFont("$(BOLD_FONT)|11|soft-shadow-thick")
    moveInstructionsLabel:SetColor(Style.DEBUFF_GHOST_TEXT.r, Style.DEBUFF_GHOST_TEXT.g, Style.DEBUFF_GHOST_TEXT.b, 0.95)
    moveInstructionsLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    moveInstructionsLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    moveInstructionsLabel:SetText((MugShot.GetText and MugShot.GetText("MOVE_MODE_INSTRUCTIONS")) or "[Mode Déplacement] Glisser : Déplacer cadre | Ligne 3 : Clic G = Permuter, Clic D = Renommer")
    moveInstructionsLabel:SetDrawLayer(DL_OVERLAY)
    moveInstructionsLabel:SetDrawLevel(2)
    moveInstructionsLabel:SetHidden(true)
    self.moveInstructionsLabel = moveInstructionsLabel

    -- Pre-create reusable pool of effect slots
    self.effectSlots = {}
    for i = 1, Style.MAX_EFFECTS do
        self:_GetOrCreateEffectSlot(i)
    end

    -- ── Drag & Click Handlers ─────────────────────────────
    local mugShot_settings = MugShot.settings

    local function OnDragStart(ctrl, button)
        if button == MOUSE_BUTTON_INDEX_LEFT and mugShot_settings and not mugShot_settings:Get().locked then
            frame:StartMoving()
        end
    end

    local function OnDragStop(ctrl, button)
        if button == MOUSE_BUTTON_INDEX_LEFT then
            frame:StopMovingOrResizing()
            if mugShot_settings then
                local isValid, point, _relativeTo, relativePoint, offsetX, offsetY = frame:GetAnchor(0)
                if isValid then
                    mugShot_settings:Set("position", {
                        point         = point,
                        relativePoint = relativePoint,
                        offsetX       = math_floor(offsetX + 0.5),
                        offsetY       = math_floor(offsetY + 0.5),
                    })
                end
            end
        end
    end

    local dragTargets = { frame, barContainer, barBg, healthBar, shieldBar, portraitBg, effectContainer }
    for _, ctrl in ipairs(dragTargets) do
        ctrl:SetHandler("OnMouseDown", OnDragStart)
        ctrl:SetHandler("OnMouseUp", OnDragStop)
    end

    -- Quadrant click / swap handlers
    local function OnQuadrantClicked(ctrl, button)
        if button == MOUSE_BUTTON_INDEX_LEFT and self._inMoveMode then
            self:_OnQuadrantClicked(ctrl._quadrantKey)
        end
    end

    for _, qCtrl in pairs(self.quadrantControls) do
        qCtrl:SetHandler("OnMouseUp", OnQuadrantClicked)
    end

    -- Line swap handlers ([L1], [L2], [L3])
    local function OnLineHandleClicked(ctrl, button)
        if button == MOUSE_BUTTON_INDEX_LEFT and self._inMoveMode then
            self:_OnLineHandleClicked(ctrl._lineIndex)
        end
    end

    for _, lHandle in pairs(self.lineHandles) do
        lHandle:SetHandler("OnMouseUp", OnLineHandleClicked)
    end

    -- Privileged debuff slot click & hover handlers
    for i, slot in ipairs(self.privilegedSlots) do
        local function OnSlotClicked(ctrl, button)
            if self._inMoveMode then
                if button == MOUSE_BUTTON_INDEX_LEFT then
                    self:_OnPrivilegedSlotClicked(i)
                elseif button == MOUSE_BUTTON_INDEX_RIGHT then
                    self:_OnPrivilegedSlotRightClicked(i, ctrl)
                end
            end
        end

        local function OnSlotMouseEnter(ctrl)
            if not self._inMoveMode then return end
            local debuff = self._activePrivileged and self._activePrivileged[i]
            if not debuff then return end

            local name = debuff.name or "Debuff"
            local title = string.format("|cffffff%s|r", name)
            local tagInfo = ""
            if debuff.defaultTag and debuff.defaultTag ~= debuff.tag then
                tagInfo = string.format("\n" .. ((MugShot.GetText and MugShot.GetText("TOOLTIP_TAG_INFO")) or "Displayed tag: |c00ffcc%s|r (Default: %s)"), debuff.tag or "", debuff.defaultTag or "")
            end
            local leftAction  = (MugShot.GetText and MugShot.GetText("TOOLTIP_LEFT_CLICK")) or "|cffd700• Left-Click:|r Swap debuffs"
            local rightAction = (MugShot.GetText and MugShot.GetText("TOOLTIP_RIGHT_CLICK")) or "|cffd700• Right-Click:|r Rename tag"
            local text = string.format("%s%s\n\n%s\n%s", title, tagInfo, leftAction, rightAction)

            ZO_Tooltips_ShowTextTooltip(ctrl, TOP, text)
        end

        local function OnSlotMouseExit(ctrl)
            ZO_Tooltips_HideTextTooltip()
        end

        slot.bg:SetHandler("OnMouseUp", OnSlotClicked)
        slot.bg:SetHandler("OnMouseEnter", OnSlotMouseEnter)
        slot.bg:SetHandler("OnMouseExit", OnSlotMouseExit)
    end

    -- Move Mode Target Toggle Button click handler
    moveTargetBtn:SetHandler("OnMouseUp", function(ctrl, button)
        if button == MOUSE_BUTTON_INDEX_LEFT and self._inMoveMode then
            local ctrl = self._controller or MugShot._controller
            if ctrl and ctrl.ToggleMoveModeTarget then
                ctrl:ToggleMoveModeTarget()
            end
        end
    end)

    -- Badge toggle click handlers
    local function OnBadgeToggleClicked(badgeKey)
        if not self._inMoveMode then return end
        local settings = MugShot.settings
        if not settings then return end
        local cur = settings:Get()[badgeKey]
        if cur == nil then cur = true end
        settings:Set(badgeKey, not cur)
        self:_UpdateBadgeToggles()
        PlaySound(SOUNDS.CLICK)
    end

    raceToggleBtn:SetHandler("OnMouseUp", function(ctrl, button)
        if button == MOUSE_BUTTON_INDEX_LEFT then OnBadgeToggleClicked("showRace") end
    end)

    allianceToggleBtn:SetHandler("OnMouseUp", function(ctrl, button)
        if button == MOUSE_BUTTON_INDEX_LEFT then OnBadgeToggleClicked("showAlliance") end
    end)

    -- ── Scene Manager Integration ─────────────────────────
    self._shouldBeVisible = false
    local fragment = ZO_SimpleSceneFragment:New(frame)
    fragment:SetConditional(function()
        return self._shouldBeVisible == true
    end)
    HUD_SCENE:AddFragment(fragment)
    HUD_UI_SCENE:AddFragment(fragment)
    self.fragment = fragment

    -- Store references
    self.frame               = frame
    self.barContainer        = barContainer
    self.barBg               = barBg
    self.healthBar           = healthBar
    self.shieldBar           = shieldBar
    self.percentageLabel     = percentageLabel
    self.healthLabel         = healthLabel
    self.targetNameLabel     = targetNameLabel
    self.portraitBg          = portraitBg
    self.portrait            = portrait
    self.raceIcon            = raceIcon
    self.allianceBase        = allianceBase
    self.allianceIcon        = allianceIcon
    self.raceToggleBtn       = raceToggleBtn
    self.allianceToggleBtn   = allianceToggleBtn
end

-- ── _GetOrCreateEffectSlot ────────────────────────────────
function TargetFrameView:_GetOrCreateEffectSlot(i)
    if self.effectSlots[i] then
        return self.effectSlots[i]
    end

    local slotsPerRow = 10
    local col = (i - 1) % slotsPerRow
    local row = math_floor((i - 1) / slotsPerRow)
    local x = col * (Style.EFFECT_SLOT_SIZE + Style.EFFECT_GAP)
    local y = row * (Style.EFFECT_SLOT_SIZE + Style.EFFECT_GAP)

    local slotBg = CreateControl("MugShot_EffectSlot_" .. i, self.effectContainer, CT_BACKDROP)
    slotBg._slotIndex = i
    slotBg:SetDimensions(Style.EFFECT_SLOT_SIZE, Style.EFFECT_SLOT_SIZE)
    slotBg:SetAnchor(TOPLEFT, self.effectContainer, TOPLEFT, x, y)
    slotBg:SetCenterTexture("")
    slotBg:SetEdgeTexture("", 1, 1, 1)
    slotBg:SetCenterColor(Style.SLOT_BG_COLOR.r, Style.SLOT_BG_COLOR.g, Style.SLOT_BG_COLOR.b, Style.SLOT_BG_COLOR.a)
    slotBg:SetEdgeColor(Style.BORDER_COLOR_PLAYER.r, Style.BORDER_COLOR_PLAYER.g, Style.BORDER_COLOR_PLAYER.b, Style.BORDER_COLOR_PLAYER.a)
    slotBg:SetMouseEnabled(true)
    slotBg:SetDrawLayer(0)

    local icon = CreateControl("MugShot_EffectIcon_" .. i, slotBg, CT_TEXTURE)
    icon:SetDimensions(Style.EFFECT_ICON_SIZE, Style.EFFECT_ICON_SIZE)
    icon:SetAnchor(CENTER, slotBg, CENTER, 0, 0)
    icon:SetHidden(true)
    icon:SetDrawLayer(1)

    local timerLabel = CreateControl("MugShot_EffectTimer_" .. i, slotBg, CT_LABEL)
    timerLabel:SetAnchor(CENTER, slotBg, CENTER, 0, 0)
    timerLabel:SetFont(Style.FONT_TIMER)
    timerLabel:SetColor(Style.TEXT_COLOR_WHITE.r, Style.TEXT_COLOR_WHITE.g, Style.TEXT_COLOR_WHITE.b, Style.TEXT_COLOR_WHITE.a)
    timerLabel:SetText("")
    timerLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    timerLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    timerLabel:SetDrawLayer(2)

    local stackLabel = CreateControl("MugShot_EffectStack_" .. i, slotBg, CT_LABEL)
    stackLabel:SetAnchor(TOPRIGHT, slotBg, TOPRIGHT, -2, 2)
    stackLabel:SetFont(Style.FONT_STACK)
    stackLabel:SetColor(Style.TEXT_COLOR_WHITE.r, Style.TEXT_COLOR_WHITE.g, Style.TEXT_COLOR_WHITE.b, Style.TEXT_COLOR_WHITE.a)
    stackLabel:SetText("")
    stackLabel:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    stackLabel:SetVerticalAlignment(TEXT_ALIGN_TOP)
    stackLabel:SetDrawLayer(3)

    local sourceLabel = CreateControl("MugShot_EffectSource_" .. i, slotBg, CT_LABEL)
    sourceLabel:SetAnchor(BOTTOMLEFT, slotBg, BOTTOMLEFT, 2, -2)
    sourceLabel:SetFont(Style.FONT_SOURCE)
    sourceLabel:SetColor(Style.TEXT_COLOR_CYAN.r, Style.TEXT_COLOR_CYAN.g, Style.TEXT_COLOR_CYAN.b, Style.TEXT_COLOR_CYAN.a)
    sourceLabel:SetText("")
    sourceLabel:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    sourceLabel:SetVerticalAlignment(TEXT_ALIGN_BOTTOM)
    sourceLabel:SetDrawLayer(3)

    local slot = {
        bg          = slotBg,
        icon        = icon,
        timerLabel  = timerLabel,
        stackLabel  = stackLabel,
        sourceLabel = sourceLabel,
    }
    self.effectSlots[i] = slot
    return slot
end

-- ── SetIdentity ───────────────────────────────────────────
function TargetFrameView:SetIdentity(pres)
    pres = pres or {}
    self.targetNameLabel:SetText(pres.displayName or "")
    self._lastIsPlayer = (pres.isPlayer == true)
    self._lastReaction = pres.reaction

    local r = pres.r or 0.85
    local g = pres.g or 0.85
    local b = pres.b or 0.85

    self.healthBar:SetColor(r, g, b, 1.0)
    self.healthBar:SetGradientColors(ORIENTATION_HORIZONTAL, r, g, b, 1.0, r * 0.70, g * 0.70, b * 0.70, 1.0)
    self.barBg:SetCenterColor(r * 0.20, g * 0.20, b * 0.20, 1.0)

    local hasPortrait = pres.portraitTexture and pres.portraitTexture ~= ""
    if hasPortrait then
        self.portrait:SetTexture(pres.portraitTexture)
        self.portrait:SetColor(1.0, 1.0, 1.0, 1.0)
        if pres.portraitCoords then
            self.portrait:SetTextureCoords(unpack(pres.portraitCoords))
        else
            self.portrait:SetTextureCoords(0, 1, 0, 1)
        end
        self.portrait:SetHidden(false)
        self.portraitBg:SetHidden(false)
        self.portraitBg:SetDimensions(Style.PORTRAIT_BG_SIZE, Style.PORTRAIT_BG_SIZE)
        self.portrait:SetDimensions(Style.PORTRAIT_SIZE, Style.PORTRAIT_SIZE)

        self._currentBarWidth = Style.BAR_WIDTH
        self.barContainer:SetDimensions(Style.BAR_BG_WIDTH, Style.BAR_BG_HEIGHT)
        self.barBg:SetDimensions(Style.BAR_BG_WIDTH, Style.BAR_BG_HEIGHT)
        self.frame:SetDimensions(Style.FRAME_WIDTH, Style.FRAME_HEIGHT + Style.EFFECT_SLOT_SIZE + 6)
    else
        self.portrait:SetHidden(true)
        self.portraitBg:SetHidden(true)
        self._currentBarWidth = Style.FRAME_WIDTH - Style.BORDER_THICKNESS * 2
        self.barContainer:SetDimensions(Style.FRAME_WIDTH, Style.BAR_BG_HEIGHT)
        self.barBg:SetDimensions(Style.FRAME_WIDTH, Style.BAR_BG_HEIGHT)
        self.frame:SetDimensions(Style.FRAME_WIDTH, Style.FRAME_HEIGHT + Style.EFFECT_SLOT_SIZE + 6)
    end

    self.healthBar:SetValue(self._lastHealthPercent or 1.0)
    self.shieldBar:SetValue(self._lastShieldPercent or 0.0)

    -- Badges
    self._lastRaceIcon      = pres.raceIcon
    self._lastAllianceIcon  = pres.allianceIcon
    self._lastAllianceBase  = pres.allianceBase or (pres.allianceIcon and MugShot.Constants.ALLIANCE_FLAG_BASE)

    local allianceColor = pres.allianceColor
    if not allianceColor and pres.allianceId then
        allianceColor = MugShot.Constants.ALLIANCE_COLORS[pres.allianceId]
    end
    if not allianceColor and pres.allianceIcon then
        local iconLower = pres.allianceIcon:lower()
        if iconLower:find("aldmeri", 1, true) then
            allianceColor = MugShot.Constants.ALLIANCE_COLORS[1]
        elseif iconLower:find("ebonheart", 1, true) then
            allianceColor = MugShot.Constants.ALLIANCE_COLORS[2]
        elseif iconLower:find("daggerfall", 1, true) then
            allianceColor = MugShot.Constants.ALLIANCE_COLORS[3]
        end
    end
    self._lastAllianceColor = allianceColor

    if pres.raceIcon and pres.raceIcon ~= "" then
        self.raceIcon:SetTexture(pres.raceIcon)
    end
    if self._lastAllianceBase and self._lastAllianceBase ~= "" then
        self.allianceBase:SetTexture(self._lastAllianceBase)
        if Style.ALLIANCE_BASE_COORDS then
            self.allianceBase:SetTextureCoords(unpack(Style.ALLIANCE_BASE_COORDS))
        end
        if allianceColor then
            self.allianceBase:SetColor(allianceColor.r, allianceColor.g, allianceColor.b, allianceColor.a or 1.0)
        end
    end
    if pres.allianceIcon and pres.allianceIcon ~= "" then
        self.allianceIcon:SetTexture(pres.allianceIcon)
        self.allianceIcon:SetColor(1.0, 1.0, 1.0, 1.0)
    end

    self:_UpdateBadgeToggles()
end

-- ── SetVitals ─────────────────────────────────────────────
function TargetFrameView:SetVitals(pres)
    local pctText = pres.percentText or ""
    local hpText  = pres.healthText  or ""

    if pctText ~= self._lastPercentText then
        self.percentageLabel:SetText(pctText)
        self._lastPercentText = pctText
    end

    if hpText ~= self._lastHealthText then
        self.healthLabel:SetText(hpText)
        self._lastHealthText = hpText
    end

    local hpPct = pres.healthPercent or 0
    if hpPct ~= self._lastHealthPercent then
        self.healthBar:SetValue(hpPct)
    end

    local shieldPct = pres.shieldPercent or 0
    if shieldPct ~= self._lastShieldPercent then
        self.shieldBar:SetValue(shieldPct)
        self.shieldBar:SetHidden(shieldPct <= 0)
    end
end

-- ── SetEffects (Standard row below frame) ─────────────────
function TargetFrameView:SetEffects(effects)
    local num = #effects
    local slotsPerRow = 10
    local neededRows = math_max(1, math_ceil(num / slotsPerRow))

    if neededRows ~= self._lastNumRows or self._lastInMoveMode ~= self._inMoveMode then
        local newH = neededRows * Style.EFFECT_SLOT_SIZE + math_max(0, neededRows - 1) * Style.EFFECT_GAP
        local extraH = self._inMoveMode and 30 or 0
        self.effectContainer:SetDimensions(Style.FRAME_WIDTH, newH)
        self.frame:SetDimensions(Style.FRAME_WIDTH, Style.BAR_BG_HEIGHT + newH + 6 + extraH)
        self._lastNumRows = neededRows
        self._lastInMoveMode = self._inMoveMode
    end

    local totalSlots = #self.effectSlots
    local maxSlots = math_max(num, totalSlots, Style.MAX_EFFECTS)
    for i = 1, maxSlots do
        local slot = self:_GetOrCreateEffectSlot(i)
        if i <= num then
            local eff = effects[i]
            slot.bg:SetHidden(false)
            slot._lastHidden = false
            slot.icon:SetTexture(eff.icon)
            slot.icon:SetHidden(false)
            slot._lastIcon = eff.icon
            local tText = eff.timerText or ""
            slot.timerLabel:SetText(tText)
            slot._lastTimerText = tText
            local sText = eff.stackText or ""
            slot.stackLabel:SetText(sText)
            slot._lastStackText = sText
            slot.sourceLabel:SetText(eff.sourceText or "")
            slot.bg:SetEdgeColor(eff.borderR or 0, eff.borderG or 0, eff.borderB or 0, eff.borderA or 1)
        else
            slot.bg:SetHidden(true)
            slot._lastHidden = true
            slot.icon:SetHidden(true)
            slot._lastIcon = nil
            slot.timerLabel:SetText("")
            slot._lastTimerText = nil
            slot.stackLabel:SetText("")
            slot._lastStackText = nil
            slot.sourceLabel:SetText("")
        end
    end
end

-- ── SetPrivilegedDebuffs (Line 3 text debuffs) ────────────
function TargetFrameView:SetPrivilegedDebuffs(debuffs)
    if not self.privilegedSlots then return end
    debuffs = debuffs or {}
    self._activePrivileged = debuffs

    local hasDebuffs = (#debuffs > 0)
    if self.privilegedContainer then
        self.privilegedContainer:SetHidden(not hasDebuffs)
    end

    for i = 1, #self.privilegedSlots do
        local slot = self.privilegedSlots[i]
        local d = hasDebuffs and debuffs[i]

        if d then
            slot.bg:SetHidden(false)
            local isPair = (d.isPair == true) or (d.majorTimerText ~= nil or d.minorTimerText ~= nil)
            local rawName = d.name or ""
            local headerText = d.tag or SHORT_DEBUFF_NAMES[rawName] or (rawName ~= "" and rawName:sub(1, 6):upper()) or "DEBUFF"

            if isPair then
                if slot.singleTimer then slot.singleTimer:SetHidden(true) end
                if slot.majorBadge  then slot.majorBadge:SetHidden(false) end
                if slot.majorTimer  then slot.majorTimer:SetHidden(false) end
                if slot.minorBadge  then slot.minorBadge:SetHidden(false) end
                if slot.minorTimer  then slot.minorTimer:SetHidden(false) end

                local majorTimer = d.majorTimerText or (d.majorTimer and string_format("%d", math_ceil(d.majorTimer))) or "0"
                majorTimer = tostring(majorTimer):gsub("s$", "")
                local minorTimer = d.minorTimerText or (d.minorTimer and string_format("%d", math_ceil(d.minorTimer))) or "0"
                minorTimer = tostring(minorTimer):gsub("s$", "")

                local isMajorActive = (d.majorActive == true) or (majorTimer ~= "0" and majorTimer ~= "")
                local isMinorActive = (d.minorActive == true) or (minorTimer ~= "0" and minorTimer ~= "")

                slot.header:SetText(headerText)
                slot.majorBadge:SetText("M")
                slot.majorTimer:SetText(isMajorActive and majorTimer or "-")
                slot.minorBadge:SetText("m")
                slot.minorTimer:SetText(isMinorActive and minorTimer or "-")

                local majorIsPlayer = (d.majorFromPlayer == true) or (d.majorFromPlayer == nil and not d.isGroup)
                local minorIsPlayer = (d.minorFromPlayer == true) or (d.minorFromPlayer == nil and not d.isGroup)

                -- Major Gold vs Ghost
                if isMajorActive then
                    slot.majorBadge:SetColor(Style.DEBUFF_MAJOR_COLOR.r, Style.DEBUFF_MAJOR_COLOR.g, Style.DEBUFF_MAJOR_COLOR.b, 1.0)
                    if majorIsPlayer then
                        slot.majorTimer:SetColor(Style.TEXT_COLOR_WHITE.r, Style.TEXT_COLOR_WHITE.g, Style.TEXT_COLOR_WHITE.b, 1.00)
                    else
                        slot.majorTimer:SetColor(Style.TEXT_COLOR_CYAN.r, Style.TEXT_COLOR_CYAN.g, Style.TEXT_COLOR_CYAN.b, 1.00)
                    end
                else
                    slot.majorBadge:SetColor(Style.DEBUFF_MAJOR_COLOR.r, Style.DEBUFF_MAJOR_COLOR.g, Style.DEBUFF_MAJOR_COLOR.b, 0.55)
                    slot.majorTimer:SetColor(Style.DEBUFF_GHOST_TEXT.r, Style.DEBUFF_GHOST_TEXT.g, Style.DEBUFF_GHOST_TEXT.b, 0.75)
                end

                -- Minor Silver vs Ghost
                if isMinorActive then
                    slot.minorBadge:SetColor(Style.DEBUFF_MINOR_COLOR.r, Style.DEBUFF_MINOR_COLOR.g, Style.DEBUFF_MINOR_COLOR.b, 1.0)
                    if minorIsPlayer then
                        slot.minorTimer:SetColor(Style.TEXT_COLOR_WHITE.r, Style.TEXT_COLOR_WHITE.g, Style.TEXT_COLOR_WHITE.b, 1.00)
                    else
                        slot.minorTimer:SetColor(Style.TEXT_COLOR_CYAN.r, Style.TEXT_COLOR_CYAN.g, Style.TEXT_COLOR_CYAN.b, 1.00)
                    end
                else
                    slot.minorBadge:SetColor(Style.DEBUFF_MINOR_COLOR.r, Style.DEBUFF_MINOR_COLOR.g, Style.DEBUFF_MINOR_COLOR.b, 0.55)
                    slot.minorTimer:SetColor(Style.DEBUFF_GHOST_TEXT.r, Style.DEBUFF_GHOST_TEXT.g, Style.DEBUFF_GHOST_TEXT.b, 0.75)
                end

                -- Header color (Active vs Ghost)
                if isMajorActive or isMinorActive then
                    slot.header:SetColor(Style.TEXT_COLOR_CYAN.r, Style.TEXT_COLOR_CYAN.g, Style.TEXT_COLOR_CYAN.b, 1.00)
                else
                    slot.header:SetColor(Style.DEBUFF_GHOST_TEXT.r, Style.DEBUFF_GHOST_TEXT.g, Style.DEBUFF_GHOST_TEXT.b, 0.85)
                end

                -- Border styling
                if d.isGroup or (isMajorActive and not majorIsPlayer) or (isMinorActive and not minorIsPlayer) then
                    slot.bg:SetEdgeColor(Style.BORDER_COLOR_GROUP.r, Style.BORDER_COLOR_GROUP.g, Style.BORDER_COLOR_GROUP.b, 0.95)
                elseif isMajorActive then
                    slot.bg:SetEdgeColor(Style.DEBUFF_MAJOR_COLOR.r, Style.DEBUFF_MAJOR_COLOR.g, Style.DEBUFF_MAJOR_COLOR.b, 0.95)
                elseif isMinorActive then
                    slot.bg:SetEdgeColor(Style.DEBUFF_MINOR_COLOR.r, Style.DEBUFF_MINOR_COLOR.g, Style.DEBUFF_MINOR_COLOR.b, 0.95)
                else
                    slot.bg:SetEdgeColor(Style.DEBUFF_GHOST_BORDER.r, Style.DEBUFF_GHOST_BORDER.g, Style.DEBUFF_GHOST_BORDER.b, Style.DEBUFF_GHOST_BORDER.a)
                end
            else
                -- Single layout
                if slot.majorBadge  then slot.majorBadge:SetHidden(true) end
                if slot.majorTimer  then slot.majorTimer:SetHidden(true) end
                if slot.minorBadge  then slot.minorBadge:SetHidden(true) end
                if slot.minorTimer  then slot.minorTimer:SetHidden(true) end
                if slot.singleTimer then slot.singleTimer:SetHidden(false) end

                local timer = d.timerText or (d.timer and string_format("%d", math_ceil(d.timer))) or ""
                timer = tostring(timer):gsub("s$", "")
                local isGhost = (d.isGhost == true) or (d.isActive == false) or (timer == "0") or (timer == "")
                local singleIsPlayer = (d.fromPlayer == true) or (d.fromPlayer == nil and not d.isGroup)

                slot.header:SetText(headerText)
                slot.singleTimer:SetText(not isGhost and timer or "-")

                if isGhost then
                    slot.bg:SetEdgeColor(Style.DEBUFF_GHOST_BORDER.r, Style.DEBUFF_GHOST_BORDER.g, Style.DEBUFF_GHOST_BORDER.b, Style.DEBUFF_GHOST_BORDER.a)
                    slot.header:SetColor(Style.DEBUFF_GHOST_TEXT.r, Style.DEBUFF_GHOST_TEXT.g, Style.DEBUFF_GHOST_TEXT.b, 0.85)
                    slot.singleTimer:SetColor(Style.DEBUFF_GHOST_TEXT.r, Style.DEBUFF_GHOST_TEXT.g, Style.DEBUFF_GHOST_TEXT.b, 0.70)
                else
                    slot.header:SetColor(Style.TEXT_COLOR_CYAN.r, Style.TEXT_COLOR_CYAN.g, Style.TEXT_COLOR_CYAN.b, 1.00)
                    if singleIsPlayer then
                        slot.singleTimer:SetColor(Style.TEXT_COLOR_WHITE.r, Style.TEXT_COLOR_WHITE.g, Style.TEXT_COLOR_WHITE.b, 1.00)
                        slot.bg:SetEdgeColor(Style.DEBUFF_MAJOR_COLOR.r, Style.DEBUFF_MAJOR_COLOR.g, Style.DEBUFF_MAJOR_COLOR.b, 0.95)
                    else
                        slot.singleTimer:SetColor(Style.TEXT_COLOR_CYAN.r, Style.TEXT_COLOR_CYAN.g, Style.TEXT_COLOR_CYAN.b, 1.00)
                        slot.bg:SetEdgeColor(Style.BORDER_COLOR_GROUP.r, Style.BORDER_COLOR_GROUP.g, Style.BORDER_COLOR_GROUP.b, 0.95)
                    end
                end
            end
        else
            slot.bg:SetHidden(true)
        end
    end
end

-- ── Move Mode Quadrant & Line Interactions ────────────────
function TargetFrameView:SwapLines(l1, l2)
    local isEnemy = (self._inMoveMode and self._moveModeTarget == "enemy") or (not self._inMoveMode and self._lastReaction == UNIT_REACTION_HOSTILE)
    local sv = MugShot.settings and MugShot.settings:Get()
    local isClassic = (sv and sv.layout == "classic")
    local key = (isEnemy and not isClassic) and "quadrantsEnemy" or "quadrantsNeutral"
    local defs = MugShot.Defaults
    local defaultQ = defs and ((isEnemy and not isClassic) and defs.quadrantsEnemy or defs.quadrantsNeutral) or self._currentQuadrants
    local quadrants = (sv and sv[key]) or (sv and sv.quadrants) or defaultQ or {}
    quadrants = ShallowCopy(quadrants)

    local left1  = "line" .. l1 .. "Left"
    local right1 = "line" .. l1 .. "Right"
    local left2  = "line" .. l2 .. "Left"
    local right2 = "line" .. l2 .. "Right"

    local tempL = quadrants[left1]
    local tempR = quadrants[right1]
    quadrants[left1] = quadrants[left2]
    quadrants[right1] = quadrants[right2]
    quadrants[left2] = tempL
    quadrants[right2] = tempR

    if MugShot.settings then
        MugShot.settings:Set(key, quadrants)
        if isEnemy then
            MugShot.settings:Set("quadrants", quadrants)
        end
    end

    self:ApplyQuadrantLayout(quadrants)
end

function TargetFrameView:_OnLineHandleClicked(lineIndex)
    if not self._inMoveMode then return end

    if not self._selectedLine then
        self._selectedLine = lineIndex
        self:_UpdateLineHandleHighlights()
        PlaySound(SOUNDS.CLICK)
    elseif self._selectedLine == lineIndex then
        self._selectedLine = nil
        self:_UpdateLineHandleHighlights()
        PlaySound(SOUNDS.CLICK)
    else
        local l1 = self._selectedLine
        local l2 = lineIndex
        self._selectedLine = nil
        self:_UpdateLineHandleHighlights()

        self:SwapLines(l1, l2)
        PlaySound(SOUNDS.INVENTORY_ITEM_UNLOCKED)
    end
end

function TargetFrameView:_UpdateLineHandleHighlights()
    if not self.lineHandles then return end
    for lineIdx, ctrl in pairs(self.lineHandles) do
        if self._selectedLine == lineIdx then
            ctrl:SetCenterColor(Style.QUADRANT_SELECTED_BG.r, Style.QUADRANT_SELECTED_BG.g, Style.QUADRANT_SELECTED_BG.b, Style.QUADRANT_SELECTED_BG.a)
            ctrl:SetEdgeColor(Style.QUADRANT_SELECTED.r, Style.QUADRANT_SELECTED.g, Style.QUADRANT_SELECTED.b, Style.QUADRANT_SELECTED.a)
        else
            ctrl:SetCenterColor(0.04, 0.05, 0.08, 0.85)
            ctrl:SetEdgeColor(Style.QUADRANT_BORDER.r, Style.QUADRANT_BORDER.g, Style.QUADRANT_BORDER.b, Style.QUADRANT_BORDER.a)
        end
    end
end

function TargetFrameView:_OnQuadrantClicked(qKey)
    local isEnemy = (self._inMoveMode and self._moveModeTarget == "enemy") or (not self._inMoveMode and self._lastReaction == UNIT_REACTION_HOSTILE)
    local sv = MugShot.settings and MugShot.settings:Get()
    local isClassic = (sv and sv.layout == "classic")
    local key = (isEnemy and not isClassic) and "quadrantsEnemy" or "quadrantsNeutral"
    local defs = MugShot.Defaults
    local defaultQ = defs and ((isEnemy and not isClassic) and defs.quadrantsEnemy or defs.quadrantsNeutral) or self._currentQuadrants
    local quadrants = (sv and sv[key]) or (sv and sv.quadrants) or defaultQ or {}
    quadrants = ShallowCopy(quadrants)

    if not self._selectedQuadrant then
        self._selectedQuadrant = qKey
        self:_UpdateQuadrantHighlights()
        PlaySound(SOUNDS.CLICK)
    elseif self._selectedQuadrant == qKey then
        self._selectedQuadrant = nil
        self:_UpdateQuadrantHighlights()
        PlaySound(SOUNDS.CLICK)
    else
        local q1 = self._selectedQuadrant
        local q2 = qKey
        local temp = quadrants[q1]
        quadrants[q1] = quadrants[q2]
        quadrants[q2] = temp

        if MugShot.settings then
            MugShot.settings:Set(key, quadrants)
            if isEnemy then
                MugShot.settings:Set("quadrants", quadrants)
            end
        end

        self._selectedQuadrant = nil
        self:_UpdateQuadrantHighlights()
        self:ApplyQuadrantLayout(quadrants)
        PlaySound(SOUNDS.INVENTORY_ITEM_UNLOCKED)
    end
end

function TargetFrameView:_UpdateQuadrantHighlights()
    if not self.quadrantControls then return end
    for qKey, ctrl in pairs(self.quadrantControls) do
        if self._selectedQuadrant == qKey then
            ctrl:SetCenterColor(Style.QUADRANT_SELECTED_BG.r, Style.QUADRANT_SELECTED_BG.g, Style.QUADRANT_SELECTED_BG.b, Style.QUADRANT_SELECTED_BG.a)
            ctrl:SetEdgeColor(Style.QUADRANT_SELECTED.r, Style.QUADRANT_SELECTED.g, Style.QUADRANT_SELECTED.b, Style.QUADRANT_SELECTED.a)
        else
            ctrl:SetCenterColor(0, 0, 0, 0)
            ctrl:SetEdgeColor(Style.QUADRANT_BORDER.r, Style.QUADRANT_BORDER.g, Style.QUADRANT_BORDER.b, Style.QUADRANT_BORDER.a)
        end
    end
end

function TargetFrameView:_OnPrivilegedSlotClicked(slotIndex)
    if not self._inMoveMode then return end

    if not self._selectedPrivileged then
        self._selectedPrivileged = slotIndex
        self:_UpdatePrivilegedSlotHighlights()
        PlaySound(SOUNDS.CLICK)
    elseif self._selectedPrivileged == slotIndex then
        self._selectedPrivileged = nil
        self:_UpdatePrivilegedSlotHighlights()
        PlaySound(SOUNDS.CLICK)
    else
        local s1 = self._selectedPrivileged
        local s2 = slotIndex
        self._selectedPrivileged = nil
        self:_UpdatePrivilegedSlotHighlights()

        local ctrl = self._controller or MugShot._controller
        if ctrl and ctrl.SwapPrivilegedDebuffs then
            ctrl:SwapPrivilegedDebuffs(s1, s2)
        end
        PlaySound(SOUNDS.INVENTORY_ITEM_UNLOCKED)
    end
end

function TargetFrameView:_UpdatePrivilegedSlotHighlights()
    if not self.privilegedSlots then return end
    for i, slot in ipairs(self.privilegedSlots) do
        if slot.bg then
            if self._selectedPrivileged == i then
                slot.bg:SetCenterColor(Style.QUADRANT_SELECTED_BG.r, Style.QUADRANT_SELECTED_BG.g, Style.QUADRANT_SELECTED_BG.b, Style.QUADRANT_SELECTED_BG.a)
                slot.bg:SetEdgeColor(Style.QUADRANT_SELECTED.r, Style.QUADRANT_SELECTED.g, Style.QUADRANT_SELECTED.b, 1.0)
            else
                slot.bg:SetCenterColor(Style.SLOT_BG_COLOR.r, Style.SLOT_BG_COLOR.g, Style.SLOT_BG_COLOR.b, Style.SLOT_BG_COLOR.a)
                local d = self._activePrivileged and self._activePrivileged[i]
                if d then
                    local isMajorActive = d.majorActive or (d.majorTimerText and d.majorTimerText ~= "0s" and d.majorTimerText ~= "")
                    local isMinorActive = d.minorActive or (d.minorTimerText and d.minorTimerText ~= "0s" and d.minorTimerText ~= "")
                    if d.isGroup then
                        slot.bg:SetEdgeColor(Style.BORDER_COLOR_GROUP.r, Style.BORDER_COLOR_GROUP.g, Style.BORDER_COLOR_GROUP.b, 0.95)
                    elseif isMajorActive then
                        slot.bg:SetEdgeColor(Style.DEBUFF_MAJOR_COLOR.r, Style.DEBUFF_MAJOR_COLOR.g, Style.DEBUFF_MAJOR_COLOR.b, 0.95)
                    elseif isMinorActive then
                        slot.bg:SetEdgeColor(Style.DEBUFF_MINOR_COLOR.r, Style.DEBUFF_MINOR_COLOR.g, Style.DEBUFF_MINOR_COLOR.b, 0.95)
                    elseif d.isPair then
                        slot.bg:SetEdgeColor(Style.DEBUFF_GHOST_BORDER.r, Style.DEBUFF_GHOST_BORDER.g, Style.DEBUFF_GHOST_BORDER.b, Style.DEBUFF_GHOST_BORDER.a)
                    else
                        local timer = d.timerText or ""
                        local isGhost = (d.isGhost == true) or (d.isActive == false) or (timer == "0s") or (timer == "")
                        if isGhost then
                            slot.bg:SetEdgeColor(Style.DEBUFF_GHOST_BORDER.r, Style.DEBUFF_GHOST_BORDER.g, Style.DEBUFF_GHOST_BORDER.b, Style.DEBUFF_GHOST_BORDER.a)
                        else
                            slot.bg:SetEdgeColor(Style.BORDER_COLOR_GROUP.r, Style.BORDER_COLOR_GROUP.g, Style.BORDER_COLOR_GROUP.b, 0.95)
                        end
                    end
                end
            end
        end
    end
end

local DIALOG_RENAME_DEBUFF = "MUGSHOT_RENAME_DEBUFF_TAG"

function TargetFrameView:RegisterDialogs()
    if not ZO_Dialogs_RegisterCustomDialog then return end

    ZO_Dialogs_RegisterCustomDialog(DIALOG_RENAME_DEBUFF, {
        title = {
            text = function(dialog)
                return (MugShot.GetText and MugShot.GetText("DIALOG_RENAME_TITLE")) or "Rename Debuff Tag"
            end,
        },
        mainText = {
            text = function(dialog)
                local data = dialog.data or {}
                local fmt = (MugShot.GetText and MugShot.GetText("DIALOG_RENAME_BODY")) or "Enter tag for %s (Default: %s, max 7 chars):"
                return string.format(fmt, data.name or "", data.defaultTag or "")
            end,
        },
        editBox = {
            maxInputCharacters = 7,
            selectAll = true,
            defaultText = function(dialog)
                return (dialog.data and dialog.data.currentTag) or ""
            end,
        },
        buttons = {
            [1] = {
                text = SI_DIALOG_CONFIRM,
                callback = function(dialog)
                    local text = ZO_Dialogs_GetEditBoxText(dialog) or ""
                    local data = dialog.data or {}
                    local ctrl = self._controller or MugShot._controller
                    if ctrl and ctrl.SetCustomDebuffTag and data.key then
                        ctrl:SetCustomDebuffTag(data.key, text)
                    end
                end,
            },
            [2] = {
                text = SI_DIALOG_CANCEL,
            },
        },
    })
end

function TargetFrameView:ShowRenameDebuffDialog(debuffKey, debuffName, currentTag, defaultTag)
    local data = {
        key        = debuffKey,
        name       = debuffName,
        currentTag = currentTag,
        defaultTag = defaultTag,
    }
    local textParams = {
        editBoxDefaultText = currentTag,
        initialEditText    = currentTag,
    }
    ZO_Dialogs_ShowPlatformDialog(DIALOG_RENAME_DEBUFF, data, textParams)
end

function TargetFrameView:_OnPrivilegedSlotRightClicked(slotIndex, anchorCtrl)
    if not self._inMoveMode then return end
    local debuff = self._activePrivileged and self._activePrivileged[slotIndex]
    if not debuff then return end

    local debuffKey = debuff.key or (debuff.name and debuff.name:lower():gsub("%s+", "_"):gsub("[^%w_]", ""))
    local curTag = debuff.tag or "DEBUFF"
    local defTag = debuff.defaultTag or curTag
    local hasCustom = (debuff.hasCustomTag == true) or (curTag ~= defTag)

    ClearMenu()
    AddCustomMenuItem((MugShot.GetText and MugShot.GetText("MENU_RENAME_TAG")) or "Rename tag...", function()
        self:ShowRenameDebuffDialog(debuffKey, debuff.name, curTag, defTag)
    end)
    if hasCustom then
        local resetText = string.format((MugShot.GetText and MugShot.GetText("MENU_RESET_TAG")) or "Reset default tag [%s]", defTag)
        AddCustomMenuItem(resetText, function()
            local ctrl = self._controller or MugShot._controller
            if ctrl and ctrl.ResetCustomDebuffTag then
                ctrl:ResetCustomDebuffTag(debuffKey)
            end
        end)
    end
    ShowMenu(anchorCtrl or (self.privilegedSlots and self.privilegedSlots[slotIndex] and self.privilegedSlots[slotIndex].bg))
end

-- ── ApplyQuadrantLayout ───────────────────────────────────
function TargetFrameView:ApplyQuadrantLayout(quadrants)
    local isEnemy = (self._inMoveMode and self._moveModeTarget == "enemy") or (not self._inMoveMode and self._lastReaction == UNIT_REACTION_HOSTILE)
    local sv = MugShot.settings and MugShot.settings:Get()
    local isClassic = (sv and sv.layout == "classic")
    local defaultQ
    if isEnemy and not isClassic then
        defaultQ = MugShot.Defaults and MugShot.Defaults.quadrantsEnemy
    else
        defaultQ = MugShot.Defaults and MugShot.Defaults.quadrantsNeutral
    end

    local qKey = (isEnemy and not isClassic) and "quadrantsEnemy" or "quadrantsNeutral"
    if isClassic then
        quadrants = (sv and sv.quadrantsNeutral) or defaultQ
    else
        quadrants = quadrants
            or (sv and sv[qKey])
            or (sv and sv.quadrants)
            or defaultQ
            or {
                [Q.LINE1_LEFT]   = V.NAME,
                [Q.LINE1_RIGHT]  = V.NONE,
                [Q.LINE2_LEFT]   = V.PERCENT,
                [Q.LINE2_RIGHT]  = V.HEALTH,
                [Q.LINE3_LEFT]   = V.PRIVILEGED,
                [Q.LINE3_RIGHT]  = V.NONE,
            }
    end

    self._currentQuadrants = quadrants

    local labelMap = self._labelMap
    if not labelMap then
        labelMap = {
            [V.PERCENT] = self.percentageLabel,
            [V.HEALTH]  = self.healthLabel,
            [V.NAME]    = self.targetNameLabel,
        }
        self._labelMap = labelMap
    end

    for _, label in pairs(labelMap) do
        label:ClearAnchors()
    end

    local privilegedLineIdx = nil

    for qKey, valType in pairs(quadrants) do
        local label = labelMap[valType]
        local cfg   = QUADRANT_CONFIG[qKey]
        if label and cfg then
            label:SetAnchor(cfg.point, self.barContainer, cfg.relPoint, cfg.offsetX, cfg.offsetY)
            label:SetHorizontalAlignment(cfg.hAlign)
            label:SetVerticalAlignment(cfg.vAlign)
        elseif valType == V.PRIVILEGED and cfg then
            privilegedLineIdx = cfg.lineIndex
        end
    end

    if self.privilegedContainer then
        if privilegedLineIdx and not isClassic then
            local lineY = Style.BORDER_THICKNESS + (privilegedLineIdx - 1) * Style.LINE_HEIGHT
            self.privilegedContainer:ClearAnchors()
            self.privilegedContainer:SetAnchor(TOPLEFT, self.barContainer, TOPLEFT, Style.BORDER_THICKNESS, lineY)
            if self._inMoveMode then
                self.privilegedContainer:SetHidden(self._moveModeTarget ~= "enemy")
            end
        else
            self.privilegedContainer:ClearAnchors()
            self.privilegedContainer:SetAnchor(TOPLEFT, self.barContainer, TOPLEFT, Style.BORDER_THICKNESS, Style.BORDER_THICKNESS + Style.LINE_HEIGHT * 2)
            self.privilegedContainer:SetHidden(true)
        end
    end
end

-- ── SetMoveMode ───────────────────────────────────────────
function TargetFrameView:SetMoveMode(enabled, targetType)
    self._inMoveMode = enabled
    self._moveModeTarget = targetType or "enemy"
    self._selectedLine = nil
    self._selectedQuadrant = nil
    self._selectedPrivileged = nil

    if enabled then
        self.barBg:SetEdgeColor(Style.MOVE_MODE_BORDER.r, Style.MOVE_MODE_BORDER.g, Style.MOVE_MODE_BORDER.b, Style.MOVE_MODE_BORDER.a)
        self.portraitBg:SetEdgeColor(Style.MOVE_MODE_BORDER.r, Style.MOVE_MODE_BORDER.g, Style.MOVE_MODE_BORDER.b, Style.MOVE_MODE_BORDER.a)
        for _, ctrl in pairs(self.quadrantControls) do ctrl:SetHidden(false) end
        if self.lineHandles then
            for _, ctrl in pairs(self.lineHandles) do ctrl:SetHidden(false) end
        end
        self:_UpdateQuadrantHighlights()
        self:_UpdateLineHandleHighlights()
        self:_UpdatePrivilegedSlotHighlights()
        self:_UpdateBadgeToggles()

        if self.moveTargetBtn then
            self.moveTargetBtn:SetHidden(false)
            if self._moveModeTarget == "enemy" then
                self.moveTargetBtn:SetText((MugShot.GetText and MugShot.GetText("PREVIEW_ENEMY_BTN")) or "[Mode Aperçu : ENNEMI (Cliquer pour Joueur)]")
                self.moveTargetBtn:SetColor(1.0, 0.4, 0.4, 1.0)
            else
                self.moveTargetBtn:SetText((MugShot.GetText and MugShot.GetText("PREVIEW_PLAYER_BTN")) or "[Mode Aperçu : JOUEUR (Cliquer pour Ennemi)]")
                self.moveTargetBtn:SetColor(0.4, 1.0, 0.4, 1.0)
            end
        end

        if self.moveInstructionsLabel then
            self.moveInstructionsLabel:SetHidden(false)
            self.moveInstructionsLabel:SetText((MugShot.GetText and MugShot.GetText("MOVE_MODE_INSTRUCTIONS")) or "[Mode Déplacement] Glisser : Déplacer cadre | Ligne 3 : Clic G = Permuter, Clic D = Renommer")
        end
    else
        self.barBg:SetEdgeColor(Style.BORDER_COLOR_PLAYER.r, Style.BORDER_COLOR_PLAYER.g, Style.BORDER_COLOR_PLAYER.b, Style.BORDER_COLOR_PLAYER.a)
        self.portraitBg:SetEdgeColor(Style.BORDER_COLOR_PLAYER.r, Style.BORDER_COLOR_PLAYER.g, Style.BORDER_COLOR_PLAYER.b, Style.BORDER_COLOR_PLAYER.a)
        for _, ctrl in pairs(self.quadrantControls) do ctrl:SetHidden(true) end
        if self.lineHandles then
            for _, ctrl in pairs(self.lineHandles) do ctrl:SetHidden(true) end
        end
        if self.moveTargetBtn then self.moveTargetBtn:SetHidden(true) end
        if self.moveInstructionsLabel then self.moveInstructionsLabel:SetHidden(true) end
        ZO_Tooltips_HideTextTooltip()
        self:_UpdatePrivilegedSlotHighlights()
        self:_UpdateBadgeToggles()
    end
end

-- ── _UpdateBadgeToggles ───────────────────────────────────
function TargetFrameView:_UpdateBadgeToggles()
    local settings = MugShot.settings and MugShot.settings:Get()
    local showRace = not settings or (settings.showRace ~= false)
    local showAlliance = not settings or (settings.showAlliance ~= false)

    if self._inMoveMode then
        local isPlayerPreview = (self._moveModeTarget == "player")
        if not isPlayerPreview then
            -- Enemy preview: STRICTLY HIDE race and alliance badges & toggles!
            self.raceIcon:SetHidden(true)
            self.allianceBase:SetHidden(true)
            self.allianceIcon:SetHidden(true)
            if self.raceToggleBtn then self.raceToggleBtn:SetHidden(true) end
            if self.allianceToggleBtn then self.allianceToggleBtn:SetHidden(true) end
        else
            -- Player preview: show badges with interactive toggle overlays
            self.raceIcon:SetHidden(false)
            if self.raceToggleBtn then self.raceToggleBtn:SetHidden(false) end
            if showRace then
                self.raceIcon:SetAlpha(Style.ALPHA_OPAQUE)
                self.raceIcon:SetColor(Style.TEXT_COLOR_WHITE.r, Style.TEXT_COLOR_WHITE.g, Style.TEXT_COLOR_WHITE.b, Style.TEXT_COLOR_WHITE.a)
                if self.raceToggleBtn then
                    self.raceToggleBtn:SetText("X")
                    self.raceToggleBtn:SetColor(Style.BADGE_TOGGLE_TEXT.r, Style.BADGE_TOGGLE_TEXT.g, Style.BADGE_TOGGLE_TEXT.b, Style.BADGE_TOGGLE_TEXT.a)
                end
            else
                self.raceIcon:SetAlpha(Style.ALPHA_DISABLED)
                self.raceIcon:SetColor(Style.BADGE_DISABLED_COLOR.r, Style.BADGE_DISABLED_COLOR.g, Style.BADGE_DISABLED_COLOR.b, Style.BADGE_DISABLED_COLOR.a)
                if self.raceToggleBtn then
                    self.raceToggleBtn:SetText("+")
                    self.raceToggleBtn:SetColor(Style.BADGE_TOGGLE_TEXT.r, Style.BADGE_TOGGLE_TEXT.g, Style.BADGE_TOGGLE_TEXT.b, Style.BADGE_TOGGLE_TEXT.a)
                end
            end

            self.allianceBase:SetHidden(false)
            self.allianceIcon:SetHidden(false)
            if self.allianceToggleBtn then self.allianceToggleBtn:SetHidden(false) end
            if showAlliance then
                self.allianceBase:SetAlpha(Style.ALPHA_OPAQUE)
                self.allianceIcon:SetAlpha(Style.ALPHA_OPAQUE)
                local c = self._lastAllianceColor
                if not c and self._lastAllianceIcon then
                    local iconLower = self._lastAllianceIcon:lower()
                    if iconLower:find("aldmeri", 1, true) then c = MugShot.Constants.ALLIANCE_COLORS[1]
                    elseif iconLower:find("ebonheart", 1, true) then c = MugShot.Constants.ALLIANCE_COLORS[2]
                    elseif iconLower:find("daggerfall", 1, true) then c = MugShot.Constants.ALLIANCE_COLORS[3]
                    end
                end
                if c then
                    self.allianceBase:SetColor(c.r, c.g, c.b, c.a or 1.0)
                else
                    self.allianceBase:SetColor(Style.TEXT_COLOR_WHITE.r, Style.TEXT_COLOR_WHITE.g, Style.TEXT_COLOR_WHITE.b, Style.TEXT_COLOR_WHITE.a)
                end
                self.allianceIcon:SetColor(Style.TEXT_COLOR_WHITE.r, Style.TEXT_COLOR_WHITE.g, Style.TEXT_COLOR_WHITE.b, Style.TEXT_COLOR_WHITE.a)
                if self.allianceToggleBtn then
                    self.allianceToggleBtn:SetText("X")
                    self.allianceToggleBtn:SetColor(Style.BADGE_TOGGLE_TEXT.r, Style.BADGE_TOGGLE_TEXT.g, Style.BADGE_TOGGLE_TEXT.b, Style.BADGE_TOGGLE_TEXT.a)
                end
            else
                self.allianceBase:SetAlpha(Style.ALPHA_DISABLED)
                self.allianceIcon:SetAlpha(Style.ALPHA_DISABLED)
                self.allianceBase:SetColor(Style.BADGE_DISABLED_COLOR.r, Style.BADGE_DISABLED_COLOR.g, Style.BADGE_DISABLED_COLOR.b, Style.BADGE_DISABLED_COLOR.a)
                self.allianceIcon:SetColor(Style.BADGE_DISABLED_COLOR.r, Style.BADGE_DISABLED_COLOR.g, Style.BADGE_DISABLED_COLOR.b, Style.BADGE_DISABLED_COLOR.a)
                if self.allianceToggleBtn then
                    self.allianceToggleBtn:SetText("+")
                    self.allianceToggleBtn:SetColor(Style.BADGE_TOGGLE_TEXT.r, Style.BADGE_TOGGLE_TEXT.g, Style.BADGE_TOGGLE_TEXT.b, Style.BADGE_TOGGLE_TEXT.a)
                end
            end
        end
    else
        if self.raceToggleBtn then self.raceToggleBtn:SetHidden(true) end
        if self.allianceToggleBtn then self.allianceToggleBtn:SetHidden(true) end
        self.raceIcon:SetAlpha(Style.ALPHA_OPAQUE)
        self.raceIcon:SetColor(Style.TEXT_COLOR_WHITE.r, Style.TEXT_COLOR_WHITE.g, Style.TEXT_COLOR_WHITE.b, Style.TEXT_COLOR_WHITE.a)
        self.allianceBase:SetAlpha(Style.ALPHA_OPAQUE)
        self.allianceIcon:SetAlpha(Style.ALPHA_OPAQUE)
        local c = self._lastAllianceColor
        if not c and self._lastAllianceIcon then
            local iconLower = self._lastAllianceIcon:lower()
            if iconLower:find("aldmeri", 1, true) then c = MugShot.Constants.ALLIANCE_COLORS[1]
            elseif iconLower:find("ebonheart", 1, true) then c = MugShot.Constants.ALLIANCE_COLORS[2]
            elseif iconLower:find("daggerfall", 1, true) then c = MugShot.Constants.ALLIANCE_COLORS[3]
            end
        end
        if c then
            self.allianceBase:SetColor(c.r, c.g, c.b, c.a or 1.0)
        else
            self.allianceBase:SetColor(Style.TEXT_COLOR_WHITE.r, Style.TEXT_COLOR_WHITE.g, Style.TEXT_COLOR_WHITE.b, Style.TEXT_COLOR_WHITE.a)
        end
        self.allianceIcon:SetColor(Style.TEXT_COLOR_WHITE.r, Style.TEXT_COLOR_WHITE.g, Style.TEXT_COLOR_WHITE.b, Style.TEXT_COLOR_WHITE.a)

        local isPlayer = (self._lastIsPlayer == true)
        local hasPortrait = self.portrait and not self.portrait:IsHidden()
        local hasRace = self._lastRaceIcon and self._lastRaceIcon ~= ""
        local hasAlliance = self._lastAllianceIcon and self._lastAllianceIcon ~= ""
        local shouldShowAlliance = (isPlayer and hasPortrait and hasAlliance and showAlliance)

        -- STRICT RULE: race and alliance badges are ONLY shown on players!
        self.raceIcon:SetHidden(not (isPlayer and hasPortrait and hasRace and showRace))
        self.allianceBase:SetHidden(not shouldShowAlliance)
        self.allianceIcon:SetHidden(not shouldShowAlliance)
    end
end

-- ── SetVisible ────────────────────────────────────────────
function TargetFrameView:SetVisible(visible)
    self._shouldBeVisible = visible
    if self.fragment then
        self.fragment:Refresh()
    else
        self.frame:SetHidden(not visible)
    end
end

-- ── ApplyLayout ───────────────────────────────────────────
function TargetFrameView:ApplyLayout(settings)
    settings = settings or (MugShot.settings and MugShot.settings:Get()) or {}
    local pos = settings.position
    if pos then
        self.frame:ClearAnchors()
        self.frame:SetAnchor(
            pos.point         or TOP,
            GuiRoot,
            pos.relativePoint or TOP,
            pos.offsetX       or 0,
            pos.offsetY       or 88
        )
    end
    self:ApplyQuadrantLayout(settings.quadrants)
end

-- ── Reset ─────────────────────────────────────────────────
function TargetFrameView:Reset()
    self._lastHealthPercent  = 0
    self._lastShieldPercent  = 0
    self._lastPercentText    = ""
    self._lastHealthText     = ""
    self._lastNumRows        = nil
    self._selectedLine       = nil
    self._selectedQuadrant   = nil
    self._selectedPrivileged = nil
    self._lastRaceIcon       = nil
    self._lastAllianceIcon   = nil
    self._lastAllianceBase   = nil
    self._lastAllianceColor  = nil
    self._lastIsPlayer       = false
    self._lastReaction       = nil
    self.barContainer:SetDimensions(Style.BAR_BG_WIDTH, Style.BAR_BG_HEIGHT)
    self.percentageLabel:SetText("")
    self.healthLabel:SetText("")
    self.targetNameLabel:SetText("")
    self.healthBar:SetDimensions(0, Style.BAR_HEIGHT)
    self.shieldBar:SetDimensions(0, Style.BAR_HEIGHT)
    self.shieldBar:SetHidden(true)
    self.portrait:SetColor(1.0, 1.0, 1.0, 1.0)
    self.portrait:SetTextureCoords(0, 1, 0, 1)
    self.portrait:SetHidden(true)
    self.portraitBg:SetHidden(true)
    self.raceIcon:SetHidden(true)
    self.allianceBase:SetHidden(true)
    self.allianceIcon:SetHidden(true)
    if self.raceToggleBtn then self.raceToggleBtn:SetHidden(true) end
    if self.allianceToggleBtn then self.allianceToggleBtn:SetHidden(true) end
    if self.moveTargetBtn then self.moveTargetBtn:SetHidden(true) end
    if self.lineHandles then
        for _, ctrl in pairs(self.lineHandles) do ctrl:SetHidden(true) end
    end
    if self.privilegedContainer then self.privilegedContainer:SetHidden(true) end
    self:SetEffects({})
end

MugShot.TargetFrameView = TargetFrameView
MugShot.logger:Info("=== TargetFrameView loaded ===")
