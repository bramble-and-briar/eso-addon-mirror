local ME = MyExtras
local AB = {}
ME.ActionBar = AB

--------------------------------------------------
-- Config
--------------------------------------------------
local FIRST_SLOT    = ACTION_BAR_FIRST_NORMAL_SLOT_INDEX + 1
local SLOT_COUNT    = 5
local ULT_SLOT      = ACTION_BAR_ULTIMATE_SLOT_INDEX + 1
local QUICKSLOT_BAR = HOTBAR_CATEGORY_QUICKSLOT_WHEEL
local UPDATE_MS     = 100
local GLOBAL_CD_MS  = 1500
local POTION_CD_MS  = 5000
local KEY_SCALE     = 100
local NUMBER_DROP   = 0.12
local PULSE_LOW     = 0.45
local MOVE_SPEED    = 500
local SCALE_SPEED   = 15
local SIZE_MIN      = 30
local SIZE_MAX      = 80
local MOVE_SCENE    = "MyExtras_ActionBarMove"
local HIDE_REASON   = "MyExtras_ActionBar"

local RESOURCE_OFFSET_GAMEPAD  = -105
local RESOURCE_OFFSET_KEYBOARD = -74
local RESOURCE_SIDE_OFFSET     = 237

local STACK_WINDOWS = {
    { name = "ZO_SynergyTopLevel" },
    { name = "ZO_ObjectiveCapture" },
    { name = "ZO_PlayerToPlayerArea", lift = -40 },
    { name = "ZO_ActiveCombatTips" },
    { name = "ZO_InstanceKickWarning_Alive" },
}

local STACK_PINNED = {
    { name = "ZO_RamTopLevel", offsetY = -210 },
}

local TEX_RING  = "MyExtras/Textures/ring.dds"
local TEX_RING_EDGE = "MyExtras/Textures/ringedge.dds"
local TEX_FRAME = "MyExtras/Textures/frame.dds"
local TEX_DISC  = "MyExtras/Textures/disc.dds"
local TEX_ARROW = "MyExtras/Textures/arrow.dds"
local TEX_ARROW_EDGE = "MyExtras/Textures/arrowedge.dds"
local FONT      = "EsoUI/Common/Fonts/FTN87.otf"

local SUBMENU_ICON = "EsoUI/Art/Addons/Gamepad/gp_mod_listing_category_abilityBar.dds"


local PREVIEW_FRONT  = { 16, 0, 12, 0, 6 }
local PREVIEW_BACK   = { 10, 4, 0, 14, 0 }
local PREVIEW_STACKS = { 0, 0, 3, 0, 0 }

AB.defaults = {
    actionBarEnabled    = false,
    actionBarShow       = "Always",
    actionBarResources  = "Row",
    actionBarPulse      = true,
    actionBarPulseSpeed = 3,
    actionBarRingStyle  = "Alliance",
    actionBarRingColor  = { r = 1, g = 1, b = 1, a = 1 },
    actionBarNumStyle   = "Alliance",
    actionBarNumColor   = { r = 1, g = 1, b = 1, a = 1 },
    actionBarSize       = 50,
    actionBarButtons    = true,
    actionBarUltNumber  = "Points",
    actionBarPosX       = 960,
    actionBarPosY       = 1050,
}

AB.showChoices = {
    { name = "Always",    value = "Always" },
    { name = "In Combat", value = "Combat" },
}

AB.resourceChoices = {
    { name = "Same Row",      value = "Row"   },
    { name = "Health on Top", value = "Split" },
}

AB.ultChoices = {
    { name = "Points",  value = "Points"  },
    { name = "Percent", value = "Percent" },
}

AB.preview = false

local front      = {}
local back       = {}
local hudShowing = { hud = false, hudui = false }
local inCombat   = false
local isDead     = false
local ticking    = false
local previewStart = 0

local pulses    = {}
local ringR, ringG, ringB    = 0.72, 0.56, 0.09
local numR, numG, numB       = 1, 1, 1
local activeBar = HOTBAR_CATEGORY_PRIMARY
local backBar   = HOTBAR_CATEGORY_BACKUP

local tenthTexts   = {}
local numberTexts  = {}
local minuteTexts  = {}
local percentTexts = {}

--------------------------------------------------
-- Helpers
--------------------------------------------------
local function SV()
    return ME.savedVariables
end

local function IsEnabled()
    local sv = SV()
    return sv ~= nil and sv.actionBarEnabled == true
end

local function NumberText(value)
    local text = numberTexts[value]
    if not text then
        text = tostring(value)
        numberTexts[value] = text
    end
    return text
end

local function PercentText(value)
    local text = percentTexts[value]
    if not text then
        text = value .. "%"
        percentTexts[value] = text
    end
    return text
end

local function TimerText(ms)
    if ms >= 60000 then
        local minutes = zo_floor(ms / 60000)
        local text = minuteTexts[minutes]
        if not text then
            text = minutes .. "m"
            minuteTexts[minutes] = text
        end
        return text
    elseif ms >= 3000 then
        return NumberText(zo_floor(ms / 1000))
    end
    local tenths = zo_floor(ms / 100)
    if tenths < 0 then tenths = 0 end
    local text = tenthTexts[tenths]
    if not text then
        text = string.format("%.1f", tenths / 10)
        tenthTexts[tenths] = text
    end
    return text
end

local function TimerColor(ms)
    if ms >= 3000 then return numR, numG, numB, 1 end
    if ms >= 1000 then return 1, 0.6, 0.1, 1 end
    return 1, 0.25, 0.25, 1
end

local function SetLabel(label, text)
    if label.shown ~= text then
        label.shown = text
        label:SetText(text)
    end
end

local function SetLabelColor(label, r, g, b)
    if label.r ~= r or label.g ~= g or label.b ~= b then
        label.r, label.g, label.b = r, g, b
        label:SetColor(r, g, b, 1)
    end
end

local function Font(size, style)
    return string.format("%s|%d|%s", FONT, math.max(10, size), style or "thick-outline")
end

local function PickColor(style, custom, r, g, b)
    if style == "Custom" and type(custom) == "table" then
        return custom.r or 1, custom.g or 1, custom.b or 1
    end
    return r, g, b
end

local function ResolveColors()
    local r, g, b = 1, 1, 1
    local color = GetAllianceColor(GetUnitAlliance("player"))
    if color then r, g, b = color:UnpackRGB() end
    local sv = SV()
    ringR, ringG, ringB = PickColor(sv.actionBarRingStyle, sv.actionBarRingColor, r, g, b)
    numR, numG, numB = PickColor(sv.actionBarNumStyle, sv.actionBarNumColor, r, g, b)
end

