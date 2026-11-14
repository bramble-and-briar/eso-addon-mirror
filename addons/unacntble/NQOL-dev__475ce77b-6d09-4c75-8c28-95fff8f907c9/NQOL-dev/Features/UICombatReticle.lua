NQOL = NQOL or {}
NQOL.Features = NQOL.Features or {}

local UI = NQOL.Features.UI

local APPLY_DELAY_MS = 50
local ANIMATION_UPDATE_MS = 25
local TARGET_EFFECT_UPDATE_MS = 100
local EVENT_NAMESPACE = "NQOL_UI_CombatReticle"
local UPDATE_NAMESPACE = "NQOL_UI_CombatReticle_Update"
local TARGET_EFFECT_EVENT_NAMESPACE = EVENT_NAMESPACE .. "_TargetEffects"
local TARGET_EFFECT_UPDATE_NAMESPACE = UPDATE_NAMESPACE .. "_TargetEffects"
local HIT_INDICATOR_DURATION_MS = 750
local SHAPE_DEFAULT = "default"
local SHOW_WHEN = {
    default = "always",
    choices = { "never", "always", "inCombat", "outOfCombat" },
    names = NQOL.Lexicon.LocalizedList({
        "features.ui_combat_reticle.show_when_never",
        "features.ui_combat_reticle.show_when_always",
        "features.ui_combat_reticle.show_when_in_combat",
        "features.ui_combat_reticle.show_when_out_of_combat",
    }),
    valid = { never = true, always = true, inCombat = true, outOfCombat = true },
}
local RETICLE_DEFAULT_TEXTURE = "EsoUI/Art/Reticle/reticleAnim.dds"
local DEFAULT_COLOR = { r = 1, g = 1, b = 1, a = 1 }
local DEFAULT_FIGHT_COLOR = { r = 1, g = 1, b = 1, a = 1 }
local OPEN_ANIMATION_SCALE = 1
local CLOSED_ANIMATION_SCALE = 0.72
local ANIMATION_SCALE_STEP = 0.07
local SCALE_DEFAULT = 1
local SCALE_MIN = 1
local SCALE_MAX = 10
local ARCANIST_CLASS_ID = 117
local CRUX_ABILITY_ID = 184220
local CRUX_EVENT_NAMESPACE = EVENT_NAMESPACE .. "_Crux"
local OFF_BALANCE_ICON_ABILITY_ID = 39077
local OFF_BALANCE_IMMUNITY_ABILITY_ID = 134599
local TAUNT_ICON_ABILITY_ID = 38254
local TAUNT_ABILITY_IDS = { [38254] = true, [38541] = true }
local ZENS_REDRESS_SET_ID = 455
local ZENS_REDRESS_REQUIRED_PIECES = 5
local ZENS_REDRESS_ABILITY_ID = 126593
local ZENS_TOUCH_ABILITY_ID = 126597
local ZENS_EVENT_NAMESPACE = EVENT_NAMESPACE .. "_ZensRedress"
local SUL_XAN = {
    SOUL_ABILITY_ID = 154720,
    BUFF_ABILITY_ID = 154737,
    SOUL_EVENT_NAMESPACE = EVENT_NAMESPACE .. "_SulXanSoul",
    BUFF_EVENT_NAMESPACE = EVENT_NAMESPACE .. "_SulXanBuff",
    UPDATE_NAMESPACE = UPDATE_NAMESPACE .. "_SulXan",
    UPDATE_MS = 100,
    soulEndTime = 0,
    buffEndTime = 0,
    eventsInstalled = false,
    updateLoopInstalled = false,
}
local OFF_BALANCE_ABILITY_IDS = NQOL.Data and NQOL.Data.OffBalanceAbilityIds or {}
local RETICLE_INFO_FONT_SIZE_DEFAULT = 28
local RETICLE_INFO_FONT_SIZE_MIN = 12
local RETICLE_INFO_FONT_SIZE_MAX = 60
local RETICLE_INFO_ICON_FONT_SCALE = 0.8
local RETICLE_INFO_OFFSET_MIN = -500
local RETICLE_INFO_OFFSET_MAX = 500
local RETICLE_INFO_WIDTH = 200
local RETICLE_INFO_HEIGHT = 42
local RETICLE_INFO_ROOT_SIZE = 1200
local RETICLE_INFO_CONTENT_DEFAULT = "off"
local RETICLE_INFO_CONTENT_CHOICES = { RETICLE_INFO_CONTENT_DEFAULT, "crux", "offBalance", "offBalanceImmunity", "taunt", "sulXan", "zensRedress" }
local RETICLE_INFO_CONTENT_NAMES = NQOL.Lexicon.LocalizedList({
    "common.off",
    "features.ui_combat_reticle.crux_tracker",
    "features.ui_combat_reticle.off_balance_tracker",
    "features.ui_combat_reticle.off_balance_immunity_tracker",
    "features.ui_combat_reticle.taunt_remaining_tracker",
    { "features.ui_combat_reticle.sul_xan_tracker", GetAbilityName and GetAbilityName(SUL_XAN.BUFF_ABILITY_ID) or "" },
    { "features.ui_combat_reticle.zens_redress_tracker", GetAbilityName and GetAbilityName(ZENS_REDRESS_ABILITY_ID) or "" },
})
local RETICLE_INFO_ICON_POSITION_DEFAULT = "off"
local RETICLE_INFO_ICON_POSITION_CHOICES = { RETICLE_INFO_ICON_POSITION_DEFAULT, "left", "right" }
local RETICLE_INFO_ICON_POSITION_NAMES = NQOL.Lexicon.LocalizedList({ "common.off", "common.left", "common.right" })
local RETICLE_INFO_ICON_POSITION_VALID = { off = true, left = true, right = true }
local RETICLE_INFO_POSITION_KEYS = { "topLeft", "topRight", "bottomLeft", "bottomRight" }
local RETICLE_INFO_POSITION_CONFIG = {
    topLeft = { labelKey = "features.ui_combat_reticle.top_left_label", horizontalOffset = -60, verticalOffset = -30 },
    topRight = { labelKey = "features.ui_combat_reticle.top_right_label", horizontalOffset = 60, verticalOffset = -30 },
    bottomLeft = { labelKey = "features.ui_combat_reticle.bottom_left_label", horizontalOffset = -60, verticalOffset = 30 },
    bottomRight = { labelKey = "features.ui_combat_reticle.bottom_right_label", horizontalOffset = 60, verticalOffset = 30 },
}
local ZENS_EQUIP_SLOTS = {
    EQUIP_SLOT_HEAD,
    EQUIP_SLOT_NECK,
    EQUIP_SLOT_CHEST,
    EQUIP_SLOT_SHOULDERS,
    EQUIP_SLOT_MAIN_HAND,
    EQUIP_SLOT_OFF_HAND,
    EQUIP_SLOT_WAIST,
    EQUIP_SLOT_LEGS,
    EQUIP_SLOT_FEET,
    EQUIP_SLOT_RING1,
    EQUIP_SLOT_RING2,
    EQUIP_SLOT_HAND,
    EQUIP_SLOT_BACKUP_MAIN,
    EQUIP_SLOT_BACKUP_OFF,
}
local SHAPES = {
    SHAPE_DEFAULT,
    "dot",
    "bigDot",
    "cross",
    "plus",
    "ring",
    "ringDot",
    "xCross",
    "diamond",
    "chevron",
    "tShape",
    "brackets",
    "duplex",
}
local SHAPE_NAMES = NQOL.Lexicon.LocalizedList({
    "features.ui_combat_reticle.shape_default", "features.ui_combat_reticle.shape_dot",
    "features.ui_combat_reticle.shape_big_dot", "features.ui_combat_reticle.shape_gap_cross",
    "features.ui_combat_reticle.shape_plus", "features.ui_combat_reticle.shape_ring",
    "features.ui_combat_reticle.shape_ring_dot", "features.ui_combat_reticle.shape_x_cross",
    "features.ui_combat_reticle.shape_diamond", "features.ui_combat_reticle.shape_chevron",
    "features.ui_combat_reticle.shape_t_shape", "features.ui_combat_reticle.shape_brackets",
    "features.ui_combat_reticle.shape_duplex",
})
local SHAPE_STYLES = {
    dot = { controlType = "dds", textureFile = "nqol_dot.dds", width = 32, height = 32 },
    bigDot = { controlType = "dds", textureFile = "nqol_big_dot.dds", width = 32, height = 32 },
    cross = { controlType = "dds", textureFile = "nqol_gap_cross.dds", width = 32, height = 32 },
    plus = { controlType = "dds", textureFile = "nqol_plus.dds", width = 32, height = 32 },
    ring = { controlType = "dds", textureFile = "nqol_ring.dds", width = 32, height = 32 },
    ringDot = { controlType = "dds", textureFile = "nqol_ring_dot.dds", width = 32, height = 32 },
    xCross = { controlType = "dds", textureFile = "nqol_x.dds", width = 32, height = 32 },
    diamond = { controlType = "dds", textureFile = "nqol_diamond.dds", width = 32, height = 32 },
    chevron = { controlType = "dds", textureFile = "nqol_chevron.dds", width = 32, height = 32 },
    tShape = { controlType = "dds", textureFile = "nqol_t.dds", width = 32, height = 32 },
    brackets = { controlType = "dds", textureFile = "nqol_brackets.dds", width = 32, height = 32 },
    duplex = { controlType = "dds", textureFile = "nqol_duplex.dds", width = 32, height = 32 },
}
local GAMEPLAY_SCENES = {
    hud = true,
    hudui = true,
    siegeBar = true,
    siegeBarUI = true,
}
local SHAPE_VALID = {
    default = true,
    dot = true,
    bigDot = true,
    cross = true,
    plus = true,
    ring = true,
    ringDot = true,
    xCross = true,
    diamond = true,
    chevron = true,
    tShape = true,
    brackets = true,
    duplex = true,
}

