-- =========================================================
-- MugShot - TargetFrameView  (UI/TargetFrameView.lua)
-- Creates and manages the custom target frame UI.
-- =========================================================

local MugShot = MugShot

local TargetFrameView = {}
TargetFrameView.__index = TargetFrameView

-- Localized functions for Lua 5.1 bytecode speed (Code65536 / Baertram pattern)
local math_max = math.max
local math_ceil = math.ceil
local unpack = unpack or table.unpack
local Style = MugShot.Style

-- ── Constructor ───────────────────────────────────────────
function TargetFrameView.New()
    local self = setmetatable({}, TargetFrameView)
    self._lastNumRows       = nil
    self._lastHealthPercent = nil
    self._lastShieldPercent = nil
    self._lastPercentText   = nil
    self._lastHealthText    = nil
    self:_Build()
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

    -- Bar background (dark unfilled portion + 2px solid border)
    local barBg = CreateControl("MugShot_BarBG", barContainer, CT_BACKDROP)
    barBg:ClearAnchors()
    barBg:SetAnchorFill(barContainer)
    barBg:SetCenterTexture("")
    barBg:SetEdgeTexture("", 2, 2, 2)
    barBg:SetCenterColor(Style.BAR_BG_COLOR.r, Style.BAR_BG_COLOR.g, Style.BAR_BG_COLOR.b, Style.BAR_BG_COLOR.a)
    barBg:SetEdgeColor(Style.BORDER_COLOR_PLAYER.r, Style.BORDER_COLOR_PLAYER.g, Style.BORDER_COLOR_PLAYER.b, Style.BORDER_COLOR_PLAYER.a)
    barBg:SetMouseEnabled(true)
    barBg:SetDrawLayer(0)

    -- Health bar (full-bleed CT_TEXTURE inside barContainer, 100% opaque and vivid)
    local healthBar = CreateControl("MugShot_HealthBar", barContainer, CT_TEXTURE)
    healthBar:SetDimensions(Style.BAR_WIDTH, Style.BAR_HEIGHT)
    healthBar:SetAnchor(TOPLEFT, barContainer, TOPLEFT, 2, 2)
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
        local barW = self._currentBarWidth or Style.BAR_WIDTH
        ctrl:SetDimensions(math.floor(barW * pct + 0.5), Style.BAR_HEIGHT)
    end

    -- Damage shield overlay bar (superposed CT_TEXTURE over health bar)
    local shieldBar = CreateControl("MugShot_ShieldBar", barContainer, CT_TEXTURE)
    shieldBar:SetDimensions(0, Style.BAR_HEIGHT)
    shieldBar:SetAnchor(TOPLEFT, barContainer, TOPLEFT, 2, 2)
    shieldBar:SetTexture(Style.BAR_TEXTURE)
    local sc = Style.SHIELD_COLOR
    shieldBar:SetColor(sc.r, sc.g, sc.b, sc.a)
    shieldBar:SetHidden(true)
    shieldBar:SetMouseEnabled(true)
    shieldBar:SetDrawLayer(2)

    shieldBar.SetValue = function(ctrl, val)
        local pct = val or 0
        if pct < 0 then pct = 0 elseif pct > 1 then pct = 1 end
        local barW = self._currentBarWidth or Style.BAR_WIDTH
        ctrl:SetDimensions(math.floor(barW * pct + 0.5), Style.BAR_HEIGHT)
    end

    -- Percentage label: TOP-LEFT of bar (e.g. "70%", "100%")
    local percentageLabel = CreateControl("MugShot_PercentageLabel", barContainer, CT_LABEL)
    percentageLabel:SetAnchor(TOPLEFT, barContainer, TOPLEFT, 8, 5)
    percentageLabel:SetFont(Style.FONT_PERCENTAGE)
    percentageLabel:SetColor(Style.TEXT_COLOR_WHITE.r, Style.TEXT_COLOR_WHITE.g, Style.TEXT_COLOR_WHITE.b, Style.TEXT_COLOR_WHITE.a)
    percentageLabel:SetText("")
    percentageLabel:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    percentageLabel:SetVerticalAlignment(TEXT_ALIGN_TOP)
    percentageLabel:SetDrawLayer(3)

    -- Health text label: TOP-RIGHT of bar (e.g. "2.1M/3M", "24.3K/24.3K [3.6K]")
    local healthLabel = CreateControl("MugShot_HealthLabel", barContainer, CT_LABEL)
    healthLabel:SetAnchor(TOPRIGHT, barContainer, TOPRIGHT, -8, 5)
    healthLabel:SetFont(Style.FONT_HEALTH)
    healthLabel:SetColor(Style.TEXT_COLOR_WHITE.r, Style.TEXT_COLOR_WHITE.g, Style.TEXT_COLOR_WHITE.b, Style.TEXT_COLOR_WHITE.a)
    healthLabel:SetText("")
    healthLabel:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    healthLabel:SetVerticalAlignment(TEXT_ALIGN_TOP)
    healthLabel:SetDrawLayer(3)

    -- Target name label: BOTTOM-LEFT of bar (e.g. "Target Skeleton, Humanoid", "@cpcharles")
    local targetNameLabel = CreateControl("MugShot_TargetNameLabel", barContainer, CT_LABEL)
    targetNameLabel:SetAnchor(BOTTOMLEFT, barContainer, BOTTOMLEFT, 8, -5)
    targetNameLabel:SetAnchor(BOTTOMRIGHT, barContainer, BOTTOMRIGHT, -8, -5)
    targetNameLabel:SetFont(Style.FONT_NAME)
    targetNameLabel:SetColor(Style.TEXT_COLOR_WHITE.r, Style.TEXT_COLOR_WHITE.g, Style.TEXT_COLOR_WHITE.b, Style.TEXT_COLOR_WHITE.a)
    targetNameLabel:SetText("")
    targetNameLabel:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    targetNameLabel:SetVerticalAlignment(TEXT_ALIGN_BOTTOM)
    targetNameLabel:SetDrawLayer(3)

    -- ── Portrait Box (MugShot!) on the right ──────────────
    -- Border top and bottom align exactly with the bar (both 79px height)
    -- Left border of portraitBg overlaps right border of barBg (-2px) into a clean 2px shared edge
    local portraitBg = CreateControl("MugShot_PortraitBG", frame, CT_BACKDROP)
    portraitBg:ClearAnchors()
    portraitBg:SetDimensions(Style.PORTRAIT_BG_SIZE, Style.PORTRAIT_BG_SIZE)
    portraitBg:SetAnchor(TOPLEFT, barContainer, TOPRIGHT, -2, 0)
    portraitBg:SetCenterTexture("")
    portraitBg:SetEdgeTexture("", 2, 2, 2)
    portraitBg:SetCenterColor(Style.PORTRAIT_BG_COLOR.r, Style.PORTRAIT_BG_COLOR.g, Style.PORTRAIT_BG_COLOR.b, Style.PORTRAIT_BG_COLOR.a)
    portraitBg:SetEdgeColor(Style.BORDER_COLOR_PLAYER.r, Style.BORDER_COLOR_PLAYER.g, Style.BORDER_COLOR_PLAYER.b, Style.BORDER_COLOR_PLAYER.a)
    portraitBg:SetMouseEnabled(true)
    portraitBg:SetDrawLayer(0)

    local portrait = CreateControl("MugShot_Portrait", portraitBg, CT_TEXTURE)
    portrait:SetDimensions(Style.PORTRAIT_SIZE, Style.PORTRAIT_SIZE)
    portrait:SetAnchor(CENTER, portraitBg, CENTER, 0, 0)
    portrait:SetHidden(true)
    portrait:SetDrawLayer(1)

    -- Race badge on top-right of portrait
    local raceIcon = CreateControl("MugShot_RaceIcon", portraitBg, CT_TEXTURE)
    raceIcon:SetDimensions(32, 32)
    raceIcon:SetAnchor(CENTER, portrait, TOPRIGHT, 0, 0)
    raceIcon:SetHidden(true)
    raceIcon:SetDrawLayer(3)

    -- Alliance / Class badge on bottom-right of portrait
    local allianceIcon = CreateControl("MugShot_AllianceIcon", portraitBg, CT_TEXTURE)
    allianceIcon:SetDimensions(32, 32)
    allianceIcon:SetAnchor(CENTER, portrait, BOTTOMRIGHT, 0, 0)
    allianceIcon:SetHidden(true)
    allianceIcon:SetDrawLayer(3)

    -- ── Buffs / Debuffs Container ─────────────────────────
    local effectContainer = CreateControl("MugShot_EffectContainer", frame, CT_CONTROL)
    effectContainer:SetDimensions(Style.FRAME_WIDTH, Style.EFFECT_SLOT_SIZE)
    effectContainer:SetAnchor(TOPLEFT, barContainer, BOTTOMLEFT, 0, 4)
    effectContainer:SetMouseEnabled(true)
    self.effectContainer = effectContainer

    -- Pre-create reusable pool of effect slots
    self.effectSlots = {}
    for i = 1, Style.MAX_EFFECTS do
        self:_GetOrCreateEffectSlot(i)
    end

    -- ── Drag Handlers ─────────────────────────────────────
    local mugShot_settings = MugShot.settings

    local function OnDragStart(ctrl, button)
        if button == MOUSE_BUTTON_INDEX_LEFT and not mugShot_settings:Get().locked then
            frame:StartMoving()
        end
    end

    local function OnDragStop(ctrl, button)
        if button == MOUSE_BUTTON_INDEX_LEFT then
            frame:StopMovingOrResizing()
            local isValid, point, _relativeTo, relativePoint, offsetX, offsetY = frame:GetAnchor(0)
            if isValid then
                mugShot_settings:Set("position", {
                    point         = point,
                    relativePoint = relativePoint,
                    offsetX       = math.floor(offsetX + 0.5),
                    offsetY       = math.floor(offsetY + 0.5),
                })
            end
        end
    end

    local dragTargets = { frame, barContainer, barBg, healthBar, shieldBar, portraitBg, effectContainer }
    for _, ctrl in ipairs(dragTargets) do
        ctrl:SetHandler("OnMouseDown", OnDragStart)
        ctrl:SetHandler("OnMouseUp", OnDragStop)
    end

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
    self.frame           = frame
    self.barContainer    = barContainer
    self.barBg           = barBg
    self.healthBar       = healthBar
    self.shieldBar       = shieldBar
    self.percentageLabel = percentageLabel
    self.healthLabel     = healthLabel
    self.targetNameLabel = targetNameLabel
    self.portraitBg      = portraitBg
    self.portrait        = portrait
    self.raceIcon        = raceIcon
    self.allianceIcon    = allianceIcon