local function ResolveBars()
    activeBar = GetActiveHotbarCategory()
    if activeBar == HOTBAR_CATEGORY_PRIMARY then
        backBar = HOTBAR_CATEGORY_BACKUP
    elseif activeBar == HOTBAR_CATEGORY_BACKUP then
        backBar = HOTBAR_CATEGORY_PRIMARY
    else
        backBar = nil
    end
end

local function StyleIcon(slotIndex, hotbar)
    if GetSlotType(slotIndex, hotbar) ~= ACTION_TYPE_ABILITY then return nil end
    local abilityId = GetSlotBoundId(slotIndex, hotbar)
    if not abilityId or abilityId == 0 then return nil end
    local skillType, lineIndex, skillIndex = GetSpecificSkillAbilityKeysByAbilityId(abilityId)
    if not (skillType and lineIndex and skillIndex) or skillType == 0 or lineIndex == 0 or skillIndex == 0 then
        return nil
    end
    local progressionId = GetProgressionSkillProgressionId(skillType, lineIndex, skillIndex)
    if not progressionId or progressionId == 0 then return nil end
    local collectibleId = GetActiveProgressionSkillAbilityFxOverrideCollectibleId(progressionId)
    if not collectibleId or collectibleId == 0 then return nil end
    local icon = GetCollectibleIcon(collectibleId)
    if type(icon) ~= "string" or icon == "" then return nil end
    return icon
end

local function SlotIcon(slotIndex, hotbar)
    if not hotbar or not IsSlotUsed(slotIndex, hotbar) then return nil end
    if hotbar ~= QUICKSLOT_BAR then
        local styled = StyleIcon(slotIndex, hotbar)
        if styled then return styled end
    end
    local icon = GetSlotTexture(slotIndex, hotbar)
    if type(icon) ~= "string" or icon == "" then return nil end
    return icon
end

--------------------------------------------------
-- Controls
--------------------------------------------------
local function NewTexture(name, parent, path, level)
    local texture = WINDOW_MANAGER:CreateControl(name, parent, CT_TEXTURE)
    if path then texture:SetTexture(path) end
    texture:SetDrawLevel(level)
    return texture
end

local function NewLabel(name, parent, level)
    local label = WINDOW_MANAGER:CreateControl(name, parent, CT_LABEL)
    label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    label:SetDrawLevel(level)
    return label
end

local function NewCooldown(name, parent, level)
    local cooldown = WINDOW_MANAGER:CreateControl(name, parent, CT_COOLDOWN)
    cooldown:SetDrawLevel(level)
    return cooldown
end

local function ApplyEdge(slot)
    if slot.glow then
        slot.edge:SetColor(ringR, ringG, ringB, 1)
        return
    end
    slot.edge:SetColor(0, 0, 0, slot.used and 1 or 0.6)
end

local function CreateSlot(name, parent, slotIndex, withKey, isBack)
    local slot = WINDOW_MANAGER:CreateControl(name, parent, CT_CONTROL)
    slot.slotIndex = slotIndex
    slot.isBack = isBack
    slot.frame  = NewTexture(name .. "Frame", slot, nil, 2)
    slot.icon   = NewTexture(name .. "Icon", slot, nil, 3)
    slot.cd     = NewCooldown(name .. "Cooldown", slot, 4)
    slot.edge   = NewTexture(name .. "Edge", slot, TEX_FRAME, 5)
    slot.timer  = NewLabel(name .. "Timer", slot, 6)
    slot.stacks = NewLabel(name .. "Stacks", slot, 6)

    if isBack then slot.icon:SetDesaturation(1) end

    slot.edge:SetAnchorFill(slot)
    slot.frame:SetColor(0, 0, 0, 1)
    ApplyEdge(slot)
    slot.cd:SetFillColor(0, 0, 0, 0.7)
    slot.cd:SetHidden(true)
    slot.stacks:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    slot.stacks:SetVerticalAlignment(TEXT_ALIGN_TOP)
    slot.stacks:SetColor(0.45, 0.9, 1, 1)

    if withKey then
        slot.key = NewLabel(name .. "Key", parent, 1)
        ZO_Keybindings_RegisterLabelForBindingUpdate(slot.key, "ACTION_BUTTON_" .. slotIndex, false,
            "GAMEPAD_ACTION_BUTTON_" .. slotIndex, nil, nil, nil, KEY_SCALE)
    end
    return slot
end

local function UltimateKeys(label)
    if IsInGamepadPreferredMode() and ZO_Keybindings_ShouldShowGamepadKeybind() then
        label:SetText(ZO_Keybindings_GenerateIconKeyMarkup(KEY_GAMEPAD_LEFT_SHOULDER, KEY_SCALE)
            .. ZO_Keybindings_GenerateIconKeyMarkup(KEY_GAMEPAD_RIGHT_SHOULDER, KEY_SCALE))
    end
end

local function ClipRound(texture)
    texture:SetHandler("OnRectChanged", function(control, left, top, right, bottom)
        control:SetCircularClip((left + right) / 2, (top + bottom) / 2, (right - left) / 2)
    end)
end

local function CreateRound(name, parent, level)
    local round = WINDOW_MANAGER:CreateControl(name, parent, CT_CONTROL)
    round.bg    = NewTexture(name .. "Bg", round, TEX_DISC, level)
    round.icon  = NewTexture(name .. "Icon", round, nil, level + 1)
    round.track = NewTexture(name .. "Track", round, TEX_RING_EDGE, level + 2)
    round.fill  = NewCooldown(name .. "Fill", round, level + 3)

    round.bg:SetColor(0, 0, 0, 0.8)
    round.bg:SetAnchorFill(round)
    round.track:SetColor(0, 0, 0, 0.9)
    round.track:SetAnchorFill(round)
    round.fill:SetTexture(TEX_RING)
    round.fill:SetAnchorFill(round)
    ClipRound(round.icon)
    return round
end

local function CreateRing(name, parent, keyboardAction, gamepadAction, onKeyChanged)
    local ring = CreateRound(name, parent, 1)
    ring.value = NewLabel(name .. "Value", ring, 11)
    ring.sub   = NewLabel(name .. "Sub", ring, 11)
    ring.sub:SetColor(0.85, 0.85, 0.85, 1)
    ring.value:SetColor(1, 1, 1, 1)

    ring.key = NewLabel(name .. "Key", parent, 1)
    ZO_Keybindings_RegisterLabelForBindingUpdate(ring.key, keyboardAction, false, gamepadAction, onKeyChanged,
        nil, nil, KEY_SCALE)
    return ring
end

