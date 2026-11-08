-- Window, target header, effect slots, layout, preview mode and redraw.
local BEV = BetterEffectViewer

local HEADER_MIN_WIDTH = 120
local HEADER_MAX_WIDTH = 360
local HEADER_PADDING = 28

local REACTION_COLORS = {
    hostile = { 0.95, 0.33, 0.30 },
    neutral = { 1.00, 0.80, 0.32 },
    friendly = { 0.45, 0.88, 0.50 },
    preview = { 0.31, 0.76, 0.97 },
}

local EDIT_ACCENT = REACTION_COLORS.preview

-- Effects shown while the window is unlocked and nothing is targeted.
-- duration 0 = permanent. Icons come from the game so they match the live client.
local PREVIEW_EFFECTS = {
    { abilityId = 61665, effectType = BUFF_EFFECT_TYPE_BUFF, duration = 22, mine = true },
    { abilityId = 61687, effectType = BUFF_EFFECT_TYPE_BUFF, duration = 14 },
    { abilityId = 61747, effectType = BUFF_EFFECT_TYPE_BUFF, duration = 6, stacks = 2 },
    { abilityId = 61745, effectType = BUFF_EFFECT_TYPE_BUFF, duration = 0 },
    { abilityId = 61743, effectType = BUFF_EFFECT_TYPE_DEBUFF, duration = 9, mine = true },
    { abilityId = 61742, effectType = BUFF_EFFECT_TYPE_DEBUFF, duration = 30, stacks = 3 },
    { abilityId = 145975, effectType = BUFF_EFFECT_TYPE_DEBUFF, duration = 4 },
}

local FALLBACK_ICON = "/esoui/art/icons/icon_missing.dds"

local function fontString(face, size, effect)
    return string.format("%s|%d|%s", face, size, effect)
end

---------------------------------------------------------------------------
-- Creation
---------------------------------------------------------------------------

function BEV:CreateUI()
    local win = BetterEffectViewer_Window
    local content = win:GetNamedChild("Content")
    local header = content:GetNamedChild("Header")

    self.win = win
    self.content = content
    self.editOverlay = win:GetNamedChild("EditOverlay")
    self.editHint = win:GetNamedChild("EditHint")
    self.header = header
    self.headerBg = header:GetNamedChild("Bg")
    self.headerAccent = header:GetNamedChild("Accent")
    self.headerName = header:GetNamedChild("Name")

    self.groups = {
        buff = { kind = "Buff", container = content:GetNamedChild("Buffs"), slots = {}, list = {}, visible = 0 },
        debuff = { kind = "Debuff", container = content:GetNamedChild("Debuffs"), slots = {}, list = {}, visible = 0 },
    }

    -- Static chrome colours
    self.editOverlay:SetCenterColor(0.04, 0.07, 0.10, 0.45)
    self.editOverlay:SetEdgeColor(EDIT_ACCENT[1], EDIT_ACCENT[2], EDIT_ACCENT[3], 0.9)
    self.editOverlay:SetEdgeTexture("", 1, 1, 1, 0)
    self.editHint:SetColor(EDIT_ACCENT[1], EDIT_ACCENT[2], EDIT_ACCENT[3], 1)

    self.headerBg:SetCenterColor(0, 0, 0, 0.65)
    self.headerBg:SetEdgeColor(0, 0, 0, 0.9)
    self.headerBg:SetEdgeTexture("", 1, 1, 1, 0)
    if TEXT_WRAP_MODE_ELLIPSIS then
        self.headerName:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    end

    -- Fade-out when the target goes away
    self.fadeOut = ANIMATION_MANAGER:CreateTimeline()
    self.fadeAnimation = self.fadeOut:InsertAnimation(ANIMATION_ALPHA, content)
    self.fadeOut:SetHandler("OnStop", function()
        if not self.contentShown then
            content:SetHidden(true)
        end
    end)
    self.contentShown = false

    -- Position
    self:RestorePosition()
    win:SetHandler("OnMoveStop", function()
        self:SavePosition()
    end)

    -- Show only with the HUD, never over menus.
    if ZO_HUDFadeSceneFragment and HUD_SCENE and HUD_UI_SCENE then
        self.fragment = ZO_HUDFadeSceneFragment:New(win)
        HUD_SCENE:AddFragment(self.fragment)
        HUD_UI_SCENE:AddFragment(self.fragment)
    else
        win:SetHidden(false)
    end
end

function BEV:RestorePosition()
    self.win:ClearAnchors()
    self.win:SetAnchor(TOP, GuiRoot, CENTER, self.sv.offsetX, self.sv.offsetY)
end

function BEV:SavePosition()
    local win = self.win
    self.sv.offsetX = zo_round(win:GetLeft() + win:GetWidth() / 2 - GuiRoot:GetWidth() / 2)
    self.sv.offsetY = zo_round(win:GetTop() - GuiRoot:GetHeight() / 2)
    self:RestorePosition()
