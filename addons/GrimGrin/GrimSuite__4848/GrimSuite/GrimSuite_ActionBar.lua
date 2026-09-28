local GS = GrimSuite
GS.ActionBar = GS.ActionBar or {}
local ActionBar = GS.ActionBar

---------------------------------------------------------------------
-- GrimSuite Action Bar v1.3.0
--
-- Static two-row action bar:
--   * FRONT BAR is always the top row.
--   * BACK BAR is always the bottom row.
--   * Both rows are GrimSuite-owned visual displays.
--   * ESO's native action buttons remain present for actual input,
--     but their visual icon presentation is hidden to prevent ghosts.
--   * Weapon swapping changes the contents of the rows, never their
--     physical positions.
--   * Hotkeys and custom cooldown text are intentionally omitted.
---------------------------------------------------------------------

local WM = WINDOW_MANAGER
local EM = EVENT_MANAGER

local MIN_SLOT = 3
local MAX_SLOT = 7
local ULT_SLOT = 8
local SLOT_COUNT = 5
local HOTBAR_CATEGORIES = { HOTBAR_CATEGORY_PRIMARY, HOTBAR_CATEGORY_BACKUP }
local SLOT_SIZE = 65
local POTION_SIZE_DEFAULT = 70
local SLOT_GAP = 3
local ROW_GAP = 3
local ULT_GAP = 10
local UTILITY_ACTIONBAR_TIGHTEN = 32

local FRAME_EDGE = { 0.62, 0.62, 0.62, 0.88 }
local FRAME_EDGE_ACTIVE = { 0.62, 0.62, 0.62, 0.88 }
local FRAME_BG = { 0.008, 0.008, 0.008, 0.34 }
local FRAME_BG_ACTIVE = { 0.035, 0.035, 0.035, 0.50 }
local FRAME_EDGE_WIDTH = 2
local FRAME_EDGE_WIDTH_ACTIVE = 2
local INACTIVE_ALPHA = 0.72
local ACTIVE_ICON_ALPHA = 1.0
local UNUSABLE_ICON_ALPHA = 0.42
local UNUSABLE_DESATURATION = 0.65
local TIMER_FONT = "Univers 67|45|thick-outline"
local STACK_FONT = "Univers 67|45|thick-outline"
local POTION_COUNT_FONT = "Univers 67|28|thick-outline"
local TIMER_COLOR = { 1, 1, 1, 1 }
local STACK_COLOR = { 1, 1, 1, 1 }
local ULT_FONT = "Univers 67|35|thick-outline"
local ULT_COLOR = { 1, 1, 1, 1 }
local GLOW_COLOR = { 1.0, 0.78, 0.16, 0.92 }
local GLOW_EDGE_WIDTH = 8
local GLOW_OUTER_WIDTH = 12

local ROW_WIDTH = (SLOT_COUNT * SLOT_SIZE) + ((SLOT_COUNT - 1) * SLOT_GAP)
local TOTAL_WIDTH = ROW_WIDTH + ULT_GAP + SLOT_SIZE

ActionBar.enabled = true
ActionBar.staticBars = true
ActionBar.frontBarTop = true
ActionBar.settingsPreviewVisible = false
ActionBar.showFrames = true
ActionBar.showCooldownText = true
ActionBar.showStackCount = true
-- GAB visual customization. Defaults intentionally match the current
-- GrimSuite look so existing users keep the same appearance.
ActionBar.iconSize = 65
ActionBar.slotGap = 3
ActionBar.rowGap = 3
ActionBar.backbarOpacity = 0.72
ActionBar.backbarDesaturation = 0.65
ActionBar.showUltimate = true
ActionBar.showQuickslot = true
ActionBar.showWeaponSwap = true
ActionBar.timerSize = 45
ActionBar.stackSize = 45
ActionBar.timerFont = "Univers 67"
ActionBar.stackFont = "Univers 67"
ActionBar.timerOutline = "outline"
ActionBar.stackOutline = "outline"
ActionBar.timerOffsetX = 0
ActionBar.timerOffsetY = 0
ActionBar.stackOffsetX = 0
ActionBar.stackOffsetY = 0
ActionBar.effectStacks = {}
ActionBar.bannerActive = false
ActionBar.initialized = false
ActionBar.frontRoot = nil
ActionBar.backbarRoot = nil
ActionBar.frontControls = {}
ActionBar.backbarControls = {}
ActionBar.frontBarIndicator = nil
ActionBar.backBarIndicator = nil

-- GrimSuite-owned utility controls.
-- The native ESO controls remain alive for their actual input handling, but
-- their visuals are hidden. These controls are the only visible potion and
-- weapon-swap presentation.
ActionBar.utilityRoot = nil
ActionBar.utilityPotion = nil
ActionBar.utilityWeaponSwap = nil

local nativeUtilityHooks = { weaponSwap = false, potion = false }

local UTILITY_GAP = 1
local UTILITY_DOWN_OFFSET = 6.5
local UTILITY_WEAPON_TEXTURE_FALLBACK = "EsoUI/Art/ActionBar/weaponSwap.dds"
local UTILITY_BAR_INDICATOR_ACTIVE = { 1.0, 0.78, 0.16, 1.0 }
local UTILITY_BAR_INDICATOR_INACTIVE = { 0.62, 0.62, 0.62, 0.38 }
local UTILITY_BAR_INDICATOR_GAP = 5
local UTILITY_BAR_INDICATOR_WIDTH = 16
local UTILITY_BAR_INDICATOR_HEIGHT = 16
local UTILITY_BAR_INDICATOR_TEXTURE = "GrimSuite/Textures/bar_indicator_triangle.dds"

-- Optional standalone stack tracker. The tracker shows one entry per supported
-- stack type, but only when a qualifying skill is slotted on either weapon bar.
-- The same stack type is never duplicated just because the skill appears on
-- both bars; this also keeps subclassing combinations predictable.
ActionBar.showStackTracker = true
ActionBar.stackTrackerUnlocked = false
ActionBar.stackTrackerHUDVisible = true
ActionBar.stackTrackerRoot = nil
ActionBar.stackTrackerEntries = {}

-- LibAddonMenu configuration + saved layout position.
-- LibAddonMenu is a required dependency for GrimSuite's settings UI.
local POSITION_SV_NAME = "GrimSuiteActionBarSavedVars"
local POSITION_SV_VERSION = 1
local POSITION_DEFAULTS = {
    positionX = -38,
    positionY = -109,
    unlocked = false,
    iconSize = 65,
    potionSize = POTION_SIZE_DEFAULT,
    slotGap = 3,
    rowGap = 3,
    backbarOpacity = 0.72,
    backbarDesaturation = 0.65,
    showUltimate = true,
    showQuickslot = true,
    showWeaponSwap = true,
    timerSize = 45,
    stackSize = 45,
    timerFont = "Univers 67",
    stackFont = "Univers 67",
    timerOutline = "outline",
    stackOutline = "outline",
    timerOffsetX = 0,
    timerOffsetY = 0,
    stackOffsetX = 0,
    stackOffsetY = 0,
}

local STACK_TRACKER_SV_NAME = "GrimSuiteStackTrackerSavedVars"
local STACK_TRACKER_SV_VERSION = 2
local STACK_TRACKER_DEFAULTS = {
    showStackTracker = true,
    unlocked = false,
    iconSize = 50,
    textSize = 45,
    showBoundArmaments = true,
    showCrux = true,
    showBow = true,
    boundArmamentsX = -54,
    boundArmamentsY = 250,
    cruxX = 0,
    cruxY = 250,
    bowX = 54,
    bowY = 250,
}

local STACK_TRACKER_MIN_ICON_SIZE = 30
local STACK_TRACKER_MAX_ICON_SIZE = 100
local STACK_TRACKER_MIN_TEXT_SIZE = 10
local STACK_TRACKER_MAX_TEXT_SIZE = 80
local STACK_TRACKER_FRAME_PADDING = 2

local positionSV = nil
local stackTrackerSV = nil
local LAM = nil
local dragState = {
    dragging = false,
    startMouseX = 0,
    startMouseY = 0,
    startX = 0,
    startY = 0,
}

local function GetPotionSize()
    return math.max(40, math.min(100, tonumber(ActionBar.potionSize) or POTION_SIZE_DEFAULT))
end

local function GetIconSize()
    return math.max(40, math.min(100, tonumber(ActionBar.iconSize) or 65))
end

local function GetSlotGap()
    return math.max(0, math.min(20, tonumber(ActionBar.slotGap) or 3))
end

local function GetRowGap()
    return math.max(0, math.min(20, tonumber(ActionBar.rowGap) or 3))
end

local function GetBackbarOpacity()
    return math.max(0, math.min(1, tonumber(ActionBar.backbarOpacity) or 0.72))
end

local function GetBackbarDesaturation()
    return math.max(0, math.min(1, tonumber(ActionBar.backbarDesaturation) or 0.65))
end

local function GetRowWidth()
    local size = GetIconSize()
    local gap = GetSlotGap()
    return (SLOT_COUNT * size) + ((SLOT_COUNT - 1) * gap)
end

local function GetTotalWidth()
    return GetRowWidth() + ULT_GAP + GetIconSize()
end

-- ESO's SetFont() expects the actual font resource path rather than the
-- human-readable font name. Keep the names user-facing, but resolve them
-- to ESO's built-in font resources before building the SetFont string.
-- These resource paths are intentionally extensionless for current ESO font
-- handling.
local OVERLAY_FONT_PATHS = {
    -- Use ESO font macros here rather than raw file paths. Since Update 41,
    -- ESO's built-in fonts are rendered through the Slug system, and the
    -- macros resolve to the correct current font resource.
    ["Univers 57"] = "$(MEDIUM_FONT)",
    ["Univers 67"] = "$(BOLD_FONT)",
    ["ProseAntique"] = "$(ANTIQUE_FONT)",
    ["Trajan Pro"] = "$(STONE_TABLET_FONT)",
    ["Skyrim Handwritten"] = "$(HANDWRITTEN_FONT)",
    ["Futura Condensed Light"] = "$(GAMEPAD_LIGHT_FONT)",
    ["Futura Condensed"] = "$(GAMEPAD_MEDIUM_FONT)",
    ["Futura Condensed Bold"] = "$(GAMEPAD_BOLD_FONT)",
}


local function BuildOverlayFont(fontName, size, outline)
    fontName = tostring(fontName or "Univers 67")
    local fontPath = OVERLAY_FONT_PATHS[fontName] or OVERLAY_FONT_PATHS["Univers 67"]
    size = tonumber(size) or 45
    outline = tostring(outline or "outline")
    return string.format("%s|%d|%s", fontPath, math.floor(size + 0.5), outline)
end

local function GetTimerFont()
    return BuildOverlayFont(ActionBar.timerFont, ActionBar.timerSize, ActionBar.timerOutline)
end

local function GetStackFont()
    return BuildOverlayFont(ActionBar.stackFont, ActionBar.stackSize, ActionBar.stackOutline)
end

local function GetStackTrackerIconSize()
    return math.max(
        STACK_TRACKER_MIN_ICON_SIZE,
        math.min(STACK_TRACKER_MAX_ICON_SIZE, tonumber(ActionBar.stackTrackerIconSize) or STACK_TRACKER_DEFAULTS.iconSize)
    )
end

local function GetStackTrackerTextSize()
    return math.max(
        STACK_TRACKER_MIN_TEXT_SIZE,
        math.min(STACK_TRACKER_MAX_TEXT_SIZE, tonumber(ActionBar.stackTrackerTextSize) or STACK_TRACKER_DEFAULTS.textSize)
    )
end

local function GetStackTrackerFont()
    return BuildOverlayFont("Univers 67", GetStackTrackerTextSize(), "outline")
end


local function GetFontVerticalOffset(fontName, offsetY)
    offsetY = tonumber(offsetY) or 0
    -- All tested overlay fonts need a 1px upward optical correction except
    -- Skyrim Handwritten, which is already visually centered at the base offset.
    if tostring(fontName or "") ~= "Skyrim Handwritten" then
        return offsetY - 1
    end
    return offsetY
end

local function AnchorOverlayText(label, frame, offsetX, offsetY)
    if not label or not frame then return end

    offsetX = tonumber(offsetX) or 0
    offsetY = tonumber(offsetY) or 0

    -- Give the label the full icon rectangle and let the alignment flags
    -- center the rendered glyphs inside that rectangle. Moving both edges by
    -- the same offset preserves the existing user-facing X/Y settings while
    -- avoiding font-specific baseline/autosize drift.
    label:ClearAnchors()
    label:SetAnchor(TOPLEFT, frame, TOPLEFT, offsetX, offsetY)
    label:SetAnchor(BOTTOMRIGHT, frame, BOTTOMRIGHT, offsetX, offsetY)
    label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
end

local PREVIEW_TIMER_DURATIONS = {
    [3] = 9,
    [4] = 8,
    [5] = 7,
    [6] = 6,
    [7] = 5,
    [8] = 9,
}

local PREVIEW_TIMER_OFFSETS = {
    [3] = 0.0,
    [4] = 0.6,
    [5] = 1.2,
    [6] = 1.8,
    [7] = 2.4,
    [8] = 3.0,
}

local PREVIEW_STACK_SAMPLE_SLOT = 5
local PREVIEW_STACK_SAMPLE_TEXT = "3"

local function UpdateSettingsPreviewTimers()
    if not ActionBar.settingsPreviewVisible then return end

    local now = GetFrameTimeMilliseconds() / 1000

    for rowIndex, controls in ipairs({ ActionBar.frontControls, ActionBar.backbarControls }) do
        for slot = MIN_SLOT, ULT_SLOT do
            local data = controls and controls[slot]
            local duration = PREVIEW_TIMER_DURATIONS[slot]

            if data then
                -- Reserve the center skill slot on the TOP row for a clear
                -- Stack Count sample. Every other slot demonstrates Timer text.
                local isStackSample = rowIndex == 1 and slot == PREVIEW_STACK_SAMPLE_SLOT

                if data.timer then
                    if isStackSample then
                        data.timer:SetText("")
                    elseif duration then
                        local phase = (now + (PREVIEW_TIMER_OFFSETS[slot] or 0)) % duration
                        local remaining = duration - phase
                        if remaining < 0.1 then
                            remaining = duration
                        end

                        -- Preview timers intentionally use whole single-digit
                        -- values so font/outline differences are easy to judge.
                        data.timer:SetText(tostring(math.max(1, math.ceil(remaining))))
                    end
                end

                if data.stack then
                    data.stack:SetText(isStackSample and PREVIEW_STACK_SAMPLE_TEXT or "")
                end
            end
        end
    end

    -- Give the Potion preview its own whole-number cooldown as well. The
    -- actual potion cooldown logic remains untouched outside settings preview.
    local potion = ActionBar.utilityPotion
    if potion and potion.timer then
        local potionDuration = 9
        local potionPhase = now % potionDuration
        local potionRemaining = potionDuration - potionPhase
        potion.timer:SetText(tostring(math.max(1, math.ceil(potionRemaining))))
    end
end

local function ApplyOverlayTextStyles()
    local timerFont = GetTimerFont()
    local stackFont = GetStackFont()
    local timerX = tonumber(ActionBar.timerOffsetX) or 0
    local timerY = tonumber(ActionBar.timerOffsetY) or 0
    local stackX = tonumber(ActionBar.stackOffsetX) or 0
    local stackY = tonumber(ActionBar.stackOffsetY) or 0
    local roots = { ActionBar.frontControls, ActionBar.backbarControls }
    for _, controls in ipairs(roots) do
        for _, data in pairs(controls) do
            if data then
                if data.timer then
                    data.timer:SetFont(timerFont)
                    AnchorOverlayText(data.timer, data.frame, timerX, GetFontVerticalOffset(ActionBar.timerFont, timerY))
                end
                if data.stack then
                    data.stack:SetFont(stackFont)
                    AnchorOverlayText(data.stack, data.frame, stackX, GetFontVerticalOffset(ActionBar.stackFont, stackY))
                end
            end
        end
    end

    if ActionBar.utilityPotion then
        ActionBar.utilityPotion.timer:SetFont(timerFont)
        AnchorOverlayText(ActionBar.utilityPotion.timer, ActionBar.utilityPotion.frame, timerX, GetFontVerticalOffset(ActionBar.timerFont, timerY))
        ActionBar.utilityPotion.count:SetFont(POTION_COUNT_FONT)
        ActionBar.utilityPotion.count:ClearAnchors()
        ActionBar.utilityPotion.count:SetAnchor(TOP, ActionBar.utilityPotion.frame, BOTTOM, 0, 0)
        ActionBar.utilityPotion.count:SetDimensions(GetPotionSize(), 30)
        ActionBar.utilityPotion.count:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        ActionBar.utilityPotion.count:SetVerticalAlignment(TEXT_ALIGN_TOP)
    end
    if ActionBar.utilityWeaponSwap then
        ActionBar.utilityWeaponSwap.count:SetFont(stackFont)
        ActionBar.utilityWeaponSwap.timer:SetFont(timerFont)
    end
end

-- Native controls that visually belong to the action bar.  We keep their
-- original screen positions as the reference and apply the same saved offset
-- used by GrimSuite's custom bars.
local nativeLayoutBase = {
    captured = false,
    weaponSwapLeft = nil,
    weaponSwapTop = nil,
    weaponSwapRight = nil,
}

local function MakeFrame(name, parent)
    local c = WM:CreateControl(name, parent, CT_BACKDROP)
    c:SetCenterColor(unpack(FRAME_BG))
    c:SetEdgeColor(unpack(FRAME_EDGE))
    c:SetEdgeTexture("EsoUI/Art/Tooltips/UI-Border.dds", 16, 16, FRAME_EDGE_WIDTH, 0)
    c:SetDrawLevel(20)
    c:SetMouseEnabled(false)
    return c