function AB:CreatePanel()
    local panel = WINDOW_MANAGER:CreateTopLevelWindow("MyExtras_ActionBarPanel")
    panel:SetClampedToScreen(true)
    panel:SetDrawLayer(DL_BACKGROUND)
    panel:SetDrawTier(DT_LOW)
    panel:SetHidden(true)
    self.panel = panel

    for i = 1, SLOT_COUNT do
        local slotIndex = FIRST_SLOT + i - 1
        front[i] = CreateSlot("MyExtras_ActionBarFront" .. i, panel, slotIndex, true, false)
        back[i]  = CreateSlot("MyExtras_ActionBarBack" .. i, panel, slotIndex, false, true)
    end

    self.arrowEdge = NewTexture("MyExtras_ActionBarArrowEdge", panel, TEX_ARROW_EDGE, 1)
    self.arrowEdge:SetColor(0, 0, 0, 1)
    self.arrow = NewTexture("MyExtras_ActionBarArrow", panel, TEX_ARROW, 2)

    self.potion   = CreateRing("MyExtras_ActionBarPotion", panel, "ACTION_BUTTON_9", "GAMEPAD_ACTION_BUTTON_9")
    self.ultimate = CreateRing("MyExtras_ActionBarUltimate", panel, "ACTION_BUTTON_" .. ULT_SLOT,
        "GAMEPAD_ACTION_BUTTON_" .. ULT_SLOT, UltimateKeys)
    local miniTop = WINDOW_MANAGER:CreateTopLevelWindow("MyExtras_ActionBarMiniPanel")
    miniTop:SetDrawLayer(DL_BACKGROUND)
    miniTop:SetDrawTier(DT_LOW)
    miniTop:SetDrawLevel(1)
    miniTop:SetHidden(true)
    self.miniPanel = miniTop

    self.ultimate.mini = CreateRound("MyExtras_ActionBarUltimateBack", miniTop, 1)
    self.ultimate.mini.icon:SetDesaturation(1)
    self.ultimate.mini:SetHidden(true)
end

--------------------------------------------------
-- Layout
--------------------------------------------------
local function LayoutSlot(slot, panel, x, y, size, border, edge)
    slot:ClearAnchors()
    slot:SetAnchor(TOPLEFT, panel, TOPLEFT, x, y)
    slot:SetDimensions(size, size)

    slot.frame:ClearAnchors()
    slot.frame:SetAnchor(TOPLEFT, slot, TOPLEFT, edge, edge)
    slot.frame:SetAnchor(BOTTOMRIGHT, slot, BOTTOMRIGHT, -edge, -edge)

    local inner = size - border * 2
    slot.icon:ClearAnchors()
    slot.icon:SetAnchor(CENTER, slot, CENTER, 0, 0)
    slot.icon:SetDimensions(inner, inner)
    slot.cd:ClearAnchors()
    slot.cd:SetAnchor(CENTER, slot, CENTER, 0, 0)
    slot.cd:SetDimensions(inner, inner)

    slot.timer:ClearAnchors()
    local timerSize = zo_floor(size * 0.58)
    slot.timer:SetAnchor(CENTER, slot, CENTER, 0, zo_floor(timerSize * NUMBER_DROP))
    slot.timer:SetFont(Font(timerSize))

    slot.stacks:ClearAnchors()
    slot.stacks:SetAnchor(TOPRIGHT, slot, TOPRIGHT, -border - 1, border)
    slot.stacks:SetDimensions(size, size)
    slot.stacks:SetFont(Font(zo_floor(size * 0.3)))
end

local function LayoutRound(round, size)
    round:SetDimensions(size, size)
    local iconSize = zo_floor(size * 0.8)
    round.icon:ClearAnchors()
    round.icon:SetAnchor(CENTER, round, CENTER, 0, 0)
    round.icon:SetDimensions(iconSize, iconSize)
    round.pct = nil
end

local function LayoutRing(ring, panel, centerX, centerY, ringSize, valueScale, valueDrop, keyY, keyHeight, showKeys)
    ring:ClearAnchors()
    ring:SetAnchor(CENTER, panel, TOPLEFT, centerX, centerY)
    ring:SetDimensions(ringSize, ringSize)

    LayoutRound(ring, ringSize)

    ring.value:ClearAnchors()
    local valueSize = zo_floor(ringSize * valueScale)
    ring.value:SetAnchor(CENTER, ring, CENTER, 0, zo_floor(valueSize * valueDrop))
    ring.value:SetFont(Font(valueSize))

    ring.sub:ClearAnchors()
    ring.sub:SetAnchor(TOP, ring, CENTER, 0, zo_floor(ringSize * 0.17))
    ring.sub:SetFont(Font(zo_floor(ringSize * 0.22)))

    ring.key:ClearAnchors()
    ring.key:SetAnchor(TOP, panel, TOPLEFT, centerX, keyY)
    ring.key:SetDimensions(ringSize, keyHeight)
    ring.key:SetFont(Font(zo_floor(keyHeight * 0.8), "soft-shadow-thick"))
    ring.key:SetHidden(not showKeys)
end

function AB:Layout()
    if not self.panel then return end
    local sv = SV()
    local panel = self.panel

    local size     = sv.actionBarSize
    local gap      = math.max(2, zo_floor(size * 0.08))
    local edge     = math.max(2, zo_floor(size * 0.08))
    local border   = math.max(1, edge - 1)
    local ringSize = zo_floor(size * 1.7)
    local arrowW   = zo_floor(size * 0.4)
    local showKeys = sv.actionBarButtons == true
    local keyH     = zo_floor(size * 0.5)
    local side     = gap * 2

    local rowsW  = SLOT_COUNT * size + (SLOT_COUNT - 1) * gap
    local rowsH  = size * 2 + gap
    local rowsX  = ringSize + side + arrowW + gap
    local miniSize = zo_floor(ringSize * 0.5)
    local miniPad  = zo_floor(ringSize * 0.14)
    local width  = rowsX + rowsW + side + ringSize + miniPad
    local height = rowsH + (showKeys and keyH or 0)

    panel:SetDimensions(width, height)
    self.panelHeight = height

    local frontY = 0
    local backY  = size + gap
    for i = 1, SLOT_COUNT do
        local x = rowsX + (i - 1) * (size + gap)
        LayoutSlot(back[i], panel, x, backY, size, border, edge)
        LayoutSlot(front[i], panel, x, frontY, size, border, edge)

        local key = front[i].key
        key:ClearAnchors()
        key:SetAnchor(TOP, back[i], BOTTOM, 0, 0)
        key:SetDimensions(size, keyH)
        key:SetFont(Font(zo_floor(keyH * 0.8), "soft-shadow-thick"))
        key:SetHidden(not showKeys)
    end

    local arrowX    = ringSize + side + zo_floor(arrowW / 2)
    local arrowY    = frontY + zo_floor(size / 2)
    local arrowSize = zo_floor(size * 0.53)
    self.arrow:ClearAnchors()
    self.arrow:SetAnchor(CENTER, panel, TOPLEFT, arrowX, arrowY)
    self.arrow:SetDimensions(arrowSize, arrowSize)
    self.arrowEdge:ClearAnchors()
    self.arrowEdge:SetAnchor(CENTER, panel, TOPLEFT, arrowX, arrowY)
    self.arrowEdge:SetDimensions(arrowSize, arrowSize)

    local centerY = zo_floor(rowsH / 2)
    LayoutRing(self.potion, panel, zo_floor(ringSize / 2), centerY, ringSize, 0.4, 0, rowsH, keyH, showKeys)
    LayoutRing(self.ultimate, panel, width - miniPad - zo_floor(ringSize / 2), centerY, ringSize, 0.3, NUMBER_DROP,
        rowsH, keyH, showKeys)

    local mini = self.ultimate.mini
    mini:ClearAnchors()
    mini:SetAnchor(CENTER, self.ultimate, BOTTOMRIGHT, -zo_floor(ringSize * 0.12), -zo_floor(ringSize * 0.1))
    LayoutRound(mini, miniSize)
    self:ApplyStack()
    self:ApplyResourceLayout(GetControl("ZO_PlayerAttribute"))