end

-- ── _GetOrCreateEffectSlot ────────────────────────────────
-- Lazily creates and anchors effect slots in rows of 10.
function TargetFrameView:_GetOrCreateEffectSlot(i)
    if self.effectSlots[i] then
        return self.effectSlots[i]
    end

    local slotsPerRow = 10
    local col = (i - 1) % slotsPerRow
    local row = math.floor((i - 1) / slotsPerRow)
    local x = col * (Style.EFFECT_SLOT_SIZE + Style.EFFECT_GAP)
    local y = row * (Style.EFFECT_SLOT_SIZE + Style.EFFECT_GAP)

    local slotBg = CreateControl("MugShot_EffectSlot_" .. i, self.effectContainer, CT_BACKDROP)
    slotBg:SetDimensions(Style.EFFECT_SLOT_SIZE, Style.EFFECT_SLOT_SIZE)
    slotBg:SetAnchor(TOPLEFT, self.effectContainer, TOPLEFT, x, y)
    slotBg:SetCenterTexture("")
    slotBg:SetEdgeTexture("", 1, 1, 1)
    slotBg:SetCenterColor(Style.SLOT_BG_COLOR.r, Style.SLOT_BG_COLOR.g, Style.SLOT_BG_COLOR.b, Style.SLOT_BG_COLOR.a)
    slotBg:SetEdgeColor(Style.BORDER_COLOR_PLAYER.r, Style.BORDER_COLOR_PLAYER.g, Style.BORDER_COLOR_PLAYER.b, Style.BORDER_COLOR_PLAYER.a)
    slotBg:SetDrawLayer(0)
    slotBg:SetHidden(true)

    local slotIcon = CreateControl("MugShot_EffectIcon_" .. i, slotBg, CT_TEXTURE)
    slotIcon:SetDimensions(Style.EFFECT_ICON_SIZE, Style.EFFECT_ICON_SIZE)
    slotIcon:SetAnchor(CENTER, slotBg, CENTER, 0, 0)
    slotIcon:SetDrawLayer(1)

    local timerLabel = CreateControl("MugShot_EffectTimer_" .. i, slotIcon, CT_LABEL)
    timerLabel:SetAnchor(CENTER, slotIcon, CENTER, 0, 0)
    timerLabel:SetDimensions(Style.EFFECT_ICON_SIZE, Style.EFFECT_ICON_SIZE)
    timerLabel:SetFont(Style.FONT_TIMER)
    timerLabel:SetColor(Style.TEXT_COLOR_WHITE.r, Style.TEXT_COLOR_WHITE.g, Style.TEXT_COLOR_WHITE.b, Style.TEXT_COLOR_WHITE.a)
    timerLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    timerLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    timerLabel:SetDrawLayer(2)

    local stackLabel = CreateControl("MugShot_EffectStack_" .. i, slotBg, CT_LABEL)
    stackLabel:SetAnchor(TOPRIGHT, slotBg, TOPRIGHT, 0, 0)
    stackLabel:SetDimensions(Style.EFFECT_SLOT_SIZE, Style.EFFECT_SLOT_SIZE)
    stackLabel:SetFont(Style.FONT_STACK)
    stackLabel:SetColor(Style.TEXT_COLOR_WHITE.r, Style.TEXT_COLOR_WHITE.g, Style.TEXT_COLOR_WHITE.b, Style.TEXT_COLOR_WHITE.a)
    stackLabel:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    stackLabel:SetVerticalAlignment(TEXT_ALIGN_TOP)
    stackLabel:SetDrawLayer(2)

    local sourceLabel = CreateControl("MugShot_EffectSource_" .. i, slotBg, CT_LABEL)
    sourceLabel:SetAnchor(BOTTOMLEFT, slotBg, BOTTOMLEFT, 0, 0)
    sourceLabel:SetDimensions(Style.EFFECT_SLOT_SIZE, Style.EFFECT_SLOT_SIZE)
    sourceLabel:SetFont(Style.FONT_SOURCE)
    sourceLabel:SetColor(Style.TEXT_COLOR_CYAN.r, Style.TEXT_COLOR_CYAN.g, Style.TEXT_COLOR_CYAN.b, Style.TEXT_COLOR_CYAN.a)
    sourceLabel:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    sourceLabel:SetVerticalAlignment(TEXT_ALIGN_BOTTOM)
    sourceLabel:SetDrawLayer(2)

    local slot = {
        bg              = slotBg,
        icon            = slotIcon,
        timerLabel      = timerLabel,
        stackLabel      = stackLabel,
        sourceLabel     = sourceLabel,
        _lastIcon       = nil,
        _lastTimerText  = nil,
        _lastStackText  = nil,
        _lastSourceText = nil,
        _lastBorderR    = nil,
        _lastBorderG    = nil,
        _lastBorderB    = nil,
        _lastBorderA    = nil,
        _lastHidden     = true,
    }
    self.effectSlots[i] = slot
    return slot