end

local function GetButton(slot, category)
    local ok, button = pcall(ZO_ActionBar_GetButton, slot, category)
    if ok then return button end
    return nil
end

local function HideNativeVisuals(button)
    if not button then return end
    if button.buttonText then
        button.buttonText:SetHidden(true)
    end
    if button.icon then
        button.icon:SetAlpha(0)
    end
    if button.bg then
        button.bg:SetAlpha(0)
    end
    if button.slot then
        local backdrop = button.slot:GetNamedChild("Backdrop")
        if backdrop then backdrop:SetAlpha(0) end
        -- Keep the native slot alive for input, but make the entire native
        -- visual hierarchy transparent so ESO cannot leave ghost boxes/frames
        -- visible behind the GrimSuite display.
        button.slot:SetAlpha(0)
    end
end

local function GetAbilityForSlot(slot, category)
    local id = GetSlotBoundId(slot, category)
    if not id or id <= 0 then return 0 end

    -- Scribed skills return a craftedAbilityId (the Grimoire ID) from
    -- GetSlotBoundId(). Convert that to the real representative ability ID
    -- before asking ESO for the icon/name/effective ability.
    if GetSlotType(slot, category) == ACTION_TYPE_CRAFTED_ABILITY then
        local ok, realId = pcall(GetAbilityIdForCraftedAbilityId, id)
        if ok and realId and realId > 0 then
            id = realId
        end
    end

    local ok, effective = pcall(GetEffectiveAbilityIdForAbilityOnHotbar, id, category)
    if ok and effective and effective > 0 then
        id = effective
    end
    return id
end

local function CreateDisplayButton(root, x, key, prefix)
    local base = "GrimSuiteAB_" .. prefix .. "_" .. key
    local frame = MakeFrame(base .. "Frame", root)
    frame:SetDimensions(GetIconSize(), GetIconSize())
    frame:ClearAnchors()
    frame:SetAnchor(TOPLEFT, root, TOPLEFT, x, 0)

    local icon = WM:CreateControl(base .. "Icon", frame, CT_TEXTURE)
    icon:SetAnchor(TOPLEFT, frame, TOPLEFT, 2, 2)
    icon:SetAnchor(BOTTOMRIGHT, frame, BOTTOMRIGHT, -2, -2)
    icon:SetTextureCoords(0, 1, 0, 1)
    icon:SetDrawLevel(21)
    icon:SetMouseEnabled(false)

    local shade = WM:CreateControl(base .. "Shade", frame, CT_BACKDROP)
    shade:SetAnchorFill(icon)
    shade:SetCenterColor(0, 0, 0, 0.10)
    shade:SetEdgeColor(0, 0, 0, 0)
    shade:SetDrawLevel(22)
    shade:SetMouseEnabled(false)

    -- Short native-style "button pressed" feedback.  This is deliberately
    -- separate from the toggle/proc glow below: casting a skill briefly
    -- darkens/presses the custom button, then returns to its normal state.
    local pressed = WM:CreateControl(base .. "Pressed", frame, CT_BACKDROP)
    pressed:ClearAnchors()
    pressed:SetAnchor(TOPLEFT, frame, TOPLEFT, 2, 2)
    pressed:SetAnchor(BOTTOMRIGHT, frame, BOTTOMRIGHT, -2, -2)
    pressed:SetCenterColor(0, 0, 0, 0.28)
    pressed:SetEdgeColor(1, 1, 1, 0.22)
    pressed:SetEdgeTexture("EsoUI/Art/Tooltips/UI-Border.dds", 16, 16, 2, 0)
    pressed:SetDrawLevel(27)
    pressed:SetHidden(true)
    pressed:SetMouseEnabled(false)

    -- Bright FAB-style state glow. ESO already provides the exact
    -- action-slot highlight texture FAB uses for toggled skills. Reuse it
    -- here so active toggles and ready ultimates have a very obvious
    -- luminous border instead of a subtle backdrop edge.
    local outerGlow = WM:CreateControl(base .. "OuterGlow", frame, CT_TEXTURE)
    outerGlow:ClearAnchors()
    outerGlow:SetAnchor(TOPLEFT, frame, TOPLEFT, 0, 0)
    outerGlow:SetAnchor(BOTTOMRIGHT, frame, BOTTOMRIGHT, 0, 0)
    outerGlow:SetTexture("EsoUI/Art/ActionBar/ActionSlot_toggledon.dds")
    outerGlow:SetTextureCoords(0, 1, 0, 1)
    outerGlow:SetColor(0.15, 0.85, 1.0, 0.50)
    outerGlow:SetDrawLevel(22)
    outerGlow:SetHidden(true)
    outerGlow:SetMouseEnabled(false)

    local glow = WM:CreateControl(base .. "Glow", frame, CT_TEXTURE)
    glow:ClearAnchors()
    glow:SetAnchor(TOPLEFT, frame, TOPLEFT, 0, 0)
    glow:SetAnchor(BOTTOMRIGHT, frame, BOTTOMRIGHT, 0, 0)
    glow:SetTexture("EsoUI/Art/ActionBar/ActionSlot_toggledon.dds")
    glow:SetTextureCoords(0, 1, 0, 1)
    glow:SetColor(0.20, 0.92, 1.0, 1.0)
    glow:SetDrawLevel(23)
    glow:SetHidden(true)
    glow:SetMouseEnabled(false)

    local timer = WM:CreateControl(base .. "Timer", frame, CT_LABEL)
    timer:SetFont(GetTimerFont())
    AnchorOverlayText(
        timer,
        frame,
        tonumber(ActionBar.timerOffsetX) or 0,
        tonumber(ActionBar.timerOffsetY) or 0
    )
    timer:SetColor(unpack(TIMER_COLOR))
    timer:SetDrawLevel(24)
    timer:SetText("")
    timer:SetMouseEnabled(false)

    local stack = WM:CreateControl(base .. "Stack", frame, CT_LABEL)
    stack:SetFont(GetStackFont())
    AnchorOverlayText(
        stack,
        frame,
        tonumber(ActionBar.stackOffsetX) or 0,
        tonumber(ActionBar.stackOffsetY) or 0
    )
    stack:SetColor(unpack(STACK_COLOR))
    stack:SetDrawLevel(25)
    stack:SetText("")
    stack:SetMouseEnabled(false)

    local ultValue = nil
    if key == "Ult" then
        ultValue = WM:CreateControl(base .. "UltValue", frame, CT_LABEL)
        ultValue:SetFont(ULT_FONT)
        ultValue:SetAnchor(CENTER, frame, TOP, 0, -15)
        ultValue:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        ultValue:SetVerticalAlignment(TEXT_ALIGN_BOTTOM)
        ultValue:SetColor(unpack(ULT_COLOR))
        ultValue:SetDrawLevel(26)
        ultValue:SetText("")
        ultValue:SetMouseEnabled(false)
    end

    return { frame = frame, icon = icon, shade = shade, pressed = pressed, glow = glow, outerGlow = outerGlow, timer = timer, stack = stack, ultValue = ultValue }
end

local function CreateBarIndicator(name, parent, rowButton)
    -- GrimSuite-owned bar selector: a small filled triangle centered on the
    -- actual action-row button.  Using a texture avoids font glyph/baseline
    -- alignment issues and keeps the indicator visually consistent.
    local indicator = WM:CreateControl(name, parent, CT_TEXTURE)
    indicator:SetDimensions(UTILITY_BAR_INDICATOR_WIDTH, UTILITY_BAR_INDICATOR_HEIGHT)
    indicator:ClearAnchors()
    indicator:SetAnchor(RIGHT, rowButton.frame, LEFT, -UTILITY_BAR_INDICATOR_GAP, 0)
    indicator:SetTexture(UTILITY_BAR_INDICATOR_TEXTURE)
    indicator:SetColor(unpack(UTILITY_BAR_INDICATOR_INACTIVE))
    indicator:SetDrawLevel(26)
    indicator:SetMouseEnabled(false)
    return indicator
end

local function CreateRow(rootName, controls, prefix)
    local root = WM:CreateTopLevelWindow(rootName)
    root:SetDimensions(GetTotalWidth(), GetIconSize())
    root:SetMouseEnabled(true)
    root:SetMovable(false)
    root:SetClampedToScreen(true)
    root:SetDrawTier(DT_LOW)

    for i = MIN_SLOT, MAX_SLOT do
        local x = (i - MIN_SLOT) * (GetIconSize() + GetSlotGap())
        controls[i] = CreateDisplayButton(root, x, tostring(i), prefix)
    end

    controls[ULT_SLOT] = CreateDisplayButton(root, GetRowWidth() + ULT_GAP, "Ult", prefix)
    if string.find(rootName, "Front", 1, true) then
        ActionBar.frontBarIndicator = CreateBarIndicator("GrimSuiteAB_FrontBarIndicator", root, controls[MIN_SLOT])
    elseif string.find(rootName, "Back", 1, true) then
        ActionBar.backBarIndicator = CreateBarIndicator("GrimSuiteAB_BackBarIndicator", root, controls[MIN_SLOT])
    end
    return root
end

local InstallDragHandlers
local GetNativeActionBarControls

local function GetNativeWeaponSwapIconTexture(weaponSwap)
    if not weaponSwap then return nil end

    -- Borrow only the native texture path. The visible control itself belongs
    -- to GrimSuite, so ESO can continue rebuilding its own hidden control safely.
    local candidates = {
        weaponSwap:GetNamedChild("Icon"),
        weaponSwap:GetNamedChild("WeaponSwapIcon"),
        weaponSwap:GetNamedChild("Button"),
    }

    for _, child in ipairs(candidates) do
        if child then
            local ok, texture = pcall(function() return child:GetTexture() end)
            if ok and texture and texture ~= "" then
                return texture
            end
            local okNormal, normal = pcall(function() return child:GetNormalTexture() end)
            if okNormal and normal and normal ~= "" then
                return normal
            end
        end
    end

    return UTILITY_WEAPON_TEXTURE_FALLBACK
end

local function CreateUtilityButton(parent, name, size)
    local frame = MakeFrame(name .. "Frame", parent)
    frame:SetDimensions(size, size)
    -- The utility weapon-swap presentation is icon-only; do not draw an
    -- otherwise empty GrimSuite action-slot box around it.
    if string.find(name, "WeaponSwap", 1, true) then
        frame:SetCenterColor(0, 0, 0, 0)
        frame:SetEdgeColor(0, 0, 0, 0)
    end
    frame:SetMouseEnabled(true)

    local icon = WM:CreateControl(name .. "Icon", frame, CT_TEXTURE)
    icon:SetAnchor(TOPLEFT, frame, TOPLEFT, 2, 2)
    icon:SetAnchor(BOTTOMRIGHT, frame, BOTTOMRIGHT, -2, -2)
    icon:SetTextureCoords(0, 1, 0, 1)
    icon:SetDrawLevel(21)
    icon:SetMouseEnabled(false)

    local shade = WM:CreateControl(name .. "Shade", frame, CT_BACKDROP)
    shade:SetAnchorFill(icon)
    if string.find(name, "WeaponSwap", 1, true) then
        -- Weapon swap is intentionally icon-only. Do not leave the faint
        -- utility-slot shadow behind it when its icon is transparent.
        shade:SetCenterColor(0, 0, 0, 0)
    else
        shade:SetCenterColor(0, 0, 0, 0.10)
    end
    shade:SetEdgeColor(0, 0, 0, 0)
    shade:SetDrawLevel(22)
    shade:SetMouseEnabled(false)

    local pressed = WM:CreateControl(name .. "Pressed", frame, CT_BACKDROP)
    pressed:SetAnchor(TOPLEFT, frame, TOPLEFT, 2, 2)
    pressed:SetAnchor(BOTTOMRIGHT, frame, BOTTOMRIGHT, -2, -2)
    pressed:SetCenterColor(0, 0, 0, 0.28)
    pressed:SetEdgeColor(1, 1, 1, 0.22)
    pressed:SetEdgeTexture("EsoUI/Art/Tooltips/UI-Border.dds", 16, 16, 2, 0)
    pressed:SetDrawLevel(27)
    pressed:SetHidden(true)
    pressed:SetMouseEnabled(false)

    local count = WM:CreateControl(name .. "Count", frame, CT_LABEL)
    count:SetFont(string.find(name, "Potion", 1, true) and POTION_COUNT_FONT or GetStackFont())
    if string.find(name, "Potion", 1, true) then
        -- Potion count lives just outside the bottom edge of the icon so it
        -- never overlaps the cooldown timer.
        count:SetAnchor(TOP, frame, BOTTOM, 0, 0)
        count:SetDimensions(size, 30)
        count:SetVerticalAlignment(TEXT_ALIGN_TOP)
    else
        count:SetAnchor(BOTTOM, frame, BOTTOM, 0, -2)
        count:SetVerticalAlignment(TEXT_ALIGN_BOTTOM)
    end
    count:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    count:SetColor(unpack(STACK_COLOR))
    count:SetDrawLevel(25)
    count:SetText("")
    count:SetMouseEnabled(false)

    local timer = WM:CreateControl(name .. "Timer", frame, CT_LABEL)
    timer:SetFont(GetTimerFont())
    timer:SetAnchor(CENTER, frame, CENTER, tonumber(ActionBar.timerOffsetX) or 0, tonumber(ActionBar.timerOffsetY) or 0)
    timer:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    timer:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    timer:SetColor(unpack(TIMER_COLOR))
    timer:SetDrawLevel(24)
    timer:SetText("")
    timer:SetMouseEnabled(false)

    return {
        frame = frame,
        icon = icon,
        shade = shade,
        pressed = pressed,
        count = count,
        timer = timer,
    }
end

local UpdatePotionTimer

local function CreateUtilityControls()
    if ActionBar.utilityRoot then return end

    local root = WM:CreateTopLevelWindow("GrimSuiteAB_UtilityRoot")
    local potionSize = GetPotionSize()
    root:SetDimensions(potionSize + UTILITY_GAP + SLOT_SIZE + UTILITY_BAR_INDICATOR_GAP + UTILITY_BAR_INDICATOR_WIDTH, potionSize)
    root:SetMouseEnabled(false)
    root:SetMovable(false)
    root:SetClampedToScreen(true)
    root:SetDrawTier(DT_LOW)

    -- Quickslot cooldowns do not reliably emit a dedicated countdown event.
    -- Tick only the GrimSuite-owned potion timer so it visibly counts down
    -- without rebuilding the whole utility control every frame.
    local timerAccumulator = 0
    root:SetHandler("OnUpdate", function(_, delta)
        timerAccumulator = timerAccumulator + (delta or 0)
        if timerAccumulator >= 0.05 then
            timerAccumulator = 0
            UpdatePotionTimer()
            UpdateSettingsPreviewTimers()
        end
    end)

    ActionBar.utilityRoot = root
    ActionBar.utilityPotion = CreateUtilityButton(root, "GrimSuiteAB_Potion", potionSize)
    ActionBar.utilityWeaponSwap = CreateUtilityButton(root, "GrimSuiteAB_WeaponSwap", SLOT_SIZE)

    ActionBar.utilityPotion.frame:SetAnchor(TOPLEFT, root, TOPLEFT, 0, 0)
    ActionBar.utilityWeaponSwap.frame:SetAnchor(
        TOPLEFT, root, TOPLEFT,
        potionSize + UTILITY_GAP,
        math.max(0, (potionSize - SLOT_SIZE) * 0.5)
    )

    local potion = ActionBar.utilityPotion
    potion.frame:SetHandler("OnMouseDown", function(_, button)
        if button == MOUSE_BUTTON_INDEX_LEFT then
            local slot = GetCurrentQuickslot()
            if slot and slot > 0 and ZO_ActionBar_CanUseActionSlots() then
                OnSlotDown(slot, HOTBAR_CATEGORY_QUICKSLOT_WHEEL)
                ZO_ActionBar_OnActionButtonDown(slot, HOTBAR_CATEGORY_QUICKSLOT_WHEEL)
                potion.pressed:SetHidden(false)
            end
        end
    end)
    potion.frame:SetHandler("OnMouseUp", function(_, button)
        if button == MOUSE_BUTTON_INDEX_LEFT then
            local slot = GetCurrentQuickslot()
            if slot and slot > 0 then
                OnSlotUp(slot, HOTBAR_CATEGORY_QUICKSLOT_WHEEL)
                ZO_ActionBar_OnActionButtonUp(slot, HOTBAR_CATEGORY_QUICKSLOT_WHEEL)
            end
            potion.pressed:SetHidden(true)
        end
    end)

    local weapon = ActionBar.utilityWeaponSwap
    weapon.frame:SetHandler("OnMouseDown", function(_, button)
        if button == MOUSE_BUTTON_INDEX_LEFT then
            weapon.pressed:SetHidden(false)
        end
    end)
    weapon.frame:SetHandler("OnMouseUp", function(_, button)
        if button == MOUSE_BUTTON_INDEX_LEFT then
            weapon.pressed:SetHidden(true)
            OnWeaponSwap()
        end
    end)
end

UpdatePotionTimer = function()
    local potion = ActionBar.utilityPotion
    if not potion then return end

    local slot = GetCurrentQuickslot()
    local remain, duration = 0, 0

    if slot and slot > 0 then
        local okCooldown, r, d = pcall(GetSlotCooldownInfo, slot, HOTBAR_CATEGORY_QUICKSLOT_WHEEL)
        if okCooldown then
            remain = r or 0
            duration = d or 0
        end
    end

    -- GetSlotCooldownInfo can report the short global/action cooldown on the
    -- quickslot when another skill is cast. That is not a potion cooldown and
    -- should never replace the potion timer. Real potion cooldowns are much
    -- longer than the ~1 second action/GCD cooldown.
    local isShortActionCooldown = duration > 0 and duration <= 2000

    if remain > 0 and duration > 0 and not isShortActionCooldown then
        potion.timer:SetText(ZO_FormatTimeShowUnitOverThresholdShowDecimalUnderThreshold(
            remain / 1000,
            ZO_ONE_MINUTE_IN_SECONDS,
            ZO_EFFECT_EXPIRATION_IMMINENCE_THRESHOLD_S,
            TIME_FORMAT_STYLE_SHOW_LARGEST_UNIT
        ))
    else
        potion.timer:SetText("")
    end