end

function AB:ApplyPosition()
    if not self.panel then return end
    local sv = SV()
    self.panel:ClearAnchors()
    self.panel:SetAnchor(BOTTOM, GuiRoot, TOPLEFT, sv.actionBarPosX, sv.actionBarPosY)
    self:ApplyStack()
end

--------------------------------------------------
-- Icons
--------------------------------------------------
local function SetSlotIcon(slot, hotbar)
    slot.hotbar = hotbar
    local icon = SlotIcon(slot.slotIndex, hotbar)
    slot.used = icon ~= nil
    if icon then
        slot.icon:SetTexture(icon)
        slot.icon:SetHidden(false)
    else
        slot.icon:SetHidden(true)
        slot.timer:SetHidden(true)
        slot.stacks:SetHidden(true)
        slot.cd:SetHidden(true)
        slot.cdExpire = nil
        slot.glow = nil
    end
    ApplyEdge(slot)
end

function AB:RefreshIcons()
    if not self.panel or not IsEnabled() then return end
    ResolveBars()

    local hasBack = backBar ~= nil
    for i = 1, SLOT_COUNT do
        SetSlotIcon(front[i], activeBar)
        if hasBack then SetSlotIcon(back[i], backBar) end
        back[i]:SetHidden(not hasBack)
    end

    local ult = self.ultimate
    local ultIcon = SlotIcon(ULT_SLOT, activeBar)
    ult.used = ultIcon ~= nil
    if ultIcon then ult.icon:SetTexture(ultIcon) end
    ult.icon:SetHidden(not ultIcon)

    local mini = ult.mini
    local backUlt = SlotIcon(ULT_SLOT, backBar)
    mini.used = backUlt ~= nil
    if backUlt then mini.icon:SetTexture(backUlt) end
    mini:SetHidden(not backUlt)
    mini.pct = nil

    local potion = self.potion
    local quickslot = GetCurrentQuickslot()
    local potionIcon = quickslot and SlotIcon(quickslot, QUICKSLOT_BAR) or nil
    potion.slotIndex = quickslot
    potion.used = potionIcon ~= nil
    if potionIcon then potion.icon:SetTexture(potionIcon) end
    potion.icon:SetHidden(not potionIcon)

    self.potion.pct = nil
    self.ultimate.pct = nil
end

--------------------------------------------------
-- Updates
--------------------------------------------------
local function PreviewRemaining(duration, offset, now)
    if duration <= 0 then return 0 end
    local cycle = duration * 1000
    return cycle - ((now - previewStart + offset) % cycle)
end

local function UpdateCooldown(slot, nowMs)
    local remain, duration = GetSlotCooldownInfo(slot.slotIndex, slot.hotbar)
    if duration > GLOBAL_CD_MS and remain > 0 then
        local expire = nowMs + remain
        if not slot.cdExpire or math.abs(expire - slot.cdExpire) > 200 then
            slot.cdExpire = expire
            slot.cd:StartCooldown(remain, duration, CD_TYPE_RADIAL, CD_TIME_TYPE_TIME_UNTIL, false)
            slot.cd:SetHidden(false)
        end
    elseif slot.cdExpire then
        slot.cdExpire = nil
        slot.cd:ResetCooldown()
        slot.cd:SetHidden(true)
    end
end

local function UpdateSlot(slot, isFront, index, nowMs)
    if not slot.used then return end

    local slotIndex, hotbar = slot.slotIndex, slot.hotbar
    local remain, stacks
    if AB.preview then
        local durations = isFront and PREVIEW_FRONT or PREVIEW_BACK
        remain = PreviewRemaining(durations[index], index * 700, nowMs)
        stacks = isFront and PREVIEW_STACKS[index] or 0
    else
        remain = GetActionSlotEffectTimeRemaining(slotIndex, hotbar)
        stacks = GetActionSlotEffectStackCount(slotIndex, hotbar)
    end

    if remain > 0 then
        SetLabel(slot.timer, TimerText(remain))
        SetLabelColor(slot.timer, TimerColor(remain))
        slot.timer:SetHidden(false)
    else
        slot.timer:SetHidden(true)
    end

    if stacks and stacks > 0 then
        SetLabel(slot.stacks, NumberText(stacks))
        slot.stacks:SetHidden(false)
    else
        slot.stacks:SetHidden(true)
    end

    local glow = ActionSlotHasActivationHighlight(slotIndex, hotbar)
    if glow ~= slot.glow then
        slot.glow = glow
        ApplyEdge(slot)
    end

    if isFront then
        local unusable = ActionSlotHasCostFailure(slotIndex, hotbar) or ActionSlotHasNonCostStateFailure(slotIndex, hotbar)
        if unusable ~= slot.unusable then
            slot.unusable = unusable
            if unusable then
                slot.icon:SetColor(0.45, 0.45, 0.45, 1)
            else
                slot.icon:SetColor(1, 1, 1, 1)
            end
        end
        UpdateCooldown(slot, nowMs)
    end
end

local function PulseEase(progress)
    return math.sin(progress * math.pi / 2)
end

local function PulseDuration()
    local speed = SV().actionBarPulseSpeed or 3
    return zo_floor(1000 / (speed * 2))
end