end

-- ── SetIdentity ───────────────────────────────────────────
-- @param  pres  table from Presentation.BuildIdentity()
function TargetFrameView:SetIdentity(pres)
    self.targetNameLabel:SetText(pres.displayName or "")

    -- Reaction color on health bar & darker shade for background
    local r = pres.r or 0.85
    local g = pres.g or 0.85
    local b = pres.b or 0.85

    -- 100% vivid baseline color
    self.healthBar:SetColor(r, g, b, 1.0)

    -- Native horizontal gradient: bright on left, subtle depth on right
    self.healthBar:SetGradientColors(ORIENTATION_HORIZONTAL, r, g, b, 1.0, r * 0.70, g * 0.70, b * 0.70, 1.0)

    -- Solid opaque dark tinted background for unfilled portion
    self.barBg:SetCenterColor(r * 0.20, g * 0.20, b * 0.20, 1.0)

    -- Portrait display vs Fallback for no icon (stretch the bar to full width)
    local hasPortrait = pres.portraitTexture and pres.portraitTexture ~= ""
    if hasPortrait then
        self._currentBarWidth = Style.BAR_WIDTH
        self.barContainer:SetDimensions(Style.BAR_BG_WIDTH, Style.BAR_BG_HEIGHT)
        self.portrait:SetTexture(pres.portraitTexture)
        if pres.portraitCoords then
            self.portrait:SetTextureCoords(unpack(pres.portraitCoords))
        else
            self.portrait:SetTextureCoords(0, 1, 0, 1)
        end
        self.portrait:SetHidden(false)
        self.portraitBg:SetHidden(false)
    else
        -- Fallback: Stretch the bar across the entire frame width to fill the empty space
        self._currentBarWidth = Style.FRAME_WIDTH - 4
        self.barContainer:SetDimensions(Style.FRAME_WIDTH, Style.BAR_BG_HEIGHT)
        self.portrait:SetHidden(true)
        self.portraitBg:SetHidden(true)
    end

    -- Refresh bar width immediately if health percentage was already computed
    if self._lastHealthPercent then
        self.healthBar:SetValue(self._lastHealthPercent)
    end
    if self._lastShieldPercent and self._lastShieldPercent > 0 then
        self.shieldBar:SetValue(self._lastShieldPercent)
    end

    -- Race badge
    if hasPortrait and pres.raceIcon and pres.raceIcon ~= "" then
        self.raceIcon:SetTexture(pres.raceIcon)
        self.raceIcon:SetHidden(false)
    else
        self.raceIcon:SetHidden(true)
    end

    -- Alliance badge
    if hasPortrait and pres.allianceIcon and pres.allianceIcon ~= "" then
        self.allianceIcon:SetTexture(pres.allianceIcon)
        if pres.allianceColor then
            self.allianceIcon:SetColor(unpack(pres.allianceColor))
        else
            self.allianceIcon:SetColor(1, 1, 1, 1)
        end
        self.allianceIcon:SetHidden(false)
    else
        self.allianceIcon:SetHidden(true)
    end