end

local function UpdateUtilityControls()
    if not ActionBar.utilityRoot then return end

    local weaponSwap, nativePotion = GetNativeActionBarControls()
    local potion = ActionBar.utilityPotion
    local weapon = ActionBar.utilityWeaponSwap
    if not potion or not weapon then return end

    potion.frame:SetHidden(not ActionBar.showQuickslot)
    weapon.frame:SetHidden(not ActionBar.showWeaponSwap)

    local activeCategory = GetActiveHotbarCategory()
    if activeCategory ~= HOTBAR_CATEGORY_PRIMARY and activeCategory ~= HOTBAR_CATEGORY_BACKUP then
        activeCategory = HOTBAR_CATEGORY_PRIMARY
    end

    -- Each indicator is anchored to the center of its actual GrimSuite row,
    -- so the top line belongs to the top bar and the bottom line to the bottom
    -- bar regardless of utility-icon position.
    if ActionBar.frontBarIndicator then
        ActionBar.frontBarIndicator:SetColor(unpack(
            activeCategory == HOTBAR_CATEGORY_PRIMARY
                and UTILITY_BAR_INDICATOR_ACTIVE or UTILITY_BAR_INDICATOR_INACTIVE
        ))
        ActionBar.frontBarIndicator:SetHidden(not ActionBar.showWeaponSwap)
    end
    if ActionBar.backBarIndicator then
        ActionBar.backBarIndicator:SetColor(unpack(
            activeCategory == HOTBAR_CATEGORY_BACKUP
                and UTILITY_BAR_INDICATOR_ACTIVE or UTILITY_BAR_INDICATOR_INACTIVE
        ))
        ActionBar.backBarIndicator:SetHidden(not ActionBar.showWeaponSwap)
    end

    if nativePotion then
        nativePotion:SetScale(1)
        nativePotion:SetHidden(true)
    end

    if weaponSwap then
        weaponSwap:SetScale(1)
        weaponSwap:SetHidden(true)
        local texture = GetNativeWeaponSwapIconTexture(weaponSwap)
        if texture and texture ~= "" then
            weapon.icon:SetTexture(texture)
        end
    end

    local slot = GetCurrentQuickslot()
    local icon = nil
    local count = 0
    local usable = true
    local remain, duration = 0, 0

    if slot and slot > 0 then
        local okTexture, slotTexture = pcall(GetSlotTexture, slot, HOTBAR_CATEGORY_QUICKSLOT_WHEEL)
        if okTexture and slotTexture then icon = slotTexture end

        local okCount, slotCount = pcall(GetSlotItemCount, slot, HOTBAR_CATEGORY_QUICKSLOT_WHEEL)
        if okCount and slotCount then count = slotCount end

        local okCooldown, r, d = pcall(GetSlotCooldownInfo, slot, HOTBAR_CATEGORY_QUICKSLOT_WHEEL)
        if okCooldown then
            remain = r or 0
            duration = d or 0
        end

        local quickslotButton = ZO_ActionBar_GetButton(slot, HOTBAR_CATEGORY_QUICKSLOT_WHEEL)
        if quickslotButton then
            if quickslotButton.HandleSlotChanged then
                quickslotButton:HandleSlotChanged(HOTBAR_CATEGORY_QUICKSLOT_WHEEL)
            end
            usable = quickslotButton.usable
        end
    end

    if icon and icon ~= "" then
        potion.icon:SetTexture(icon)
        potion.icon:SetHidden(false)
        potion.shade:SetHidden(false)
        potion.icon:SetAlpha(usable == false and UNUSABLE_ICON_ALPHA or ACTIVE_ICON_ALPHA)
        potion.icon:SetDesaturation(usable == false and UNUSABLE_DESATURATION or 0)
    else
        potion.icon:SetTexture("")
        potion.icon:SetHidden(true)
        potion.shade:SetHidden(true)
    end

    if count and count > 0 then
        potion.count:SetText(tostring(count))
    else
        potion.count:SetText("")
    end

    UpdatePotionTimer()

    -- HandleSlotChanged() above may repaint the native quickslot. Hide the
    -- native presentation again after state synchronization.
    if nativePotion then nativePotion:SetHidden(true) end
    if weaponSwap then weaponSwap:SetHidden(true) end
end

local function AnchorUtilityControls()
    if not ActionBar.utilityRoot then return end
    local actionBar = GetControl("ZO_ActionBar1")
    local weaponSwap = actionBar and actionBar:GetNamedChild("WeaponSwap")
    if not weaponSwap then return end

    ActionBar.utilityRoot:ClearAnchors()
    -- Keep the existing horizontal placement, but center the utility root
    -- vertically on the stable weapon-swap reference instead of using a
    -- guessed top-edge offset.
    ActionBar.utilityRoot:SetAnchor(RIGHT, weaponSwap, RIGHT, 0, 0)
end

function ActionBar:CreateRows()
    CreateUtilityControls()
    if not self.frontRoot then
        self.frontRoot = CreateRow("GrimSuiteAB_FrontRoot", self.frontControls, "Front")
    end
    if not self.backbarRoot then
        self.backbarRoot = CreateRow("GrimSuiteAB_BackRoot", self.backbarControls, "Back")
    end

    -- Install the drag handlers after the roots actually exist.  The local
    -- function is defined later in the file, but CreateRows() is only called
    -- after the addon has finished loading.
    if InstallDragHandlers then
        InstallDragHandlers()
    end
end

local function StyleDisplay(data, active, hasAbility, usable)
    if not data then return end
    data.frame:SetHidden(not ActionBar.showFrames)
    if data.glow then
        data.glow:SetHidden(true)
    end
    if data.outerGlow then
        data.outerGlow:SetHidden(true)
    end

    if active then
        data.frame:SetCenterColor(unpack(FRAME_BG_ACTIVE))
        data.frame:SetEdgeColor(unpack(FRAME_EDGE_ACTIVE))
        data.frame:SetEdgeTexture("EsoUI/Art/Tooltips/UI-Border.dds", 16, 16, FRAME_EDGE_WIDTH_ACTIVE, 0)
        if usable == false then
            data.icon:SetAlpha(UNUSABLE_ICON_ALPHA)
            data.icon:SetDesaturation(UNUSABLE_DESATURATION)
        else
            data.icon:SetAlpha(ACTIVE_ICON_ALPHA)
            data.icon:SetDesaturation(0)
        end
    else
        data.frame:SetCenterColor(unpack(FRAME_BG))
        data.frame:SetEdgeColor(unpack(FRAME_EDGE))
        data.frame:SetEdgeTexture("EsoUI/Art/Tooltips/UI-Border.dds", 16, 16, FRAME_EDGE_WIDTH, 0)
        data.icon:SetAlpha(GetBackbarOpacity())
        -- Inactive rows stay desaturated at all times, including the backbar.
        -- This is a visual state of the row, not ESO usability state.
        data.icon:SetDesaturation(GetBackbarDesaturation())
    end

    if not hasAbility then
        data.timer:SetText("")
        data.stack:SetText("")
    end

    if hasAbility then
        data.icon:SetHidden(false)
        data.shade:SetHidden(false)
    else
        data.icon:SetTexture("")
        data.icon:SetHidden(true)
        data.shade:SetHidden(true)
    end
end

local function InstallNativeUtilitySuppressionHooks()
    local weaponSwap, potion = GetNativeActionBarControls()

    if weaponSwap and not nativeUtilityHooks.weaponSwap then
        nativeUtilityHooks.weaponSwap = true
        ZO_PreHookHandler(weaponSwap, "OnShow", function()
            weaponSwap:SetHidden(true)
        end)
    end

    if potion and not nativeUtilityHooks.potion then
        nativeUtilityHooks.potion = true
        ZO_PreHookHandler(potion, "OnShow", function()
            potion:SetHidden(true)
        end)
    end
end

function ActionBar:UpdateNativeVisualSuppression()
    InstallNativeUtilitySuppressionHooks()

    -- Keep ESO's controls alive for keyboard/mouse/gamepad input, but remove
    -- their visible icon/background so they cannot appear as ghost bars.
    for _, category in ipairs(HOTBAR_CATEGORIES) do
        for i = MIN_SLOT, ULT_SLOT do
            local button = GetButton(i, category)
            if button then HideNativeVisuals(button) end
        end
    end

    local weaponSwap, potion = GetNativeActionBarControls()
    if weaponSwap then weaponSwap:SetHidden(true) end
    if potion then potion:SetHidden(true) end
end

GetNativeActionBarControls = function()
    local actionBar = GetControl("ZO_ActionBar1")
    if not actionBar then return nil, nil end

    local weaponSwap = actionBar:GetNamedChild("WeaponSwap")
    local potion = actionBar:GetNamedChild("PotionSlot")

    -- Be a little defensive about UI naming changes.
    if not potion then
        potion = actionBar:GetNamedChild("Potion")
    end
    if not potion then
        potion = actionBar:GetNamedChild("Quickslot")
    end
    if not potion then
        -- Current ESO uses QuickslotButton for the visible potion/quickslot
        -- control.  It may be exposed as a direct child or as a global control
        -- depending on the current UI layout.
        potion = actionBar:GetNamedChild("QuickslotButton")
    end
    if not potion then
        potion = GetControl("QuickslotButton")
    end

    return weaponSwap, potion
end

local function CaptureNativeLayoutBase()
    if nativeLayoutBase.captured then return true end

    local weaponSwap, potion = GetNativeActionBarControls()
    if not weaponSwap then return false end

    nativeLayoutBase.weaponSwapLeft = weaponSwap:GetLeft()
    nativeLayoutBase.weaponSwapTop = weaponSwap:GetTop()
    nativeLayoutBase.weaponSwapRight = weaponSwap:GetRight()

    nativeLayoutBase.captured = true
    return true
end

local function ApplyNativeLayoutOffset()
    if not CaptureNativeLayoutBase() then return end

    local posX = tonumber(ActionBar.positionX) or 0
    local posY = tonumber(ActionBar.positionY) or 0
    local weaponSwap, potion = GetNativeActionBarControls()

    if weaponSwap and nativeLayoutBase.weaponSwapLeft and nativeLayoutBase.weaponSwapTop then
        weaponSwap:ClearAnchors()
        weaponSwap:SetAnchor(
            TOPLEFT,
            GuiRoot,
            TOPLEFT,
            nativeLayoutBase.weaponSwapLeft + posX,
            nativeLayoutBase.weaponSwapTop + posY
        )
    end

    -- Native utility controls remain alive for ESO input/state, but GrimSuite
    -- owns the visible rendering now.
    if potion then
        potion:SetScale(1)
        potion:SetHidden(true)
    end
    if weaponSwap then
        weaponSwap:SetScale(1)
        weaponSwap:SetHidden(true)
    end

    AnchorUtilityControls()
    UpdateUtilityControls()
end

function ActionBar:AnchorRows()
    -- Anchor both rows to ESO's weapon-swap control, not an action button.
    -- Action buttons can be repositioned/rebuilt during weapon swaps; the
    -- weapon-swap control is the stable visual reference.
    local actionBar = GetControl("ZO_ActionBar1")
    local weaponSwap = actionBar and actionBar:GetNamedChild("WeaponSwap")
    if not weaponSwap then return end

    self.frontRoot:ClearAnchors()
    self.backbarRoot:ClearAnchors()

    -- Keep both rows on the same stable weapon-swap reference. The front row
    -- sits just above it by ROW_GAP; the back row starts at the reference.
    -- Do not include SLOT_SIZE in the offset: the BOTTOMLEFT anchor already
    -- positions the bottom edge of the front row.
    -- Move the native weapon-swap/potion controls first.  The GrimSuite
    -- rows then follow the moved weapon-swap control, so one saved position
    -- moves the entire action-bar composition together.
    ApplyNativeLayoutOffset()

    -- The native weapon-swap control is now the physical position anchor.
    -- Do not apply positionX/positionY a second time here.
    local rowGap = GetRowGap()
    self.frontRoot:SetAnchor(BOTTOMLEFT, weaponSwap, RIGHT, -UTILITY_ACTIONBAR_TIGHTEN, -rowGap)
    self.backbarRoot:SetAnchor(TOPLEFT, weaponSwap, RIGHT, -UTILITY_ACTIONBAR_TIGHTEN, 0)

    -- Keep the ultimate beside the bars, centered vertically across the
    -- combined two-row block.  Anchor both ult controls to the same stable
    -- weapon-swap reference so the position does not move when weapon bars
    -- are swapped.  Only the active ult is made visible in UpdateRow().
    local ultX = GetRowWidth() + ULT_GAP
    local ultY = -(GetIconSize() + GetRowGap()) * 0.5

    local frontUlt = self.frontControls[ULT_SLOT]
    if frontUlt and frontUlt.frame then
        frontUlt.frame:ClearAnchors()
        frontUlt.frame:SetAnchor(TOPLEFT, weaponSwap, RIGHT, ultX - UTILITY_ACTIONBAR_TIGHTEN, ultY)
    end

    local backUlt = self.backbarControls[ULT_SLOT]
    if backUlt and backUlt.frame then
        backUlt.frame:ClearAnchors()
        backUlt.frame:SetAnchor(TOPLEFT, weaponSwap, RIGHT, ultX - UTILITY_ACTIONBAR_TIGHTEN, ultY)
    end
end

---------------------------------------------------------------------
-- Small FAB-style effect layer
--
-- FAB has a large effect database and reconciliation engine. GrimSuite only
-- needs the two pieces that matter visually here:
--   1) ESO's action-slot effect duration/time-remaining for real slot timers.
--   2) Player effect stack changes for matching slotted abilities.
--
-- No FancyActionBar dependency. No copied FAB effect database.
---------------------------------------------------------------------

local function ClearEffectDisplay(data)
    if not data then return end
    data.timer:SetText("")
    data.stack:SetText("")
end

-- Small standalone stack map. These are the same stack-tracker relationships
-- used by the FAB/CombatMetronome source we inspected, but kept deliberately
-- local so GrimSuite does not depend on FAB.
--
-- key   = slotted ability
-- value = player-effect ability that carries the actual stack count
-- Shared Crux is handled separately so the tracker can determine whether
-- Crux is actually relevant to the current build without tying it to one
-- specific Arcanist ability.
local STACK_EFFECT_BY_ABILITY = {
    -- Molten Whip / Seething Fury
    [20805] = 122658,
    -- Bound Armaments
    [24165] = 203447,
    -- Grim Focus / Merciless Resolve / Relentless Focus
    [61902] = 122585,
    [61919] = 122586,
    [61927] = 122587,
    -- Flame Skull / Ricochet Skull / Venom Skull
    [114108] = 114131,
    [123683] = 114131,
    [123685] = 114131,
    [117637] = 117638,
    [123718] = 117638,
    [123719] = 117638,
    [117624] = 117625,
    [123699] = 117625,
    [123704] = 117625,
    -- Ruinous Scythe
    [125750] = 125749,
    -- Fetcher Infection
    [86027] = 91416,
    -- Arcanist Crux is intentionally handled separately below.
    -- Only Fatecarver and its morphs should display the Crux stack count.

}

local CRUX_EFFECT_ID = 184220

-- Crystal Fragments uses a hidden proc/passive effect to signal the empowered
-- instant-cast state. Keep the proc state separately from normal stack counts.
local CRYSTAL_FRAGMENTS_EFFECT_ID = 46327
local CRYSTAL_FRAGMENTS_ABILITY_ID = 114716

-- Crux is a shared resource, so the tracker should only appear when the
-- player has a slotted ability that can actually consume Crux. Skills that
-- merely benefit from having Crux but do not spend it do not make the tracker
-- relevant on their own.
local function IsFatecarverAbility(abilityId)
    if not abilityId or abilityId <= 0 or not GetAbilityName then
        return false
    end

    local ok, name = pcall(GetAbilityName, abilityId)
    if not ok or not name then
        return false
    end

    name = zo_strlower(tostring(name))
    return string.find(name, "fatecarver", 1, true) ~= nil
end

local NIGHTBLADE_STACK_EFFECTS = {
    [122585] = true, -- Grim Focus
    [122586] = true, -- Merciless Resolve
    [122587] = true, -- Relentless Focus
}

-- Necromancer Skull uses a player-effect row whose live stack count is
-- reliable through GetUnitBuffInfo(), but the normal GrimSuite cache does not
-- consistently retain the row. Track the live buff directly for the glow.
local NECRO_SKULL_STACK_EFFECTS = {
    [114131] = true, -- Flame Skull
    [117638] = true, -- Ricochet Skull
    [117625] = true, -- Venom Skull
}

local function IsNecroSkullAbility(abilityId)
    return abilityId == 114108 or abilityId == 123683 or abilityId == 123685
        or abilityId == 117637 or abilityId == 123718 or abilityId == 123719
        or abilityId == 117624 or abilityId == 123699 or abilityId == 123704
end

local CRUX_STACK_EFFECTS = {
    [CRUX_EFFECT_ID] = true,
}

-- Forward declarations: these helpers are defined later in the file but are
-- used by the stack tracker above them.
local IsTentacularDreadAbility
local GetCurrentCrux