local applyQueued = false
local initialized = false
local hooksInstalled = false
local hookAttempts = 0
local eventsInstalled = false
local runtimeActive = false
local settingsPreviewVisible = false
local visibilitySuppressed = false
local updateLoopInstalled = false
local sceneCallbackInstalled = false
local appliedShape
local appliedTexturePath
local appliedPreviewTexturePath
local animationScale = OPEN_ANIMATION_SCALE
local inFight = false
local customRoot
local customTexture
local previewRoot
local previewTexture
local reticleInfoRoot
local reticleInfoLabels = {}
local cruxCount = 0
local cruxEventsInstalled = false
local offBalanceEndTime = 0
local offBalanceAbilityId = OFF_BALANCE_ICON_ABILITY_ID
local offBalanceImmunityEndTime = 0
local tauntEndTime = 0
local targetEffectEventsInstalled = false
local targetEffectUpdateLoopInstalled = false
local zensStacks = 0
local zensFivePieceEquipped = false
local zensEventsInstalled = false
local RefreshAnimationLoop
local RefreshReticleRuntime
local ScanCruxCount
local ScanTargetEffectEndTimes
local ScanZensStacks
local RefreshZensEquipmentState

local function GetSettings()
    return UI.GetCombatReticleSettings()
end

local function GetShowWhen()
    local settings = GetSettings()
    if SHOW_WHEN.valid[settings.showWhen] ~= true then
        settings.showWhen = SHOW_WHEN.default
    end
    return settings.showWhen
end

local function ShouldShowReticle()
    local showWhen = GetShowWhen()
    return showWhen == "always" or (showWhen == "inCombat" and inFight) or (showWhen == "outOfCombat" and not inFight)
end

local function GetShape()
    local settings = GetSettings()
    local shape = settings.shape
    if SHAPE_VALID[shape] ~= true then
        shape = SHAPE_DEFAULT
        settings.shape = shape
    end

    return shape
end

local function IsReticleRuntimeActive()
    return runtimeActive
end

local function UsesCustomShape()
    return GetShape() ~= SHAPE_DEFAULT
end

local function GetReticleInfoPositionSettings(positionKey)
    local infoSettings = GetSettings().info
    return infoSettings and infoSettings[positionKey] or nil
end

local function HasEnabledReticleInfo()
    for _, positionKey in ipairs(RETICLE_INFO_POSITION_KEYS) do
        local settings = GetReticleInfoPositionSettings(positionKey)
        if settings and settings.content ~= RETICLE_INFO_CONTENT_DEFAULT then
            return true
        end
    end

    return false
end

local function HasCruxCapableSkillLine()
    if GetNumSkillLines and GetSkillLineClassId and GetSkillLineDynamicInfo and SKILL_TYPE_CLASS then
        for skillLineIndex = 1, GetNumSkillLines(SKILL_TYPE_CLASS) do
            if GetSkillLineClassId(SKILL_TYPE_CLASS, skillLineIndex) == ARCANIST_CLASS_ID then
                local _, _, isActive = GetSkillLineDynamicInfo(SKILL_TYPE_CLASS, skillLineIndex)
                if isActive == true then
                    return true
                end
            end
        end
    end

    return GetUnitClassId and GetUnitClassId("player") == ARCANIST_CLASS_ID
end

local function UsesCruxTracker()
    if not HasCruxCapableSkillLine() then
        return false
    end

    for _, positionKey in ipairs(RETICLE_INFO_POSITION_KEYS) do
        local settings = GetReticleInfoPositionSettings(positionKey)
        if settings and settings.content == "crux" then
            return true
        end
    end

    return false
end

local function UsesTargetEffectTracker()
    for _, positionKey in ipairs(RETICLE_INFO_POSITION_KEYS) do
        local settings = GetReticleInfoPositionSettings(positionKey)
        if settings and (settings.content == "offBalance" or settings.content == "offBalanceImmunity" or settings.content == "taunt") then
            return true
        end
    end

    return false
end

local function UsesZensTracker()
    for _, positionKey in ipairs(RETICLE_INFO_POSITION_KEYS) do
        local settings = GetReticleInfoPositionSettings(positionKey)
        if settings and settings.content == "zensRedress" then
            return true
        end
    end

    return false
end

function SUL_XAN.UsesTracker()
    for _, positionKey in ipairs(RETICLE_INFO_POSITION_KEYS) do
        local settings = GetReticleInfoPositionSettings(positionKey)
        if settings and settings.content == "sulXan" then
            return true
        end
    end

    return false
end

function SUL_XAN.GetDisplayState()
    local currentTime = GetFrameTimeSeconds and GetFrameTimeSeconds() or 0
    if SUL_XAN.buffEndTime > currentTime then
        return SUL_XAN.buffEndTime, SUL_XAN.BUFF_ABILITY_ID
    elseif SUL_XAN.soulEndTime > currentTime then
        return SUL_XAN.soulEndTime, SUL_XAN.SOUL_ABILITY_ID
    end

    return 0, SUL_XAN.BUFF_ABILITY_ID
end

local function HasFivePieceZensEquipped()
    if not GetItemLink or not GetItemLinkSetInfo or not BAG_WORN then
        return false
    end

    local pieceCount = 0
    for _, equipSlot in ipairs(ZENS_EQUIP_SLOTS) do
        local itemLink = GetItemLink(BAG_WORN, equipSlot)
        if itemLink and itemLink ~= "" then
            local hasSet, _, _, _, _, setId = GetItemLinkSetInfo(itemLink)
            if hasSet == true and setId == ZENS_REDRESS_SET_ID then
                local pieceValue = 1
                if GetItemEquipType and EQUIP_TYPE_TWO_HAND and GetItemEquipType(BAG_WORN, equipSlot) == EQUIP_TYPE_TWO_HAND then
                    pieceValue = 2
                end
                pieceCount = pieceCount + pieceValue
                if pieceCount >= ZENS_REDRESS_REQUIRED_PIECES then
                    return true
                end
            end
        end
    end

    return false
end

local function GetScale()
    local scale = tonumber(GetSettings().scale) or SCALE_DEFAULT
    scale = NQOL.Util.Clamp(scale, SCALE_MIN, SCALE_MAX)
    return math.floor(scale + 0.5)
end

local function IsAnimatedReticleEnabled()
    return GetSettings().animated == true
end

local function RefreshFightState()
    inFight = IsUnitInCombat and IsUnitInCombat("player") == true
end

local function SetControlScale(control, scale)
    if control and control.SetScale and (not control.GetScale or control:GetScale() ~= scale) then
        control:SetScale(scale)
    end
end

local function RestoreVanillaReticleControls()
    SetControlScale(ZO_ReticleContainerReticle, 1)
    SetControlScale(ZO_ReticleContainerCombatLock, 1)

    if ZO_ReticleContainerReticle and ZO_ReticleContainerReticle.SetAlpha then
        ZO_ReticleContainerReticle:SetAlpha(1)
    end

    if ZO_ReticleContainerCombatLock and ZO_ReticleContainerCombatLock.SetAlpha then
        ZO_ReticleContainerCombatLock:SetAlpha(1)
    end
end

local function HideVanillaReticleControls()
    SetControlScale(ZO_ReticleContainerReticle, 0)
    SetControlScale(ZO_ReticleContainerCombatLock, 0)
end

local function IsPlayerInStealthOrDisguise()
    local disguiseNone = DISGUISE_STATE_NONE or 0
    local stealthNone = STEALTH_STATE_NONE or 0
    local disguiseState = GetUnitDisguiseState and GetUnitDisguiseState("player") or disguiseNone
    local stealthState = GetUnitStealthState and GetUnitStealthState("player") or stealthNone

    return disguiseState ~= disguiseNone or stealthState ~= stealthNone
end

local function ShouldCloseReticle()
    local interactionPossible = RETICLE and RETICLE.interact and RETICLE.interact.IsHidden and not RETICLE.interact:IsHidden()
    local hasPlayerTarget = PLAYER_TO_PLAYER and PLAYER_TO_PLAYER.HasTarget and PLAYER_TO_PLAYER:HasTarget()
    local hasAttackableTarget = IsGameCameraUnitHighlightedAttackable and IsGameCameraUnitHighlightedAttackable()

    return interactionPossible or hasPlayerTarget or hasAttackableTarget
end

local function MoveToward(value, target, step)
    if math.abs(target - value) <= step then
        return target
    elseif value < target then
        return value + step
    end

    return value - step
end

local function UpdateAnimationScale()
    local targetScale = ShouldCloseReticle() and CLOSED_ANIMATION_SCALE or OPEN_ANIMATION_SCALE
    animationScale = MoveToward(animationScale, targetScale, ANIMATION_SCALE_STEP)
end