local function SetPulse(round, on)
    on = on == true
    local state = pulses[round]
    if not state then
        state = { on = false }
        pulses[round] = state
    end
    if state.on == on then return end
    state.on = on
    if on then
        if not state.timeline then
            state.timeline = ANIMATION_MANAGER:CreateTimeline()
            state.fade = state.timeline:InsertAnimation(ANIMATION_ALPHA, round.fill, 0)
            state.fade:SetAlphaValues(PULSE_LOW, 1)
            state.fade:SetEasingFunction(PulseEase)
            state.timeline:SetPlaybackType(ANIMATION_PLAYBACK_PING_PONG, LOOP_INDEFINITELY)
        end
        state.fade:SetDuration(PulseDuration())
        state.timeline:PlayFromStart()
    else
        if state.timeline then state.timeline:Stop() end
        round.fill:SetAlpha(1)
    end
end

local function IsPulsing(round)
    local state = pulses[round]
    return state ~= nil and state.on
end

local function CanPulse()
    if not SV().actionBarPulse then return false end
    return inCombat or AB.preview
end

local function SetRingFill(ring, pct, r, g, b)
    pct = zo_floor(pct * 200 + 0.5) / 200
    if ring.pct ~= pct then
        ring.pct = pct
        ring.fill:StartFixedCooldown(pct, CD_TYPE_RADIAL, CD_TIME_TYPE_TIME_REMAINING, false)
    end
    ring.fill:SetFillColor(r, g, b, 1)
end

function AB:UpdatePotion(nowMs)
    local ring = self.potion
    if not ring.used then
        SetRingFill(ring, 0, ringR, ringG, ringB)
        SetPulse(ring, false)
        ring.value:SetHidden(true)
        ring.sub:SetHidden(true)
        return
    end

    local remain, duration
    if self.preview then
        local cycle = (nowMs - previewStart) % 45000
        duration = 30000
        remain = cycle < duration and (duration - cycle) or 0
    else
        remain, duration = GetSlotCooldownInfo(ring.slotIndex, QUICKSLOT_BAR)
    end

    local count = GetSlotItemCount(ring.slotIndex, QUICKSLOT_BAR)
    if count then
        SetLabel(ring.sub, NumberText(count))
        ring.sub:SetHidden(false)
    else
        ring.sub:SetHidden(true)
    end

    local onCooldown = duration > POTION_CD_MS and remain > 0
    SetPulse(ring, not onCooldown and count ~= nil and count > 0 and CanPulse())

    if onCooldown then
        SetRingFill(ring, 1 - remain / duration, ringR, ringG, ringB)
        if remain >= 60000 then
            SetLabel(ring.value, TimerText(remain))
        else
            SetLabel(ring.value, NumberText(zo_ceil(remain / 1000)))
        end
        ring.value:SetHidden(false)
        ring.icon:SetDesaturation(1)
        ring.icon:SetColor(0.35, 0.35, 0.35, 1)
    else
        SetRingFill(ring, 1, ringR, ringG, ringB)
        ring.value:SetHidden(true)
        ring.icon:SetDesaturation(0)
        if count and count <= 0 then
            ring.icon:SetColor(0.45, 0.45, 0.45, 1)
        else
            ring.icon:SetColor(1, 1, 1, 1)
        end
    end
end

local function UltimatePercent(current, cost)
    if cost and cost > 0 then return math.min(current / cost, 1) end
    return 1
end

local function SetUltimateFill(round, pct, isBack)
    local shade
    if pct >= 1 then
        SetRingFill(round, 1, ringR, ringG, ringB)
        shade = isBack and 0.7 or 0.55
    else
        SetRingFill(round, pct, ringR, ringG, ringB)
        shade = isBack and 0.45 or 0.3
    end
    round.icon:SetColor(shade, shade, shade, 1)
    SetPulse(round, pct >= 1 and CanPulse())
end

function AB:UpdateUltimate(nowMs)
    local ring = self.ultimate
    ring.sub:SetHidden(true)

    local current, cost, backCost
    if self.preview then
        cost, backCost = 150, 100
        local cycle = (nowMs - previewStart) % 12000
        current = zo_floor(math.min(cycle / 9000, 1) * cost)
    else
        current = GetUnitPower("player", COMBAT_MECHANIC_FLAGS_ULTIMATE) or 0
        cost = GetSlotAbilityCost(ULT_SLOT, COMBAT_MECHANIC_FLAGS_ULTIMATE, activeBar) or 0
        if ring.mini.used then
            backCost = GetSlotAbilityCost(ULT_SLOT, COMBAT_MECHANIC_FLAGS_ULTIMATE, backBar) or 0
        end
    end

    if ring.mini.used then
        SetUltimateFill(ring.mini, UltimatePercent(current, backCost), true)
    else
        SetPulse(ring.mini, false)
    end

    if not ring.used then
        SetRingFill(ring, 0, ringR, ringG, ringB)
        SetPulse(ring, false)
        ring.value:SetHidden(true)
        return
    end

    local pct = UltimatePercent(current, cost)
    SetUltimateFill(ring, pct)

    if SV().actionBarUltNumber == "Percent" then
        SetLabel(ring.value, PercentText(zo_floor(pct * 100)))
    else
        SetLabel(ring.value, NumberText(current))
    end
    ring.value:SetHidden(false)
end

function AB:Update()
    local nowMs = GetFrameTimeMilliseconds()
    for i = 1, SLOT_COUNT do
        UpdateSlot(front[i], true, i, nowMs)
        if backBar then UpdateSlot(back[i], false, i, nowMs) end
    end
    self:UpdatePotion(nowMs)
    self:UpdateUltimate(nowMs)
end

--------------------------------------------------
-- Visibility
--------------------------------------------------
function AB:ShouldShow()
    if not IsEnabled() then return false end
    if self.preview or self.moving or ME.placing then return true end
    if not (hudShowing.hud or hudShowing.hudui) then return false end
    if isDead then return false end
    if SV().actionBarShow == "Combat" and not inCombat then return false end
    return true
end

function AB:UpdateVisibility()
    if not self.panel then return end
    local show = self:ShouldShow()
    self.panel:SetHidden(not show)
    self.miniPanel:SetHidden(not show)

    if show and not ticking then
        ticking = true
        EVENT_MANAGER:RegisterForUpdate(ME.name .. "_ActionBar", UPDATE_MS, function() AB:Update() end)
        self:Update()
    elseif not show and ticking then
        ticking = false
        EVENT_MANAGER:UnregisterForUpdate(ME.name .. "_ActionBar")
        SetPulse(self.potion, false)
        SetPulse(self.ultimate, false)
        SetPulse(self.ultimate.mini, false)
    end
end

function AB:RestartPulses()
    local rounds = { self.potion, self.ultimate, self.ultimate.mini }
    for i = 1, #rounds do
        if IsPulsing(rounds[i]) then
            SetPulse(rounds[i], false)
            SetPulse(rounds[i], true)
        end
    end