local function GetLivePlayerStack(effectId, trackedEffects)
    if not trackedEffects[effectId] then
        return nil
    end

    -- GetUnitBuffInfo() is authoritative for the currently-present player
    -- buff. Do NOT reject a positive stack count based on endTime here: ESO
    -- can leave an effect row present for a short period around expiration,
    -- and the diagnostic proved the row itself is carrying the correct stack.
    for i = 1, GetNumBuffs("player") do
        local _, _, _, _, stackCount, _, _, _, _, _, buffAbilityId = GetUnitBuffInfo("player", i)
        if buffAbilityId == effectId then
            local stacks = tonumber(stackCount) or 0
            return stacks > 0 and stacks or nil
        end
    end

    return nil
end

local function FindTrackedStack(abilityId)
    local effectId = STACK_EFFECT_BY_ABILITY[abilityId]
    if not effectId and IsFatecarverAbility(abilityId) then
        effectId = CRUX_EFFECT_ID
    end
    if not effectId then return nil end

    -- Nightblade spectral-bow counters use the live player buff directly.
    -- This intentionally bypasses the ActionBar cache for display; the cache
    -- remains available for the existing tracking/glow machinery.
    local liveStack = GetLivePlayerStack(effectId, NIGHTBLADE_STACK_EFFECTS)
    if liveStack ~= nil then
        return liveStack
    end

    -- Necromancer Skull has the same cache problem: ESO reports the live
    -- stack correctly, but the normal ActionBar effect cache can remain nil.
    -- Read the authoritative player buff directly for Skull only.
    local liveSkullStack = GetLivePlayerStack(effectId, NECRO_SKULL_STACK_EFFECTS)
    if liveSkullStack ~= nil then
        return liveSkullStack
    end

    local entry = ActionBar.effectStacks[effectId]
    if not entry then return nil end
    local now = GetGameTimeSeconds()
    if entry.endTime and entry.endTime > 0 and entry.endTime <= now then
        ActionBar.effectStacks[effectId] = nil
        return nil
    end
    return entry.stack
end

---------------------------------------------------------------------
-- Optional standalone stack tracker
--
-- Each supported stack type is represented once. An entry is shown only when
-- one of its qualifying skills is present on either GrimSuite weapon bar.
-- This keeps the tracker useful for subclassing without duplicating the same
-- stack counter when a skill appears on both bars.
---------------------------------------------------------------------

local BOUND_ARMAMENTS_ABILITY_ID = 24165

-- Any ability matching one of these names is a Crux spender. The tracker
-- checks both weapon bars, so subclassing and support/tank Arcanist setups
-- are handled without hard-coding one particular role or rotation.
local CRUX_CONSUMING_ABILITY_NAMES = {
    "fatecarver",
    "tentacular dread",
    "remedy cascade",
    "cascading fortune",
    "curative surge",
    "tidal chakram",
    "runespite ward",
    "impervious runeward",
    "spiteward of the lucid mind",
    "unbreakable fate",
}

local function IsCruxConsumingAbility(abilityId)
    if not abilityId or abilityId <= 0 or not GetAbilityName then
        return false
    end

    local ok, name = pcall(GetAbilityName, abilityId)
    if not ok or not name then
        return false
    end

    name = zo_strlower(tostring(name))
    for _, cruxName in ipairs(CRUX_CONSUMING_ABILITY_NAMES) do
        if string.find(name, cruxName, 1, true) then
            return true
        end
    end

    return false
end

local BOW_STACK_ABILITIES = {
    [61902] = true, -- Grim Focus
    [61919] = true, -- Merciless Resolve
    [61927] = true, -- Relentless Focus
}

local function IsBowStackAbility(abilityId)
    return BOW_STACK_ABILITIES[abilityId] == true
end

local function GetTrackerSlottedAbility(kind)
    local categories = { HOTBAR_CATEGORY_PRIMARY, HOTBAR_CATEGORY_BACKUP }

    -- Prefer the currently active bar so the displayed icon matches the bar
    -- the player is currently using when a tracked skill exists there.
    local activeCategory = GetActiveHotbarCategory()
    if activeCategory == HOTBAR_CATEGORY_PRIMARY or activeCategory == HOTBAR_CATEGORY_BACKUP then
        categories = {
            activeCategory,
            activeCategory == HOTBAR_CATEGORY_PRIMARY
                and HOTBAR_CATEGORY_BACKUP or HOTBAR_CATEGORY_PRIMARY,
        }
    end

    for _, category in ipairs(categories) do
        for slot = MIN_SLOT, MAX_SLOT do
            local abilityId = GetAbilityForSlot(slot, category)
            if abilityId and abilityId > 0 then
                if kind == "BoundArmaments" and abilityId == BOUND_ARMAMENTS_ABILITY_ID then
                    return abilityId
                elseif kind == "Crux" and IsCruxConsumingAbility(abilityId) then
                    return abilityId
                elseif kind == "Bow" and IsBowStackAbility(abilityId) then
                    return abilityId
                end
            end
        end
    end

    return nil
end

local function GetStackTrackerCount(kind, abilityId)
    if kind == "BoundArmaments" then
        return math.max(0, tonumber(FindTrackedStack(BOUND_ARMAMENTS_ABILITY_ID)) or 0)
    elseif kind == "Crux" then
        return math.max(0, tonumber(GetCurrentCrux()) or 0)
    elseif kind == "Bow" then
        return math.max(0, tonumber(FindTrackedStack(abilityId)) or 0)
    end

    return 0
end

local STACK_TRACKER_DEFINITIONS = {
    {
        key = "BoundArmaments",
        name = "Bound Armaments",
        maxStacks = 4,
    },
    {
        key = "Crux",
        name = "Crux",
        maxStacks = 3,
    },
    {
        key = "Bow",
        name = "Grim Focus / Resolve",
        maxStacks = 5,
    },
}

local stackTrackerDragState = {
    dragging = false,
    key = nil,
    startMouseX = 0,
    startMouseY = 0,
    startX = 0,
    startY = 0,
}

local function GetStackTrackerVisibilityKey(kind)
    if kind == "BoundArmaments" then return "showBoundArmaments" end
    if kind == "Crux" then return "showCrux" end
    if kind == "Bow" then return "showBow" end
    return nil
end

local function GetStackTrackerPositionKeys(kind)
    if kind == "BoundArmaments" then return "boundArmamentsX", "boundArmamentsY" end
    if kind == "Crux" then return "cruxX", "cruxY" end
    if kind == "Bow" then return "bowX", "bowY" end
    return nil, nil
end

local function IsStackTrackerVisible(kind)
    local key = GetStackTrackerVisibilityKey(kind)
    if not key then return false end
    return ActionBar[key] == true
end

local function GetStackTrackerPosition(kind)
    local xKey, yKey = GetStackTrackerPositionKeys(kind)
    if not xKey then return 0, 250 end

    return tonumber(ActionBar[xKey]) or tonumber(STACK_TRACKER_DEFAULTS[xKey]) or 0,
        tonumber(ActionBar[yKey]) or tonumber(STACK_TRACKER_DEFAULTS[yKey]) or 250
end

local function SaveStackTrackerSetting(key, value)
    ActionBar[key] = value
    if stackTrackerSV then
        stackTrackerSV[key] = value
    end
end

local function SaveStackTrackerPosition(kind)
    if not stackTrackerSV then return end

    local xKey, yKey = GetStackTrackerPositionKeys(kind)
    if not xKey then return end

    stackTrackerSV[xKey] = tonumber(ActionBar[xKey]) or STACK_TRACKER_DEFAULTS[xKey]
    stackTrackerSV[yKey] = tonumber(ActionBar[yKey]) or STACK_TRACKER_DEFAULTS[yKey]
end

local function AnchorStackTrackerEntry(kind)
    local root = ActionBar.stackTrackerRoot
    local data = ActionBar.stackTrackerEntries[kind]
    if not root or not data or not data.frame then return end

    local x, y = GetStackTrackerPosition(kind)
    data.frame:ClearAnchors()
    data.frame:SetAnchor(CENTER, root, CENTER, x, y)
end

local function AnchorAllStackTrackerEntries()
    for _, definition in ipairs(STACK_TRACKER_DEFINITIONS) do
        AnchorStackTrackerEntry(definition.key)
    end
end

local function UpdateStackTrackerDragEnabled(enabled)
    enabled = enabled == true

    for _, data in pairs(ActionBar.stackTrackerEntries or {}) do
        data.frame:SetMouseEnabled(enabled)
    end
end

local function BeginStackTrackerDrag(kind)
    if not ActionBar.stackTrackerUnlocked then return end

    local data = ActionBar.stackTrackerEntries[kind]
    if not data or data.frame:IsHidden() then return end

    local x, y = GetUIMousePosition()
    if not x or not y then return end

    local startX, startY = GetStackTrackerPosition(kind)

    stackTrackerDragState.dragging = true
    stackTrackerDragState.key = kind
    stackTrackerDragState.startMouseX = x
    stackTrackerDragState.startMouseY = y
    stackTrackerDragState.startX = startX
    stackTrackerDragState.startY = startY

    EM:UnregisterForUpdate(GS.name .. "_AB_StackTrackerDrag")
    EM:RegisterForUpdate(GS.name .. "_AB_StackTrackerDrag", 16, function()
        if not stackTrackerDragState.dragging or not ActionBar.stackTrackerUnlocked then
            EM:UnregisterForUpdate(GS.name .. "_AB_StackTrackerDrag")
            return
        end

        local mouseX, mouseY = GetUIMousePosition()
        if not mouseX or not mouseY then return end

        local key = stackTrackerDragState.key
        if not key then
            EM:UnregisterForUpdate(GS.name .. "_AB_StackTrackerDrag")
            return
        end

        local xKey, yKey = GetStackTrackerPositionKeys(key)
        if not xKey then
            EM:UnregisterForUpdate(GS.name .. "_AB_StackTrackerDrag")
            return
        end

        ActionBar[xKey] = stackTrackerDragState.startX + (mouseX - stackTrackerDragState.startMouseX)
        ActionBar[yKey] = stackTrackerDragState.startY + (mouseY - stackTrackerDragState.startMouseY)

        AnchorStackTrackerEntry(key)
    end)
end

local function EndStackTrackerDrag(kind)
    if not stackTrackerDragState.dragging then return end
    if kind and stackTrackerDragState.key ~= kind then return end

    local key = stackTrackerDragState.key
    stackTrackerDragState.dragging = false
    stackTrackerDragState.key = nil
    EM:UnregisterForUpdate(GS.name .. "_AB_StackTrackerDrag")

    if key then
        SaveStackTrackerPosition(key)
    end
end

local function CreateStackTracker()
    if ActionBar.stackTrackerRoot then return end

    local root = WM:CreateTopLevelWindow("GrimSuiteAB_StackTracker")
    root:SetAnchorFill(GuiRoot)
    root:SetMovable(false)
    root:SetClampedToScreen(true)
    root:SetDrawTier(DT_LOW)
    root:SetMouseEnabled(false)

    ActionBar.stackTrackerRoot = root
    ActionBar.stackTrackerEntries = {}

    for _, definition in ipairs(STACK_TRACKER_DEFINITIONS) do
        local trackerKey = definition.key
        local frame = WM:CreateControl(
            "GrimSuiteAB_StackTracker_" .. definition.key .. "_Frame",
            root,
            CT_BACKDROP
        )
        frame:SetDimensions(GetStackTrackerIconSize(), GetStackTrackerIconSize())
        frame:SetCenterColor(0.008, 0.008, 0.008, 0.48)
        frame:SetEdgeColor(unpack(FRAME_EDGE))
        frame:SetEdgeTexture("EsoUI/Art/Tooltips/UI-Border.dds", 16, 16, 2, 0)
        frame:SetDrawLevel(20)
        frame:SetMouseEnabled(false)

        local icon = WM:CreateControl(
            "GrimSuiteAB_StackTracker_" .. definition.key .. "_Icon",
            frame,
            CT_TEXTURE
        )
        icon:SetAnchor(TOPLEFT, frame, TOPLEFT, STACK_TRACKER_FRAME_PADDING, STACK_TRACKER_FRAME_PADDING)
        icon:SetAnchor(BOTTOMRIGHT, frame, BOTTOMRIGHT, -STACK_TRACKER_FRAME_PADDING, -STACK_TRACKER_FRAME_PADDING)
        icon:SetDrawLevel(21)
        icon:SetMouseEnabled(false)

        local stack = WM:CreateControl(
            "GrimSuiteAB_StackTracker_" .. definition.key .. "_Stack",
            frame,
            CT_LABEL
        )
        stack:SetFont(GetStackTrackerFont())
        stack:SetAnchor(CENTER, frame, CENTER, 0, 0)
        stack:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        stack:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        stack:SetColor(unpack(STACK_COLOR))
        stack:SetDrawLevel(22)
        stack:SetText("")
        stack:SetMouseEnabled(false)

        frame:SetHandler("OnMouseDown", function(_, button)
            if button == MOUSE_BUTTON_INDEX_LEFT then
                BeginStackTrackerDrag(trackerKey)
            end
        end)

        frame:SetHandler("OnMouseUp", function(_, button)
            if button == MOUSE_BUTTON_INDEX_LEFT then
                EndStackTrackerDrag(trackerKey)
            end
        end)

        ActionBar.stackTrackerEntries[definition.key] = {
            definition = definition,
            frame = frame,
            icon = icon,
            stack = stack,
        }
    end

    AnchorAllStackTrackerEntries()
end

local function ApplyStackTrackerAppearance()
    local iconSize = GetStackTrackerIconSize()
    local textFont = GetStackTrackerFont()

    for _, definition in ipairs(STACK_TRACKER_DEFINITIONS) do
        local data = ActionBar.stackTrackerEntries[definition.key]
        if data then
            data.frame:SetDimensions(iconSize, iconSize)
            data.icon:ClearAnchors()
            data.icon:SetAnchor(TOPLEFT, data.frame, TOPLEFT, STACK_TRACKER_FRAME_PADDING, STACK_TRACKER_FRAME_PADDING)
            data.icon:SetAnchor(BOTTOMRIGHT, data.frame, BOTTOMRIGHT, -STACK_TRACKER_FRAME_PADDING, -STACK_TRACKER_FRAME_PADDING)
            data.stack:SetFont(textFont)
            data.stack:ClearAnchors()
            data.stack:SetAnchor(CENTER, data.frame, CENTER, 0, 0)
        end
    end

    AnchorAllStackTrackerEntries()
end

local function UpdateStackTracker()
    if not ActionBar.stackTrackerRoot then return end

    local count = 0
    local shouldShow = ActionBar.showStackTracker and ActionBar.stackTrackerHUDVisible

    for _, definition in ipairs(STACK_TRACKER_DEFINITIONS) do
        local data = ActionBar.stackTrackerEntries[definition.key]
        local abilityId = shouldShow and IsStackTrackerVisible(definition.key)
            and GetTrackerSlottedAbility(definition.key) or nil

        if data and abilityId then
            -- Crux is a shared resource, so its tracker icon stays fixed even
            -- when the qualifying Arcanist skill changes with a bar swap.
            local iconAbilityId = definition.key == "Crux" and CRUX_EFFECT_ID or abilityId
            data.icon:SetTexture(GetAbilityIcon(iconAbilityId))
            data.stack:SetFont(GetStackTrackerFont())
            data.stack:SetText(tostring(GetStackTrackerCount(definition.key, abilityId)))
            data.frame:SetHidden(false)
            count = count + 1
        elseif data then
            data.frame:SetHidden(true)
        end
    end

    ActionBar.stackTrackerRoot:SetHidden(count == 0 or not shouldShow)
    UpdateStackTrackerDragEnabled(ActionBar.stackTrackerUnlocked and count > 0)
end

local function ResetStackTrackerPositions()
    for _, definition in ipairs(STACK_TRACKER_DEFINITIONS) do
        local xKey, yKey = GetStackTrackerPositionKeys(definition.key)
        if xKey then
            ActionBar[xKey] = STACK_TRACKER_DEFAULTS[xKey]
            ActionBar[yKey] = STACK_TRACKER_DEFAULTS[yKey]
            SaveStackTrackerPosition(definition.key)
        end
    end

    AnchorAllStackTrackerEntries()
    UpdateStackTracker()
end

-- FAB treats Banner Bearer effects as one shared toggle state. Keep the
-- relevant effect IDs local so GrimSuite can reproduce that visible behavior
-- without importing FAB's full effect engine.
local BANNER_BEARER_EFFECTS = {
    [217699] = true, [227085] = true, [227600] = true, [230289] = true,
    [217704] = true, [217705] = true, [217706] = true,
    [227003] = true, [227004] = true, [227007] = true, [227008] = true,
    [227009] = true, [227029] = true, [227030] = true, [227066] = true,
    [227067] = true, [227069] = true, [227070] = true, [227071] = true,
    [227073] = true, [227082] = true, [227086] = true, [227087] = true,
    [227088] = true, [227089] = true, [227091] = true, [227092] = true,
    [227093] = true, [227094] = true, [227095] = true, [227096] = true,
    [227101] = true, [227102] = true, [227103] = true, [227104] = true,
    [227106] = true, [227107] = true, [227108] = true, [227109] = true,
    [227110] = true, [227111] = true, [227112] = true, [227113] = true,
    [227115] = true, [227116] = true, [227120] = true, [227123] = true,
    [230293] = true, [231753] = true,
}

local function ReconcileBannerState()
    local active = false
    local now = GetGameTimeSeconds()
    for i = 1, GetNumBuffs("player") do
        local _, _, endTime, _, _, _, _, _, _, _, abilityId = GetUnitBuffInfo("player", i)
        if abilityId and BANNER_BEARER_EFFECTS[abilityId] then
            if not endTime or endTime == 0 or endTime > now then
                active = true
                break
            end
        end
    end
    ActionBar.bannerActive = active
end