end

function BEV:ResetPosition()
    self.sv.offsetX = self.defaults.offsetX
    self.sv.offsetY = self.defaults.offsetY - 40
    self:RestorePosition()
end

---------------------------------------------------------------------------
-- Slots
---------------------------------------------------------------------------

local function styleSlotChrome(self, slot)
    local edge = self.sv.borderSize
    local timerSize = self.fontSize
    local countSize = math.max(10, math.floor(timerSize * 0.75))

    slot.border:SetEdgeTexture("", 1, 1, edge, 0)
    slot.border:SetCenterColor(0, 0, 0, 0.8)

    for _, child in ipairs({ slot.icon, slot.sweep }) do
        child:ClearAnchors()
        child:SetAnchor(TOPLEFT, slot, TOPLEFT, edge, edge)
        child:SetAnchor(BOTTOMRIGHT, slot, BOTTOMRIGHT, -edge, -edge)
    end

    slot.timer:SetFont(fontString("$(BOLD_FONT)", timerSize, "soft-shadow-thick"))
    slot.count:SetFont(fontString("$(BOLD_FONT)", countSize, "soft-shadow-thick"))
    slot.count:SetColor(self:UnpackColor(self.sv.stackColor))
end

function BEV:AcquireSlot(group, index)
    local slot = group.slots[index]
    if slot then
        return slot
    end

    slot = CreateControlFromVirtual("BetterEffectViewer_" .. group.kind .. "Slot" .. index, group.container,
        "BetterEffectViewer_SlotTemplate")
    slot.icon = slot:GetNamedChild("Icon")
    slot.border = slot:GetNamedChild("Border")
    slot.sweep = slot:GetNamedChild("Sweep")
    slot.timer = slot:GetNamedChild("Timer")
    slot.count = slot:GetNamedChild("Count")
    if slot.sweep.SetFillColor then
        slot.sweep:SetFillColor(0, 0, 0, 0.6)
    end

    styleSlotChrome(self, slot)
    group.slots[index] = slot
    group.positionKey = nil
    return slot
end

local function clearSlot(slot)
    slot.effect = nil
    slot.sweepEnd = nil
    slot.isFlashing = false
    slot:SetHidden(true)
end

local function setupSlot(self, slot, effect, now)
    local sv = self.sv
    slot.effect = effect

    local icon = effect.iconName
    if not icon or icon == "" then
        icon = FALLBACK_ICON
    end
    if slot.iconPath ~= icon then
        slot.icon:SetTexture(icon)
        slot.iconPath = icon
    end

    local dim = sv.dimOtherEffects and not effect.castByPlayer
    slot.icon:SetAlpha(dim and 0.75 or 1)
    slot.icon:SetDesaturation(dim and 0.25 or 0)

    slot.count:SetText(effect.stackCount > 1 and tostring(effect.stackCount) or "")

    local borderColor, timerColor = self:GetColorsForEffect(effect)
    slot.baseBorderColor = borderColor
    slot.baseTimerColor = timerColor
    slot.border:SetEdgeColor(self:UnpackColor(borderColor))
    slot.timer:SetColor(self:UnpackColor(timerColor))
    slot.isFlashing = false
    slot.lastTimerText = nil

    -- Radial sweep, restarted only when the effect is (re)applied.
    local sweep = slot.sweep
    if sv.showDurationSweep and not effect.isPermanent and effect.endTime > now then
        if slot.sweepEnd ~= effect.endTime or slot.sweepKey ~= effect.key then
            local durationMs = math.max(1, (effect.endTime - effect.startTime) * 1000)
            local remainingMs = (effect.endTime - now) * 1000
            sweep:StartCooldown(remainingMs, durationMs, CD_TYPE_RADIAL, CD_TIME_TYPE_TIME_UNTIL, false)
            slot.sweepEnd = effect.endTime
            slot.sweepKey = effect.key
        end
        sweep:SetHidden(false)
    else
        sweep:SetHidden(true)
        slot.sweepEnd = nil
    end

    slot:SetHidden(false)
end

---------------------------------------------------------------------------
-- Header
---------------------------------------------------------------------------

local function getReactionKey(unitTag)
    if IsUnitAttackable(unitTag) then
        return "hostile"
    end
    local reaction = GetUnitReaction(unitTag)
    if reaction == UNIT_REACTION_HOSTILE then
        return "hostile"
    elseif reaction == UNIT_REACTION_FRIENDLY
        or reaction == UNIT_REACTION_PLAYER_ALLY
        or reaction == UNIT_REACTION_NPC_ALLY then
        return "friendly"
    end
    return "neutral"
end

