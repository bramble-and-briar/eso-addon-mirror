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
local GLOW_INNER    = 1.18
local GLOW_OUTER    = 1.36
local GLOW_INNER_A  = 0.65
local GLOW_OUTER_A  = 0.3
local MOVE_SPEED    = 500
local SCALE_SPEED   = 15
local SIZE_MIN      = 30
local SIZE_MAX      = 80
local MOVE_SCENE    = "MyExtras_ActionBarMove"
local HIDE_REASON   = "MyExtras_ActionBar"

local RESOURCE_OFFSET_GAMEPAD  = -105
local RESOURCE_OFFSET_KEYBOARD = -74
local RESOURCE_SIDE_OFFSET     = 237

local STACK_GAP    = 12
local STACK_DELAY  = 50
local PROMPT_GUESS = 50
local KEYBOARD_BAR_INSET = 20

local FLOOR_CONTROLS = {
    "ZO_PlayerAttributeHealth",
    "ZO_PlayerAttributeMagicka",
    "ZO_PlayerAttributeStamina",
}
local BUFF_ROWS = {
    "ZO_BuffDebuffTopLevelSelfContainerContainer1",
    "ZO_BuffDebuffTopLevelSelfContainerContainer2",
}
local BUFF_CONTAINER      = "ZO_BuffDebuffTopLevelSelfContainer"
local BUFF_GAP            = 6
local BUFF_SPACE_GAMEPAD  = 80
local BUFF_SPACE_KEYBOARD = 66
local PROMPT_BASE  = "ZO_PlayerToPlayerAreaPromptContainer"
local PROMPT_PARTS = {
    "ZO_PlayerToPlayerAreaPromptContainerActionArea",
    "ZO_PlayerToPlayerAreaPromptContainerActionAreaActionKeybindButton",
    "ZO_PlayerToPlayerAreaPromptContainerActionAreaPromptKeybindButton1",
    "ZO_PlayerToPlayerAreaPromptContainerActionAreaPromptKeybindButton2",
    "ZO_PlayerToPlayerAreaPromptContainerActionAreaAdditionalInfo",
    "ZO_PlayerToPlayerAreaPromptContainerActionAreaPendingResurrectInfo",
}
local STACK_PLACED = {
    "ZO_SynergyTopLevelContainer",
    "ZO_ObjectiveCaptureMeter",
    "ZO_ActiveCombatTipsTip",
    "ZO_InstanceKickWarning_AliveContainer",
    "ZO_RamTopLevel",
}