local function ApplyReticleColor(texture)
    if not texture then
        return
    end

    local settings = GetSettings()
    local defaultColor = inFight and DEFAULT_FIGHT_COLOR or DEFAULT_COLOR
    local color = (inFight and settings.fightColor or settings.color) or defaultColor
    texture:SetColor(color.r or defaultColor.r, color.g or defaultColor.g, color.b or defaultColor.b, 1)
end

local function GetAddonTexturePath(textureFile)
    return "/" .. tostring(NQOL.name or "NQOL") .. "/Art/Reticle/" .. textureFile
end

local function EnsureCustomReticle()
    if customTexture or not WINDOW_MANAGER or not GuiRoot then
        return customTexture
    end

    customRoot = WINDOW_MANAGER:CreateTopLevelWindow("NQOL_CombatReticleRoot")
    customRoot:SetDimensions(72, 72)
    customRoot:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
    customRoot:SetMouseEnabled(false)
    customRoot:SetMovable(false)
    customRoot:SetHidden(true)
    if customRoot.SetDrawTier then customRoot:SetDrawTier(DT_HIGH) end
    if customRoot.SetDrawLayer then customRoot:SetDrawLayer(DL_OVERLAY) end
    if customRoot.SetDrawLevel then customRoot:SetDrawLevel(219900) end

    customTexture = WINDOW_MANAGER:CreateControl("NQOL_CombatReticleTexture", customRoot, CT_TEXTURE)
    customTexture:SetAnchor(CENTER, customRoot, CENTER, 0, 0)
    customTexture:SetDimensions(32, 32)
    customTexture:SetHidden(true)
    if customTexture.SetDrawTier then customTexture:SetDrawTier(DT_HIGH) end
    if customTexture.SetDrawLayer then customTexture:SetDrawLayer(DL_OVERLAY) end
    if customTexture.SetDrawLevel then customTexture:SetDrawLevel(220000) end

    return customTexture
end

local function HideCustomReticle()
    if customTexture then
        customTexture:SetHidden(true)
    end
    if customRoot then
        customRoot:SetHidden(true)
    end
end

local function RestoreDefaultReticleState()
    local reticleTexture = RETICLE and RETICLE.reticleTexture or nil
    HideCustomReticle()
    RestoreVanillaReticleControls()
    if reticleTexture then
        if visibilitySuppressed then
            reticleTexture:SetHidden(IsPlayerInStealthOrDisguise())
        end
        reticleTexture:SetTexture(RETICLE_DEFAULT_TEXTURE)
        reticleTexture:SetDimensions(64, 64)
        if reticleTexture.SetTextureCoords then
            reticleTexture:SetTextureCoords(0, 1, 0, 1)
        end
    end
    appliedShape = SHAPE_DEFAULT
    appliedTexturePath = nil
    visibilitySuppressed = false
end

local function EnsureSettingsPreviewReticle()
    if previewTexture or not WINDOW_MANAGER or not GuiRoot then
        return previewTexture
    end

    previewRoot = WINDOW_MANAGER:CreateTopLevelWindow("NQOL_CombatReticlePreviewRoot")
    previewRoot:SetDimensions(104, 104)
    previewRoot:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
    previewRoot:SetMouseEnabled(false)
    previewRoot:SetMovable(false)
    previewRoot:SetHidden(true)
    if previewRoot.SetDrawTier then previewRoot:SetDrawTier(DT_HIGH) end
    if previewRoot.SetDrawLayer then previewRoot:SetDrawLayer(DL_OVERLAY) end
    if previewRoot.SetDrawLevel then previewRoot:SetDrawLevel(219900) end

    previewTexture = WINDOW_MANAGER:CreateControl("NQOL_CombatReticlePreviewTexture", previewRoot, CT_TEXTURE)
    previewTexture:SetAnchor(CENTER, previewRoot, CENTER, 0, 0)
    previewTexture:SetDimensions(64, 64)
    previewTexture:SetHidden(true)
    if previewTexture.SetDrawTier then previewTexture:SetDrawTier(DT_HIGH) end
    if previewTexture.SetDrawLayer then previewTexture:SetDrawLayer(DL_OVERLAY) end
    if previewTexture.SetDrawLevel then previewTexture:SetDrawLevel(220000) end

    return previewTexture
end

local function HideSettingsPreviewReticle()
    if previewTexture then
        previewTexture:SetHidden(true)
    end
    if previewRoot then
        previewRoot:SetHidden(true)
    end
end

local function GetCurrentSceneName()
    if not SCENE_MANAGER then
        return nil
    end

    if SCENE_MANAGER.GetCurrentSceneName then
        return SCENE_MANAGER:GetCurrentSceneName()
    end

    if SCENE_MANAGER.GetCurrentScene then
        local scene = SCENE_MANAGER:GetCurrentScene()
        if scene and scene.GetName then
            return scene:GetName()
        end
    end

    return nil
end

local function IsGameplaySceneShowing()
    if not SCENE_MANAGER then
        return true
    end

    return GAMEPLAY_SCENES[GetCurrentSceneName()] == true
end

local function HideReticleInfo()
    for _, label in pairs(reticleInfoLabels) do
        label:SetHidden(true)
    end
    if reticleInfoRoot then
        reticleInfoRoot:SetHidden(true)
    end
end

local function EnsureReticleInfoRoot()
    if reticleInfoRoot or not WINDOW_MANAGER or not GuiRoot then
        return reticleInfoRoot
    end

    reticleInfoRoot = WINDOW_MANAGER:CreateTopLevelWindow("NQOL_CombatReticleInfoRoot")
    reticleInfoRoot:SetDimensions(RETICLE_INFO_ROOT_SIZE, RETICLE_INFO_ROOT_SIZE)
    reticleInfoRoot:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
    reticleInfoRoot:SetMouseEnabled(false)
    reticleInfoRoot:SetMovable(false)
    reticleInfoRoot:SetHidden(true)
    if reticleInfoRoot.SetDrawTier then reticleInfoRoot:SetDrawTier(DT_HIGH) end
    if reticleInfoRoot.SetDrawLayer then reticleInfoRoot:SetDrawLayer(DL_OVERLAY) end
    if reticleInfoRoot.SetDrawLevel then reticleInfoRoot:SetDrawLevel(220000) end
    return reticleInfoRoot
end

local function EnsureReticleInfoLabel(positionKey)
    if reticleInfoLabels[positionKey] then
        return reticleInfoLabels[positionKey]
    end

    local root = EnsureReticleInfoRoot()
    if not root then
        return nil
    end

    local label = WINDOW_MANAGER:CreateControl("NQOL_CombatReticleInfo_" .. positionKey, root, CT_LABEL)
    label:SetDimensions(RETICLE_INFO_WIDTH, RETICLE_INFO_HEIGHT)
    label:SetMouseEnabled(false)
    label:SetHidden(true)
    if label.SetDrawTier then label:SetDrawTier(DT_HIGH) end
    if label.SetDrawLayer then label:SetDrawLayer(DL_OVERLAY) end
    if label.SetDrawLevel then label:SetDrawLevel(220100) end
    reticleInfoLabels[positionKey] = label
    return label
end

local function AnchorReticleInfoLabel(label, settings)
    local horizontalOffset = NQOL.Util.Clamp(tonumber(settings.horizontalOffset) or 0, RETICLE_INFO_OFFSET_MIN, RETICLE_INFO_OFFSET_MAX)
    local verticalOffset = NQOL.Util.Clamp(tonumber(settings.verticalOffset) or 0, RETICLE_INFO_OFFSET_MIN, RETICLE_INFO_OFFSET_MAX)
    label:ClearAnchors()
    label:SetAnchor(CENTER, reticleInfoRoot, CENTER, horizontalOffset, verticalOffset)
    if label.SetHorizontalAlignment then label:SetHorizontalAlignment(TEXT_ALIGN_CENTER) end
    if label.SetVerticalAlignment then label:SetVerticalAlignment(TEXT_ALIGN_CENTER) end
end

local function GetCountdownText(endTime)
    local currentTime = GetFrameTimeSeconds and GetFrameTimeSeconds() or 0
    local remaining = math.max(0, (tonumber(endTime) or 0) - currentTime)
    if remaining <= 0 then
        return "0"
    elseif remaining > 2 then
        return tostring(math.ceil(remaining))
    end

    return string.format("%.1f", math.ceil(remaining * 10) / 10)
end

local function GetReticleInfoAbilityId(content)
    if content == "crux" then
        return CRUX_ABILITY_ID
    elseif content == "offBalance" then
        return offBalanceAbilityId
    elseif content == "offBalanceImmunity" then
        return OFF_BALANCE_IMMUNITY_ABILITY_ID
    elseif content == "taunt" then
        return TAUNT_ICON_ABILITY_ID
    elseif content == "sulXan" then
        local _, abilityId = SUL_XAN.GetDisplayState()
        return abilityId
    elseif content == "zensRedress" then
        return ZENS_TOUCH_ABILITY_ID
    end

    return nil
end

local function AddReticleInfoIcon(valueText, content, iconPosition, iconSize)
    if RETICLE_INFO_ICON_POSITION_VALID[iconPosition] ~= true or iconPosition == RETICLE_INFO_ICON_POSITION_DEFAULT or not GetAbilityIcon then
        return valueText
    end

    local abilityId = GetReticleInfoAbilityId(content)
    local iconPath = abilityId and GetAbilityIcon(abilityId) or nil
    if not iconPath or iconPath == "" then
        return valueText
    end

    iconSize = math.max(1, math.floor((iconSize * RETICLE_INFO_ICON_FONT_SCALE) + 0.5))
    local iconMarkup = string.format("|t%d:%d:%s|t", iconSize, iconSize, iconPath)
    if iconPosition == "left" then
        return iconMarkup .. " " .. valueText
    end

    return valueText .. " " .. iconMarkup