local function IsSlotToggleActive(slot, category)
    local ok, toggled = pcall(IsSlotToggled, slot, category)
    if ok and toggled then
        return true
    end

    local abilityId = GetAbilityForSlot(slot, category)
    return ActionBar.bannerActive and BANNER_BEARER_EFFECTS[abilityId] == true
end

-- Stack thresholds for abilities that become directly usable when their
-- tracked stacks are full. Keep this separate from STACK_EFFECT_BY_ABILITY
-- because many tracked stacks are informational and should NOT glow when full.
local READY_PROC_STACKS = {
    -- Bound Armaments: fire at 4 stacks
    [24165] = 4,
    -- Grim Focus / Merciless Resolve: spectral bow at 5 stacks
    [61902] = 5,
    [61919] = 5,
    -- Relentless Focus: spectral bow at 4 stacks
    [61927] = 4,
    -- Skull's empowered third cast is ready after two qualifying casts.
    [114108] = 2,
    [123683] = 2,
    [123685] = 2,
    [117637] = 2,
    [123718] = 2,
    [123719] = 2,
    [117624] = 2,
    [123699] = 2,
    [123704] = 2,
}

-- Some ESO action-slot timers are backed by a buff/effect associated with the
-- slotted skill rather than the skill's own visible duration. When another
-- source refreshes/re-associates that buff (for example Traveling Knife +
-- Force refreshing Minor Force while Barbed Trap is active), ESO can briefly
-- or permanently stop reporting the timer for the original slot. Keep the
-- last known expiration for that exact slot/ability as a fallback so a valid
-- timer is not erased just because the action-slot query stopped reporting it.
--
-- Boneyard is intentionally different: its action-slot effect can jump to a
-- longer buff duration when Nazaray extends the associated effect. GrimSuite's
-- Action Bar timer should represent the ground DoT itself, which is a hard 10s
-- window. Boneyard therefore gets its own cast-time expiration in the same
-- cache and ignores later buff extensions for that cast.
local SLOT_EFFECT_TIMER_CACHE = {}

local BONEYARD_DURATION = 10
local BONEYARD_ABILITIES = {
    -- Current Necromancer Boneyard morph IDs.
    [40117850] = true, -- Avid Boneyard
    [117805] = true,   -- Unnerving Boneyard
}

local function IsBoneyardAbility(abilityId)
    return BONEYARD_ABILITIES[abilityId] == true
end

local HAUNTING_CURSE_DURATION = 12
local HAUNTING_CURSE_ABILITIES = {
    [24324] = true,
    [24326] = true,
    [24330] = true,
}

local function IsHauntingCurseAbility(abilityId)
    return HAUNTING_CURSE_ABILITIES[abilityId] == true
end

local function StartBoneyardTimer(slot, category, abilityId)
    if not IsBoneyardAbility(abilityId) then return end

    local categoryCache = SLOT_EFFECT_TIMER_CACHE[category]
    if not categoryCache then
        categoryCache = {}
        SLOT_EFFECT_TIMER_CACHE[category] = categoryCache
    end

    categoryCache[slot] = {
        abilityId = abilityId,
        expiresAt = GetGameTimeSeconds() + BONEYARD_DURATION,
        fixedDuration = true,
    }
end

local function StartHauntingCurseTimer(slot, category, abilityId)
    if not IsHauntingCurseAbility(abilityId) then return end

    local categoryCache = SLOT_EFFECT_TIMER_CACHE[category]
    if not categoryCache then
        categoryCache = {}
        SLOT_EFFECT_TIMER_CACHE[category] = categoryCache
    end

    categoryCache[slot] = {
        abilityId = abilityId,
        expiresAt = GetGameTimeSeconds() + HAUNTING_CURSE_DURATION,
        fixedDuration = true,
    }
end

local function GetSlotEffectRemaining(slot, category)
    if not GetActionSlotEffectDuration or not GetActionSlotEffectTimeRemaining then
        return nil
    end

    local abilityId = GetAbilityForSlot(slot, category)
    if not abilityId or abilityId <= 0 then
        if SLOT_EFFECT_TIMER_CACHE[category] then
            SLOT_EFFECT_TIMER_CACHE[category][slot] = nil
        end
        return nil
    end

    local now = GetGameTimeSeconds()
    local categoryCache = SLOT_EFFECT_TIMER_CACHE[category]
    if not categoryCache then
        categoryCache = {}
        SLOT_EFFECT_TIMER_CACHE[category] = categoryCache
    end

    local cached = categoryCache[slot]

    -- Boneyard is tracked from the actual cast window and intentionally does
    -- not inherit later buff extensions such as Nazaray. The cast event below
    -- refreshes this exact 10s window whenever Boneyard is recast. Do this
    -- BEFORE consulting the action-slot effect API so an extended buff can
    -- never replace the hard 10s ground-effect timer.
    if IsBoneyardAbility(abilityId) then
        if cached
            and cached.abilityId == abilityId
            and cached.fixedDuration
            and cached.expiresAt > now
        then
            return cached.expiresAt - now
        end

        categoryCache[slot] = nil
        return nil
    end

    -- Haunting Curse is a two-hit mechanic with a 12-second full lifecycle.
    -- Track that full player-useful window directly instead of allowing the
    -- generic action-slot effect API to swap to an intermediate effect between
    -- the first and second explosions.
    if IsHauntingCurseAbility(abilityId) then
        if cached
            and cached.abilityId == abilityId
            and cached.fixedDuration
            and cached.expiresAt > now
        then
            return cached.expiresAt - now
        end

        categoryCache[slot] = nil
        return nil
    end

    local okDuration, durationMs = pcall(GetActionSlotEffectDuration, slot, category)
    local okRemain, remainMs = pcall(GetActionSlotEffectTimeRemaining, slot, category)

    durationMs = tonumber(durationMs) or 0
    remainMs = tonumber(remainMs) or 0

    if okDuration and okRemain and durationMs > 0 and remainMs > 0 then
        local duration = durationMs / 1000
        local remain = remainMs / 1000
        if remain <= math.max(duration, 0.1) + 0.25 then
            categoryCache[slot] = {
                abilityId = abilityId,
                expiresAt = now + remain,
            }
            return remain
        end
    end

    -- If ESO stopped reporting the effect but the same ability is still in the
    -- slot and our last confirmed timer has not expired, continue counting down
    -- from that previously observed expiration. A fresh ESO value always wins
    -- and refreshes the cache above for normal skill timers.

    if cached
        and cached.abilityId == abilityId
        and cached.expiresAt > now
    then
        return cached.expiresAt - now
    end

    categoryCache[slot] = nil
    return nil
end

IsTentacularDreadAbility = function(abilityId)
    -- Known current Tentacular Dread ability ID.
    if abilityId == 185823 then
        return true
    end

    if not abilityId or abilityId <= 0 or not GetAbilityName then
        return false
    end

    local ok, name = pcall(GetAbilityName, abilityId)
    if not ok or not name then
        return false
    end

    name = zo_strlower(tostring(name))
    return string.find(name, "tentacular dread", 1, true) ~= nil
end

local function IsCrystalFragmentsAbility(abilityId)
    return abilityId == CRYSTAL_FRAGMENTS_ABILITY_ID
end

local function ReadCrystalFragmentsProcState()
    for i = 1, GetNumBuffs("player") do
        local _, _, _, _, _, _, _, _, _, _, buffAbilityId = GetUnitBuffInfo("player", i)
        if buffAbilityId == CRYSTAL_FRAGMENTS_EFFECT_ID then
            return true
        end
    end
    return false
end

-- Forward declaration: Crystal Fragments glow refresh is defined before
-- the shared glow renderer itself.
local UpdateSlotGlow

local function UpdateCrystalFragmentsGlowForBar(controls, category)
    if not controls then return end

    for slot = MIN_SLOT, MAX_SLOT do
        local data = controls[slot]
        if data and data.glow then
            local abilityId = GetAbilityForSlot(slot, category)
            if IsCrystalFragmentsAbility(abilityId) then
                -- Crystal Fragments' proc is a shared player state. Refresh
                -- both weapon bars immediately instead of waiting for a swap.
                UpdateSlotGlow(data, slot, category, false, false)
            end
        end
    end
end

GetCurrentCrux = function()
    local liveStack = GetLivePlayerStack(CRUX_EFFECT_ID, CRUX_STACK_EFFECTS)
    if liveStack ~= nil then
        return liveStack
    end

    local entry = ActionBar.effectStacks[CRUX_EFFECT_ID]
    if not entry then return 0 end

    local now = GetGameTimeSeconds()
    if entry.endTime and entry.endTime > 0 and entry.endTime <= now then
        ActionBar.effectStacks[CRUX_EFFECT_ID] = nil
        return 0
    end

    return tonumber(entry.stack) or 0
end

local function IsStackProcReady(abilityId)
    -- Tentacular Dread becomes a GrimSuite ready-state glow at 3 Crux.
    -- Crux remains an informational shared resource and is not displayed as
    -- a stack counter on the Tentacular Dread icon.
    if IsTentacularDreadAbility(abilityId) then
        return GetCurrentCrux() >= 3
    end

    -- Crystal Fragments becomes ready when its hidden proc/passive effect is
    -- active. This is a state-based proc, not a stack counter.
    if IsCrystalFragmentsAbility(abilityId) then
        return ActionBar.crystalFragmentsReady == true
    end

    -- Fatecarver becomes ready to cast at 3 Crux. Crux is a shared resource,
    -- so it is handled separately from the normal per-ability stack map.
    if IsFatecarverAbility(abilityId) then
        local stacks = FindTrackedStack(abilityId)
        return stacks ~= nil and stacks >= 3
    end

    local required = READY_PROC_STACKS[abilityId]
    if not required then return false end
    local stacks = FindTrackedStack(abilityId)
    return stacks ~= nil and stacks >= required
end

-- Simmering Frenzy (often referred to as "Shimmering Frenzy") is a toggle
-- whose active state should remain visible on the custom action bar even when
-- the weapon bar containing it is inactive.  The other toggle glows remain
-- active-bar-only so we do not change their existing behavior.
local function IsSimmeringFrenzyAbility(abilityId)
    if not abilityId or abilityId <= 0 or not GetAbilityName then
        return false
    end

    local ok, name = pcall(GetAbilityName, abilityId)
    if not ok or not name then
        return false
    end

    name = zo_strlower(tostring(name))
    return string.find(name, "simmering frenzy", 1, true) ~= nil
        or string.find(name, "shimmering frenzy", 1, true) ~= nil
end

UpdateSlotGlow = function(data, slot, category, active, ultimateReady)
    if not data or not data.glow then return end
    local abilityId = GetAbilityForSlot(slot, category)
    local procReady = abilityId > 0 and IsStackProcReady(abilityId)
    local persistentToggle = abilityId > 0
        and IsSimmeringFrenzyAbility(abilityId)
        and IsSlotToggleActive(slot, category)
    local shouldGlow = (active and IsSlotToggleActive(slot, category))
        or persistentToggle
        or ultimateReady
        or procReady

    data.glow:SetHidden(not shouldGlow)
    if data.outerGlow then
        data.outerGlow:SetHidden(not shouldGlow)
    end
    if shouldGlow then
        data.glow:SetAlpha(ultimateReady and 1.0 or 0.95)
        if data.outerGlow then
            data.outerGlow:SetAlpha(ultimateReady and 0.75 or 0.58)
        end
    end
end

local function UpdateTentacularDreadGlowForBar(controls, category)
    if not controls then return end

    for slot = MIN_SLOT, MAX_SLOT do
        local data = controls[slot]
        if data and data.glow then
            local abilityId = GetAbilityForSlot(slot, category)
            if IsTentacularDreadAbility(abilityId) then
                -- Crux is shared between weapon bars. Refresh Tentacular Dread
                -- on inactive bars too, so the ready glow appears immediately
                -- when the third Crux is gained instead of waiting for a bar swap.
                UpdateSlotGlow(data, slot, category, false, false)
            end
        end
    end
end

local function UpdateFatecarverGlowForBar(controls, category)
    if not controls then return end

    for slot = MIN_SLOT, MAX_SLOT do
        local data = controls[slot]
        if data and data.glow then
            local abilityId = GetAbilityForSlot(slot, category)
            if IsFatecarverAbility(abilityId) then
                -- Unlike normal toggle/proc glows, this must also be refreshed
                -- while the weapon bar is inactive so the Beam is visibly ready
                -- on either bar as soon as 3 Crux are available.
                UpdateSlotGlow(data, slot, category, false, false)
            end
        end
    end
end

local function FlashPressed(data)
    if not data or not data.pressed then return end

    data.pressed:SetHidden(false)
    data.pressed:SetAlpha(1.0)

    if data.pressedTimer then
        data.pressedTimer = data.pressedTimer + 1
    else
        data.pressedTimer = 1
    end

    local token = data.pressedTimer
    zo_callLater(function()
        if data.pressed and data.pressedTimer == token then
            data.pressed:SetHidden(true)
        end
    end, 110)
end

local function GetUltimateState(slot, category)
    local okPower, power = pcall(GetUnitPower, "player", COMBAT_MECHANIC_FLAGS_ULTIMATE)
    if not okPower then return nil end

    local okCost, slotCost = pcall(GetSlotAbilityCost, slot, COMBAT_MECHANIC_FLAGS_ULTIMATE, category)
    if not okCost then return nil end

    local current = math.floor(tonumber(power) or 0)
    local cost = math.floor(tonumber(slotCost) or 0)
    return current, cost, cost > 0 and current >= cost
end

local function UpdateUltimateDisplay(data, slot, category, active)
    if not data or not data.ultValue then return end
    data.ultValue:SetText("")
    if not active then return end

    local current, cost, ready = GetUltimateState(slot, category)
    if not current or not cost or cost <= 0 then return end

    if ready then
        data.ultValue:SetText(tostring(current))
        data.ultValue:SetColor(1.0, 0.86, 0.25, 1.0)
    else
        data.ultValue:SetText(string.format("%d/%d", current, cost))
        data.ultValue:SetColor(unpack(ULT_COLOR))
    end
end

local function UpdateSlotEffectDisplay(data, slot, category, active)
    ClearEffectDisplay(data)
    if not data then return end

    local abilityId = GetAbilityForSlot(slot, category)
    if abilityId <= 0 then return end

    -- Stack/proc abilities use their stack counter instead of an effect timer.
    -- Fatecarver is the one special case for the shared Crux effect.
    -- Showing the action-slot effect duration here makes instant abilities such
    -- as Bound Armaments / Skull procs visually fight with the stack number.
    local suppressTimer = STACK_EFFECT_BY_ABILITY[abilityId] ~= nil or IsFatecarverAbility(abilityId)

    -- ESO exposes the exact action-slot effect duration and remaining time.
    -- This is the compact equivalent of the useful part of FAB's timer path.
    if not suppressTimer then
        local remain = GetSlotEffectRemaining(slot, category)
        if remain then
            if remain <= 5 then
                data.timer:SetText(string.format("%.1f", remain))
            else
                data.timer:SetText(string.format("%d", math.ceil(remain)))
            end
            data.timer:SetColor(unpack(TIMER_COLOR))
        end
    end

    if ActionBar.showStackCount and not IsNecroSkullAbility(abilityId) then
        local stacks = FindTrackedStack(abilityId)
        if stacks and stacks > 0 then
            data.stack:SetText(tostring(stacks))
            data.stack:SetColor(unpack(STACK_COLOR))
        end
    end
end

-- Ultimate timers are special: GrimSuite only renders one ultimate slot,
-- but an active ultimate effect can have been cast from either weapon bar.
-- Prefer the current bar's ultimate timer; if it has none, fall back to the
-- other bar so an active back-bar ultimate (e.g. Goliath) remains visible
-- after swapping to the front bar. This matches FAB+'s intended behavior.
local function UpdateUltimateTimerDisplay()
    local activeCategory = GetActiveHotbarCategory()
    local activeData = nil
    local activeTimer = nil

    if activeCategory == HOTBAR_CATEGORY_PRIMARY then
        activeData = ActionBar.frontControls[ULT_SLOT]
        activeTimer = ActionBar.backbarControls[ULT_SLOT]
    elseif activeCategory == HOTBAR_CATEGORY_BACKUP then
        activeData = ActionBar.backbarControls[ULT_SLOT]
        activeTimer = ActionBar.frontControls[ULT_SLOT]
    else
        return
    end

    if not activeData or not activeData.timer then return end

    activeData.timer:SetText("")
    if activeTimer and activeTimer.timer then
        activeTimer.timer:SetText("")
    end

    -- Prefer an active effect on the currently selected ultimate. If there
    -- isn't one, show the still-active ultimate from the other weapon bar.
    local remain = GetSlotEffectRemaining(ULT_SLOT, activeCategory)
    if not remain then
        local otherCategory = activeCategory == HOTBAR_CATEGORY_PRIMARY
            and HOTBAR_CATEGORY_BACKUP or HOTBAR_CATEGORY_PRIMARY
        remain = GetSlotEffectRemaining(ULT_SLOT, otherCategory)
    end

    if remain then
        if remain <= 5 then
            activeData.timer:SetText(string.format("%.1f", remain))
        else
            activeData.timer:SetText(string.format("%d", math.ceil(remain)))
        end
        activeData.timer:SetColor(unpack(TIMER_COLOR))
    end
end

local function UpdateEffectDisplays()
    if not ActionBar.initialized then return end

    for _, category in ipairs(HOTBAR_CATEGORIES) do
        local controls = category == HOTBAR_CATEGORY_PRIMARY
            and ActionBar.frontControls or ActionBar.backbarControls
        for slot = MIN_SLOT, MAX_SLOT do
            UpdateSlotEffectDisplay(controls[slot], slot, category, false)
        end

        local ult = controls[ULT_SLOT]
        if ult and ult.timer then
            ult.timer:SetText("")
        end
    end

    -- Ultimate is a shared visual slot in GrimSuite. Its timer may come from
    -- either weapon bar, so render it only after checking both categories.
    UpdateUltimateTimerDisplay()
    UpdateStackTracker()