end

function AB:OnPlacing()
    self:UpdateVisibility()
end

function AB:ApplyDefaultBar()
    if ACTION_BAR_FRAGMENT and ACTION_BAR_FRAGMENT.SetHiddenForReason then
        ACTION_BAR_FRAGMENT:SetHiddenForReason(HIDE_REASON, IsEnabled())
    end
end

local function SetBarAnchor(name, point, target, targetPoint, x, y)
    local control = GetControl(name)
    if not (control and target) then return end
    control:ClearAnchors()
    control:SetAnchor(point, target, targetPoint, x, y)
end

function AB:ApplyResourceLayout(bars)
    local split = IsEnabled() and SV().actionBarResources == "Split"
    if split then
        local size = SV().actionBarSize
        local gap = zo_floor(size * 0.25)
        local miniPad = zo_floor(zo_floor(size * 1.7) * 0.14)
        SetBarAnchor("ZO_PlayerAttributeMagicka", RIGHT, self.potion, LEFT, -gap, 0)
        SetBarAnchor("ZO_PlayerAttributeStamina", LEFT, self.ultimate, RIGHT, miniPad + gap, 0)
        self.resourceSplit = true
    elseif self.resourceSplit then
        SetBarAnchor("ZO_PlayerAttributeMagicka", RIGHT, bars, LEFT, RESOURCE_SIDE_OFFSET, 0)
        SetBarAnchor("ZO_PlayerAttributeStamina", LEFT, bars, RIGHT, -RESOURCE_SIDE_OFFSET, 0)
        self.resourceSplit = false
    end
end

function AB:ApplyResourceBars()
    local bars = GetControl("ZO_PlayerAttribute")
    if not (bars and self.panel) then return end
    if IsEnabled() then
        bars:ClearAnchors()
        bars:SetAnchor(BOTTOM, self.panel, TOP, 0, 0)
        self.resourcePinned = true
    elseif self.resourcePinned then
        local offsetY = IsInGamepadPreferredMode() and RESOURCE_OFFSET_GAMEPAD or RESOURCE_OFFSET_KEYBOARD
        bars:ClearAnchors()
        bars:SetAnchor(BOTTOM, GuiRoot, BOTTOM, 0, offsetY)
        self.resourcePinned = false
    end
    self:ApplyResourceLayout(bars)
end

function AB:ApplyStack()
    if not self.panelHeight then return end
    local shift = 0
    local active = IsEnabled()
    if active then
        local _, screenH = GuiRoot:GetDimensions()
        local defaultOffset = IsInGamepadPreferredMode() and RESOURCE_OFFSET_GAMEPAD or RESOURCE_OFFSET_KEYBOARD
        local barsBottom = SV().actionBarPosY - self.panelHeight
        shift = zo_floor(barsBottom - (screenH + defaultOffset))
    elseif not self.stackShifted then
        return
    end
    for i = 1, #STACK_WINDOWS do
        local entry = STACK_WINDOWS[i]
        local window = GetControl(entry.name)
        if window then
            local offsetY = active and (shift + (entry.lift or 0)) or 0
            window:ClearAnchors()
            window:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, 0, offsetY)
            window:SetAnchor(BOTTOMRIGHT, GuiRoot, BOTTOMRIGHT, 0, offsetY)
        end
    end
    for i = 1, #STACK_PINNED do
        local entry = STACK_PINNED[i]
        local window = GetControl(entry.name)
        if window then
            window:ClearAnchors()
            window:SetAnchor(BOTTOM, GuiRoot, BOTTOM, 0, entry.offsetY + shift)
        end
    end
    self.stackShifted = active
end

function AB:HookResourceBars()
    if self.resourceHooked or not PLAYER_ATTRIBUTE_BARS then return end
    self.resourceHooked = true
    ZO_PostHook(PLAYER_ATTRIBUTE_BARS, "ApplyStyle", function()
        if AB.resourcePinned then
            AB.resourcePinned = false
            AB:ApplyResourceBars()
        end
    end)
end

function AB:ApplyColors()
    ResolveColors()
    self.arrow:SetColor(ringR, ringG, ringB, 1)
    self:RefreshIcons()
    if ticking then self:Update() end
end

function AB:Refresh()
    ResolveColors()
    self.arrow:SetColor(ringR, ringG, ringB, 1)
    self:Layout()
    self:ApplyPosition()
    self:ApplyDefaultBar()
    self:ApplyResourceBars()
    self:ApplyStack()
    self:RefreshIcons()
    self:UpdateVisibility()
    if ticking then self:Update() end
end

function AB:SetEnabled(value)
    SV().actionBarEnabled = value == true
    if not value then self.preview = false end
    self:Refresh()
    local panel = ME.settingsPanel
    if panel and panel.Refresh then panel:Refresh() end
end

function AB:SetPreview(value)
    self.preview = value == true
    if self.preview then previewStart = GetFrameTimeMilliseconds() end
    self.potion.pct = nil
    self.ultimate.pct = nil
    self:RefreshIcons()
    self:UpdateVisibility()
    if ticking then self:Update() end
end

--------------------------------------------------
-- Move
--------------------------------------------------
AB.mover = {}

function AB.mover:UpdateDirectionalInput(deltaS)
    local x, y = DIRECTIONAL_INPUT:GetXY(ZO_DI_LEFT_STICK)
    if x ~= 0 or y ~= 0 then
        AB:Nudge(x * MOVE_SPEED * deltaS, -y * MOVE_SPEED * deltaS)
    end
    local _, scaleY = DIRECTIONAL_INPUT:GetXY(ZO_DI_RIGHT_STICK)
    if scaleY ~= 0 then
        AB:SetScale(AB.moveSize + scaleY * SCALE_SPEED * deltaS)
    end
end

AB.moveKeybinds = {
    alignment = KEYBIND_STRIP_ALIGN_CENTER,
    {
        name     = "Save",
        keybind  = "UI_SHORTCUT_PRIMARY",
        callback = function() AB:EndMove(true) end,
    },
    {
        name     = "Default",
        keybind  = "UI_SHORTCUT_TERTIARY",
        callback = function() AB:MoveToDefault() end,
    },
    {
        name     = "Cancel",
        keybind  = "UI_SHORTCUT_NEGATIVE",
        callback = function() AB:EndMove(false) end,
    },
}

function AB:SetPosition(x, y)
    local screenW, screenH = GuiRoot:GetDimensions()
    self.moveX = zo_clamp(x, 0, screenW)
    self.moveY = zo_clamp(y, 0, screenH)
    local sv = SV()
    sv.actionBarPosX = zo_floor(self.moveX + 0.5)
    sv.actionBarPosY = zo_floor(self.moveY + 0.5)
    self:ApplyPosition()