end

local function ApplyReticleInfo()
    local displaySceneShowing = settingsPreviewVisible or IsGameplaySceneShowing()
    local hiddenForPlayerState = not settingsPreviewVisible and IsPlayerInStealthOrDisguise()
    if not HasEnabledReticleInfo() or not displaySceneShowing or hiddenForPlayerState then
        HideReticleInfo()
        return
    end

    local canDisplayCrux = HasCruxCapableSkillLine()
    for _, positionKey in ipairs(RETICLE_INFO_POSITION_KEYS) do
        local settings = GetReticleInfoPositionSettings(positionKey)
        local label = reticleInfoLabels[positionKey]
        local shouldDisplay = settings and (settings.content == "offBalance" or settings.content == "offBalanceImmunity" or settings.content == "taunt" or (settings.content == "zensRedress" and zensFivePieceEquipped) or (settings.content == "crux" and canDisplayCrux))
        if settings and settings.content == "sulXan" then
            shouldDisplay = true
        end
        if shouldDisplay then
            label = EnsureReticleInfoLabel(positionKey)
            if label then
                local color = settings.color or DEFAULT_COLOR
                local red, green, blue = color.r or 1, color.g or 1, color.b or 1
                local fontSize = NQOL.Util.Clamp(tonumber(settings.fontSize) or RETICLE_INFO_FONT_SIZE_DEFAULT, RETICLE_INFO_FONT_SIZE_MIN, RETICLE_INFO_FONT_SIZE_MAX)
                fontSize = math.floor(fontSize + 0.5)
                if label.nqolInfoFont ~= settings.font or label.nqolInfoFontSize ~= fontSize then
                    label:SetFont(NQOL.Util.CreateFontString(settings.font, fontSize, "ZoFontGamepad27"))
                    label:SetDimensions(RETICLE_INFO_WIDTH, math.max(RETICLE_INFO_HEIGHT, fontSize + 8))
                    label.nqolInfoFont = settings.font
                    label.nqolInfoFontSize = fontSize
                end
                if label.nqolInfoRed ~= red or label.nqolInfoGreen ~= green or label.nqolInfoBlue ~= blue then
                    label:SetColor(red, green, blue, 1)
                    label.nqolInfoRed, label.nqolInfoGreen, label.nqolInfoBlue = red, green, blue
                end
                local infoText
                if settings.content == "crux" then
                    infoText = tostring(cruxCount)
                elseif settings.content == "zensRedress" then
                    infoText = tostring(zensStacks)
                elseif settings.content == "offBalanceImmunity" then
                    infoText = GetCountdownText(offBalanceImmunityEndTime)
                elseif settings.content == "taunt" then
                    infoText = GetCountdownText(tauntEndTime)
                elseif settings.content == "sulXan" then
                    infoText = GetCountdownText(SUL_XAN.GetDisplayState())
                else
                    infoText = GetCountdownText(offBalanceEndTime)
                end
                infoText = AddReticleInfoIcon(infoText, settings.content, settings.iconPosition, fontSize)
                if label.nqolInfoText ~= infoText then
                    label:SetText(infoText)
                    label.nqolInfoText = infoText
                end
                AnchorReticleInfoLabel(label, settings)
                reticleInfoRoot:SetHidden(false)
                label:SetHidden(false)
            end
        elseif label then
            label:SetHidden(true)
        end
    end
end

local function ApplySettingsPreviewReticle(shape, style)
    local texture = EnsureSettingsPreviewReticle()
    if not texture then
        return
    end

    local texturePath = style and GetAddonTexturePath(style.textureFile) or RETICLE_DEFAULT_TEXTURE
    local baseWidth = style and style.width or 64
    local baseHeight = style and style.height or 64
    local scale = 1
    if style then
        if IsAnimatedReticleEnabled() then
            UpdateAnimationScale()
        else
            animationScale = OPEN_ANIMATION_SCALE
        end
        scale = GetScale() * animationScale
    end

    local width = math.floor((baseWidth * scale) + 0.5)
    local height = math.floor((baseHeight * scale) + 0.5)
    previewRoot:ClearAnchors()
    previewRoot:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
    previewRoot:SetDimensions(math.max(width, height) + 40, math.max(width, height) + 40)
    texture:ClearAnchors()
    texture:SetAnchor(CENTER, previewRoot, CENTER, 0, 0)
    texture:SetDimensions(width, height)
    if appliedPreviewTexturePath ~= texturePath then
        texture:SetTexture(nil)
        texture:SetTexture(texturePath)
        appliedPreviewTexturePath = texturePath
    end
    if texture.SetTextureCoords then
        texture:SetTextureCoords(0, 1, 0, 1)
    end
    if style then
        ApplyReticleColor(texture)
    else
        texture:SetColor(DEFAULT_COLOR.r, DEFAULT_COLOR.g, DEFAULT_COLOR.b, 1)
    end
    previewRoot:SetHidden(false)
    texture:SetHidden(false)
end

local function ApplyCombatReticle()
    local shape = GetShape()
    local style = SHAPE_STYLES[shape]
    local reticleTexture = RETICLE and RETICLE.reticleTexture or nil
    local useCustomShape = style ~= nil
    local useVanillaShape = useCustomShape and style.controlType == "vanilla"
    local useDdsShape = useCustomShape and style.controlType == "dds"

    if settingsPreviewVisible then
        ApplyReticleInfo()
        ApplySettingsPreviewReticle(shape, style)
        return
    end

    HideSettingsPreviewReticle()
    if not ShouldShowReticle() then
        HideCustomReticle()
        HideReticleInfo()
        HideVanillaReticleControls()
        if reticleTexture then
            reticleTexture:SetHidden(true)
        end
        visibilitySuppressed = true
        return
    end

    if visibilitySuppressed then
        RestoreVanillaReticleControls()
        if reticleTexture then
            reticleTexture:SetHidden(IsPlayerInStealthOrDisguise())
        end
        visibilitySuppressed = false
    end

    ApplyReticleInfo()
    local ddsTexture = useDdsShape and EnsureCustomReticle() or nil

    if not useCustomShape and (appliedShape == nil or appliedShape == SHAPE_DEFAULT) then
        return
    end

    if not reticleTexture and not useDdsShape then
        return
    end

    if not IsGameplaySceneShowing() then
        HideReticleInfo()
        if not useCustomShape then
            RestoreDefaultReticleState()
        else
            HideCustomReticle()
        end
        if useCustomShape and reticleTexture then
            reticleTexture:SetHidden(true)
        end
        return
    end

    if useVanillaShape then
        if appliedShape ~= shape then
            reticleTexture:SetTexture(RETICLE_DEFAULT_TEXTURE)
            reticleTexture:SetDimensions(style.width, style.height)
            appliedTexturePath = nil
        end
    elseif useDdsShape and ddsTexture then
        local texturePath = GetAddonTexturePath(style.textureFile)
        if IsAnimatedReticleEnabled() then
            UpdateAnimationScale()
        else
            animationScale = OPEN_ANIMATION_SCALE
        end
        local scale = GetScale() * animationScale
        local width = math.floor((style.width * scale) + 0.5)
        local height = math.floor((style.height * scale) + 0.5)
        local rootSize = math.max(width, height) + 40
        customRoot:ClearAnchors()
        customRoot:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
        customRoot:SetDimensions(rootSize, rootSize)
        ddsTexture:ClearAnchors()
        ddsTexture:SetAnchor(CENTER, customRoot, CENTER, 0, 0)
        ddsTexture:SetDimensions(width, height)
        if appliedTexturePath ~= texturePath then
            ddsTexture:SetTexture(nil)
            ddsTexture:SetTexture(texturePath)
            appliedTexturePath = texturePath
        end
    elseif not useCustomShape and appliedShape ~= shape then
        reticleTexture:SetTexture(RETICLE_DEFAULT_TEXTURE)
        reticleTexture:SetDimensions(64, 64)
        appliedTexturePath = nil
    end

    appliedShape = shape

    if useCustomShape and RETICLE and RETICLE.reticleOpenCloseTimeline and RETICLE.reticleOpenCloseTimeline.Stop then
        RETICLE.reticleOpenCloseTimeline:Stop()
    end

    if useVanillaShape then
        HideCustomReticle()
        RestoreVanillaReticleControls()
        reticleTexture:SetHidden(IsPlayerInStealthOrDisguise())
        if reticleTexture.SetTextureCoords then
            reticleTexture:SetTextureCoords(style.left, style.right, style.top, style.bottom)
        end
    elseif useDdsShape then
        HideVanillaReticleControls()
        if reticleTexture then
            reticleTexture:SetHidden(false)
        end
        if ddsTexture then
            customRoot:SetHidden(false)
            ddsTexture:SetHidden(false)
            ApplyReticleColor(ddsTexture)
        end
    else
        HideCustomReticle()
        RestoreVanillaReticleControls()
        reticleTexture:SetHidden(IsPlayerInStealthOrDisguise())
        if reticleTexture.SetTextureCoords then
            reticleTexture:SetTextureCoords(0, 1, 0, 1)
        end
    end

    if reticleTexture and useCustomShape then
        ApplyReticleColor(reticleTexture)
    end