end

local function UpdateActiveBarGlows()
    local activeCategory = GetActiveHotbarCategory()
    if activeCategory ~= HOTBAR_CATEGORY_PRIMARY and activeCategory ~= HOTBAR_CATEGORY_BACKUP then
        return
    end

    local controls = activeCategory == HOTBAR_CATEGORY_PRIMARY
        and ActionBar.frontControls or ActionBar.backbarControls
    local _, _, ultimateReady = GetUltimateState(ULT_SLOT, activeCategory)
    ultimateReady = ultimateReady == true

    for slot = MIN_SLOT, ULT_SLOT do
        local data = controls[slot]
        if data then
            if slot == ULT_SLOT then
                UpdateUltimateDisplay(data, ULT_SLOT, activeCategory, true)
            end
            UpdateSlotGlow(data, slot, activeCategory, true, slot == ULT_SLOT and ultimateReady)
        end
    end

    -- Crux is shared between bars. Keep both Crux-driven ready states
    -- synchronized on inactive bars as well.
    UpdateTentacularDreadGlowForBar(ActionBar.frontControls, HOTBAR_CATEGORY_PRIMARY)
    UpdateTentacularDreadGlowForBar(ActionBar.backbarControls, HOTBAR_CATEGORY_BACKUP)
    UpdateCrystalFragmentsGlowForBar(ActionBar.frontControls, HOTBAR_CATEGORY_PRIMARY)
    UpdateCrystalFragmentsGlowForBar(ActionBar.backbarControls, HOTBAR_CATEGORY_BACKUP)
    UpdateFatecarverGlowForBar(ActionBar.frontControls, HOTBAR_CATEGORY_PRIMARY)
    UpdateFatecarverGlowForBar(ActionBar.backbarControls, HOTBAR_CATEGORY_BACKUP)

    -- Simmering/Shimmering Frenzy is a persistent toggle: keep its glow
    -- synchronized even when the row containing it is inactive.
    for _, entry in ipairs({
        { controls = ActionBar.frontControls, category = HOTBAR_CATEGORY_PRIMARY },
        { controls = ActionBar.backbarControls, category = HOTBAR_CATEGORY_BACKUP },
    }) do
        for slot = MIN_SLOT, MAX_SLOT do
            local data = entry.controls[slot]
            if data and data.glow then
                local abilityId = GetAbilityForSlot(slot, entry.category)
                if IsSimmeringFrenzyAbility(abilityId) then
                    UpdateSlotGlow(data, slot, entry.category, false, false)
                end
            end
        end
    end
end

local function TrackPlayerEffect(eventCode, change, effectSlot, effectName, unitTag, beginTime, endTime, stackCount, iconName, buffType, effectType, abilityType, statusEffectType, unitName, unitId, abilityId, sourceType)
    if unitTag ~= "player" then return end
    if not abilityId or abilityId <= 0 then return end

    -- Crystal Fragments proc is a player-wide state. Track the hidden proc
    -- directly and immediately refresh both bars.
    if abilityId == CRYSTAL_FRAGMENTS_EFFECT_ID then
        local active = change ~= EFFECT_RESULT_FADED
            and (not endTime or endTime == 0 or endTime > GetGameTimeSeconds())
        ActionBar.crystalFragmentsReady = active
        UpdateCrystalFragmentsGlowForBar(ActionBar.frontControls, HOTBAR_CATEGORY_PRIMARY)
        UpdateCrystalFragmentsGlowForBar(ActionBar.backbarControls, HOTBAR_CATEGORY_BACKUP)
        return
    end

    -- Crux is a shared player effect. Track it directly by its effect ID,
    -- rather than requiring Crux itself to be the slotted ability.
    if abilityId == CRUX_EFFECT_ID then
        local now = GetGameTimeSeconds()
        if change == EFFECT_RESULT_FADED or (endTime and endTime > 0 and endTime <= now) then
            ActionBar.effectStacks[CRUX_EFFECT_ID] = nil
            return
        end

        local stacks = tonumber(stackCount) or 0
        if stacks > 0 then
            ActionBar.effectStacks[CRUX_EFFECT_ID] = {
                stack = stacks,
                beginTime = beginTime or now,
                endTime = endTime or 0,
            }
        elseif change == EFFECT_RESULT_UPDATED or change == EFFECT_RESULT_GAINED then
            ActionBar.effectStacks[CRUX_EFFECT_ID] = nil
        end
        return
    end

    local matched = false
    local trackedEffectId = nil
    for _, category in ipairs(HOTBAR_CATEGORIES) do
        for slot = MIN_SLOT, ULT_SLOT do
            local slottedAbility = GetAbilityForSlot(slot, category)
            if slottedAbility > 0 then
                local effectId = STACK_EFFECT_BY_ABILITY[slottedAbility] or slottedAbility
                if abilityId == slottedAbility or abilityId == effectId then
                    matched = true
                    trackedEffectId = effectId
                    break
                end
            end
        end
        if matched then break end
    end
    if not matched then return end

    local now = GetGameTimeSeconds()
    if change == EFFECT_RESULT_FADED or (endTime and endTime > 0 and endTime <= now) then
        ActionBar.effectStacks[trackedEffectId or abilityId] = nil
        return
    end

    local stacks = tonumber(stackCount) or 0
    if stacks > 0 then
        ActionBar.effectStacks[trackedEffectId or abilityId] = {
            stack = stacks,
            beginTime = beginTime or now,
            endTime = endTime or 0,
        }
    elseif change == EFFECT_RESULT_UPDATED or change == EFFECT_RESULT_GAINED then
        -- Keep the entry alive for non-stackable effects; the timer path is
        -- independent. A zero stack count means simply don't draw a counter.
        ActionBar.effectStacks[trackedEffectId or abilityId] = nil
    end

    UpdateStackTracker()
end

local function ReconcilePlayerStacks()
    if not ActionBar.initialized then return end
    local now = GetGameTimeSeconds()
    local seen = {}
    for i = 1, GetNumBuffs("player") do
        local _, beginTime, endTime, _, stackCount, _, _, _, _, _, buffAbilityId = GetUnitBuffInfo("player", i)
        if buffAbilityId == CRUX_EFFECT_ID and stackCount and stackCount > 0 then
            seen[CRUX_EFFECT_ID] = true
            ActionBar.effectStacks[CRUX_EFFECT_ID] = { stack = tonumber(stackCount) or 0, beginTime = beginTime or now, endTime = endTime or 0 }
        elseif buffAbilityId and buffAbilityId > 0 and stackCount and stackCount > 0 then
            for _, category in ipairs(HOTBAR_CATEGORIES) do
                for slot = MIN_SLOT, ULT_SLOT do
                    local slottedAbility = GetAbilityForSlot(slot, category)
                    if slottedAbility > 0 then
                        local mappedEffect = STACK_EFFECT_BY_ABILITY[slottedAbility]
                        if buffAbilityId == slottedAbility or buffAbilityId == mappedEffect then
                            local effectId = mappedEffect or slottedAbility
                            seen[effectId] = true
                            ActionBar.effectStacks[effectId] = { stack = tonumber(stackCount) or 0, beginTime = beginTime or now, endTime = endTime or 0 }
                        end
                    end
                end
            end
        end
    end
    for effectId in pairs(ActionBar.effectStacks) do
        if not seen[effectId] then ActionBar.effectStacks[effectId] = nil end
    end
end

function ActionBar:UpdateRow(controls, category, active)
    for i = MIN_SLOT, MAX_SLOT do
        local data = controls[i]
        local id = GetAbilityForSlot(i, category)
        if id > 0 then
            data.icon:SetTexture(GetAbilityIcon(id))
        end

        -- FAB's important swap-time step is syncActionButton(), which calls
        -- HandleSlotChanged() on the native ESO button BEFORE it reads/uses
        -- the button state. That is what makes ESO rebuild the button's state
        -- for the newly active hotbar. We need the same step here.
        local usable = nil
        if active then
            local button = GetButton(i, category)
            if button then
                if button.HandleSlotChanged then
                    button:HandleSlotChanged(category)
                end
                usable = button.usable
            end
        end

        StyleDisplay(data, active, id > 0, usable)
        UpdateSlotGlow(data, i, category, active, false)
    end

    local ult = controls[ULT_SLOT]
    local ultId = GetAbilityForSlot(ULT_SLOT, category)
    if ultId > 0 then
        ult.icon:SetTexture(GetAbilityIcon(ultId))
    end

    local ultUsable = nil
    if active then
        local button = GetButton(ULT_SLOT, category)
        if button then
            if button.HandleSlotChanged then
                button:HandleSlotChanged(category)
            end
            ultUsable = button.usable
        end
    end
    StyleDisplay(ult, active, ultId > 0, ultUsable)

    -- Main rows remain visible in both weapon-bar states, but only the
    -- currently active bar's ultimate icon should be visible.
    ult.frame:SetHidden(not (ActionBar.showFrames and ActionBar.showUltimate and active and ultId > 0))

    UpdateUltimateDisplay(ult, ULT_SLOT, category, active)
    local ultimateReady = false
    if active then
        local _, _, ready = GetUltimateState(ULT_SLOT, category)
        ultimateReady = ready == true
    end
    UpdateSlotGlow(ult, ULT_SLOT, category, active, ultimateReady)
end

local function SetDragEnabled(enabled)
    if not ActionBar.frontRoot or not ActionBar.backbarRoot then return end

    ActionBar.frontRoot:SetMouseEnabled(enabled)
    ActionBar.backbarRoot:SetMouseEnabled(enabled)
    ActionBar.frontRoot:SetMovable(false)
    ActionBar.backbarRoot:SetMovable(false)

    for _, controls in ipairs({ ActionBar.frontControls, ActionBar.backbarControls }) do
        local ult = controls[ULT_SLOT]
        if ult and ult.frame then
            -- The row roots receive mouse input even when the pointer is over
            -- a child display control.  Keep the children themselves passive.
            ult.frame:SetMouseEnabled(false)
        end
    end
end

local function SavePosition()
    if not positionSV then return end
    positionSV.positionX = tonumber(ActionBar.positionX) or 0
    positionSV.positionY = tonumber(ActionBar.positionY) or 0
end

local function BeginActionBarDrag()
    if not ActionBar.positionUnlocked then return end
    local x, y = GetUIMousePosition()
    if not x or not y then return end

    dragState.dragging = true
    dragState.startMouseX = x
    dragState.startMouseY = y
    dragState.startX = tonumber(ActionBar.positionX) or 0
    dragState.startY = tonumber(ActionBar.positionY) or 0
end

local function EndActionBarDrag()
    if not dragState.dragging then return end
    dragState.dragging = false
    SavePosition()
end

local function UpdateActionBarDrag()
    if not dragState.dragging or not ActionBar.positionUnlocked then return end

    local x, y = GetUIMousePosition()
    if not x or not y then return end

    ActionBar.positionX = dragState.startX + (x - dragState.startMouseX)
    ActionBar.positionY = dragState.startY + (y - dragState.startMouseY)
    ActionBar:AnchorRows()
end

InstallDragHandlers = function()
    if not ActionBar.frontRoot or not ActionBar.backbarRoot then return end

    local function bind(root)
        root:SetHandler("OnMouseDown", function(_, button)
            if button == MOUSE_BUTTON_INDEX_LEFT then
                BeginActionBarDrag()
            end
        end)

        root:SetHandler("OnMouseUp", function(_, button)
            if button == MOUSE_BUTTON_INDEX_LEFT then
                EndActionBarDrag()
            end
        end)
    end

    bind(ActionBar.frontRoot)
    bind(ActionBar.backbarRoot)

    EM:UnregisterForUpdate(GS.name .. "_AB_Drag")
    EM:RegisterForUpdate(GS.name .. "_AB_Drag", 16, UpdateActionBarDrag)
end

local function LayoutDisplayButton(data, parent, x, size)
    if not data or not data.frame then return end

    data.frame:SetDimensions(size, size)
    data.frame:ClearAnchors()
    data.frame:SetAnchor(TOPLEFT, parent, TOPLEFT, x, 0)

    data.icon:ClearAnchors()
    data.icon:SetAnchor(TOPLEFT, data.frame, TOPLEFT, 2, 2)
    data.icon:SetAnchor(BOTTOMRIGHT, data.frame, BOTTOMRIGHT, -2, -2)

    data.pressed:ClearAnchors()
    data.pressed:SetAnchor(TOPLEFT, data.frame, TOPLEFT, 2, 2)
    data.pressed:SetAnchor(BOTTOMRIGHT, data.frame, BOTTOMRIGHT, -2, -2)
end

local function LayoutUtilityButton(data, parent, x, size)
    if not data or not data.frame or not parent then return end

    data.frame:SetDimensions(size, size)
    data.frame:ClearAnchors()
    data.frame:SetAnchor(TOPLEFT, parent, TOPLEFT, x, 0)

    if data.icon then
        data.icon:ClearAnchors()
        data.icon:SetAnchor(TOPLEFT, data.frame, TOPLEFT, 2, 2)
        data.icon:SetAnchor(BOTTOMRIGHT, data.frame, BOTTOMRIGHT, -2, -2)
    end

    if data.pressed then
        data.pressed:ClearAnchors()
        data.pressed:SetAnchor(TOPLEFT, data.frame, TOPLEFT, 2, 2)
        data.pressed:SetAnchor(BOTTOMRIGHT, data.frame, BOTTOMRIGHT, -2, -2)
    end

    if data.count and data.count:GetName() == "GrimSuiteAB_PotionCount" then
        data.count:ClearAnchors()
        data.count:SetAnchor(TOP, data.frame, BOTTOM, 0, 0)
        data.count:SetDimensions(size, 30)
        data.count:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        data.count:SetVerticalAlignment(TEXT_ALIGN_TOP)
    end
end

local function ApplyGABCustomization()
    if not ActionBar.initialized then return end

    local size = GetIconSize()
    local gap = GetSlotGap()
    local rowWidth = GetRowWidth()
    local totalWidth = GetTotalWidth()

    local roots = { ActionBar.frontRoot, ActionBar.backbarRoot }
    for _, root in ipairs(roots) do
        if root then
            root:SetDimensions(totalWidth, size)
            root:SetScale(1)
        end
    end

    local function resizeControls(controls)
        for i = MIN_SLOT, MAX_SLOT do
            local data = controls[i]
            if data and data.frame then
                local x = (i - MIN_SLOT) * (size + gap)
                LayoutDisplayButton(data, data.frame:GetParent(), x, size)
            end
        end

        local ult = controls[ULT_SLOT]
        if ult and ult.frame then
            LayoutDisplayButton(ult, ult.frame:GetParent(), rowWidth + ULT_GAP, size)
        end
    end

    resizeControls(ActionBar.frontControls)
    resizeControls(ActionBar.backbarControls)

    local potionSize = GetPotionSize()
    if ActionBar.utilityRoot then
        ActionBar.utilityRoot:SetDimensions(
            potionSize + UTILITY_GAP + SLOT_SIZE + UTILITY_BAR_INDICATOR_GAP + UTILITY_BAR_INDICATOR_WIDTH,
            potionSize
        )
    end
    if ActionBar.utilityPotion and ActionBar.utilityPotion.frame then
        LayoutUtilityButton(ActionBar.utilityPotion, ActionBar.utilityRoot, 0, potionSize)
    end
    if ActionBar.utilityWeaponSwap and ActionBar.utilityWeaponSwap.frame and ActionBar.utilityRoot then
        ActionBar.utilityWeaponSwap.frame:ClearAnchors()
        ActionBar.utilityWeaponSwap.frame:SetAnchor(
            TOPLEFT,
            ActionBar.utilityRoot,
            TOPLEFT,
            potionSize + UTILITY_GAP,
            math.max(0, (potionSize - SLOT_SIZE) * 0.5)
        )
    end

    ApplyOverlayTextStyles()
    ActionBar:AnchorRows()

    local weaponSwap, potion = GetNativeActionBarControls()
    if weaponSwap then weaponSwap:SetScale(1) end
    if potion then potion:SetScale(potionSize / SLOT_SIZE) end

    ActionBar:Refresh()
end

local function CenterOnThirdSlot()
    local actionBar = GetControl("ZO_ActionBar1")
    local weaponSwap = actionBar and actionBar:GetNamedChild("WeaponSwap")
    if not weaponSwap then return end

    -- The actual ESO "third skill slot" in the displayed five-skill bar
    -- is hotbar slot 5 (slots 3, 4, 5, 6, 7).
    -- Center the midpoint of displayed slot 5 on the exact horizontal
    -- midpoint of the screen.
    CaptureNativeLayoutBase()

    local screenCenterX = GuiRoot:GetWidth() * 0.5
    local displayedSlot3Index = 3
    local slot5CenterOffset = ((displayedSlot3Index - 1) * (GetIconSize() + GetSlotGap())) + (GetIconSize() * 0.5)
    local desiredRootLeft = screenCenterX - slot5CenterOffset
    local referenceRight = nativeLayoutBase.weaponSwapRight or weaponSwap:GetRight()

    -- The displayed rows start UTILITY_ACTIONBAR_TIGHTEN pixels left of
    -- the native weapon-swap reference. Include that offset when converting
    -- the desired third-slot center into the shared native-layout position.
    -- This keeps the center of skill slot 3 exactly on screen center.
    ActionBar.positionX = desiredRootLeft - referenceRight + UTILITY_ACTIONBAR_TIGHTEN
    SavePosition()
    ActionBar:AnchorRows()
end

local function ResetPosition()
    ActionBar.positionX = 0
    ActionBar.positionY = 0
    SavePosition()
    ActionBar:AnchorRows()