end

-- ── SetVitals ─────────────────────────────────────────────
-- @param  pres  table from Presentation.BuildVitals()
function TargetFrameView:SetVitals(pres)
    if pres.healthKnown then
        local pct = pres.healthPercent or 0
        local shieldPct = pres.shieldPercent or 0

        if self._lastHealthPercent ~= pct then
            self.healthBar:SetValue(pct)
            self._lastHealthPercent = pct
        end

        local pText = pres.percentText or ""
        if self._lastPercentText ~= pText then
            self.percentageLabel:SetText(pText)
            self._lastPercentText = pText
        end

        local hText = pres.healthText or ""
        if self._lastHealthText ~= hText then
            self.healthLabel:SetText(hText)
            self._lastHealthText = hText
        end

        -- Shield overlay
        if shieldPct > 0 then
            if self._lastShieldPercent ~= shieldPct then
                self.shieldBar:SetValue(shieldPct)
                self._lastShieldPercent = shieldPct
            end
            local shieldColor = Style.SHIELD_COLOR
            self.shieldBar:SetColor(shieldColor.r, shieldColor.g, shieldColor.b, shieldColor.a)
            self.shieldBar:SetGradientColors(ORIENTATION_HORIZONTAL, shieldColor.r, shieldColor.g, shieldColor.b, shieldColor.a, shieldColor.r * 0.75, shieldColor.g * 0.75, shieldColor.b * 0.75, shieldColor.a)
            self.shieldBar:SetHidden(false)
        else
            if self._lastShieldPercent ~= 0 then
                self.shieldBar:SetValue(0)
                self._lastShieldPercent = 0
            end
            self.shieldBar:SetHidden(true)
        end
    else
        self._lastHealthPercent = 0
        self._lastShieldPercent = 0
        self._lastPercentText   = ""
        self._lastHealthText    = ""
        self.healthBar:SetValue(0)
        self.shieldBar:SetValue(0)
        self.shieldBar:SetHidden(true)
        self.percentageLabel:SetText("")
        self.healthLabel:SetText("")
    end