end

function UI.QueueCombatReticleApply()
    if applyQueued or not IsReticleRuntimeActive() then
        return
    end

    applyQueued = true
    zo_callLater(function()
        applyQueued = false
        if IsReticleRuntimeActive() then
            ApplyCombatReticle()
        end
    end, APPLY_DELAY_MS)
end

local function StopReticleHitIndicator()
    if RETICLE and RETICLE.hitIndicatorTimeline and RETICLE.hitIndicatorTimeline.Stop then
        RETICLE.hitIndicatorTimeline:Stop()
    end
end

local function InstallReticleHooks()
    if hooksInstalled or not IsReticleRuntimeActive() then
        return
    end

    if not RETICLE or not RETICLE.OnImpactfulHit or not RETICLE.UpdateHiddenState or type(ZO_PostHook) ~= "function" then
        hookAttempts = hookAttempts + 1
        if hookAttempts < 10 then
            zo_callLater(InstallReticleHooks, 1000)
        end
        return
    end

    ZO_PostHook(RETICLE, "OnImpactfulHit", function()
        if IsReticleRuntimeActive() then
            if UsesCustomShape() then
                StopReticleHitIndicator()
            end
            ApplyCombatReticle()
        end
    end)

    ZO_PostHook(RETICLE, "UpdateHiddenState", function()
        if IsReticleRuntimeActive() then
            ApplyCombatReticle()
        end
    end)

    hooksInstalled = true
end

local function OnSceneStateChanged(scene, _, newState)
    if not IsReticleRuntimeActive() then
        return
    end

    local sceneName = scene and scene.GetName and scene:GetName() or nil
    local isGameplayScene = GAMEPLAY_SCENES[sceneName] == true
    local isShowing = newState == SCENE_SHOWING or newState == SCENE_SHOWN

    if isShowing and not isGameplayScene and not settingsPreviewVisible then
        HideReticleInfo()
        if UsesCustomShape() then
            HideCustomReticle()
        end
        if UsesCustomShape() and RETICLE and RETICLE.reticleTexture then
            RETICLE.reticleTexture:SetHidden(true)
        end
    end

    UI.QueueCombatReticleApply()
end

local function InstallSceneCallback()
    if sceneCallbackInstalled or not IsReticleRuntimeActive() or not SCENE_MANAGER or not SCENE_MANAGER.RegisterCallback then
        return
    end

    sceneCallbackInstalled = true
    SCENE_MANAGER:RegisterCallback("SceneStateChanged", OnSceneStateChanged)
end

local function UninstallSceneCallback()
    if sceneCallbackInstalled and SCENE_MANAGER and SCENE_MANAGER.UnregisterCallback then
        SCENE_MANAGER:UnregisterCallback("SceneStateChanged", OnSceneStateChanged)
    end

    sceneCallbackInstalled = false
end

local function InstallUpdateLoop()
    if updateLoopInstalled or not EVENT_MANAGER then
        return
    end

    EVENT_MANAGER:RegisterForUpdate(UPDATE_NAMESPACE, ANIMATION_UPDATE_MS, function()
        if IsReticleRuntimeActive() then
            ApplyCombatReticle()
        else
            animationScale = OPEN_ANIMATION_SCALE
        end
    end)
    updateLoopInstalled = true
end

local function UninstallUpdateLoop()
    if updateLoopInstalled and EVENT_MANAGER then
        EVENT_MANAGER:UnregisterForUpdate(UPDATE_NAMESPACE)
    end

    updateLoopInstalled = false
    animationScale = OPEN_ANIMATION_SCALE
end

RefreshAnimationLoop = function()
    if IsAnimatedReticleEnabled() and UsesCustomShape() and IsReticleRuntimeActive() then
        InstallUpdateLoop()
    else
        UninstallUpdateLoop()
    end
end

local function InstallReticleEvents()
    if eventsInstalled or not EVENT_MANAGER or not IsReticleRuntimeActive() then
        return
    end

    EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE, EVENT_PLAYER_ACTIVATED, function()
        RefreshFightState()
        if UsesCruxTracker() then
            ScanCruxCount()
        end
        if UsesTargetEffectTracker() then
            ScanTargetEffectEndTimes()
        end
        if UsesZensTracker() then
            RefreshZensEquipmentState()
        end
        if SUL_XAN.UsesTracker() then
            SUL_XAN.soulEndTime = 0
            SUL_XAN.ScanBuffEndTime()
        end
        InstallReticleHooks()
        InstallSceneCallback()
        UI.QueueCombatReticleApply()
    end)
    EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE, EVENT_PLAYER_ALIVE, UI.QueueCombatReticleApply)
    EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE, EVENT_PLAYER_DEAD, UI.QueueCombatReticleApply)
    EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE, EVENT_PLAYER_COMBAT_STATE, function(_, isInFight)
        inFight = isInFight == true
        UI.QueueCombatReticleApply()
    end)
    EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE, EVENT_RETICLE_HIDDEN_UPDATE, UI.QueueCombatReticleApply)
    EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE, EVENT_STEALTH_STATE_CHANGED, function(_, unitTag)
        if unitTag == "player" then
            UI.QueueCombatReticleApply()
        end
    end)
    EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE, EVENT_DISGUISE_STATE_CHANGED, function(_, unitTag)
        if unitTag == "player" then
            UI.QueueCombatReticleApply()
        end
    end)
    EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE, EVENT_IMPACTFUL_HIT, function()
        if IsAnimatedReticleEnabled() and UsesCustomShape() and IsReticleRuntimeActive() then
            zo_callLater(ApplyCombatReticle, HIT_INDICATOR_DURATION_MS + APPLY_DELAY_MS)
        end
    end)
    if EVENT_SKILLS_FULL_UPDATE then
        EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE, EVENT_SKILLS_FULL_UPDATE, RefreshReticleRuntime)
    end
    eventsInstalled = true
end

local function UninstallReticleEvents()
    if not eventsInstalled or not EVENT_MANAGER then
        return
    end

    EVENT_MANAGER:UnregisterForEvent(EVENT_NAMESPACE, EVENT_PLAYER_ACTIVATED)
    EVENT_MANAGER:UnregisterForEvent(EVENT_NAMESPACE, EVENT_PLAYER_ALIVE)
    EVENT_MANAGER:UnregisterForEvent(EVENT_NAMESPACE, EVENT_PLAYER_DEAD)
    EVENT_MANAGER:UnregisterForEvent(EVENT_NAMESPACE, EVENT_PLAYER_COMBAT_STATE)
    EVENT_MANAGER:UnregisterForEvent(EVENT_NAMESPACE, EVENT_RETICLE_HIDDEN_UPDATE)
    EVENT_MANAGER:UnregisterForEvent(EVENT_NAMESPACE, EVENT_STEALTH_STATE_CHANGED)
    EVENT_MANAGER:UnregisterForEvent(EVENT_NAMESPACE, EVENT_DISGUISE_STATE_CHANGED)
    EVENT_MANAGER:UnregisterForEvent(EVENT_NAMESPACE, EVENT_IMPACTFUL_HIT)
    if EVENT_SKILLS_FULL_UPDATE then
        EVENT_MANAGER:UnregisterForEvent(EVENT_NAMESPACE, EVENT_SKILLS_FULL_UPDATE)
    end
    eventsInstalled = false
end

ScanCruxCount = function()
    local nextCount = 0
    if GetNumBuffs and GetUnitBuffInfo then
        for buffIndex = 1, GetNumBuffs("player") do
            local _, _, _, _, stackCount, _, _, _, _, _, abilityId = GetUnitBuffInfo("player", buffIndex)
            if abilityId == CRUX_ABILITY_ID then
                nextCount = tonumber(stackCount) or 0
                break
            end
        end
    end

    cruxCount = math.max(0, math.floor(nextCount + 0.5))
    UI.QueueCombatReticleApply()
end

local function InstallCruxEvents()
    if cruxEventsInstalled or not EVENT_MANAGER or not UsesCruxTracker() then
        return
    end

    EVENT_MANAGER:RegisterForEvent(CRUX_EVENT_NAMESPACE, EVENT_EFFECT_CHANGED, ScanCruxCount)
    if EVENT_MANAGER.AddFilterForEvent then
        EVENT_MANAGER:AddFilterForEvent(CRUX_EVENT_NAMESPACE, EVENT_EFFECT_CHANGED, REGISTER_FILTER_UNIT_TAG, "player")
        EVENT_MANAGER:AddFilterForEvent(CRUX_EVENT_NAMESPACE, EVENT_EFFECT_CHANGED, REGISTER_FILTER_ABILITY_ID, CRUX_ABILITY_ID)
    end
    cruxEventsInstalled = true
end

local function UninstallCruxEvents()
    if cruxEventsInstalled and EVENT_MANAGER then
        EVENT_MANAGER:UnregisterForEvent(CRUX_EVENT_NAMESPACE, EVENT_EFFECT_CHANGED)
    end

    cruxEventsInstalled = false
    cruxCount = 0
end