local DELVE_BUFF_ID  = 66282
local ATTACK_ICON    = "EsoUI/Art/AvA/AvA_tooltipIcon_keep.dds"
local ATTACK_RANK    = 3
local FOOD_DIM      = 0.45
local FOOD_SHOW_MIN = 59
local FOOD_FALLBACK = 61259
local FOOD_IDS = {
    [17407] = true, [17577] = true, [17581] = true, [17608] = true, [17614] = true,
    [61218] = true, [61255] = true, [61257] = true, [61259] = true, [61260] = true,
    [61261] = true, [61294] = true, [61322] = true, [61325] = true, [61328] = true,
    [61335] = true, [61340] = true, [61345] = true, [61350] = true, [66125] = true,
    [66128] = true, [66130] = true, [66132] = true, [66137] = true, [66141] = true,
    [66551] = true, [66568] = true, [66576] = true, [66586] = true, [66590] = true,
    [66594] = true, [68411] = true, [68416] = true, [72816] = true, [72819] = true,
    [72822] = true, [72824] = true, [72956] = true, [72959] = true, [72961] = true,
    [72965] = true, [72968] = true, [72971] = true, [84678] = true, [84681] = true,
    [84700] = true, [84704] = true, [84709] = true, [84720] = true, [84725] = true,
    [84731] = true, [84732] = true, [84733] = true, [84735] = true, [84736] = true,
    [85484] = true, [85497] = true, [86559] = true, [86560] = true, [86673] = true,
    [86674] = true, [86677] = true, [86678] = true, [86746] = true, [86747] = true,
    [86749] = true, [86787] = true, [86789] = true, [86791] = true, [89955] = true,
    [89957] = true, [89971] = true, [92433] = true, [92435] = true, [92437] = true,
    [92474] = true, [92476] = true, [92477] = true, [100488] = true, [100498] = true,
    [100502] = true, [107748] = true, [107789] = true, [127531] = true, [127537] = true,
    [127572] = true, [127578] = true, [127596] = true, [127619] = true, [127736] = true,
    [148633] = true, [267468] = true,
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

AB.charDefaults = {
    actionBarUseCharacter = false,
}

AB.defaults = {
    actionBarEnabled    = false,
    actionBarShow       = "Always",
    actionBarStatic     = true,
    actionBarResources  = "Row",
    actionBarBuffs      = "Above",
    actionBarShowFood     = true,
    actionBarShowDelve    = false,
    actionBarShowAttack   = false,
    actionBarReadyUltimate = true,
    actionBarReadyPotion   = false,
    actionBarReadyPulsate = true,
    actionBarReadyGlow    = false,
    actionBarReadyTint    = false,
    actionBarGlowStyle  = "Custom",
    actionBarGlowColor  = { r = 1, g = 0.82, b = 0.2, a = 1 },
    actionBarReadyStyle = "Custom",
    actionBarReadyColor = { r = 1, g = 0.82, b = 0.2, a = 1 },
    actionBarPulseSpeed = 5,
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

AB.readyChoices = {
    { name = "Pulsate",      value = "Pulsate" },
    { name = "Glow",         value = "Glow"    },
    { name = "Color Change", value = "Color"   },
}

AB.potionRingChoices = {
    { name = "Food",              value = "Food"   },
    { name = "Delve Buff",        value = "Delve"  },
    { name = "Continuous Attack", value = "Attack" },
}

local POTION_RING_KEYS = {
    Food   = "actionBarShowFood",
    Delve  = "actionBarShowDelve",
    Attack = "actionBarShowAttack",
}

AB.readyOnChoices = {
    { name = "Ultimate", value = "Ultimate" },
    { name = "Potion",   value = "Potion"   },
}

local READY_ON_KEYS = {
    Ultimate = "actionBarReadyUltimate",
    Potion   = "actionBarReadyPotion",
}

local READY_KEYS = {
    Pulsate = "actionBarReadyPulsate",
    Glow    = "actionBarReadyGlow",
    Color   = "actionBarReadyTint",
}

AB.buffChoices = {
    { name = "Above Action Bar", value = "Above" },
    { name = "Below Action Bar", value = "Below" },
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
local readyR, readyG, readyB = 1, 0.82, 0.2
local glowR, glowG, glowB    = 1, 0.82, 0.2
local activeBar = HOTBAR_CATEGORY_PRIMARY
local backBar   = HOTBAR_CATEGORY_BACKUP

local tenthTexts   = {}
local numberTexts  = {}
local minuteTexts  = {}
local percentTexts = {}

--------------------------------------------------
-- Helpers
--------------------------------------------------
local charFilled = false

local function CharSettings()
    local cv = ME.charVariables
    if not cv then return nil end
    if type(cv.actionBarCharSettings) ~= "table" then cv.actionBarCharSettings = {} end
    local settings = cv.actionBarCharSettings
    if not settings.seeded then
        local account = ME.savedVariables
        for key, value in pairs(AB.defaults) do
            local current = account and account[key]
            if current == nil then current = value end
            settings[key] = current
        end
        settings.seeded = true
        charFilled = true
    elseif not charFilled then
        for key, value in pairs(AB.defaults) do
            if settings[key] == nil then settings[key] = value end
        end
        charFilled = true
    end
    return settings
end

function AB:UsesCharacterSettings()
    return ME.charVariables ~= nil and ME.charVariables.actionBarUseCharacter == true
end

local function SV()
    if AB:UsesCharacterSettings() then
        return CharSettings() or ME.savedVariables
    end
    return ME.savedVariables
end

local function SavedTip()
    if AB:UsesCharacterSettings() then return ME.SAVED_CHARACTER_TIP end
    return ME.SAVED_ACCOUNT_TIP
end

local function IsEnabled()
    local sv = SV()
    return sv ~= nil and sv.actionBarEnabled == true
end

local function BuffsBelow()
    return IsEnabled() and SV().actionBarBuffs == "Below"
end

local function BuffSpace()
    return IsInGamepadPreferredMode() and BUFF_SPACE_GAMEPAD or BUFF_SPACE_KEYBOARD
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
    readyR, readyG, readyB = PickColor(sv.actionBarReadyStyle, sv.actionBarReadyColor, r, g, b)
    glowR, glowG, glowB = PickColor(sv.actionBarGlowStyle, sv.actionBarGlowColor, r, g, b)
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

    local arrowTop = WINDOW_MANAGER:CreateTopLevelWindow("MyExtras_ActionBarArrowPanel")
    arrowTop:SetDrawLayer(DL_CONTROLS)
    arrowTop:SetDrawTier(DT_LOW)
    arrowTop:SetDrawLevel(2)
    arrowTop:SetHidden(true)
    self.arrowPanel = arrowTop
    self.arrowEdge = NewTexture("MyExtras_ActionBarArrowEdge", arrowTop, TEX_ARROW_EDGE, 1)
    self.arrowEdge:SetColor(0, 0, 0, 1)
    self.arrow = NewTexture("MyExtras_ActionBarArrow", arrowTop, TEX_ARROW, 2)

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

    self.food = CreateRound("MyExtras_ActionBarFood", miniTop, 1)
    self.food.value = NewLabel("MyExtras_ActionBarFoodValue", self.food, 11)
    self.food.value:SetColor(1, 1, 1, 1)
    self.food.value:SetHidden(true)
    self.delve = CreateRound("MyExtras_ActionBarDelve", miniTop, 1)
    self.delve.value = NewLabel("MyExtras_ActionBarDelveValue", self.delve, 11)
    self.delve.value:SetColor(1, 1, 1, 1)
    self.delve.value:SetHidden(true)
    self.delve.icon:SetTexture(GetAbilityIcon(DELVE_BUFF_ID))
    self.attack = CreateRound("MyExtras_ActionBarAttack", miniTop, 1)
    self.attack.value = NewLabel("MyExtras_ActionBarAttackValue", self.attack, 11)
    self.attack.value:SetColor(1, 1, 1, 1)
    self.attack.value:SetHidden(true)
    self.attack.icon:SetTexture(ATTACK_ICON)
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

local function SizeGlow(round, size)
    if not round.glow then return end
    round.glow:SetDimensions(zo_floor(size * GLOW_INNER), zo_floor(size * GLOW_INNER))
    round.glowOuter:SetDimensions(zo_floor(size * GLOW_OUTER), zo_floor(size * GLOW_OUTER))
end

local function LayoutRound(round, size)
    round:SetDimensions(size, size)
    SizeGlow(round, size)
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
    local miniSize = zo_floor(ringSize * 0.5)
    local miniPad  = zo_floor(ringSize * 0.14)
    local rowsX  = miniPad + ringSize + side + arrowW + gap
    local width  = rowsX + rowsW + side + ringSize + miniPad
    local height = rowsH + (showKeys and keyH or 0)

    panel:SetDimensions(width, height)
    self.panelHeight = height

    local backY = size + gap
    for i = 1, SLOT_COUNT do
        local x = rowsX + (i - 1) * (size + gap)
        LayoutSlot(back[i], panel, x, backY, size, border, edge)
        LayoutSlot(front[i], panel, x, 0, size, border, edge)

        local key = front[i].key
        key:ClearAnchors()
        key:SetAnchor(TOP, panel, TOPLEFT, x + zo_floor(size / 2), rowsH)
        key:SetDimensions(size, keyH)
        key:SetFont(Font(zo_floor(keyH * 0.8), "soft-shadow-thick"))
        key:SetHidden(not showKeys)
    end

    local arrowSize = zo_floor(size * 0.53)
    self.arrow:SetDimensions(arrowSize, arrowSize)
    self.arrowEdge:SetDimensions(arrowSize, arrowSize)
    self.rowLayout = {
        rowsX  = rowsX,
        size   = size,
        gap    = gap,
        backY  = backY,
        arrowX = miniPad + ringSize + side + zo_floor(arrowW / 2),
    }
    self:PlaceRows(true)

    local centerY = zo_floor(rowsH / 2)
    LayoutRing(self.potion, panel, miniPad + zo_floor(ringSize / 2), centerY, ringSize, 0.4, 0, rowsH, keyH, showKeys)
    LayoutRing(self.ultimate, panel, width - miniPad - zo_floor(ringSize / 2), centerY, ringSize, 0.3, NUMBER_DROP,
        rowsH, keyH, showKeys)

    local mini = self.ultimate.mini
    mini:ClearAnchors()
    mini:SetAnchor(CENTER, self.ultimate, BOTTOMRIGHT, -zo_floor(ringSize * 0.12), -zo_floor(ringSize * 0.1))
    LayoutRound(mini, miniSize)

    local food = self.food
    food:ClearAnchors()
    food:SetAnchor(CENTER, self.potion, BOTTOMLEFT, zo_floor(ringSize * 0.12), -zo_floor(ringSize * 0.1))
    LayoutRound(food, miniSize)
    food.value:ClearAnchors()
    food.value:SetAnchor(CENTER, food, CENTER, 0, 0)
    food.value:SetFont(Font(zo_floor(miniSize * 0.4)))

    local extraSize = miniSize
    local extras = {
        { self.delve,  zo_floor(ringSize * 0.237), zo_floor(ringSize * 0.015) },
        { self.attack, -zo_floor(ringSize * 0.047), zo_floor(ringSize * 0.428) },
    }
    for i = 1, #extras do
        local round, offsetX, offsetY = extras[i][1], extras[i][2], extras[i][3]
        round:ClearAnchors()
        round:SetAnchor(CENTER, self.potion, TOPLEFT, offsetX, offsetY)
        LayoutRound(round, extraSize)
        round.value:ClearAnchors()
        round.value:SetAnchor(CENTER, round, CENTER, 0, 0)
        round.value:SetFont(Font(zo_floor(extraSize * 0.4)))
    end
    self:ApplyStack()
    self:ApplyResourceLayout(GetControl("ZO_PlayerAttribute"))
end

function AB:ApplyPosition()
    if not self.panel then return end
    local sv = SV()
    local lift = 0
    if BuffsBelow() then
        lift = math.max(0, sv.actionBarPosY + BuffSpace() - GuiRoot:GetHeight())
    end
    self.panel:ClearAnchors()
    self.panel:SetAnchor(BOTTOM, GuiRoot, TOPLEFT, sv.actionBarPosX, sv.actionBarPosY - lift)
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

function AB:PlaceRows(force)
    local rows = self.rowLayout
    if not rows then return end
    local swapped = SV().actionBarStatic == true and activeBar == HOTBAR_CATEGORY_BACKUP
    if not force and self.rowsSwapped == swapped then return end
    self.rowsSwapped = swapped
    local activeY = swapped and rows.backY or 0
    local otherY  = swapped and 0 or rows.backY
    local panel = self.panel
    for i = 1, SLOT_COUNT do
        local x = rows.rowsX + (i - 1) * (rows.size + rows.gap)
        front[i]:ClearAnchors()
        front[i]:SetAnchor(TOPLEFT, panel, TOPLEFT, x, activeY)
        back[i]:ClearAnchors()
        back[i]:SetAnchor(TOPLEFT, panel, TOPLEFT, x, otherY)
    end
    local arrowY = activeY + zo_floor(rows.size / 2)
    self.arrow:ClearAnchors()
    self.arrow:SetAnchor(CENTER, panel, TOPLEFT, rows.arrowX, arrowY)
    self.arrowEdge:ClearAnchors()
    self.arrowEdge:SetAnchor(CENTER, panel, TOPLEFT, rows.arrowX, arrowY)
end

function AB:RefreshIcons()
    if not self.panel or not IsEnabled() then return end
    ResolveBars()
    self:PlaceRows()

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
    local speed = SV().actionBarPulseSpeed or 5
    return zo_floor(1000 / (speed * 2))
end

local function EnsureGlow(round)
    if round.glow then return end
    local name = round:GetName()
    round.glowOuter = NewTexture(name .. "GlowOuter", round, TEX_DISC, 0)
    round.glow = NewTexture(name .. "Glow", round, TEX_DISC, 0)
    round.glowOuter:SetAnchor(CENTER, round, CENTER, 0, 0)
    round.glow:SetAnchor(CENTER, round, CENTER, 0, 0)
    round.glow:SetHidden(true)
    round.glowOuter:SetHidden(true)
    SizeGlow(round, round:GetWidth())
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
            EnsureGlow(round)
            state.timeline = ANIMATION_MANAGER:CreateTimeline()
            state.fades = {}
            local targets = { round.fill, round.glow, round.glowOuter }
            for i = 1, #targets do
                local fade = state.timeline:InsertAnimation(ANIMATION_ALPHA, targets[i], 0)
                fade:SetAlphaValues(PULSE_LOW, 1)
                fade:SetEasingFunction(PulseEase)
                state.fades[i] = fade
            end
            state.timeline:SetPlaybackType(ANIMATION_PLAYBACK_PING_PONG, LOOP_INDEFINITELY)
        end
        local duration = PulseDuration()
        for i = 1, #state.fades do
            state.fades[i]:SetDuration(duration)
        end
        state.timeline:PlayFromStart()
    else
        if state.timeline then state.timeline:Stop() end
        round.fill:SetAlpha(1)
        if round.glow then
            round.glow:SetAlpha(1)
            round.glowOuter:SetAlpha(1)
        end
    end
end

local function IsPulsing(round)
    local state = pulses[round]
    return state ~= nil and state.on
end

local function ReadyOn(choice)
    return SV()[READY_KEYS[choice]] == true
end

local function ReadyFor(kind)
    return SV()[READY_ON_KEYS[kind]] == true
end

local function AnyReady()
    return ReadyOn("Pulsate") or ReadyOn("Glow") or ReadyOn("Color")
end

local function CanPulse()
    if not AnyReady() then return false end
    return inCombat or AB.preview
end

local function ShowGlow(round, on)
    if on then EnsureGlow(round) end
    if not round.glow then return end
    round.glow:SetColor(glowR, glowG, glowB, GLOW_INNER_A)
    round.glowOuter:SetColor(glowR, glowG, glowB, GLOW_OUTER_A)
    round.glow:SetHidden(not on)
    round.glowOuter:SetHidden(not on)
end

local function SetReady(round, on)
    on = on == true
    local pulsate = on and ReadyOn("Pulsate")
    local glow    = on and ReadyOn("Glow")
    local tint    = on and ReadyOn("Color")
    local key = (pulsate and "P" or "") .. (glow and "G" or "") .. (tint and "C" or "")
    round.readyOn = on
    if round.readyKey == key then return end
    round.readyKey = key
    round.readyTint = tint
    SetPulse(round, pulsate)
    ShowGlow(round, glow)
    if tint then
        round.fill:SetFillColor(readyR, readyG, readyB, 1)
    else
        round.fill:SetFillColor(ringR, ringG, ringB, 1)
    end
end

local function SetRingFill(ring, pct, r, g, b)
    if ring.readyTint then
        r, g, b = readyR, readyG, readyB
    end
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
        SetReady(ring, false)
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
    SetReady(ring, not onCooldown and count ~= nil and count > 0 and CanPulse() and ReadyFor("Potion"))

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
        shade = isBack and 0.7 or 1
    else
        SetRingFill(round, pct, ringR, ringG, ringB)
        shade = isBack and 0.45 or 0.3
    end
    round.icon:SetColor(shade, shade, shade, 1)
    SetReady(round, pct >= 1 and CanPulse() and ReadyFor("Ultimate"))
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
        SetReady(ring.mini, false)
    end

    if not ring.used then
        SetRingFill(ring, 0, ringR, ringG, ringB)
        SetReady(ring, false)
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
    self:UpdateFood()
end

--------------------------------------------------
-- Food
--------------------------------------------------
local function IsFood(abilityId, abilityType, effectType)
    if effectType == BUFF_EFFECT_TYPE_DEBUFF then return false end
    return FOOD_IDS[abilityId] == true or abilityType == ABILITY_TYPE_INTERACTIVES
end

local attackIcons = nil

local function AttackIcons()
    if attackIcons then return attackIcons end
    local typeData = SKILLS_DATA_MANAGER and SKILLS_DATA_MANAGER.GetSkillTypeData
        and SKILLS_DATA_MANAGER:GetSkillTypeData(SKILL_TYPE_AVA)
    if not typeData then return nil end
    local icons = {}
    for _, lineData in typeData:SkillLineIterator() do
        for _, skillData in lineData:SkillIterator() do
            if skillData:IsPassive() then
                for rank = 1, skillData:GetNumRanks() do
                    local rankData = skillData:GetRankData(rank)
                    local abilityId = rankData and rankData:GetAbilityId()
                    local icon = abilityId and GetAbilityIcon(abilityId)
                    if type(icon) == "string" and icon ~= "" then
                        icons[icon:lower()] = true
                    end
                end
            end
        end
    end
    attackIcons = icons
    return icons
end

local function AttackSkillIcon()
    local typeData = SKILLS_DATA_MANAGER and SKILLS_DATA_MANAGER.GetSkillTypeData
        and SKILLS_DATA_MANAGER:GetSkillTypeData(SKILL_TYPE_AVA)
    if not typeData then return nil end
    local best, bestLine
    for lineIndex, lineData in typeData:SkillLineIterator() do
        for _, skillData in lineData:SkillIterator() do
            if skillData:IsPassive() and skillData.GetLineRankNeededToPurchase
                and skillData:GetLineRankNeededToPurchase() == ATTACK_RANK then
                local progression = skillData.GetCurrentProgressionData and skillData:GetCurrentProgressionData()
                local icon = progression and progression.GetIcon and progression:GetIcon()
                if type(icon) == "string" and icon ~= "" and (not bestLine or lineIndex < bestLine) then
                    best, bestLine = icon, lineIndex
                end
            end
        end
    end
    return best
end

local function IsAttack(icon, ending)
    if not (ending and ending > 0) or type(icon) ~= "string" then return false end
    local icons = AttackIcons()
    return icons ~= nil and icons[icon:lower()] == true
end

local function InPvP()
    return IsPlayerInAvAWorld() or IsInImperialCity()
end

local function ShowOnRing(choice)
    return SV()[POTION_RING_KEYS[choice]] == true
end

local function SetRoundTimes(round, started, ending)
    if ending and ending > 0 and started and ending > started then
        round.started = started
        round.ending = ending
    else
        round.started = nil
        round.ending = nil
    end
    round.shown = nil
end

local function RoundActive(round)
    return round.ending ~= nil and round.ending > GetGameTimeSeconds()
end

local function UpdateTimedRound(round)
    if not round or round:IsHidden() then return end
    local remain = round.ending and (round.ending - GetGameTimeSeconds()) or 0
    if remain <= 0 then
        if round.shown ~= 0 then
            round.shown = 0
            SetRingFill(round, 0, ringR, ringG, ringB)
            round.icon:SetColor(FOOD_DIM, FOOD_DIM, FOOD_DIM, 1)
            round.value:SetHidden(true)
        end
        return
    end
    SetRingFill(round, remain / (round.ending - round.started), ringR, ringG, ringB)
    local minutes = zo_ceil(remain / 60)
    local shown
    if remain < 60 then
        shown = -zo_ceil(remain)
    elseif minutes <= FOOD_SHOW_MIN then
        shown = minutes
    else
        shown = 1000
    end
    if shown == round.shown then return end
    round.shown = shown
    round.icon:SetColor(1, 1, 1, 1)
    if shown == 1000 then
        round.value:SetHidden(true)
    elseif shown < 0 then
        SetLabel(round.value, -shown .. "s")
        round.value:SetHidden(false)
    else
        SetLabel(round.value, shown .. "m")
        round.value:SetHidden(false)
    end
end

function AB:SetFood(started, ending, icon)
    if icon and icon ~= "" then
        self.foodIcon = icon
        local cv = ME.charVariables
        if cv then cv.actionBarFoodIcon = icon end
    end
    if self.food then
        SetRoundTimes(self.food, started, ending)
        self.food.icon:SetTexture(self.foodIcon or GetAbilityIcon(FOOD_FALLBACK))
    end
end

function AB:SetBuffRound(round, started, ending, icon)
    if not round then return end
    SetRoundTimes(round, started, ending)
    if type(icon) == "string" and icon ~= "" then
        round.icon:SetTexture(icon)
        if round == self.attack then
            local account = ME.savedVariables
            if account then account.actionBarAttackIcon = icon end
        end
    end
end

local function PotionRingIcon(choice)
    local icon
    if choice == "Food" then
        icon = AB.foodIcon or GetAbilityIcon(FOOD_FALLBACK)
    elseif choice == "Delve" then
        icon = GetAbilityIcon(DELVE_BUFF_ID)
    elseif choice == "Attack" then
        local account = ME.savedVariables
        icon = account and account.actionBarAttackIcon
        if type(icon) ~= "string" or icon == "" then icon = AttackSkillIcon() or ATTACK_ICON end
    end
    if type(icon) == "string" and icon ~= "" then return icon end
end

function AB:ApplyPotionRings()
    if not self.food then return end
    local preview = self.preview or self.moving or ME.placing
    local pvp = InPvP()
    self.food:SetHidden(not ShowOnRing("Food"))
    self.delve:SetHidden(not (ShowOnRing("Delve") and (preview or pvp or RoundActive(self.delve))))
    self.attack:SetHidden(not (ShowOnRing("Attack") and (preview or pvp or RoundActive(self.attack))))
    self.food.shown = nil
    self.delve.shown = nil
    self.attack.shown = nil
end

function AB:SetAttackIcon()
    local account = ME.savedVariables
    local icon = account and account.actionBarAttackIcon
    if type(icon) ~= "string" or icon == "" then icon = AttackSkillIcon() end
    if type(icon) == "string" and icon ~= "" then self.attack.icon:SetTexture(icon) end
end

function AB:ScanFood()
    if attackIcons and next(attackIcons) == nil then attackIcons = nil end
    if self.attack and not self.attack.ending then self:SetAttackIcon() end
    local cv = ME.charVariables
    if not self.foodIcon and cv and type(cv.actionBarFoodIcon) == "string" then
        self.foodIcon = cv.actionBarFoodIcon
    end
    local food, delve, attack = false, false, false
    for i = 1, GetNumBuffs("player") do
        local _, started, ending, _, _, icon, _, effectType, abilityType, _, abilityId = GetUnitBuffInfo("player", i)
        if ending and ending > 0 and effectType ~= BUFF_EFFECT_TYPE_DEBUFF then
            if not food and IsFood(abilityId, abilityType, effectType) then
                self:SetFood(started, ending, icon)
                food = true
            elseif not delve and abilityId == DELVE_BUFF_ID then
                self:SetBuffRound(self.delve, started, ending, icon)
                delve = true
            elseif not attack and IsAttack(icon, ending) then
                self:SetBuffRound(self.attack, started, ending, icon)
                attack = true
            end
        end
    end
    if not food then self:SetFood(nil, nil, nil) end
    if not delve then self:SetBuffRound(self.delve) end
    if not attack then self:SetBuffRound(self.attack) end
    self:ApplyPotionRings()
end

function AB:OnEffectChanged(changeType, started, ending, icon, effectType, abilityType, abilityId)
    if effectType == BUFF_EFFECT_TYPE_DEBUFF then return end
    local faded = changeType == EFFECT_RESULT_FADED
    if IsFood(abilityId, abilityType, effectType) then
        if faded then self:ScanFood() else self:SetFood(started, ending, icon) end
    elseif abilityId == DELVE_BUFF_ID then
        if faded then self:SetBuffRound(self.delve) else self:SetBuffRound(self.delve, started, ending, icon) end
        self:ApplyPotionRings()
    elseif IsAttack(icon, ending) or (faded and self.attack and self.attack.ending and IsAttack(icon, 1)) then
        if faded then self:SetBuffRound(self.attack) else self:SetBuffRound(self.attack, started, ending, icon) end
        self:ApplyPotionRings()
    end
end

function AB:UpdateFood()
    UpdateTimedRound(self.food)
    UpdateTimedRound(self.delve)
    UpdateTimedRound(self.attack)
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
    self:ApplyPotionRings()
    if not self.panel then return end
    local show = self:ShouldShow()
    self.panel:SetHidden(not show)
    self.miniPanel:SetHidden(not show)
    self.arrowPanel:SetHidden(not show)

    if show and not ticking then
        ticking = true
        EVENT_MANAGER:RegisterForUpdate(ME.name .. "_ActionBar", UPDATE_MS, function() AB:Update() end)
        self:Update()
    elseif not show and ticking then
        ticking = false
        EVENT_MANAGER:UnregisterForUpdate(ME.name .. "_ActionBar")
        SetReady(self.potion, false)
        SetReady(self.ultimate, false)
        SetReady(self.ultimate.mini, false)
    end
end

function AB:RefreshReady()
    local rounds = { self.potion, self.ultimate, self.ultimate.mini }
    for i = 1, #rounds do
        local round = rounds[i]
        local wasReady = round.readyOn == true
        round.readyKey = nil
        SetReady(round, false)
        if wasReady then SetReady(round, true) end
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
        SetBarAnchor("ZO_PlayerAttributeMagicka", RIGHT, self.potion, LEFT, -(miniPad + gap), 0)
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

local function RestoreBuffs(container)
    local element
    if HUD_MANAGER then
        if IsInGamepadPreferredMode() then
            if HUD_MANAGER.GetGamepadElementForControl then
                element = HUD_MANAGER:GetGamepadElementForControl(container)
            end
        elseif HUD_MANAGER.GetKeyboardElementForControl then
            element = HUD_MANAGER:GetKeyboardElementForControl(container)
        end
    end
    if element and element.RevertOffsetModifications then
        element:RevertOffsetModifications()
        return
    end
    local bars = GetControl("ZO_PlayerAttribute")
    if not bars then return end
    container:ClearAnchors()
    container:SetAnchor(CENTER, bars, TOP, 0, -40)
end

function AB:ApplyBuffs()
    local container = GetControl(BUFF_CONTAINER)
    if not (container and self.panel) then return end
    if BuffsBelow() then
        container:ClearAnchors()
        container:SetAnchor(TOP, self.panel, BOTTOM, 0, BUFF_GAP)
        self.buffsMoved = true
    elseif self.buffsMoved then
        self.buffsMoved = false
        RestoreBuffs(container)
    end
end

function AB:HookBuffs()
    if self.buffsHooked or not (HUD_MANAGER and HUD_MANAGER.RegisterCallback) then return end
    self.buffsHooked = true
    HUD_MANAGER:RegisterCallback("PropagateSettings", function()
        if AB.buffsMoved then AB:ApplyBuffs() end
    end)
end

local function StackTarget()
    if SV().actionBarBuffs ~= "Below" then
        for i = 1, #BUFF_ROWS do
            local row = GetControl(BUFF_ROWS[i])
            if row and not row:IsHidden() and row:GetHeight() > 0 then
                local container = GetControl(BUFF_CONTAINER)
                if container then return container, 0 end
            end
        end
    end
    local bars = GetControl("ZO_PlayerAttribute")
    if not bars then return nil end
    return bars, IsInGamepadPreferredMode() and 0 or KEYBOARD_BAR_INSET
end

local function PromptReach()
    local base = GetControl(PROMPT_BASE)
    local baseBottom = base and base:GetBottom()
    if not baseBottom then return PROMPT_GUESS end
    local lowest
    for i = 1, #PROMPT_PARTS do
        local part = GetControl(PROMPT_PARTS[i])
        if part and not part:IsHidden() and part:GetHeight() > 0 then
            local bottom = part:GetBottom()
            if bottom and bottom > 0 then
                lowest = lowest and math.max(lowest, bottom) or bottom
            end
        end
    end
    if not lowest then return PROMPT_GUESS end
    return math.max(0, zo_ceil(lowest - baseBottom))
end

function AB:ApplyStack()
    local name = ME.name .. "_ActionBarStack"
    EVENT_MANAGER:UnregisterForUpdate(name)
    EVENT_MANAGER:RegisterForUpdate(name, STACK_DELAY, function()
        EVENT_MANAGER:UnregisterForUpdate(name)
        AB:PlaceStack()
    end)
end

function AB:PinStack(name, target, offsetY)
    local control = GetControl(name)
    if not control then return end
    self.stackAnchors = self.stackAnchors or {}
    if not self.stackAnchors[name] then
        local isValid, point, relativeTo, relativePoint, offsetX, originalY = control:GetAnchor(0)
        if not isValid then return end
        self.stackAnchors[name] = { point, relativeTo, relativePoint, offsetX, originalY }
    end
    local _, point, relativeTo, relativePoint, offsetX, currentY = control:GetAnchor(0)
    if point == BOTTOM and relativeTo == target and relativePoint == TOP
        and offsetX == 0 and currentY == offsetY then
        return
    end
    control:ClearAnchors()
    control:SetAnchor(BOTTOM, target, TOP, 0, offsetY)
end

function AB:UnpinStack()
    local anchors = self.stackAnchors
    if not anchors then return end
    for name, anchor in pairs(anchors) do
        local control = GetControl(name)
        if control then
            control:ClearAnchors()
            control:SetAnchor(anchor[1], anchor[2], anchor[3], anchor[4], anchor[5])
        end
    end
    self.stackAnchors = nil
end

function AB:PlaceStack()
    if self.placingStack or not self.panelHeight then return end
    self.placingStack = true
    if not IsEnabled() then
        self:UnpinStack()
    else
        local target, inset = StackTarget()
        if target then
            local offsetY = inset - STACK_GAP
            self:PinStack(PROMPT_BASE, target, offsetY - PromptReach())
            for i = 1, #STACK_PLACED do
                self:PinStack(STACK_PLACED[i], target, offsetY)
            end
        end
    end
    self.placingStack = false
end

function AB:WatchStack()
    if self.stackWatched then return end
    self.stackWatched = true
    local function OnStackChanged()
        if IsEnabled() then AB:ApplyStack() end
    end
    local function OnPlacedMoved()
        if IsEnabled() then AB:PlaceStack() end
    end
    for i = 1, #FLOOR_CONTROLS do
        local control = GetControl(FLOOR_CONTROLS[i])
        if control then control:SetHandler("OnRectChanged", OnStackChanged, ME.name) end
    end
    for i = 1, #BUFF_ROWS do
        local row = GetControl(BUFF_ROWS[i])
        if row then
            row:SetHandler("OnRectChanged", OnStackChanged, ME.name)
            row:SetHandler("OnEffectivelyShown", OnStackChanged, ME.name)
            row:SetHandler("OnEffectivelyHidden", OnStackChanged, ME.name)
        end
    end
    local base = GetControl(PROMPT_BASE)
    if base then base:SetHandler("OnEffectivelyShown", OnStackChanged, ME.name) end
    for i = 1, #PROMPT_PARTS do
        local part = GetControl(PROMPT_PARTS[i])
        if part then
            part:SetHandler("OnRectChanged", OnStackChanged, ME.name)
            part:SetHandler("OnEffectivelyShown", OnStackChanged, ME.name)
        end
    end
    for i = 1, #STACK_PLACED do
        local control = GetControl(STACK_PLACED[i])
        if control then
            control:SetHandler("OnEffectivelyShown", OnPlacedMoved, ME.name)
            control:SetHandler("OnRectChanged", OnPlacedMoved, ME.name)
        end
    end
    if base then base:SetHandler("OnRectChanged", OnPlacedMoved, ME.name) end
    if HUD_MANAGER and HUD_MANAGER.RegisterCallback then
        HUD_MANAGER:RegisterCallback("PropagateSettings", OnPlacedMoved)
    end
    if SYNERGY and SYNERGY.ApplyTextStyle then
        ZO_PostHook(SYNERGY, "ApplyTextStyle", OnPlacedMoved)
    end
    EVENT_MANAGER:RegisterForEvent(ME.name .. "_ActionBarSynergy", EVENT_SYNERGY_ABILITY_CHANGED, OnPlacedMoved)
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
    self:RefreshReady()
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
    self:ApplyBuffs()
    self:ApplyStack()
    self:RefreshIcons()
    self:ScanFood()
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
    ME:RaiseWhilePlacing({ self.panel, self.miniPanel, self.arrowPanel }, true)
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
    ME:RaiseWhilePlacing({ self.panel, self.miniPanel, self.arrowPanel }, false)
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

    local foodName = name .. "_Food"
    EVENT_MANAGER:RegisterForEvent(foodName, EVENT_EFFECT_CHANGED,
        function(_, changeType, _, _, _, started, ending, _, icon, _, effectType, abilityType, _, _, _, abilityId)
            AB:OnEffectChanged(changeType, started, ending, icon, effectType, abilityType, abilityId)
        end)
    EVENT_MANAGER:AddFilterForEvent(foodName, EVENT_EFFECT_CHANGED, REGISTER_FILTER_UNIT_TAG, "player")
    EVENT_MANAGER:RegisterForEvent(foodName, EVENT_PLAYER_ACTIVATED, function() AB:ScanFood() end)

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
    if self.panel then return { self.panel, self.miniPanel, self.arrowPanel } end
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
            tooltip = function()
                return "Turn off any other action bar addon while this is enabled.\n\n" .. SavedTip()
            end,
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
                    type    = "toggle",
                    name    = "Character Settings",
                    tooltip = "Off uses the same settings for the whole account. On gives this character its own settings, "
                           .. "copied from the account settings the first time you turn it on.",
                    details = function()
                        if AB:UsesCharacterSettings() then
                            return "This character has its own settings."
                        end
                        return "All your characters share the same settings."
                    end,
                    getFunc = function() return AB:UsesCharacterSettings() end,
                    setFunc = function(val) AB:SetUseCharacterSettings(val) end,
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
                    type     = "submenu",
                    name     = "Layout",
                    disabled = IsOff,
                    tooltip  = "Where and how your action bar shows.",
                    options  = {
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
                            type     = "toggle",
                            name     = "Static Bars",
                            preset   = "YES_NO",
                            default  = defaults.actionBarStatic,
                            details  = function()
                                if SV().actionBarStatic then
                                    return "Your front bar stays on top and the arrow moves to the bar you're using."
                                end
                                return "The bar you're using moves to the top when you swap."
                            end,
                            disabled = IsOff,
                            getFunc  = function() return SV().actionBarStatic end,
                            setFunc  = function(val)
                                SV().actionBarStatic = val
                                AB:PlaceRows(true)
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
                            type     = "dropdown",
                            name     = "Buffs / Debuffs",
                            choices  = AB.buffChoices,
                            default  = defaults.actionBarBuffs,
                            disabled = IsOff,
                            details  = function()
                                if SV().actionBarBuffs == "Below" then
                                    return "Buffs and debuffs sit below the action bar."
                                end
                                return "Buffs and debuffs sit above your health, magicka and stamina."
                            end,
                            getFunc  = function() return SV().actionBarBuffs end,
                            setFunc  = function(val)
                                SV().actionBarBuffs = val
                                AB:ApplyPosition()
                                AB:ApplyBuffs()
                            end,
                        },
                    },
                },
                {
                    type     = "submenu",
                    name     = "Appearance",
                    disabled = IsOff,
                    tooltip  = "Colors for your rings, arrow and skill timers.",
                    options  = {
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
                            sample       = function() return "18", Font(40), numR, numG, numB end,
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
                    },
                },
                {
                    type     = "submenu",
                    name     = "Ultimate & Potion",
                    disabled = IsOff,
                    tooltip  = "Your ultimate number and how your potion and ultimate rings show they're ready.",
                    options  = {
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
                            type     = "checklist",
                            name     = "Potion Ring",
                            choices  = AB.potionRingChoices,
                            default  = { "Food" },
                            details  = function()
                                local shown = {}
                                for i = 1, #AB.potionRingChoices do
                                    local value = AB.potionRingChoices[i].value
                                    if ShowOnRing(value) then
                                        local icon = PotionRingIcon(value)
                                        if icon then shown[#shown + 1] = zo_iconFormat(icon, 48, 48) end
                                    end
                                end
                                return table.concat(shown, "  ")
                            end,
                            tooltip  = "What shows in the small rings around your potion.",
                            disabled = IsOff,
                            getFunc  = function()
                                local values = {}
                                for i = 1, #AB.potionRingChoices do
                                    local value = AB.potionRingChoices[i].value
                                    if ShowOnRing(value) then values[#values + 1] = value end
                                end
                                return values
                            end,
                            setFunc  = function(values)
                                local sv = SV()
                                local set = {}
                                if type(values) == "table" then
                                    for i = 1, #values do set[values[i]] = true end
                                end
                                for value, key in pairs(POTION_RING_KEYS) do
                                    sv[key] = set[value] == true
                                end
                                AB:ApplyPotionRings()
                                if ticking then AB:Update() end
                            end,
                        },
                        {
                            type     = "checklist",
                            name     = "When Ready",
                            choices  = AB.readyChoices,
                            default  = { "Pulsate" },
                            tooltip  = "How your potion and ultimate rings show they're ready to use in combat.",
                            disabled = IsOff,
                            getFunc  = function()
                                local values = {}
                                for i = 1, #AB.readyChoices do
                                    local value = AB.readyChoices[i].value
                                    if ReadyOn(value) then values[#values + 1] = value end
                                end
                                return values
                            end,
                            setFunc  = function(values)
                                local sv = SV()
                                local set = {}
                                if type(values) == "table" then
                                    for i = 1, #values do set[values[i]] = true end
                                end
                                for value, key in pairs(READY_KEYS) do
                                    sv[key] = set[value] == true
                                end
                                AB:RefreshReady()
                                if ticking then AB:Update() end
                            end,
                        },
                        {
                            type     = "checklist",
                            name     = "Apply To",
                            choices  = AB.readyOnChoices,
                            default  = { "Ultimate" },
                            tooltip  = "Which rings use your When Ready effects.",
                            disabled = function() return IsOff() or not AnyReady() end,
                            getFunc  = function()
                                local values = {}
                                for i = 1, #AB.readyOnChoices do
                                    local value = AB.readyOnChoices[i].value
                                    if ReadyFor(value) then values[#values + 1] = value end
                                end
                                return values
                            end,
                            setFunc  = function(values)
                                local sv = SV()
                                local set = {}
                                if type(values) == "table" then
                                    for i = 1, #values do set[values[i]] = true end
                                end
                                for value, key in pairs(READY_ON_KEYS) do
                                    sv[key] = set[value] == true
                                end
                                SetReady(AB.potion, false)
                                SetReady(AB.ultimate, false)
                                SetReady(AB.ultimate.mini, false)
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
                            disabled = function() return IsOff() or not ReadyOn("Pulsate") end,
                            getFunc  = function() return SV().actionBarPulseSpeed end,
                            setFunc  = function(val)
                                SV().actionBarPulseSpeed = val
                                AB:RestartPulses()
                            end,
                        },
                        {
                            type         = "stylecolor",
                            name         = ME.RainbowText("Glow Color"),
                            choices      = { "Alliance", "Custom" },
                            customValue  = "Custom",
                            default      = defaults.actionBarGlowStyle,
                            colorDefault = { r = 1, g = 0.82, b = 0.2 },
                            disabled     = function() return IsOff() or not ReadyOn("Glow") end,
                            details      = function()
                                if SV().actionBarGlowStyle == "Custom" then
                                    return "Your rings glow in your color when they're ready to use."
                                end
                                return "Your rings glow in your alliance color when they're ready to use."
                            end,
                            getFunc  = function() return SV().actionBarGlowStyle end,
                            setFunc  = function(val)
                                SV().actionBarGlowStyle = val
                                AB:ApplyColors()
                            end,
                            getColor = function()
                                local c = SV().actionBarGlowColor
                                if type(c) == "table" then return c.r or 1, c.g or 0.82, c.b or 0.2 end
                                return 1, 0.82, 0.2
                            end,
                            setColor = function(r, g, b)
                                SV().actionBarGlowColor = { r = r, g = g, b = b, a = 1 }
                                AB:ApplyColors()
                            end,
                        },
                        {
                            type         = "stylecolor",
                            name         = ME.RainbowText("Ready Color"),
                            choices      = { "Alliance", "Custom" },
                            customValue  = "Custom",
                            default      = defaults.actionBarReadyStyle,
                            colorDefault = { r = 1, g = 0.82, b = 0.2 },
                            disabled     = function() return IsOff() or not ReadyOn("Color") end,
                            details      = function()
                                local sv = SV()
                                if sv.actionBarReadyStyle == "Custom" then
                                    return "Your rings change to your color when they're ready to use."
                                end
                                if sv.actionBarRingStyle ~= "Custom" then
                                    return "Your rings already use your alliance color, so pick Custom to see a change."
                                end
                                return "Your rings change to your alliance color when they're ready to use."
                            end,
                            getFunc  = function() return SV().actionBarReadyStyle end,
                            setFunc  = function(val)
                                SV().actionBarReadyStyle = val
                                AB:ApplyColors()
                            end,
                            getColor = function()
                                local c = SV().actionBarReadyColor
                                if type(c) == "table" then return c.r or 1, c.g or 0.82, c.b or 0.2 end
                                return 1, 0.82, 0.2
                            end,
                            setColor = function(r, g, b)
                                SV().actionBarReadyColor = { r = r, g = g, b = b, a = 1 }
                                AB:ApplyColors()
                            end,
                        },
                    },
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
    local account = ME.savedVariables
    if account then
        account.actionBarPromptReach = nil
        account.actionBarPromptSpace = nil
        account.actionBarReadout = nil
    end
    local saved = { account, SV() }
    for i = 1, #saved do
        local sv = saved[i]
        if type(sv) == "table" then
            if sv.actionBarPulse == false then
                sv.actionBarReadyPulsate = false
                sv.actionBarReadyGlow = false
                sv.actionBarReadyTint = false
            end
            sv.actionBarPulse = nil
            local mode = sv.actionBarReady
            if type(mode) == "string" then
                sv.actionBarReadyPulsate = mode == "Pulsate"
                sv.actionBarReadyGlow = mode == "Glow" or mode == "GlowColor"
                sv.actionBarReadyTint = mode == "Color" or mode == "GlowColor"
            end
            sv.actionBarReady = nil
            local readyOn = sv.actionBarReadyOn
            if type(readyOn) == "string" then
                sv.actionBarReadyUltimate = readyOn ~= "Potion"
                sv.actionBarReadyPotion = readyOn ~= "Ultimate"
            end
            sv.actionBarReadyOn = nil
        end
    end
    self:CreatePanel()
    self:HookResourceBars()
    self:HookBuffs()
    self:WatchStack()
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

function AB:SetUseCharacterSettings(value)
    local cv = ME.charVariables
    if not cv then return end
    value = value == true
    if (cv.actionBarUseCharacter == true) == value then return end
    cv.actionBarUseCharacter = value
    if not IsEnabled() then self.preview = false end
    self:Refresh()
    local panel = ME.settingsPanel
    if panel and panel.Refresh then panel:Refresh() end
end

function AB:ResetSkipKeys()
    local keys = {}
    if self:UsesCharacterSettings() then
        for key in pairs(self.defaults) do keys[#keys + 1] = key end
    end
    return keys
end

function AB:OnReset()
    self.preview = false
    if self:UsesCharacterSettings() then
        local settings = CharSettings()
        if settings then
            for key, value in pairs(self.defaults) do
                if type(value) == "table" then
                    local copy = {}
                    for k, v in pairs(value) do copy[k] = v end
                    settings[key] = copy
                else
                    settings[key] = value
                end
            end
            settings.seeded = true
        end
    end
    self:Refresh()
end

ME:RegisterFeature(AB)