end

-- ── SetEffects ────────────────────────────────────
-- @param  items  table array from Presentation.BuildEffects()
function TargetFrameView:SetEffects(items)
    items = items or {}
    local numItems = #items
    local numSlots = math_max(numItems, #self.effectSlots)

    -- Adjust container & frame height only when row count changes (Dirty Flag)
    local slotsPerRow = 10
    local numRows = math_max(1, math_ceil(math_max(1, numItems) / slotsPerRow))
    if self._lastNumRows ~= numRows then
        self._lastNumRows = numRows
        local containerHeight = numRows * Style.EFFECT_SLOT_SIZE + (numRows - 1) * Style.EFFECT_GAP
        self.effectContainer:SetDimensions(Style.FRAME_WIDTH, containerHeight)
        self.frame:SetDimensions(Style.FRAME_WIDTH, Style.FRAME_HEIGHT + containerHeight + 6)
    end

    for i = 1, numSlots do
        local data = items[i]
        if data then
            local slot = self:_GetOrCreateEffectSlot(i)

            local icon = data.icon or ""
            if slot._lastIcon ~= icon then
                slot.icon:SetTexture(icon)
                slot._lastIcon = icon
            end

            local timerText = data.timerText or ""
            if slot._lastTimerText ~= timerText then
                slot.timerLabel:SetText(timerText)
                slot._lastTimerText = timerText
            end

            local stackText = data.stackText or ""
            if slot._lastStackText ~= stackText then
                slot.stackLabel:SetText(stackText)
                slot._lastStackText = stackText
            end

            local sourceText = data.sourceText or ""
            if slot._lastSourceText ~= sourceText then
                slot.sourceLabel:SetText(sourceText)
                slot._lastSourceText = sourceText
            end

            local br, bg, bb, ba = data.borderR or 0, data.borderG or 0, data.borderB or 0, data.borderA or 1
            if slot._lastBorderR ~= br or slot._lastBorderG ~= bg or slot._lastBorderB ~= bb or slot._lastBorderA ~= ba then
                slot.bg:SetEdgeColor(br, bg, bb, ba)
                slot._lastBorderR = br
                slot._lastBorderG = bg
                slot._lastBorderB = bb
                slot._lastBorderA = ba
            end

            if slot._lastHidden ~= false then
                slot.bg:SetHidden(false)
                slot._lastHidden = false
            end
        else
            local slot = self.effectSlots[i]
            if slot and slot._lastHidden ~= true then
                slot.bg:SetHidden(true)
                slot._lastHidden = true
                slot.icon:SetTexture("")
                slot.timerLabel:SetText("")
                slot.stackLabel:SetText("")
                slot.sourceLabel:SetText("")
                slot.bg:SetEdgeColor(0, 0, 0, 1)
                slot._lastIcon = nil
                slot._lastTimerText = nil
                slot._lastStackText = nil
                slot._lastSourceText = nil
                slot._lastBorderR = nil
                slot._lastBorderG = nil
                slot._lastBorderB = nil
                slot._lastBorderA = nil
            end
        end
    end
end

-- ── SetVisible ────────────────────────────────────────────
-- @param  visible  bool
function TargetFrameView:SetVisible(visible)
    self._shouldBeVisible = visible
    self.frame:SetHidden(not visible)
    if self.fragment then
        self.fragment:Refresh()
    end
end

-- ── SetMoveMode ───────────────────────────────────────────
-- Toggles visual feedback (glowing cyan border) for repositioning.
-- @param  enabled  bool
function TargetFrameView:SetMoveMode(enabled)
    if enabled then
        self.barBg:SetEdgeColor(Style.MOVE_MODE_BORDER.r, Style.MOVE_MODE_BORDER.g, Style.MOVE_MODE_BORDER.b, Style.MOVE_MODE_BORDER.a)
        self.portraitBg:SetEdgeColor(Style.MOVE_MODE_BORDER.r, Style.MOVE_MODE_BORDER.g, Style.MOVE_MODE_BORDER.b, Style.MOVE_MODE_BORDER.a)
    else
        self.barBg:SetEdgeColor(Style.BORDER_COLOR_PLAYER.r, Style.BORDER_COLOR_PLAYER.g, Style.BORDER_COLOR_PLAYER.b, Style.BORDER_COLOR_PLAYER.a)
        self.portraitBg:SetEdgeColor(Style.BORDER_COLOR_PLAYER.r, Style.BORDER_COLOR_PLAYER.g, Style.BORDER_COLOR_PLAYER.b, Style.BORDER_COLOR_PLAYER.a)
    end
end

-- ── ApplyLayout ───────────────────────────────────────────
-- Applies saved position from settings.
-- @param  settings  table from Settings:Get()
function TargetFrameView:ApplyLayout(settings)
    local pos = settings.position
    if not pos then return end

    self.frame:ClearAnchors()
    self.frame:SetAnchor(
        pos.point         or TOP,
        GuiRoot,
        pos.relativePoint or TOP,
        pos.offsetX       or 0,
        pos.offsetY       or 88
    )
end

-- ── Reset ─────────────────────────────────────────────────
-- Clears all displayed data without hiding the frame.
function TargetFrameView:Reset()
    self._currentBarWidth   = Style.BAR_WIDTH
    self._lastHealthPercent = 0
    self._lastShieldPercent = 0
    self._lastPercentText   = ""
    self._lastHealthText    = ""
    self._lastNumRows       = nil
    self.barContainer:SetDimensions(Style.BAR_BG_WIDTH, Style.BAR_BG_HEIGHT)
    self.percentageLabel:SetText("")
    self.healthLabel:SetText("")
    self.targetNameLabel:SetText("")
    self.healthBar:SetValue(0)
    self.shieldBar:SetValue(0)
    self.shieldBar:SetHidden(true)
    self.barBg:SetCenterColor(Style.BAR_BG_COLOR.r, Style.BAR_BG_COLOR.g, Style.BAR_BG_COLOR.b, Style.BAR_BG_COLOR.a)
    self.portrait:SetTextureCoords(0, 1, 0, 1)
    self.portrait:SetHidden(true)
    self.portraitBg:SetHidden(true)
    self.raceIcon:SetHidden(true)
    self.allianceIcon:SetHidden(true)
    self:SetEffects({})
end

MugShot.TargetFrameView = TargetFrameView
MugShot.logger:Info("=== TargetFrameView loaded ===")