ScanTargetEffectEndTimes = function()
    local nextOffBalanceEndTime = 0
    local nextOffBalanceAbilityId = OFF_BALANCE_ICON_ABILITY_ID
    local nextOffBalanceImmunityEndTime = 0
    local nextTauntEndTime = 0
    local targetExists = not DoesUnitExist or DoesUnitExist("reticleover") == true
    if targetExists and GetNumBuffs and GetUnitBuffInfo then
        for buffIndex = 1, GetNumBuffs("reticleover") do
            local _, _, endTime, _, _, _, _, _, _, _, abilityId = GetUnitBuffInfo("reticleover", buffIndex)
            local numericAbilityId = tonumber(abilityId)
            local numericEndTime = tonumber(endTime) or 0
            if OFF_BALANCE_ABILITY_IDS[numericAbilityId] == true and numericEndTime > nextOffBalanceEndTime then
                nextOffBalanceEndTime = numericEndTime
                nextOffBalanceAbilityId = numericAbilityId
            elseif numericAbilityId == OFF_BALANCE_IMMUNITY_ABILITY_ID and numericEndTime > nextOffBalanceImmunityEndTime then
                nextOffBalanceImmunityEndTime = numericEndTime
            elseif TAUNT_ABILITY_IDS[numericAbilityId] == true and numericEndTime > nextTauntEndTime then
                nextTauntEndTime = numericEndTime
            end
        end
    end

    offBalanceEndTime = nextOffBalanceEndTime
    offBalanceAbilityId = nextOffBalanceAbilityId
    offBalanceImmunityEndTime = nextOffBalanceImmunityEndTime
    tauntEndTime = nextTauntEndTime
end

local function RefreshTargetEffectsFromEvent()
    ScanTargetEffectEndTimes()
    UI.QueueCombatReticleApply()
end

local function InstallTargetEffectEvents()
    if targetEffectEventsInstalled or not EVENT_MANAGER or not UsesTargetEffectTracker() then
        return
    end

    EVENT_MANAGER:RegisterForEvent(TARGET_EFFECT_EVENT_NAMESPACE, EVENT_EFFECT_CHANGED, RefreshTargetEffectsFromEvent)
    EVENT_MANAGER:RegisterForEvent(TARGET_EFFECT_EVENT_NAMESPACE, EVENT_RETICLE_TARGET_CHANGED, RefreshTargetEffectsFromEvent)
    if EVENT_MANAGER.AddFilterForEvent then
        EVENT_MANAGER:AddFilterForEvent(TARGET_EFFECT_EVENT_NAMESPACE, EVENT_EFFECT_CHANGED, REGISTER_FILTER_UNIT_TAG, "reticleover")
    end
    targetEffectEventsInstalled = true
end

local function UninstallTargetEffectEvents()
    if targetEffectEventsInstalled and EVENT_MANAGER then
        EVENT_MANAGER:UnregisterForEvent(TARGET_EFFECT_EVENT_NAMESPACE, EVENT_EFFECT_CHANGED)
        EVENT_MANAGER:UnregisterForEvent(TARGET_EFFECT_EVENT_NAMESPACE, EVENT_RETICLE_TARGET_CHANGED)
    end

    targetEffectEventsInstalled = false
    offBalanceEndTime = 0
    offBalanceAbilityId = OFF_BALANCE_ICON_ABILITY_ID
    offBalanceImmunityEndTime = 0
    tauntEndTime = 0
end

local function InstallTargetEffectUpdateLoop()
    if targetEffectUpdateLoopInstalled or not EVENT_MANAGER or not UsesTargetEffectTracker() then
        return
    end

    EVENT_MANAGER:RegisterForUpdate(TARGET_EFFECT_UPDATE_NAMESPACE, TARGET_EFFECT_UPDATE_MS, function()
        if IsReticleRuntimeActive() and UsesTargetEffectTracker() then
            ScanTargetEffectEndTimes()
            ApplyCombatReticle()
        end
    end)
    targetEffectUpdateLoopInstalled = true
end

local function UninstallTargetEffectUpdateLoop()
    if targetEffectUpdateLoopInstalled and EVENT_MANAGER then
        EVENT_MANAGER:UnregisterForUpdate(TARGET_EFFECT_UPDATE_NAMESPACE)
    end

    targetEffectUpdateLoopInstalled = false
end

ScanZensStacks = function()
    if not zensFivePieceEquipped then
        zensStacks = 0
        UI.QueueCombatReticleApply()
        return
    end

    local nextCount = 0
    local touchActive = false
    local targetExists = not DoesUnitExist or DoesUnitExist("reticleover") == true
    if targetExists and GetNumBuffs and GetUnitBuffInfo then
        for buffIndex = 1, GetNumBuffs("reticleover") do
            local _, _, _, _, _, _, _, _, abilityType, _, abilityId, _, castByPlayer = GetUnitBuffInfo("reticleover", buffIndex)
            if castByPlayer == true then
                if abilityId == ZENS_TOUCH_ABILITY_ID then
                    touchActive = true
                elseif abilityType == ABILITY_TYPE_DAMAGE then
                    nextCount = nextCount + 1
                end
            end
        end
    end

    zensStacks = touchActive and nextCount or 0
    UI.QueueCombatReticleApply()
end

RefreshZensEquipmentState = function()
    zensFivePieceEquipped = HasFivePieceZensEquipped()
    if zensFivePieceEquipped then
        ScanZensStacks()
    else
        zensStacks = 0
        UI.QueueCombatReticleApply()
    end
end

local function InstallZensEvents()
    if zensEventsInstalled or not EVENT_MANAGER or not UsesZensTracker() then
        return
    end

    EVENT_MANAGER:RegisterForEvent(ZENS_EVENT_NAMESPACE, EVENT_EFFECT_CHANGED, ScanZensStacks)
    EVENT_MANAGER:RegisterForEvent(ZENS_EVENT_NAMESPACE, EVENT_RETICLE_TARGET_CHANGED, ScanZensStacks)
    EVENT_MANAGER:RegisterForEvent(ZENS_EVENT_NAMESPACE, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, RefreshZensEquipmentState)
    if EVENT_MANAGER.AddFilterForEvent then
        EVENT_MANAGER:AddFilterForEvent(ZENS_EVENT_NAMESPACE, EVENT_EFFECT_CHANGED, REGISTER_FILTER_UNIT_TAG, "reticleover")
        EVENT_MANAGER:AddFilterForEvent(ZENS_EVENT_NAMESPACE, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_BAG_ID, BAG_WORN)
    end
    zensEventsInstalled = true
    RefreshZensEquipmentState()
end

local function UninstallZensEvents()
    if zensEventsInstalled and EVENT_MANAGER then
        EVENT_MANAGER:UnregisterForEvent(ZENS_EVENT_NAMESPACE, EVENT_EFFECT_CHANGED)
        EVENT_MANAGER:UnregisterForEvent(ZENS_EVENT_NAMESPACE, EVENT_RETICLE_TARGET_CHANGED)
        EVENT_MANAGER:UnregisterForEvent(ZENS_EVENT_NAMESPACE, EVENT_INVENTORY_SINGLE_SLOT_UPDATE)
    end

    zensEventsInstalled = false
    zensFivePieceEquipped = false
    zensStacks = 0
end

function SUL_XAN.ScanBuffEndTime()
    local nextEndTime = 0
    if GetNumBuffs and GetUnitBuffInfo then
        for buffIndex = 1, GetNumBuffs("player") do
            local _, _, endTime, _, _, _, _, _, _, _, abilityId = GetUnitBuffInfo("player", buffIndex)
            if abilityId == SUL_XAN.BUFF_ABILITY_ID then
                nextEndTime = tonumber(endTime) or 0
                break
            end
        end
    end

    SUL_XAN.buffEndTime = nextEndTime
    UI.QueueCombatReticleApply()
end

function SUL_XAN.OnSoulEffectChanged(_, changeType, _, _, _, _, endTime, _, _, _, _, _, _, _, _, abilityId)
    if abilityId ~= SUL_XAN.SOUL_ABILITY_ID then
        return
    end

    SUL_XAN.soulEndTime = changeType == EFFECT_RESULT_FADED and 0 or math.max(0, tonumber(endTime) or 0)
    UI.QueueCombatReticleApply()
end

function SUL_XAN.OnBuffEffectChanged(_, changeType, _, _, _, _, endTime, _, _, _, _, _, _, _, _, abilityId)
    if abilityId ~= SUL_XAN.BUFF_ABILITY_ID then
        return
    end

    SUL_XAN.buffEndTime = changeType == EFFECT_RESULT_FADED and 0 or math.max(0, tonumber(endTime) or 0)
    UI.QueueCombatReticleApply()
end

function SUL_XAN.InstallEvents()
    if SUL_XAN.eventsInstalled or not EVENT_MANAGER or not SUL_XAN.UsesTracker() then
        return
    end

    EVENT_MANAGER:RegisterForEvent(SUL_XAN.SOUL_EVENT_NAMESPACE, EVENT_EFFECT_CHANGED, SUL_XAN.OnSoulEffectChanged)
    EVENT_MANAGER:RegisterForEvent(SUL_XAN.BUFF_EVENT_NAMESPACE, EVENT_EFFECT_CHANGED, SUL_XAN.OnBuffEffectChanged)
    if EVENT_MANAGER.AddFilterForEvent then
        EVENT_MANAGER:AddFilterForEvent(SUL_XAN.SOUL_EVENT_NAMESPACE, EVENT_EFFECT_CHANGED, REGISTER_FILTER_ABILITY_ID, SUL_XAN.SOUL_ABILITY_ID)
        EVENT_MANAGER:AddFilterForEvent(SUL_XAN.SOUL_EVENT_NAMESPACE, EVENT_EFFECT_CHANGED, REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER)
        EVENT_MANAGER:AddFilterForEvent(SUL_XAN.BUFF_EVENT_NAMESPACE, EVENT_EFFECT_CHANGED, REGISTER_FILTER_ABILITY_ID, SUL_XAN.BUFF_ABILITY_ID)
        EVENT_MANAGER:AddFilterForEvent(SUL_XAN.BUFF_EVENT_NAMESPACE, EVENT_EFFECT_CHANGED, REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER)
    end
    SUL_XAN.eventsInstalled = true