function BEV:SetHeaderText(text, color)
    local header, label = self.header, self.headerName
    -- Measure at full width, then shrink the plate to fit the name.
    header:SetWidth(HEADER_MAX_WIDTH)
    label:SetText(text)
    local width = zo_clamp(label:GetTextWidth() + HEADER_PADDING, HEADER_MIN_WIDTH, HEADER_MAX_WIDTH)
    header:SetWidth(width)

    local r, g, b = color[1], color[2], color[3]
    label:SetColor(r, g, b, 1)
    self.headerAccent:SetColor(r, g, b, 0.9)
end

function BEV:UpdateTargetHeader(unitTag)
    self:SetHeaderStale(false)
    if unitTag then
        local name = zo_strformat(SI_UNIT_NAME, GetUnitName(unitTag))
        self:SetHeaderText(name, REACTION_COLORS[getReactionKey(unitTag)])
    elseif self.previewActive then
        self:SetHeaderText("Target Preview", REACTION_COLORS.preview)
    end
end

-- Dims the header while the last target is held after the reticle moved off it.
function BEV:SetHeaderStale(isStale)
    self.header:SetAlpha(isStale and 0.5 or 1)
end

---------------------------------------------------------------------------
-- Appearance & layout
---------------------------------------------------------------------------

-- Re-applies fonts, borders and sizes to everything, then redraws.
function BEV:RefreshAppearance()
    if not self.groups then
        return
    end

    local headerSize = self.sv.targetNameFontSize
    self.headerHeight = headerSize + 10
    self.header:SetHeight(self.headerHeight)
    self.headerName:SetFont(fontString("$(BOLD_FONT)", headerSize, "soft-shadow-thick"))

    for _, group in pairs(self.groups) do
        for _, slot in ipairs(group.slots) do
            styleSlotChrome(self, slot)
            slot.sweepEnd = nil
        end
        group.positionKey = nil
    end

    self.layoutKey = nil
    self:Redraw()
end

local function positionSlots(group, count, cols, size, spacing, contentWidth, alignment)
    local key = string.format("%d:%d:%d:%d:%d:%s", count, cols, size, spacing, contentWidth, alignment)
    if group.positionKey == key then
        return
    end
    group.positionKey = key

    local step = size + spacing
    for i = 1, count do
        local index = i - 1
        local row = math.floor(index / cols)
        local col = index % cols
        local inRow = math.min(cols, count - row * cols)
        local rowWidth = inRow * size + (inRow - 1) * spacing

        local x = 0
        if alignment == "center" then
            x = math.floor((contentWidth - rowWidth) / 2)
        elseif alignment == "right" then
            x = contentWidth - rowWidth
        end

        local slot = group.slots[i]
        slot:ClearAnchors()
        slot:SetAnchor(TOPLEFT, group.container, TOPLEFT, x + col * step, row * step)
        slot:SetDimensions(size, size)
    end
end

local function layoutGroup(self, group, y, contentWidth)
    local container = group.container
    if not group.enabled then
        container:SetHidden(true)
        return y, false
    end

    local size, cols, spacing = self.iconSize, self.maxCols, self.sv.iconSpacing
    local rows = math.ceil(group.visible / cols)
    if rows == 0 and not self.sv.collapseEmptyRows then
        rows = 1
    end
    if rows == 0 then
        container:SetHidden(true)
        return y, false
    end

    local height = rows * size + (rows - 1) * spacing
    container:SetHidden(false)
    container:ClearAnchors()
    container:SetAnchor(TOPLEFT, self.content, TOPLEFT, 0, y)
    container:SetDimensions(contentWidth, height)

    positionSlots(group, group.visible, cols, size, spacing, contentWidth, self.sv.alignment)
    return y + height + self.GROUP_GAP, true
end

function BEV:UpdateLayout()
    local sv = self.sv
    local size, cols, spacing = self.iconSize, self.maxCols, sv.iconSpacing
    local contentWidth = cols * size + (cols - 1) * spacing

    local y = 0
    local lastGap = 0
    local showHeader = sv.showTargetName
    self.header:SetHidden(not showHeader)
    if showHeader then
        y = self.headerHeight + self.HEADER_GAP
        lastGap = self.HEADER_GAP
    end

    local first, second = self.groups.buff, self.groups.debuff
    if sv.groupOrder == "debuffsFirst" then
        first, second = second, first
    end

    local placed
    y, placed = layoutGroup(self, first, y, contentWidth)
    if placed then
        lastGap = self.GROUP_GAP
    end
    y, placed = layoutGroup(self, second, y, contentWidth)
    if placed then
        lastGap = self.GROUP_GAP
    end

    local height = math.max(1, y - lastGap)
    self.content:SetDimensions(contentWidth, height)
    self.win:SetDimensions(contentWidth, height)
end

---------------------------------------------------------------------------
-- Visibility, lock & preview
---------------------------------------------------------------------------