end

function AB:Nudge(dx, dy)
    self:SetPosition(self.moveX + dx, self.moveY + dy)
end

function AB:SetScale(size)
    self.moveSize = zo_clamp(size, SIZE_MIN, SIZE_MAX)
    local rounded = zo_floor(self.moveSize + 0.5)
    local sv = SV()
    if sv.actionBarSize ~= rounded then
        sv.actionBarSize = rounded
        self:Layout()
    end
end

function AB:MoveToDefault()
    self:SetScale(self.defaults.actionBarSize)
    self:SetPosition(self.defaults.actionBarPosX, self.defaults.actionBarPosY)
end

function AB:GetMoveScene()
    if self.moveScene then return self.moveScene end
    local scene = ZO_Scene:New(MOVE_SCENE, SCENE_MANAGER)
    scene:AddFragmentGroup(FRAGMENT_GROUP.GAMEPAD_DRIVEN_UI_NO_KEYBIND_BACKGROUND_WINDOW)
    ME:AddPlacementFragments(scene)
    scene:RegisterCallback("StateChange", function(oldState, newState)
        if newState == SCENE_SHOWING then
            AB:OnMoveShowing()
        elseif newState == SCENE_HIDDEN then
            AB:OnMoveHidden()
        end
    end)
    self.moveScene = scene
    return scene
end

function AB:StartMove()
    if not IsEnabled() or self.moving then return end
    self.movePreview = self.preview
    self.moveSaved = false
    self.moving = true
    self:GetMoveScene()
    SCENE_MANAGER:Push(MOVE_SCENE)
end

function AB:OnMoveShowing()
    local sv = SV()
    self.moving = true
    ME:RaiseWhilePlacing({ self.panel, self.miniPanel }, true)
    self.moveStartX = sv.actionBarPosX
    self.moveStartY = sv.actionBarPosY
    self.moveX = sv.actionBarPosX
    self.moveY = sv.actionBarPosY
    self.moveStartSize = sv.actionBarSize
    self.moveSize = sv.actionBarSize
    KEYBIND_STRIP:AddKeybindButtonGroup(self.moveKeybinds)
    DIRECTIONAL_INPUT:Activate(self.mover, self.panel)
    self:RefreshIcons()
    ME:SetPlacing(true)
end

function AB:OnMoveHidden()
    DIRECTIONAL_INPUT:Deactivate(self.mover)
    KEYBIND_STRIP:RemoveKeybindButtonGroup(self.moveKeybinds)
    if not self.moveSaved then
        self:SetScale(self.moveStartSize)
        self:SetPosition(self.moveStartX, self.moveStartY)
    end
    self.moving = false
    ME:RaiseWhilePlacing({ self.panel, self.miniPanel }, false)
    ME:SetPlacing(false)
    if self.movePreview then
        self.movePreview = false
        self:SetPreview(true)
    else
        self:UpdateVisibility()
    end
end

function AB:EndMove(save)
    if not self.moving then return end
    self.moveSaved = save == true
    if save then
        PlaySound(SOUNDS.GAMEPAD_MENU_FORWARD)
    else
        PlaySound(SOUNDS.GAMEPAD_MENU_BACK)
    end
    SCENE_MANAGER:HideCurrentScene()
end

--------------------------------------------------
-- Events
--------------------------------------------------
function AB:RegisterEvents()
    local name = ME.name .. "_ActionBar"
    local function OnSlotsChanged() AB:RefreshIcons() end

    EVENT_MANAGER:RegisterForEvent(name, EVENT_ACTION_SLOTS_ACTIVE_HOTBAR_UPDATED, OnSlotsChanged)
    EVENT_MANAGER:RegisterForEvent(name, EVENT_ACTION_SLOTS_ALL_HOTBARS_UPDATED, OnSlotsChanged)
    EVENT_MANAGER:RegisterForEvent(name, EVENT_HOTBAR_SLOT_UPDATED, OnSlotsChanged)
    EVENT_MANAGER:RegisterForEvent(name, EVENT_ACTION_SLOT_UPDATED, OnSlotsChanged)
    EVENT_MANAGER:RegisterForEvent(name, EVENT_ACTIVE_QUICKSLOT_CHANGED, OnSlotsChanged)
    EVENT_MANAGER:RegisterForEvent(name, EVENT_ACTIVE_WEAPON_PAIR_CHANGED, OnSlotsChanged)
    EVENT_MANAGER:RegisterForEvent(name, EVENT_COLLECTIBLE_UPDATED, OnSlotsChanged)

    EVENT_MANAGER:RegisterForEvent(name, EVENT_PLAYER_COMBAT_STATE, function(_, combat)
        inCombat = combat == true
        AB:UpdateVisibility()
    end)
    EVENT_MANAGER:RegisterForEvent(name, EVENT_PLAYER_DEAD, function()
        isDead = true
        AB:UpdateVisibility()
    end)
    EVENT_MANAGER:RegisterForEvent(name, EVENT_PLAYER_ALIVE, function()
        isDead = false
        AB:UpdateVisibility()
    end)
end

function AB:RegisterScenes()
    local names = { "hud", "hudui" }
    for i = 1, #names do
        local sceneName = names[i]
        local scene = SCENE_MANAGER:GetScene(sceneName)
        if scene then
            hudShowing[sceneName] = scene:IsShowing()
            scene:RegisterCallback("StateChange", function(oldState, newState)
                hudShowing[sceneName] = newState == SCENE_SHOWING or newState == SCENE_SHOWN
                AB:UpdateVisibility()
            end)
        end
    end
end

--------------------------------------------------
-- Settings
--------------------------------------------------
function AB:GetPreviewControls()
    if self.panel then return { self.panel, self.miniPanel } end
    return {}
end