end

local GAB_SETTING_KEYS = {
    "iconSize", "potionSize", "slotGap", "rowGap",
    "backbarOpacity", "backbarDesaturation",
    "showUltimate", "showQuickslot", "showWeaponSwap",
    "timerSize", "stackSize", "timerFont", "stackFont",
    "timerOutline", "stackOutline",
    "timerOffsetX", "timerOffsetY", "stackOffsetX", "stackOffsetY",
}

local function SaveGABSetting(key, value)
    ActionBar[key] = value
    if positionSV then
        positionSV[key] = value
    end
end

local function ResetGABCustomization()
    for _, key in ipairs(GAB_SETTING_KEYS) do
        SaveGABSetting(key, POSITION_DEFAULTS[key])
    end
    ApplyGABCustomization()
end

local function RegisterLibAddonMenu()
    LAM = LibAddonMenu2

    -- Saved vars are normally initialized during ActionBar:Initialize(), so
    -- position persistence does not depend on LibAddonMenu's load order.
    if not positionSV then
        positionSV = ZO_SavedVars:NewAccountWide(POSITION_SV_NAME, POSITION_SV_VERSION, nil, POSITION_DEFAULTS)
    end

    local panelName = GS.name .. "_ActionBar_Settings"
    local panelData = {
        type = "panel",
        name = "GrimSuite Action Bar",
        displayName = "GrimSuite Action Bar",
        author = "@GrimGrin94",
        version = GS.version,
        registerForRefresh = true,
        registerForDefaults = true,
    }

    local options = {
        {
            type = "description",
            text = "Position and movement controls for the GrimSuite action bar.",
        },
        {
            type = "header",
            name = "GAB Customization",
        },
        {
            type = "slider",
            name = "Icon Size",
            tooltip = "Changes the size of the skill, ultimate, and backbar icons.",
            min = 40, max = 100, step = 1,
            getFunc = function() return GetIconSize() end,
            setFunc = function(value)
                SaveGABSetting("iconSize", tonumber(value) or POSITION_DEFAULTS.iconSize)
                ApplyGABCustomization()
            end,
            default = POSITION_DEFAULTS.iconSize,
        },
        {
            type = "slider",
            name = "Potion Size",
            tooltip = "Changes the size of the GrimSuite potion icon independently from the action-bar skill icons.",
            min = 40, max = 100, step = 1,
            getFunc = function() return GetPotionSize() end,
            setFunc = function(value)
                SaveGABSetting("potionSize", tonumber(value) or POSITION_DEFAULTS.potionSize)
                ApplyGABCustomization()
            end,
            default = POSITION_DEFAULTS.potionSize,
        },
        {
            type = "slider",
            name = "Icon Spacing",
            tooltip = "Horizontal spacing between skill icons.",
            min = 0, max = 20, step = 1,
            getFunc = function() return GetSlotGap() end,
            setFunc = function(value)
                SaveGABSetting("slotGap", tonumber(value) or POSITION_DEFAULTS.slotGap)
                ApplyGABCustomization()
            end,
            default = POSITION_DEFAULTS.slotGap,
        },
        {
            type = "slider",
            name = "Bar Spacing",
            tooltip = "Vertical spacing between the front and back bars.",
            min = 0, max = 20, step = 1,
            getFunc = function() return GetRowGap() end,
            setFunc = function(value)
                SaveGABSetting("rowGap", tonumber(value) or POSITION_DEFAULTS.rowGap)
                ApplyGABCustomization()
            end,
            default = POSITION_DEFAULTS.rowGap,
        },
        {
            type = "slider",
            name = "Backbar Opacity",
            tooltip = "Controls the opacity of icons on the inactive backbar.",
            min = 0, max = 1, step = 0.05,
            getFunc = function() return GetBackbarOpacity() end,
            setFunc = function(value)
                SaveGABSetting("backbarOpacity", tonumber(value) or POSITION_DEFAULTS.backbarOpacity)
                ActionBar:Refresh()
            end,
            default = POSITION_DEFAULTS.backbarOpacity,
        },
        {
            type = "slider",
            name = "Backbar Desaturation",
            tooltip = "Controls how gray the inactive backbar icons appear.",
            min = 0, max = 1, step = 0.05,
            getFunc = function() return GetBackbarDesaturation() end,
            setFunc = function(value)
                SaveGABSetting("backbarDesaturation", tonumber(value) or POSITION_DEFAULTS.backbarDesaturation)
                ActionBar:Refresh()
            end,
            default = POSITION_DEFAULTS.backbarDesaturation,
        },
        {
            type = "header",
            name = "Cooldown Timer Text",
        },
        {
            type = "description",
            text = "These settings control the text shown for cooldown and effect timers. The Action Bar preview shows live test numbers.",
        },
        {
            type = "slider",
            name = "Timer Horizontal Position",
            tooltip = "Moves timer text left or right relative to the center of its icon.",
            min = -20, max = 20, step = 1,
            getFunc = function() return tonumber(ActionBar.timerOffsetX) or POSITION_DEFAULTS.timerOffsetX end,
            setFunc = function(value)
                SaveGABSetting("timerOffsetX", tonumber(value) or POSITION_DEFAULTS.timerOffsetX)
                ApplyOverlayTextStyles()
            end,
            default = POSITION_DEFAULTS.timerOffsetX,
        },
        {
            type = "slider",
            name = "Timer Vertical Position",
            tooltip = "Moves timer text up or down relative to the center of its icon.",
            min = -20, max = 20, step = 1,
            getFunc = function() return tonumber(ActionBar.timerOffsetY) or POSITION_DEFAULTS.timerOffsetY end,
            setFunc = function(value)
                SaveGABSetting("timerOffsetY", tonumber(value) or POSITION_DEFAULTS.timerOffsetY)
                ApplyOverlayTextStyles()
            end,
            default = POSITION_DEFAULTS.timerOffsetY,
        },
        {
            type = "slider",
            name = "Timer Size",
            tooltip = "Changes the size of cooldown/effect timer text on skill and ultimate slots.",
            min = 10, max = 80, step = 1,
            getFunc = function() return tonumber(ActionBar.timerSize) or POSITION_DEFAULTS.timerSize end,
            setFunc = function(value)
                SaveGABSetting("timerSize", tonumber(value) or POSITION_DEFAULTS.timerSize)
                ApplyOverlayTextStyles()
            end,
            default = POSITION_DEFAULTS.timerSize,
        },
        {
            type = "dropdown",
            name = "Timer Font",
            tooltip = "Font used for cooldown/effect timer text.",
            choices = { "Univers 67", "Univers 57", "ProseAntique", "Trajan Pro", "Skyrim Handwritten", "Futura Condensed Light", "Futura Condensed", "Futura Condensed Bold" },
            getFunc = function() return ActionBar.timerFont end,
            setFunc = function(value)
                SaveGABSetting("timerFont", tostring(value))
                ApplyOverlayTextStyles()
            end,
            default = POSITION_DEFAULTS.timerFont,
        },
        {
            type = "dropdown",
            name = "Timer Outline",
            tooltip = "Outline style used for cooldown/effect timer text.",
            choices = { "none", "outline", "outline", "soft-shadow-thick", "shadow" },
            getFunc = function() return ActionBar.timerOutline end,
            setFunc = function(value)
                SaveGABSetting("timerOutline", tostring(value))
                ApplyOverlayTextStyles()
            end,
            default = POSITION_DEFAULTS.timerOutline,
        },
        {
            type = "header",
            name = "Stack Count Text",
        },
        {
            type = "description",
            text = "These settings control stack-count text on skills that track stacks. A sample stack count is shown in the Action Bar preview.",
        },
        {
            type = "slider",
            name = "Stack Count Horizontal Position",
            tooltip = "Moves stack-count text left or right relative to the center of its icon.",
            min = -20, max = 20, step = 1,
            getFunc = function() return tonumber(ActionBar.stackOffsetX) or POSITION_DEFAULTS.stackOffsetX end,
            setFunc = function(value)
                SaveGABSetting("stackOffsetX", tonumber(value) or POSITION_DEFAULTS.stackOffsetX)
                ApplyOverlayTextStyles()
            end,
            default = POSITION_DEFAULTS.stackOffsetX,
        },
        {
            type = "slider",
            name = "Stack Count Vertical Position",
            tooltip = "Moves stack-count text up or down relative to the center of its icon.",
            min = -20, max = 20, step = 1,
            getFunc = function() return tonumber(ActionBar.stackOffsetY) or POSITION_DEFAULTS.stackOffsetY end,
            setFunc = function(value)
                SaveGABSetting("stackOffsetY", tonumber(value) or POSITION_DEFAULTS.stackOffsetY)
                ApplyOverlayTextStyles()
            end,
            default = POSITION_DEFAULTS.stackOffsetY,
        },
        {
            type = "slider",
            name = "Stack Count Size",
            tooltip = "Changes the size of stack-count text displayed on abilities with stack counts.",
            min = 10, max = 80, step = 1,
            getFunc = function() return tonumber(ActionBar.stackSize) or POSITION_DEFAULTS.stackSize end,
            setFunc = function(value)
                SaveGABSetting("stackSize", tonumber(value) or POSITION_DEFAULTS.stackSize)
                ApplyOverlayTextStyles()
            end,
            default = POSITION_DEFAULTS.stackSize,
        },
        {
            type = "dropdown",
            name = "Stack Count Font",
            tooltip = "Font used for stack-count text displayed on abilities with stack counts.",
            choices = { "Univers 67", "Univers 57", "ProseAntique", "Trajan Pro", "Skyrim Handwritten", "Futura Condensed Light", "Futura Condensed", "Futura Condensed Bold" },
            getFunc = function() return ActionBar.stackFont end,
            setFunc = function(value)
                SaveGABSetting("stackFont", tostring(value))
                ApplyOverlayTextStyles()
            end,
            default = POSITION_DEFAULTS.stackFont,
        },
        {
            type = "dropdown",
            name = "Stack Count Outline",
            tooltip = "Outline style used for stack-count text displayed on abilities with stack counts.",
            choices = { "none", "outline", "outline", "soft-shadow-thick", "shadow" },
            getFunc = function() return ActionBar.stackOutline end,
            setFunc = function(value)
                SaveGABSetting("stackOutline", tostring(value))
                ApplyOverlayTextStyles()
            end,
            default = POSITION_DEFAULTS.stackOutline,
        },
        {
            type = "checkbox",
            name = "Show Ultimate",
            tooltip = "Show the active ultimate icon.",
            getFunc = function() return ActionBar.showUltimate == true end,
            setFunc = function(value)
                SaveGABSetting("showUltimate", value == true)
                ActionBar:Refresh()
            end,
            default = POSITION_DEFAULTS.showUltimate,
        },
        {
            type = "checkbox",
            name = "Show Quickslot",
            tooltip = "Show the ESO quickslot/potion control beside GAB.",
            getFunc = function() return ActionBar.showQuickslot == true end,
            setFunc = function(value)
                SaveGABSetting("showQuickslot", value == true)
                ActionBar:AnchorRows()
            end,
            default = POSITION_DEFAULTS.showQuickslot,
        },
        {
            type = "checkbox",
            name = "Show Weapon Swap",
            tooltip = "Show the ESO weapon-swap indicator beside GAB.",
            getFunc = function() return ActionBar.showWeaponSwap == true end,
            setFunc = function(value)
                SaveGABSetting("showWeaponSwap", value == true)
                ActionBar:AnchorRows()
            end,
            default = POSITION_DEFAULTS.showWeaponSwap,
        },
        {
            type = "button",
            name = "Reset GAB Customization",
            tooltip = "Restore the original GrimSuite GAB size, spacing, scale, backbar appearance, and element visibility.",
            func = ResetGABCustomization,
            width = "half",
        },
        {
            type = "checkbox",
            name = "Unlock Action Bar",
            tooltip = "When enabled, drag anywhere on either GrimSuite bar to move the entire layout.",
            getFunc = function()
                return ActionBar.positionUnlocked == true
            end,
            setFunc = function(value)
                ActionBar.positionUnlocked = value == true
                if positionSV then positionSV.unlocked = ActionBar.positionUnlocked end
                SetDragEnabled(ActionBar.positionUnlocked)
            end,
            default = POSITION_DEFAULTS.unlocked,
            width = "full",
        },
        {
            type = "button",
            name = "Center Horizontally (Skill Slot 3)",
            tooltip = "Centers the middle of the third displayed skill (ESO hotbar slot 5) on the exact center of the screen.",
            func = CenterOnThirdSlot,
            width = "half",
        },
        {
            type = "button",
            name = "Reset Position",
            tooltip = "Returns the action bar to its original ESO-relative position.",
            func = ResetPosition,
            width = "half",
        },
    }

    local stackTrackerPanelName = GS.name .. "_StackTracker_Settings"
    local stackTrackerPanelData = {
        type = "panel",
        name = "GrimSuite Stack Tracker",
        displayName = "GrimSuite Stack Tracker",
        author = "@GrimGrin94",
        version = GS.version,
        registerForRefresh = true,
        registerForDefaults = true,
    }

    local stackTrackerOptions = {
        {
            type = "header",
            name = "Stack Tracker",
        },
        {
            type = "checkbox",
            name = "Show Stack Tracker",
            tooltip = "Enable the standalone Stack Tracker system.",
            getFunc = function()
                return ActionBar.showStackTracker == true
            end,
            setFunc = function(value)
                SaveStackTrackerSetting("showStackTracker", value == true)
                UpdateStackTracker()
            end,
            default = STACK_TRACKER_DEFAULTS.showStackTracker,
            width = "full",
        },
        {
            type = "checkbox",
            name = "Unlock Stack Tracker",
            tooltip = "When enabled, drag any visible stack tracker with left click to move that tracker independently.",
            getFunc = function()
                return ActionBar.stackTrackerUnlocked == true
            end,
            setFunc = function(value)
                ActionBar.stackTrackerUnlocked = value == true
                if stackTrackerSV then
                    stackTrackerSV.unlocked = ActionBar.stackTrackerUnlocked
                end
                UpdateStackTrackerDragEnabled(ActionBar.stackTrackerUnlocked)
            end,
            default = STACK_TRACKER_DEFAULTS.unlocked,
            width = "full",
        },
        {
            type = "slider",
            name = "Icon Size",
            tooltip = "Changes the icon size for all Stack Tracker entries.",
            min = STACK_TRACKER_MIN_ICON_SIZE,
            max = STACK_TRACKER_MAX_ICON_SIZE,
            step = 1,
            getFunc = function() return GetStackTrackerIconSize() end,
            setFunc = function(value)
                local size = tonumber(value) or STACK_TRACKER_DEFAULTS.iconSize
                ActionBar.stackTrackerIconSize = size
                if stackTrackerSV then
                    stackTrackerSV.iconSize = size
                end
                ApplyStackTrackerAppearance()
                UpdateStackTracker()
            end,
            default = STACK_TRACKER_DEFAULTS.iconSize,
        },
        {
            type = "slider",
            name = "Text Size",
            tooltip = "Changes the stack-count text size for all Stack Tracker entries.",
            min = STACK_TRACKER_MIN_TEXT_SIZE,
            max = STACK_TRACKER_MAX_TEXT_SIZE,
            step = 1,
            getFunc = function() return GetStackTrackerTextSize() end,
            setFunc = function(value)
                local size = tonumber(value) or STACK_TRACKER_DEFAULTS.textSize
                ActionBar.stackTrackerTextSize = size
                if stackTrackerSV then
                    stackTrackerSV.textSize = size
                end
                ApplyStackTrackerAppearance()
                UpdateStackTracker()
            end,
            default = STACK_TRACKER_DEFAULTS.textSize,
        },
        {
            type = "description",
            text = "Each tracker keeps its own position. Enable Unlock Stack Tracker, then drag the individual tracker you want to move.",
        },
        {
            type = "header",
            name = "Bound Armaments",
        },
        {
            type = "checkbox",
            name = "Show Bound Armaments",
            tooltip = "Show the Bound Armaments stack tracker when the ability is slotted on either weapon bar.",
            getFunc = function() return ActionBar.showBoundArmaments == true end,
            setFunc = function(value)
                SaveStackTrackerSetting("showBoundArmaments", value == true)
                UpdateStackTracker()
            end,
            default = STACK_TRACKER_DEFAULTS.showBoundArmaments,
            width = "full",
        },
        {
            type = "header",
            name = "Crux",
        },
        {
            type = "checkbox",
            name = "Show Crux",
            tooltip = "Show the Crux tracker when a Crux-consuming ability is slotted on either weapon bar.",
            getFunc = function() return ActionBar.showCrux == true end,
            setFunc = function(value)
                SaveStackTrackerSetting("showCrux", value == true)
                UpdateStackTracker()
            end,
            default = STACK_TRACKER_DEFAULTS.showCrux,
            width = "full",
        },
        {
            type = "header",
            name = "Nightblade Bow",
        },
        {
            type = "checkbox",
            name = "Show Nightblade Bow",
            tooltip = "Show the Nightblade spectral-bow stack tracker when Grim Focus, Merciless Resolve, or Relentless Focus is slotted.",
            getFunc = function() return ActionBar.showBow == true end,
            setFunc = function(value)
                SaveStackTrackerSetting("showBow", value == true)
                UpdateStackTracker()
            end,
            default = STACK_TRACKER_DEFAULTS.showBow,
            width = "full",
        },
        {
            type = "button",
            name = "Reset Stack Tracker Positions",
            tooltip = "Restore the default position of Bound Armaments, Crux, and Nightblade Bow.",
            func = ResetStackTrackerPositions,
            width = "half",
        },
    }

    LAM:RegisterAddonPanel(panelName, panelData)
    LAM:RegisterOptionControls(panelName, options)
    LAM:RegisterAddonPanel(stackTrackerPanelName, stackTrackerPanelData)
    LAM:RegisterOptionControls(stackTrackerPanelName, stackTrackerOptions)

    if CALLBACK_MANAGER and not ActionBar.settingsPreviewCallbacksRegistered then
        ActionBar.settingsPreviewCallbacksRegistered = true

        CALLBACK_MANAGER:RegisterCallback("LAM-PanelOpened", function(panel)
            local openedName = panel and panel:GetName()
            ActionBar:SetSettingsPreviewVisible(openedName == panelName)
        end)

        CALLBACK_MANAGER:RegisterCallback("LAM-PanelClosed", function(panel)
            local closedName = panel and panel:GetName()
            if closedName == panelName then
                ActionBar:SetSettingsPreviewVisible(false)
            end
        end)
    end