function BEV:SetContentShown(shown)
    if shown == self.contentShown then
        return
    end
    self.contentShown = shown

    local content = self.content
    if shown then
        self.fadeOut:Stop()
        content:SetAlpha(1)
        content:SetHidden(false)
        self.nextVisualUpdateAt = 0
    else
        local duration = self.sv.fadeOutDuration
        if duration <= 0 then
            content:SetHidden(true)
            return
        end
        self.fadeAnimation:SetAlphaValues(content:GetAlpha(), 0)
        self.fadeAnimation:SetDuration(duration * 1000)
        self.fadeOut:PlayFromStart()
    end
end

function BEV:RefreshVisibility()
    local hasIcons = self.groups.buff.visible + self.groups.debuff.visible > 0
    local shown = self.previewActive or (self.hasTarget and (self.sv.showTargetName or hasIcons))
    self:SetContentShown(shown)
end

function BEV:ApplyLockState()
    local unlocked = not self.sv.lockWindow
    self.win:SetMouseEnabled(unlocked)
    self.win:SetMovable(unlocked)
    self.editOverlay:SetHidden(not unlocked)
    self.editHint:SetHidden(not unlocked)

    self.previewActive = unlocked
    if unlocked then
        self:BuildPreviewEffects(GetFrameTimeSeconds())
    else
        self.previewEffects = nil
    end

    if not self.hasTarget then
        self:UpdateTargetHeader(nil)
    end
    self:Redraw()
end

function BEV:SetLocked(locked)
    self.sv.lockWindow = locked
    self:ApplyLockState()
end

function BEV:BuildPreviewEffects(now)
    local effects = {}
    for index, def in ipairs(PREVIEW_EFFECTS) do
        local permanent = def.duration == 0
        -- Stagger start times so the preview shows a spread of timers.
        local elapsed = permanent and 0 or (def.duration * (index % 3) / 4)
        effects[index] = {
            key = -index,
            name = GetAbilityName(def.abilityId),
            abilityId = def.abilityId,
            iconName = GetAbilityIcon(def.abilityId),
            effectType = def.effectType,
            startTime = now - elapsed,
            endTime = permanent and 0 or (now - elapsed + def.duration),
            duration = def.duration,
            stackCount = def.stacks or 0,
            castByPlayer = def.mine == true,
            isPermanent = permanent,
        }
    end
    self.previewEffects = effects
    self.needsRedraw = true
end

-- Loops expired preview timers. Returns true if anything restarted.
function BEV:RefreshPreviewEffects(now)
    if not self.previewEffects or self.hasTarget then
        return false
    end
    local restarted = false
    for _, effect in ipairs(self.previewEffects) do
        if not effect.isPermanent and now >= effect.endTime then
            effect.startTime = now
            effect.endTime = now + effect.duration
            restarted = true
        end
    end
    return restarted
end

---------------------------------------------------------------------------
-- Redraw
---------------------------------------------------------------------------

function BEV:GetMaxSlotsPerGroup()
    local rows = self.sv.maxRows
    if self.runtime.maxRows then
        rows = math.min(rows, self.runtime.maxRows)
    end
    return math.min(self.maxCols * rows, self.MAX_SLOTS_PER_GROUP)
end

local function fillGroup(self, group, now, cap)
    local list = group.list
    local count = 0
    if group.enabled then
        self:SortEffects(list, now)
        count = math.min(#list, cap)
        for i = 1, count do
            setupSlot(self, self:AcquireSlot(group, i), list[i], now)
        end
    end
    for i = count + 1, group.visible do
        clearSlot(group.slots[i])
    end
    group.visible = count
end

function BEV:Redraw(now)
    self.needsRedraw = false
    if not self.groups then
        return
    end
    now = now or GetFrameTimeSeconds()

    local sv = self.sv
    local buff, debuff = self.groups.buff, self.groups.debuff
    buff.enabled = sv.showBuffs
    debuff.enabled = sv.showDebuffs
    ZO_ClearNumericallyIndexedTable(buff.list)
    ZO_ClearNumericallyIndexedTable(debuff.list)

    local function collect(effect)
        if sv.showPermanents or not effect.isPermanent then
            local list = effect.effectType == BUFF_EFFECT_TYPE_BUFF and buff.list or debuff.list
            list[#list + 1] = effect
        end
    end

    if self.previewActive and not self.hasTarget and self.previewEffects then
        for _, effect in ipairs(self.previewEffects) do
            collect(effect)
        end
    else
        for _, effect in pairs(self.effects) do
            collect(effect)
        end
    end

    local cap = self:GetMaxSlotsPerGroup()
    fillGroup(self, buff, now, cap)
    fillGroup(self, debuff, now, cap)

    self:UpdateLayout()
    self:RefreshVisibility()
    self.nextVisualUpdateAt = 0
end