end

function SUL_XAN.UninstallEvents()
    if SUL_XAN.eventsInstalled and EVENT_MANAGER then
        EVENT_MANAGER:UnregisterForEvent(SUL_XAN.SOUL_EVENT_NAMESPACE, EVENT_EFFECT_CHANGED)
        EVENT_MANAGER:UnregisterForEvent(SUL_XAN.BUFF_EVENT_NAMESPACE, EVENT_EFFECT_CHANGED)
    end

    SUL_XAN.eventsInstalled = false
    SUL_XAN.soulEndTime = 0
    SUL_XAN.buffEndTime = 0
end

function SUL_XAN.InstallUpdateLoop()
    if SUL_XAN.updateLoopInstalled or not EVENT_MANAGER or not SUL_XAN.UsesTracker() then
        return
    end

    EVENT_MANAGER:RegisterForUpdate(SUL_XAN.UPDATE_NAMESPACE, SUL_XAN.UPDATE_MS, function()
        if IsReticleRuntimeActive() and SUL_XAN.UsesTracker() then
            ApplyCombatReticle()
        end
    end)
    SUL_XAN.updateLoopInstalled = true
end

function SUL_XAN.UninstallUpdateLoop()
    if SUL_XAN.updateLoopInstalled and EVENT_MANAGER then
        EVENT_MANAGER:UnregisterForUpdate(SUL_XAN.UPDATE_NAMESPACE)
    end

    SUL_XAN.updateLoopInstalled = false
end

function SUL_XAN.RefreshRuntime()
    if IsReticleRuntimeActive() and SUL_XAN.UsesTracker() then
        SUL_XAN.InstallEvents()
        SUL_XAN.InstallUpdateLoop()
        SUL_XAN.ScanBuffEndTime()
        return
    end

    SUL_XAN.UninstallEvents()
    SUL_XAN.UninstallUpdateLoop()
end

RefreshReticleRuntime = function()
    runtimeActive = settingsPreviewVisible or GetShowWhen() ~= SHOW_WHEN.default or UsesCustomShape() or HasEnabledReticleInfo()
    if IsReticleRuntimeActive() then
        RefreshFightState()
        InstallReticleEvents()
        if UsesCruxTracker() then
            InstallCruxEvents()
            ScanCruxCount()
        else
            UninstallCruxEvents()
        end
        if UsesTargetEffectTracker() then
            InstallTargetEffectEvents()
            InstallTargetEffectUpdateLoop()
            ScanTargetEffectEndTimes()
        else
            UninstallTargetEffectEvents()
            UninstallTargetEffectUpdateLoop()
        end
        if UsesZensTracker() then
            InstallZensEvents()
            RefreshZensEquipmentState()
        else
            UninstallZensEvents()
        end
        SUL_XAN.RefreshRuntime()
        InstallReticleHooks()
        InstallSceneCallback()
        RefreshAnimationLoop()
        UI.QueueCombatReticleApply()
        return
    end

    UninstallReticleEvents()
    UninstallCruxEvents()
    UninstallTargetEffectEvents()
    UninstallTargetEffectUpdateLoop()
    UninstallZensEvents()
    SUL_XAN.RefreshRuntime()
    UninstallSceneCallback()
    UninstallUpdateLoop()
    HideSettingsPreviewReticle()
    HideReticleInfo()
    RestoreDefaultReticleState()
end

function UI.InitializeCombatReticle()
    if initialized or not EVENT_MANAGER then
        return
    end

    initialized = true
    RefreshReticleRuntime()
end

function UI.SetCombatReticleSettingsPanelVisible(visible)
    visible = visible == true
    if settingsPreviewVisible == visible then
        if visible then
            UI.QueueCombatReticleApply()
        end
        return
    end

    settingsPreviewVisible = visible
    RefreshReticleRuntime()
end

function UI.GetCombatReticleColor()
    local color = GetSettings().color
    color.a = 1
    return color.r, color.g, color.b, 1
end

function UI.SetCombatReticleColor(red, green, blue, alpha)
    local color = GetSettings().color
    color.r = NQOL.Util.Clamp(tonumber(red) or DEFAULT_COLOR.r, 0, 1)
    color.g = NQOL.Util.Clamp(tonumber(green) or DEFAULT_COLOR.g, 0, 1)
    color.b = NQOL.Util.Clamp(tonumber(blue) or DEFAULT_COLOR.b, 0, 1)
    color.a = 1
    if IsReticleRuntimeActive() then
        UI.QueueCombatReticleApply()
    end
end

function UI.GetCombatReticleFightColor()
    local color = GetSettings().fightColor
    color.a = 1
    return color.r, color.g, color.b, 1
end

function UI.SetCombatReticleFightColor(red, green, blue, alpha)
    local color = GetSettings().fightColor
    color.r = NQOL.Util.Clamp(tonumber(red) or DEFAULT_FIGHT_COLOR.r, 0, 1)
    color.g = NQOL.Util.Clamp(tonumber(green) or DEFAULT_FIGHT_COLOR.g, 0, 1)
    color.b = NQOL.Util.Clamp(tonumber(blue) or DEFAULT_FIGHT_COLOR.b, 0, 1)
    color.a = 1
    if IsReticleRuntimeActive() then
        UI.QueueCombatReticleApply()
    end
end

function UI.GetCombatReticleShape()
    return GetShape()
end

function UI.GetCombatReticleShowWhen()
    return GetShowWhen()
end

function UI.SetCombatReticleShowWhen(value)
    GetSettings().showWhen = SHOW_WHEN.valid[value] and value or SHOW_WHEN.default
    RefreshReticleRuntime()
end

function UI.GetCombatReticleShowWhenChoices()
    return SHOW_WHEN.choices
end

function UI.GetCombatReticleShowWhenChoiceNames()
    return SHOW_WHEN.names
end

function UI.GetCombatReticleShowWhenDefault()
    return SHOW_WHEN.default
end

function UI.GetCombatReticleShowWhenLabel()
    return NQOL.L("features.ui_combat_reticle.show_when_label")
end

function UI.GetCombatReticleShowWhenTooltip()
    return NQOL.L("features.ui_combat_reticle.show_when_tooltip")
end

function UI.SetCombatReticleShape(shape)
    if SHAPE_VALID[shape] ~= true then
        shape = SHAPE_DEFAULT
    end

    GetSettings().shape = shape
    RefreshReticleRuntime()
end

function UI.GetCombatReticleShapeChoices()
    return SHAPES
end

function UI.GetCombatReticleShapeChoiceNames()
    return SHAPE_NAMES
end

function UI.GetCombatReticleShapeDefault()
    return SHAPE_DEFAULT
end

function UI.GetCombatReticleScale()
    return GetScale()
end

function UI.SetCombatReticleScale(value)
    local scale = NQOL.Util.Clamp(tonumber(value) or SCALE_DEFAULT, SCALE_MIN, SCALE_MAX)
    GetSettings().scale = math.floor(scale + 0.5)
    if IsReticleRuntimeActive() then
        UI.QueueCombatReticleApply()
    end
end

function UI.GetAnimatedCombatReticle()
    return IsAnimatedReticleEnabled()
end

function UI.SetAnimatedCombatReticle(value)
    GetSettings().animated = value == true
    RefreshAnimationLoop()
    if IsReticleRuntimeActive() then
        UI.QueueCombatReticleApply()
    end
end

function UI.GetAnimatedCombatReticleDefault()
    return true
end

function UI.GetCombatReticleScaleDefault()
    return SCALE_DEFAULT
end

function UI.GetCombatReticleScaleMin()
    return SCALE_MIN
end

function UI.GetCombatReticleScaleMax()
    return SCALE_MAX
end

function UI.GetCombatReticleColorLabel()
    return NQOL.L("features.ui_combat_reticle.combat_reticle_color_label")
end

function UI.GetCombatReticleColorTooltip()
    return NQOL.L("features.ui_combat_reticle.combat_reticle_color_tooltip")
end

function UI.GetCombatReticleFightColorLabel()
    return NQOL.L("features.ui_combat_reticle.combat_reticle_fight_color_label")
end

function UI.GetCombatReticleFightColorTooltip()
    return NQOL.L("features.ui_combat_reticle.combat_reticle_fight_color_tooltip")
end

function UI.GetCombatReticleShapeLabel()
    return NQOL.L("features.ui_combat_reticle.combat_reticle_shape_label")
end

function UI.GetCombatReticleShapeTooltip()
    return NQOL.L("features.ui_combat_reticle.combat_reticle_shape_tooltip")
end

function UI.GetCombatReticleScaleLabel()
    return NQOL.L("features.ui_combat_reticle.combat_reticle_scale_label")
end

function UI.GetCombatReticleScaleTooltip()
    return NQOL.L("features.ui_combat_reticle.combat_reticle_scale_tooltip")
end

function UI.GetAnimatedCombatReticleLabel()
    return NQOL.L("features.ui_combat_reticle.animated_combat_reticle_label")