end

function ActionBar:SetHUDVisible(visible)
    visible = visible == true
    self.hudVisible = visible
    self.stackTrackerHUDVisible = visible

    local shouldShowBars = (visible or self.settingsPreviewVisible) and self.showFrames

    if self.frontRoot then
        self.frontRoot:SetHidden(not shouldShowBars)
    end
    if self.backbarRoot then
        self.backbarRoot:SetHidden(not shouldShowBars)
    end

    -- Utility controls follow the same rule as the Action Bar settings preview:
    -- visible on the live HUD, and visible while specifically previewing the
    -- GrimSuite Action Bar settings panel.
    if self.utilityRoot then
        self.utilityRoot:SetHidden(not (visible or self.settingsPreviewVisible))
    end

    UpdateStackTracker()
end

function ActionBar:SetSettingsPreviewVisible(visible)
    self.settingsPreviewVisible = visible == true

    local hudVisible = self.hudVisible ~= false
    local shouldShowBars = (hudVisible or self.settingsPreviewVisible) and self.showFrames

    if self.frontRoot then
        self.frontRoot:SetHidden(not shouldShowBars)
    end
    if self.backbarRoot then
        self.backbarRoot:SetHidden(not shouldShowBars)
    end

    if self.utilityRoot then
        self.utilityRoot:SetHidden(not (hudVisible or self.settingsPreviewVisible))
    end

    if self.settingsPreviewVisible then
        ApplyOverlayTextStyles()
        UpdateSettingsPreviewTimers()
    end
end

function ActionBar:Refresh()
    if not self.initialized then return end

    self:CreateRows()
    self:AnchorRows()
    local activeCategory = GetActiveHotbarCategory()
    if activeCategory ~= HOTBAR_CATEGORY_PRIMARY and activeCategory ~= HOTBAR_CATEGORY_BACKUP then
        activeCategory = HOTBAR_CATEGORY_PRIMARY
    end

    -- Physical rows are permanently tied to the two weapon bars.
    -- The FRONT BAR is always the top row and the BACK BAR is always the
    -- bottom row. Weapon swapping changes only which row is active; it never
    -- changes which abilities belong to either physical row.
    local frontCategory = HOTBAR_CATEGORY_PRIMARY
    local backCategory = HOTBAR_CATEGORY_BACKUP
    self:UpdateRow(self.frontControls, frontCategory, activeCategory == HOTBAR_CATEGORY_PRIMARY)
    self:UpdateRow(self.backbarControls, backCategory, activeCategory == HOTBAR_CATEGORY_BACKUP)

    -- HandleSlotChanged() above can make the native button visible again, so
    -- suppress native visuals AFTER the sync/paint pass, just like a final
    -- presentation step.
    self:UpdateNativeVisualSuppression()
    UpdateUtilityControls()
    UpdateEffectDisplays()
    UpdateStackTracker()

    -- Settings preview is intentionally layered over the normal paint pass so
    -- test timers remain visible while changing fonts/sizes/offsets in LAM.
    UpdateSettingsPreviewTimers()
end

function ActionBar:Initialize()
    if self.initialized then return end
    self.initialized = true

    -- Load the position independently of LibAddonMenu.  LAM is only the
    -- settings UI; the actual saved position must be available immediately
    -- so /reloadui cannot briefly rebuild the bar at the default location.
    if not positionSV then
        positionSV = ZO_SavedVars:NewAccountWide(POSITION_SV_NAME, POSITION_SV_VERSION, nil, POSITION_DEFAULTS)
    end

    self.positionX = tonumber(positionSV.positionX) or 0
    self.positionY = tonumber(positionSV.positionY) or 0
    self.positionUnlocked = positionSV.unlocked == true

    self.iconSize = tonumber(positionSV.iconSize) or POSITION_DEFAULTS.iconSize
    self.potionSize = tonumber(positionSV.potionSize) or POSITION_DEFAULTS.potionSize
    self.slotGap = tonumber(positionSV.slotGap) or POSITION_DEFAULTS.slotGap
    self.rowGap = tonumber(positionSV.rowGap) or POSITION_DEFAULTS.rowGap
    self.backbarOpacity = tonumber(positionSV.backbarOpacity) or POSITION_DEFAULTS.backbarOpacity
    self.backbarDesaturation = tonumber(positionSV.backbarDesaturation) or POSITION_DEFAULTS.backbarDesaturation
    self.showUltimate = positionSV.showUltimate ~= false
    self.showQuickslot = positionSV.showQuickslot ~= false
    self.showWeaponSwap = positionSV.showWeaponSwap ~= false
    self.timerSize = tonumber(positionSV.timerSize) or POSITION_DEFAULTS.timerSize
    self.stackSize = tonumber(positionSV.stackSize) or POSITION_DEFAULTS.stackSize
    self.timerFont = tostring(positionSV.timerFont or POSITION_DEFAULTS.timerFont)
    self.stackFont = tostring(positionSV.stackFont or POSITION_DEFAULTS.stackFont)
    self.timerOutline = tostring(positionSV.timerOutline or POSITION_DEFAULTS.timerOutline)
    self.stackOutline = tostring(positionSV.stackOutline or POSITION_DEFAULTS.stackOutline)

    -- Migrate the pre-fix UI label/value to ESO's actual supported modifier.
    -- The old "soft-shadow-thick-outline" token was invalid; ESO expects
    -- "soft-shadow-thick".
    if self.timerOutline == "soft-shadow-thick-outline" then
        self.timerOutline = "soft-shadow-thick"
        positionSV.timerOutline = self.timerOutline
    end
    if self.stackOutline == "soft-shadow-thick-outline" then
        self.stackOutline = "soft-shadow-thick"
        positionSV.stackOutline = self.stackOutline
    end
    -- Migrate the removed Thick Outline option to the remaining Outline style.
    if self.timerOutline == "thick-outline" then
        self.timerOutline = "outline"
        positionSV.timerOutline = self.timerOutline
    end
    if self.stackOutline == "thick-outline" then
        self.stackOutline = "outline"
        positionSV.stackOutline = self.stackOutline
    end
    self.timerOffsetX = tonumber(positionSV.timerOffsetX) or POSITION_DEFAULTS.timerOffsetX
    self.timerOffsetY = tonumber(positionSV.timerOffsetY) or POSITION_DEFAULTS.timerOffsetY
    self.stackOffsetX = tonumber(positionSV.stackOffsetX) or POSITION_DEFAULTS.stackOffsetX
    self.stackOffsetY = tonumber(positionSV.stackOffsetY) or POSITION_DEFAULTS.stackOffsetY

    if not stackTrackerSV then
        stackTrackerSV = ZO_SavedVars:NewAccountWide(
            STACK_TRACKER_SV_NAME,
            STACK_TRACKER_SV_VERSION,
            nil,
            STACK_TRACKER_DEFAULTS
        )
    end

    self.showStackTracker = stackTrackerSV.showStackTracker ~= false
    self.stackTrackerUnlocked = stackTrackerSV.unlocked == true
    self.stackTrackerIconSize = tonumber(stackTrackerSV.iconSize) or STACK_TRACKER_DEFAULTS.iconSize
    self.stackTrackerTextSize = tonumber(stackTrackerSV.textSize) or STACK_TRACKER_DEFAULTS.textSize
    self.showBoundArmaments = stackTrackerSV.showBoundArmaments ~= false
    self.showCrux = stackTrackerSV.showCrux ~= false
    self.showBow = stackTrackerSV.showBow ~= false
    self.boundArmamentsX = tonumber(stackTrackerSV.boundArmamentsX) or STACK_TRACKER_DEFAULTS.boundArmamentsX
    self.boundArmamentsY = tonumber(stackTrackerSV.boundArmamentsY) or STACK_TRACKER_DEFAULTS.boundArmamentsY
    self.cruxX = tonumber(stackTrackerSV.cruxX) or STACK_TRACKER_DEFAULTS.cruxX
    self.cruxY = tonumber(stackTrackerSV.cruxY) or STACK_TRACKER_DEFAULTS.cruxY
    self.bowX = tonumber(stackTrackerSV.bowX) or STACK_TRACKER_DEFAULTS.bowX
    self.bowY = tonumber(stackTrackerSV.bowY) or STACK_TRACKER_DEFAULTS.bowY
    self.stackTrackerHUDVisible = true

    CreateStackTracker()
    ApplyStackTrackerAppearance()
    UpdateStackTrackerDragEnabled(self.stackTrackerUnlocked)
    UpdateStackTracker()

    RegisterLibAddonMenu()
    SetDragEnabled(self.positionUnlocked)

    EM:RegisterForEvent(GS.name .. "_AB_PlayerActivated", EVENT_PLAYER_ACTIVATED, function()
        -- Let ESO finish establishing the native action-bar layout, then
        -- reapply the saved position without recapturing the native reference.
        -- The captured reference is the original ESO-relative baseline used by
        -- the saved position; recapturing during activation can capture an
        -- intermediate layout state.
        zo_callLater(function() self:Refresh() end, 100)
    end)

    -- ESO can re-show/re-anchor ZO_ActionBar1 after scene/zone transitions.
    -- Azurah handles this by restoring the user's action-bar position from
    -- the action bar's OnShow lifecycle rather than relying only on
    -- EVENT_PLAYER_ACTIVATED.  Do the same repair here, while leaving all
    -- existing GrimSuite geometry and saved-position math untouched.
    if ZO_ActionBar1 then
        ZO_PreHookHandler(ZO_ActionBar1, "OnShow", function()
            if not self.initialized then return end
            zo_callLater(function()
                if self.initialized then
                    self:Refresh()
                end
            end, 0)
        end)
    end

    -- This is the authoritative action-slot update event used by ESO/FAB.
    -- IMPORTANT: the first boolean only tells us whether the ACTIVE hotbar
    -- changed. The second boolean tells us whether the ability assignments
    -- changed. Wizard-style setup/loadout swaps can change both bars while
    -- keeping the same weapon/gear setup, so didActiveHotbarChange can be
    -- false even though every skill icon needs to be repainted.
    EM:RegisterForEvent(GS.name .. "_AB_HotbarUpdated", EVENT_ACTION_SLOTS_ACTIVE_HOTBAR_UPDATED, function(_, didActiveHotbarChange, shouldUpdateAbilityAssignments, activeHotbarCategory)
        if not didActiveHotbarChange and not shouldUpdateAbilityAssignments then
            return
        end
        if activeHotbarCategory ~= HOTBAR_CATEGORY_PRIMARY and activeHotbarCategory ~= HOTBAR_CATEGORY_BACKUP then
            return
        end

        -- Let ESO finish publishing the new slot assignments before we read
        -- them. This is particularly important when a setup changes skills
        -- without changing the active weapon pair.
        zo_callLater(function()
            if not self.initialized then return end
            local currentCategory = GetActiveHotbarCategory()
            if currentCategory ~= HOTBAR_CATEGORY_PRIMARY and currentCategory ~= HOTBAR_CATEGORY_BACKUP then
                return
            end

            self:CreateRows()
            self:AnchorRows()
            self:UpdateRow(self.frontControls, HOTBAR_CATEGORY_PRIMARY, currentCategory == HOTBAR_CATEGORY_PRIMARY)
            self:UpdateRow(self.backbarControls, HOTBAR_CATEGORY_BACKUP, currentCategory == HOTBAR_CATEGORY_BACKUP)
            self:UpdateNativeVisualSuppression()
            UpdateUtilityControls()
        end, 0)
    end)

    -- Quickslot is no longer part of the normal action-slot update event.
    -- Keep the GrimSuite-owned potion presentation synchronized with ESO's
    -- dedicated quickslot events instead.
    if EVENT_ACTIVE_QUICKSLOT_CHANGED then
        EM:RegisterForEvent(GS.name .. "_AB_UtilityQuickslot", EVENT_ACTIVE_QUICKSLOT_CHANGED, function()
            if not self.initialized then return end
            UpdateUtilityControls()
            self:UpdateNativeVisualSuppression()
        end)
    end

    if EVENT_ACTION_UPDATE_COOLDOWNS then
        EM:RegisterForEvent(GS.name .. "_AB_UtilityCooldowns", EVENT_ACTION_UPDATE_COOLDOWNS, function()
            if not self.initialized then return end
            UpdateUtilityControls()
        end)
    end

    -- Inventory changes can alter the quickslot count/usable state without
    -- changing which quickslot is selected.
    local function RefreshUtilityInventory()
        if not self.initialized then return end
        UpdateUtilityControls()
    end
    EM:RegisterForEvent(GS.name .. "_AB_UtilityInventoryFull", EVENT_INVENTORY_FULL_UPDATE, RefreshUtilityInventory)
    EM:RegisterForEvent(GS.name .. "_AB_UtilityInventorySingle", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, RefreshUtilityInventory)
    EM:RegisterForEvent(GS.name .. "_AB_UtilityItemSlotChanged", EVENT_ITEM_SLOT_CHANGED, RefreshUtilityInventory)

    -- Some setup/loadout systems can update both hotbars without changing the
    -- active-hotbar state. This event is the explicit all-bars assignment
    -- notification, so use it as a lightweight repaint fallback.
    if EVENT_ACTION_SLOTS_ALL_HOTBARS_UPDATED then
        EM:RegisterForEvent(GS.name .. "_AB_AllHotbarsUpdated", EVENT_ACTION_SLOTS_ALL_HOTBARS_UPDATED, function()
            zo_callLater(function()
                if self.initialized then
                    self:Refresh()
                end
            end, 0)
        end)
    end

    -- ESO reports the actual skill activation here.  Flash only the
    -- corresponding GrimSuite button on the currently active bar.
    EM:RegisterForEvent(GS.name .. "_AB_PressedFeedback", EVENT_ACTION_SLOT_ABILITY_USED, function(_, slot)
        if slot < MIN_SLOT or slot > ULT_SLOT then return end

        local category = GetActiveHotbarCategory()
        local abilityId = GetAbilityForSlot(slot, category)
        StartBoneyardTimer(slot, category, abilityId)
        StartHauntingCurseTimer(slot, category, abilityId)

        local controls = category == HOTBAR_CATEGORY_PRIMARY and self.frontControls or self.backbarControls
        local data = controls and controls[slot]
        if data then
            FlashPressed(data)
        end
    end)

    -- Slot assignment changes repaint the affected rows.
    EM:RegisterForEvent(GS.name .. "_AB_SlotUpdate", EVENT_HOTBAR_SLOT_UPDATED, function()
        self:Refresh()
    end)

    -- FAB only responds to usability state changes for the CURRENT active bar.
    -- Do the same here instead of rebuilding/caching usability ourselves.
    EM:RegisterForEvent(GS.name .. "_AB_Usability", EVENT_HOTBAR_SLOT_STATE_UPDATED, function(_, slot, hotbar)
        if slot < MIN_SLOT or slot > ULT_SLOT then return end
        if hotbar ~= GetActiveHotbarCategory() then return end

        local controls = hotbar == HOTBAR_CATEGORY_PRIMARY and self.frontControls or self.backbarControls
        local data = controls[slot]
        local button = GetButton(slot, hotbar)
        if not data or not button then return end

        local id = GetAbilityForSlot(slot, hotbar)
        StyleDisplay(data, true, id > 0, button.usable)

        -- Re-evaluate the state glow immediately so active toggles and ready
        -- procs/ultimates do not briefly disappear while ESO updates the slot.
        local currentUlt, costUlt = 0, 0
        local ultimateReady = false
        if slot == ULT_SLOT then
            local okPower, power = pcall(GetUnitPower, "player", COMBAT_MECHANIC_FLAGS_ULTIMATE)
            local okCost, cost = pcall(GetSlotAbilityCost, ULT_SLOT, COMBAT_MECHANIC_FLAGS_ULTIMATE, hotbar)
            if okPower then currentUlt = tonumber(power) or 0 end
            if okCost then costUlt = tonumber(cost) or 0 end
            ultimateReady = costUlt > 0 and currentUlt >= costUlt
        end
        UpdateSlotGlow(data, slot, hotbar, true, ultimateReady)
    end)

    -- Player effect changes provide stack counts. We deliberately only retain
    -- effects whose ability is actually slotted on one of GrimSuite's bars.
    ActionBar.crystalFragmentsReady = ReadCrystalFragmentsProcState()
    EM:RegisterForEvent(GS.name .. "_AB_Effects", EVENT_EFFECT_CHANGED, TrackPlayerEffect)

    -- Action-slot effects are the authoritative source for timers. Update at
    -- a modest rate so the text moves smoothly without rebuilding the bars.
    EM:RegisterForUpdate(GS.name .. "_AB_EffectDisplay", 100, function()
        if self.initialized then
            ReconcileBannerState()
            UpdateEffectDisplays()
            UpdateActiveBarGlows()
        end
    end)

    -- No periodic Refresh(): FAB is event-driven for bar/usability presentation.
    -- This avoids re-reading a stale native usability flag between ESO events.
    zo_callLater(function() self:Refresh() end, 250)
end