function AB:GetOptions()
    local defaults = self.defaults

    local function IsOff() return not IsEnabled() end

    return {
        {
            type    = "submenu",
            name    = "Action Bar",
            icon    = SUBMENU_ICON,
            tooltip = "Turn off any other action bar add-on while this is enabled.\n\n" .. ME.SAVED_ACCOUNT_TIP,
            options = {
                {
                    type    = "toggle",
                    name    = "Enabled",
                    preset  = "YES_NO",
                    default = defaults.actionBarEnabled,
                    tooltip = "Replaces the game's action bar with both of your bars at once.",
                    getFunc = function() return SV().actionBarEnabled end,
                    setFunc = function(val) AB:SetEnabled(val) end,
                },
                {
                    type     = "toggle",
                    name     = "Preview",
                    tooltip  = "Shows the action bar here so you can see your changes. "
                            .. "Stays on until you turn it off or leave the settings.",
                    disabled = IsOff,
                    getFunc  = function() return AB.preview end,
                    setFunc  = function(val) AB:SetPreview(val) end,
                },
                {
                    type       = "button",
                    name       = "Move / Scale",
                    buttonText = "Move / Scale",
                    tooltip    = "Move it with the left stick and scale it with the right stick.",
                    disabled   = IsOff,
                    func       = function() AB:StartMove() end,
                },
                {
                    type     = "dropdown",
                    name     = "Show",
                    choices  = AB.showChoices,
                    default  = defaults.actionBarShow,
                    details  = function()
                        if SV().actionBarShow == "Combat" then
                            return "Only shows the action bar while you're in combat."
                        end
                        return "Always shows the action bar."
                    end,
                    disabled = IsOff,
                    getFunc  = function() return SV().actionBarShow end,
                    setFunc  = function(val)
                        SV().actionBarShow = val
                        AB:UpdateVisibility()
                    end,
                },
                {
                    type     = "dropdown",
                    name     = "Resource Bars",
                    choices  = AB.resourceChoices,
                    default  = defaults.actionBarResources,
                    disabled = IsOff,
                    details  = function()
                        if SV().actionBarResources == "Split" then
                            return "Health sits above the action bar, with magicka and stamina on each side."
                        end
                        return "Health, magicka and stamina sit in a row above the action bar."
                    end,
                    getFunc  = function() return SV().actionBarResources end,
                    setFunc  = function(val)
                        SV().actionBarResources = val
                        AB:ApplyResourceBars()
                    end,
                },
                {
                    type         = "stylecolor",
                    name         = ME.RainbowText("Ring / Arrow Color"),
                    choices      = { "Alliance", "Custom" },
                    customValue  = "Custom",
                    default      = defaults.actionBarRingStyle,
                    colorDefault = { r = 1, g = 1, b = 1 },
                    disabled     = IsOff,
                    details      = function()
                        if SV().actionBarRingStyle == "Custom" then
                            return "Rings, the arrow and proc borders use your color."
                        end
                        return "Rings, the arrow and proc borders use your alliance color."
                    end,
                    getFunc  = function() return SV().actionBarRingStyle end,
                    setFunc  = function(val)
                        SV().actionBarRingStyle = val
                        AB:ApplyColors()
                    end,
                    getColor = function()
                        local c = SV().actionBarRingColor
                        if type(c) == "table" then return c.r or 1, c.g or 1, c.b or 1 end
                        return 1, 1, 1
                    end,
                    setColor = function(r, g, b)
                        SV().actionBarRingColor = { r = r, g = g, b = b, a = 1 }
                        AB:ApplyColors()
                    end,
                },
                {
                    type         = "stylecolor",
                    name         = ME.RainbowText("Skill Number Color"),
                    choices      = { "Alliance", "Custom" },
                    customValue  = "Custom",
                    default      = defaults.actionBarNumStyle,
                    colorDefault = { r = 1, g = 1, b = 1 },
                    disabled     = IsOff,
                    details      = function()
                        if SV().actionBarNumStyle == "Custom" then
                            return "Skill timers use your color, then turn orange and red as they run out."
                        end
                        return "Skill timers use your alliance color, then turn orange and red as they run out."
                    end,
                    getFunc  = function() return SV().actionBarNumStyle end,
                    setFunc  = function(val)
                        SV().actionBarNumStyle = val
                        AB:ApplyColors()
                    end,
                    getColor = function()
                        local c = SV().actionBarNumColor
                        if type(c) == "table" then return c.r or 1, c.g or 1, c.b or 1 end
                        return 1, 1, 1
                    end,
                    setColor = function(r, g, b)
                        SV().actionBarNumColor = { r = r, g = g, b = b, a = 1 }
                        AB:ApplyColors()
                    end,
                },
                {
                    type     = "toggle",
                    name     = "Show Buttons",
                    preset   = "YES_NO",
                    default  = defaults.actionBarButtons,
                    tooltip  = "Shows the button for each skill, your potion and your ultimate.",
                    disabled = IsOff,
                    getFunc  = function() return SV().actionBarButtons end,
                    setFunc  = function(val)
                        SV().actionBarButtons = val
                        AB:Layout()
                    end,
                },
                {
                    type     = "dropdown",
                    name     = "Ultimate Number",
                    choices  = AB.ultChoices,
                    default  = defaults.actionBarUltNumber,
                    details  = function()
                        if SV().actionBarUltNumber == "Percent" then
                            return "Shows your ultimate as a percentage."
                        end
                        return "Shows your ultimate points."
                    end,
                    disabled = IsOff,
                    getFunc  = function() return SV().actionBarUltNumber end,
                    setFunc  = function(val)
                        SV().actionBarUltNumber = val
                        if ticking then AB:Update() end
                    end,
                },
                {
                    type     = "toggle",
                    name     = "Pulsate When Ready",
                    preset   = "YES_NO",
                    default  = defaults.actionBarPulse,
                    tooltip  = "In combat, your potion and ultimate rings pulsate when they're ready to use.",
                    disabled = IsOff,
                    getFunc  = function() return SV().actionBarPulse end,
                    setFunc  = function(val)
                        SV().actionBarPulse = val
                        if ticking then AB:Update() end
                    end,
                },
                {
                    type     = "slider",
                    name     = "Pulse Speed",
                    min      = 1, max = 10, step = 1,
                    default  = defaults.actionBarPulseSpeed,
                    tooltip  = "How fast the rings pulse. 1 is the slowest, 10 is the fastest. Default is "
                            .. defaults.actionBarPulseSpeed .. ".",
                    disabled = function() return IsOff() or not SV().actionBarPulse end,
                    getFunc  = function() return SV().actionBarPulseSpeed end,
                    setFunc  = function(val)
                        SV().actionBarPulseSpeed = val
                        AB:RestartPulses()
                    end,
                },
            },
        },
    }
end

function AB:OnSettingsState(newState)
    if newState == SCENE_HIDDEN and self.preview then
        self:SetPreview(false)
    end
end

--------------------------------------------------
-- Lifecycle
--------------------------------------------------
function AB:Init()
    self:CreatePanel()
    self:HookResourceBars()
    self:RegisterEvents()
    self:RegisterScenes()
    ResolveColors()
    inCombat = IsUnitInCombat("player") == true
    isDead = IsUnitDead("player") == true
    self:Refresh()
end

function AB:OnPlayerActivated()
    ResolveColors()
    inCombat = IsUnitInCombat("player") == true
    isDead = IsUnitDead("player") == true
    self:Refresh()
end

function AB:OnReset()
    self.preview = false
    self:Refresh()
end

ME:RegisterFeature(AB)