end

function UI.GetAnimatedCombatReticleTooltip()
    return NQOL.L("features.ui_combat_reticle.animated_combat_reticle_tooltip")
end

function UI.GetReticleInfoContent(positionKey)
    local settings = GetReticleInfoPositionSettings(positionKey)
    return settings and settings.content or RETICLE_INFO_CONTENT_DEFAULT
end

function UI.SetReticleInfoContent(positionKey, content)
    local settings = GetReticleInfoPositionSettings(positionKey)
    if not settings then
        return
    end

    if content ~= "crux" and content ~= "offBalance" and content ~= "offBalanceImmunity" and content ~= "taunt" and content ~= "sulXan" and content ~= "zensRedress" then
        content = RETICLE_INFO_CONTENT_DEFAULT
    end
    settings.content = content
    RefreshReticleRuntime()
end

function UI.GetReticleInfoContentChoices()
    return RETICLE_INFO_CONTENT_CHOICES
end

function UI.GetReticleInfoContentChoiceNames()
    return RETICLE_INFO_CONTENT_NAMES
end

function UI.GetReticleInfoContentDefault()
    return RETICLE_INFO_CONTENT_DEFAULT
end

function UI.GetReticleInfoIconPosition(positionKey)
    local settings = GetReticleInfoPositionSettings(positionKey)
    local iconPosition = settings and settings.iconPosition or RETICLE_INFO_ICON_POSITION_DEFAULT
    return RETICLE_INFO_ICON_POSITION_VALID[iconPosition] and iconPosition or RETICLE_INFO_ICON_POSITION_DEFAULT
end

function UI.SetReticleInfoIconPosition(positionKey, iconPosition)
    local settings = GetReticleInfoPositionSettings(positionKey)
    if not settings then
        return
    end

    settings.iconPosition = RETICLE_INFO_ICON_POSITION_VALID[iconPosition] and iconPosition or RETICLE_INFO_ICON_POSITION_DEFAULT
    UI.QueueCombatReticleApply()
end

function UI.GetReticleInfoIconPositionChoices()
    return RETICLE_INFO_ICON_POSITION_CHOICES
end

function UI.GetReticleInfoIconPositionChoiceNames()
    return RETICLE_INFO_ICON_POSITION_NAMES
end

function UI.GetReticleInfoIconPositionDefault()
    return RETICLE_INFO_ICON_POSITION_DEFAULT
end

function UI.GetReticleInfoHorizontalOffset(positionKey)
    local settings = GetReticleInfoPositionSettings(positionKey)
    return settings and settings.horizontalOffset or 0
end

function UI.SetReticleInfoHorizontalOffset(positionKey, value)
    local settings = GetReticleInfoPositionSettings(positionKey)
    if not settings then
        return
    end

    local offset = NQOL.Util.Clamp(tonumber(value) or 0, RETICLE_INFO_OFFSET_MIN, RETICLE_INFO_OFFSET_MAX)
    settings.horizontalOffset = math.floor(offset + 0.5)
    UI.QueueCombatReticleApply()
end

function UI.GetReticleInfoHorizontalOffsetDefault(positionKey)
    local config = RETICLE_INFO_POSITION_CONFIG[positionKey]
    return config and config.horizontalOffset or 0
end

function UI.GetReticleInfoVerticalOffset(positionKey)
    local settings = GetReticleInfoPositionSettings(positionKey)
    return settings and settings.verticalOffset or 0
end

function UI.SetReticleInfoVerticalOffset(positionKey, value)
    local settings = GetReticleInfoPositionSettings(positionKey)
    if not settings then
        return
    end

    local offset = NQOL.Util.Clamp(tonumber(value) or 0, RETICLE_INFO_OFFSET_MIN, RETICLE_INFO_OFFSET_MAX)
    settings.verticalOffset = math.floor(offset + 0.5)
    UI.QueueCombatReticleApply()
end

function UI.GetReticleInfoVerticalOffsetDefault(positionKey)
    local config = RETICLE_INFO_POSITION_CONFIG[positionKey]
    return config and config.verticalOffset or 0
end

function UI.GetReticleInfoOffsetMin()
    return RETICLE_INFO_OFFSET_MIN
end

function UI.GetReticleInfoOffsetMax()
    return RETICLE_INFO_OFFSET_MAX
end

function UI.GetReticleInfoFont(positionKey)
    local settings = GetReticleInfoPositionSettings(positionKey)
    return settings and settings.font or NQOL.Util.GetDefaultFont()
end

function UI.SetReticleInfoFont(positionKey, font)
    local settings = GetReticleInfoPositionSettings(positionKey)
    if not settings then
        return
    end

    if not NQOL.Util.IsFontChoice(font) then
        font = NQOL.Util.GetDefaultFont()
    end
    settings.font = font
    UI.QueueCombatReticleApply()
end

function UI.GetReticleInfoFontChoices()
    return NQOL.Util.GetFontChoices()
end

function UI.GetReticleInfoFontChoiceNames()
    return NQOL.Util.GetFontChoiceNames()
end

function UI.GetReticleInfoFontSize(positionKey)
    local settings = GetReticleInfoPositionSettings(positionKey)
    return settings and settings.fontSize or RETICLE_INFO_FONT_SIZE_DEFAULT
end

function UI.SetReticleInfoFontSize(positionKey, value)
    local settings = GetReticleInfoPositionSettings(positionKey)
    if not settings then
        return
    end

    local fontSize = NQOL.Util.Clamp(tonumber(value) or RETICLE_INFO_FONT_SIZE_DEFAULT, RETICLE_INFO_FONT_SIZE_MIN, RETICLE_INFO_FONT_SIZE_MAX)
    settings.fontSize = math.floor(fontSize + 0.5)
    UI.QueueCombatReticleApply()
end

function UI.GetReticleInfoFontSizeDefault()
    return RETICLE_INFO_FONT_SIZE_DEFAULT
end

function UI.GetReticleInfoFontSizeMin()
    return RETICLE_INFO_FONT_SIZE_MIN
end

function UI.GetReticleInfoFontSizeMax()
    return RETICLE_INFO_FONT_SIZE_MAX
end

function UI.GetReticleInfoColor(positionKey)
    local settings = GetReticleInfoPositionSettings(positionKey)
    local color = settings and settings.color or DEFAULT_COLOR
    return color.r, color.g, color.b, 1
end

function UI.SetReticleInfoColor(positionKey, red, green, blue, alpha)
    local settings = GetReticleInfoPositionSettings(positionKey)
    if not settings then
        return
    end

    local color = settings.color
    color.r = NQOL.Util.Clamp(tonumber(red) or 1, 0, 1)
    color.g = NQOL.Util.Clamp(tonumber(green) or 1, 0, 1)
    color.b = NQOL.Util.Clamp(tonumber(blue) or 1, 0, 1)
    color.a = 1
    UI.QueueCombatReticleApply()
end

function UI.GetReticleInfoLabel()
    return NQOL.L("features.ui_combat_reticle.reticle_info_label")
end

function UI.GetReticleInfoTooltip()
    return NQOL.L("features.ui_combat_reticle.reticle_info_tooltip")
end

function UI.GetReticleInfoPositionLabel(positionKey)
    local config = RETICLE_INFO_POSITION_CONFIG[positionKey]
    return NQOL.L(config and config.labelKey or "common.unknown_value")
end

function UI.GetReticleInfoPositionTooltip()
    return NQOL.L("features.ui_combat_reticle.position_tooltip")
end

function UI.GetReticleInfoContentLabel()
    return NQOL.L("features.ui_combat_reticle.information_label")
end

function UI.GetReticleInfoContentTooltip()
    return NQOL.L("features.ui_combat_reticle.information_tooltip")
end

function UI.GetReticleInfoIconPositionLabel()
    return NQOL.L("features.ui_combat_reticle.display_icon_label")
end

function UI.GetReticleInfoIconPositionTooltip()
    return NQOL.L("features.ui_combat_reticle.display_icon_tooltip")
end

function UI.GetReticleInfoHorizontalOffsetLabel()
    return NQOL.L("features.ui_combat_reticle.horizontal_offset_label")
end

function UI.GetReticleInfoHorizontalOffsetTooltip()
    return NQOL.L("features.ui_combat_reticle.horizontal_offset_tooltip")
end

function UI.GetReticleInfoVerticalOffsetLabel()
    return NQOL.L("features.ui_combat_reticle.vertical_offset_label")
end

function UI.GetReticleInfoVerticalOffsetTooltip()
    return NQOL.L("features.ui_combat_reticle.vertical_offset_tooltip")
end

function UI.GetReticleInfoFontLabel()
    return NQOL.L("features.ui_combat_reticle.info_font_label")
end

function UI.GetReticleInfoFontTooltip()
    return NQOL.L("features.ui_combat_reticle.info_font_tooltip")
end

function UI.GetReticleInfoFontSizeLabel()
    return NQOL.L("features.ui_combat_reticle.info_font_size_label")
end

function UI.GetReticleInfoFontSizeTooltip()
    return NQOL.L("features.ui_combat_reticle.info_font_size_tooltip")
end

function UI.GetReticleInfoColorLabel()
    return NQOL.L("features.ui_combat_reticle.info_color_label")
end

function UI.GetReticleInfoColorTooltip()
    return NQOL.L("features.ui_combat_reticle.info_color_tooltip")
end
