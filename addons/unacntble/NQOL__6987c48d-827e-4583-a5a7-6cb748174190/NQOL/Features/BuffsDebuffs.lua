NQOL = NQOL or {}
NQOL.Features = NQOL.Features or {}

local BuffsDebuffs = {}

local EVENT_NAMESPACE = "NQOL_BuffsDebuffs"
local TEXTURE_WHITE = "EsoUI/Art/Miscellaneous/white.dds"
local TEXTURE_NON_PERMANENT_MARKER = "EsoUI/Art/Buttons/Gamepad/gp_plus_large.dds"
local TEXTURE_PERMANENT_MARKER = "EsoUI/Art/Buttons/featureDot_active.dds"
local DRAW_LEVEL = 210
local INSET_X = 0
local INSET_Y = 0
local WINDOW_PADDING_X = 8
local WINDOW_PADDING_Y = 6
local ROW_MIN_HEIGHT = 32
local ROW_GAP = 1
local INDICATOR_COLUMN_WIDTH = 34
local LABEL_GAP = 8
local LABEL_MIN_WIDTH = 24
local ICON_SIZE = 21
local SLOT_SIZE = 30
local DEFAULT_FONT_SIZE = 18
local FONT_SIZE_MIN = 12
local FONT_SIZE_MAX = 32
local DEFAULT_BACKGROUND_OPACITY = 0
local BACKGROUND_OPACITY_MIN = 0
local BACKGROUND_OPACITY_MAX = 100
local BUFF_MAJOR_COLOR = { 1, 0.05, 0.02, 1 }
local BUFF_MINOR_COLOR = { 0.02, 0.9, 0.18, 1 }
local EMPTY_SLOT_COLOR = { 1, 1, 1, 0.16 }
local TRACKER_MODE_EVERYTHING = "everything"
local TRACKER_MODE_ACTIVE = "active"
local TRACKER_MODE_SELECTED = "selected"
local TRACKER_MODE_CHOICES = {
    TRACKER_MODE_EVERYTHING,
    TRACKER_MODE_ACTIVE,
    TRACKER_MODE_SELECTED,
}
local TRACKER_MODE_CHOICE_NAMES = NQOL.Lexicon.LocalizedList({
    "features.buffs_debuffs.track_everything",
    "features.buffs_debuffs.track_if_active",
    "features.buffs_debuffs.track_selected",
})
local STACK_TOP_BOTTOM = "topBottom"
local STACK_BOTTOM_TOP = "bottomTop"
local STACK_CHOICES = {
    STACK_TOP_BOTTOM,
    STACK_BOTTOM_TOP,
}
local STACK_CHOICE_NAMES = NQOL.Lexicon.LocalizedList({ "common.top_bottom", "common.bottom_top" })
local VALID_STACK_DIRECTIONS = {
    [STACK_TOP_BOTTOM] = true,
    [STACK_BOTTOM_TOP] = true,
}
local VALID_TRACKER_MODES = {
    [TRACKER_MODE_EVERYTHING] = true,
    [TRACKER_MODE_ACTIVE] = true,
    [TRACKER_MODE_SELECTED] = true,
}
local GAMEPLAY_SCENES = {
    hud = true,
    hudui = true,
    siegeBar = true,
}

local EFFECT_NAMES = NQOL.Features.BuffsDebuffsEffectIds.GetEffectNames()

local defaults = {
    buffsDebuffs = {
        enabled = false,
        monitorMajor = true,
        monitorMinor = true,
        horizontalPosition = 0,
        verticalPosition = 30,
        showInSettings = true,
        useGameIcons = false,
        font = NQOL.Util.GetDefaultFont(),
        fontSize = DEFAULT_FONT_SIZE,
        backgroundOpacity = DEFAULT_BACKGROUND_OPACITY,
        stack = STACK_TOP_BOTTOM,
        trackerMode = TRACKER_MODE_EVERYTHING,
        selectedBuffs = {},
        selectedDebuffs = {},
    },
}

local savedVariables
local initialized = false
local control
local background
local rowControls = {}
local activeEffects = {}
local activeEffectSlots = {}
local dirtyEffectRows = {}
local settingsPanelVisible = false
local refreshQueued = false
local effectRefreshQueued = false
local effectLayoutDirty = false
local sceneCallbackInstalled = false
local dialogCallbackInstalled = false
local eventsRegistered = false
local fontStringCache = {}
local measuringLabel
local effectSequence = 0

local Clamp = NQOL.Util.Clamp
local Round = NQOL.Util.Round

local function GetSettings()
    return NQOL.Settings.GetSection(savedVariables, defaults, "buffsDebuffs")
end

local function IsTrackedBaseName(baseName)
    if type(baseName) ~= "string" then
        return false
    end

    for _, trackedName in ipairs(EFFECT_NAMES) do
        if baseName == trackedName then
            return true
        end
    end

    return false
end

local function GetSortedEffectNames()
    return EFFECT_NAMES
end

local function GetEffectDisplayName(baseName)
    if baseName == "Vexation" then
        -- Prefer ESO's localized effect name; the lexicon provides a short
        -- family-label fallback if the ability has no name available.
        local abilityName = GetAbilityName and GetAbilityName(263403)
        if type(abilityName) == "string" and abilityName ~= "" then
            return zo_strformat(SI_ABILITY_NAME, abilityName)
        end

        return NQOL.L("features.buffs_debuffs.vexation")
    end

    return baseName
end

local function GetEffectDefinition(abilityId)
    return NQOL.Features.BuffsDebuffsEffectIds.GetEffectDefinition(abilityId)
end

local function IsMatchingEnabled(effectType, tier)
    local settings = GetSettings()

    return (tier == "Major" and settings.monitorMajor == true)
        or (tier == "Minor" and settings.monitorMinor == true)
end

local function HasAnyMonitorEnabled()
    local settings = GetSettings()
    return settings.enabled == true
        and (settings.monitorMajor == true
        or settings.monitorMinor == true
        )
end

local function IsEffectTypeSelected(settings, baseName, effectType)
    if effectType == BUFF_EFFECT_TYPE_BUFF then
        return settings.selectedBuffs[baseName] == true
    elseif effectType == BUFF_EFFECT_TYPE_DEBUFF then
        return settings.selectedDebuffs[baseName] == true
    end

    return false
end

local function IsBaseNameAllowedBySelection(settings, baseName)
    if settings.trackerMode ~= TRACKER_MODE_SELECTED then
        return true
    end

    return settings.selectedBuffs[baseName] == true
        and settings.selectedDebuffs[baseName] == true
end

local function HasActiveEnabledEffect(baseName)
    local effects = activeEffects[baseName]
    if not effects then
        return false
    end

    return (effects.Major and IsMatchingEnabled(effects.Major.effectType, "Major"))
        or (effects.Minor and IsMatchingEnabled(effects.Minor.effectType, "Minor"))
end

local function HideControl()
    if control then
        control:SetHidden(true)
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

local function ShouldShow()
    local settings = GetSettings()
    if ZO_Dialogs_IsShowingDialog and ZO_Dialogs_IsShowingDialog() then
        return false
    end

    if settingsPanelVisible and settings.showInSettings == true then
        return true
    end

    return IsGameplaySceneShowing() and HasAnyMonitorEnabled()
end

local function IsRowEnabled(baseName)
    local settings = GetSettings()
    if not IsTrackedBaseName(baseName) then
        return false
    end

    if not HasAnyMonitorEnabled() and not (settings.showInSettings == true and settingsPanelVisible) then
        return false
    end

    if not IsBaseNameAllowedBySelection(settings, baseName) then
        return false
    end

    if settings.trackerMode == TRACKER_MODE_ACTIVE then
        return HasActiveEnabledEffect(baseName)
    end

    return true
end

local function MoveControlAbove(targetControl, drawLevel)
    if targetControl and targetControl.SetDrawLayer and DL_OVERLAY then
        targetControl:SetDrawLayer(DL_OVERLAY)
    end

    if targetControl and targetControl.SetDrawTier and DT_HIGH then
        targetControl:SetDrawTier(DT_HIGH)
    end

    if targetControl and targetControl.SetDrawLevel then
        targetControl:SetDrawLevel(drawLevel)
    end
end

local function GetScreenDimensions()
    local width = GetScreenWidth and GetScreenWidth() or nil
    local height = GetScreenHeight and GetScreenHeight() or nil

    if (not width or width <= 0) and GuiRoot and GuiRoot.GetWidth then
        width = GuiRoot:GetWidth()
    end
    if (not height or height <= 0) and GuiRoot and GuiRoot.GetHeight then
        height = GuiRoot:GetHeight()
    end

    return width or 1920, height or 1080
end

local function SetTextureColor(textureControl, color)
    textureControl:SetColor(color[1], color[2], color[3], color[4])
end

local function ResolveFont()
    local settings = GetSettings()
    local key = tostring(settings.font) .. ":" .. tostring(settings.fontSize)
    if not fontStringCache[key] then
        fontStringCache[key] = NQOL.Util.CreateFontString(settings.font, settings.fontSize, "ZoFontGamepad18")
    end

    return fontStringCache[key]
end

local function GetRowHeight()
    local settings = GetSettings()
    return math.max(ROW_MIN_HEIGHT, (tonumber(settings.fontSize) or DEFAULT_FONT_SIZE) + 8, SLOT_SIZE + 2)
end

local function GetTextWidth(text)
    if not measuringLabel or not measuringLabel.SetText then
        return LABEL_MIN_WIDTH
    end

    measuringLabel:SetFont(ResolveFont())
    measuringLabel:SetText(text or "")

    if measuringLabel.GetTextWidth then
        return math.max(LABEL_MIN_WIDTH, measuringLabel:GetTextWidth())
    end

    return math.max(LABEL_MIN_WIDTH, string.len(text or "") * (tonumber(GetSettings().fontSize) or DEFAULT_FONT_SIZE) * 0.6)
end

local function ApplyBackgroundOpacity()
    if background then
        background:SetCenterColor(0, 0, 0, GetSettings().backgroundOpacity / 100)
        background:SetEdgeColor(0, 0, 0, 0)
    end
end

local function EnsureControls()
    if control or not WINDOW_MANAGER or not GuiRoot then
        return
    end

    control = WINDOW_MANAGER:CreateTopLevelWindow("NQOLBuffsDebuffs")
    control:SetHidden(true)
    MoveControlAbove(control, DRAW_LEVEL)

    background = WINDOW_MANAGER:CreateControl(nil, control, CT_BACKDROP)
    background:SetCenterColor(0, 0, 0, GetSettings().backgroundOpacity / 100)
    background:SetEdgeColor(0, 0, 0, 0)
    background:SetAnchorFill(control)
    MoveControlAbove(background, DRAW_LEVEL)

    measuringLabel = WINDOW_MANAGER:CreateControl(nil, control, CT_LABEL)
    measuringLabel:SetAlpha(0)
    measuringLabel:SetAnchor(TOPLEFT, control, TOPLEFT, -4096, -4096)
    measuringLabel:SetDimensions(4096, ROW_MIN_HEIGHT)
    measuringLabel:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    measuringLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
end

local function GetRowControl(baseName)
    local row = rowControls[baseName]
    if row then
        return row
    end

    row = WINDOW_MANAGER:CreateControl(nil, control, CT_CONTROL)

    row.minorSlot = WINDOW_MANAGER:CreateControl(nil, row, CT_TEXTURE)
    row.minorSlot:SetTexture(TEXTURE_WHITE)
    SetTextureColor(row.minorSlot, EMPTY_SLOT_COLOR)
    row.minorSlot:SetDimensions(SLOT_SIZE, SLOT_SIZE)
    MoveControlAbove(row.minorSlot, DRAW_LEVEL + 2)

    row.majorSlot = WINDOW_MANAGER:CreateControl(nil, row, CT_TEXTURE)
    row.majorSlot:SetTexture(TEXTURE_WHITE)
    SetTextureColor(row.majorSlot, EMPTY_SLOT_COLOR)
    row.majorSlot:SetDimensions(SLOT_SIZE, SLOT_SIZE)
    MoveControlAbove(row.majorSlot, DRAW_LEVEL + 2)

    row.minorIcon = WINDOW_MANAGER:CreateControl(nil, row, CT_TEXTURE)
    row.minorIcon:SetDimensions(ICON_SIZE, ICON_SIZE)
    MoveControlAbove(row.minorIcon, DRAW_LEVEL + 3)

    row.majorIcon = WINDOW_MANAGER:CreateControl(nil, row, CT_TEXTURE)
    row.majorIcon:SetDimensions(ICON_SIZE, ICON_SIZE)
    MoveControlAbove(row.majorIcon, DRAW_LEVEL + 3)

    row.minorMarker = WINDOW_MANAGER:CreateControl(nil, row, CT_LABEL)
    row.minorMarker:SetDimensions(SLOT_SIZE, SLOT_SIZE)
    row.minorMarker:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    row.minorMarker:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    row.minorMarker:SetFont("ZoFontGamepad34")
    row.minorMarker:SetHidden(true)
    MoveControlAbove(row.minorMarker, DRAW_LEVEL + 4)

    row.majorMarker = WINDOW_MANAGER:CreateControl(nil, row, CT_LABEL)
    row.majorMarker:SetDimensions(SLOT_SIZE, SLOT_SIZE)
    row.majorMarker:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    row.majorMarker:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    row.majorMarker:SetFont("ZoFontGamepad34")
    row.majorMarker:SetHidden(true)
    MoveControlAbove(row.majorMarker, DRAW_LEVEL + 4)

    row.label = WINDOW_MANAGER:CreateControl(nil, row, CT_LABEL)
    row.label:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    row.label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    row.label:SetColor(1, 1, 1, 0.95)
    if row.label.SetWrapMode and TEXT_WRAP_MODE_ELLIPSIS then
        row.label:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    end
    MoveControlAbove(row.label, DRAW_LEVEL + 3)

    rowControls[baseName] = row
    return row
end

local function ApplyPosition()
    if not control then
        return
    end

    local settings = GetSettings()
    local screenWidth, screenHeight = GetScreenDimensions()
    local controlWidth = control:GetWidth()
    local x = (screenWidth - controlWidth - (INSET_X * 2)) * (settings.horizontalPosition / 100) + INSET_X
    local y = (screenHeight - (INSET_Y * 2)) * (settings.verticalPosition / 100) + INSET_Y

    control:ClearAnchors()
    if settings.stack == STACK_BOTTOM_TOP then
        control:SetAnchor(BOTTOMLEFT, GuiRoot, TOPLEFT, x, y)
    else
        control:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, x, y)
    end
end

local function ApplyIcon(textureControl, effectData)
    if effectData and type(effectData.iconFilename) == "string" and effectData.iconFilename ~= "" then
        textureControl:SetTexture(effectData.iconFilename)
        textureControl:SetColor(1, 1, 1, 1)
        textureControl:SetHidden(false)
    else
        textureControl:SetHidden(true)
    end
end

local function ApplyBuffShape(textureControl, markerControl, effectData, tier)
    markerControl:SetHidden(true)

    local color = tier == "Major" and BUFF_MAJOR_COLOR or BUFF_MINOR_COLOR
    textureControl:SetTexture(TEXTURE_NON_PERMANENT_MARKER)
    textureControl:SetColor(color[1], color[2], color[3], color[4])
    textureControl:SetHidden(false)
end

local function ApplyPermanentShape(textureControl, effectData, tier)
    if not effectData then
        textureControl:SetHidden(true)
        return
    end

    local color = tier == "Major" and BUFF_MAJOR_COLOR or BUFF_MINOR_COLOR
    textureControl:SetTexture(TEXTURE_PERMANENT_MARKER)
    textureControl:SetColor(color[1], color[2], color[3], color[4])
    textureControl:SetHidden(false)
end

local function ApplySlotIcon(textureControl, markerControl, effectData, tier)
    markerControl:SetHidden(true)

    if effectData and effectData.permanent == true then
        ApplyPermanentShape(textureControl, effectData, tier)
    elseif GetSettings().useGameIcons == false and effectData then
        ApplyBuffShape(textureControl, markerControl, effectData, tier)
    else
        ApplyIcon(textureControl, effectData)
    end
end

local function GetVisibleEffectData(baseName, tier)
    local effectData = activeEffects[baseName] and activeEffects[baseName][tier] or nil
    if not effectData or not IsMatchingEnabled(effectData.effectType, tier) then
        return nil
    end

    if GetSettings().trackerMode == TRACKER_MODE_SELECTED and not IsEffectTypeSelected(GetSettings(), baseName, effectData.effectType) then
        return nil
    end

    return effectData
end

local function UpdateRowIcons(baseName)
    local row = rowControls[baseName]
    if not row then
        return
    end

    local settings = GetSettings()
    if settings.monitorMinor == true then
        ApplySlotIcon(row.minorIcon, row.minorMarker, GetVisibleEffectData(baseName, "Minor"), "Minor")
    else
        row.minorIcon:SetHidden(true)
        row.minorMarker:SetHidden(true)
    end

    if settings.monitorMajor == true then
        ApplySlotIcon(row.majorIcon, row.majorMarker, GetVisibleEffectData(baseName, "Major"), "Major")
    else
        row.majorIcon:SetHidden(true)
        row.majorMarker:SetHidden(true)
    end
end

local function Render()
    EnsureControls()
    if not control then
        return
    end

    for _, row in pairs(rowControls) do
        row:SetHidden(true)
    end

    if not ShouldShow() then
        control:SetHidden(true)
        return
    end

    local visibleNames = {}
    for _, baseName in ipairs(GetSortedEffectNames()) do
        if IsRowEnabled(baseName) then
            visibleNames[#visibleNames + 1] = baseName
        end
    end

    if #visibleNames == 0 then
        control:SetHidden(true)
        return
    end

    local settings = GetSettings()
    local indicatorColumnCount = 0
    if settings.monitorMinor == true then
        indicatorColumnCount = indicatorColumnCount + 1
    end
    if settings.monitorMajor == true then
        indicatorColumnCount = indicatorColumnCount + 1
    end

    if indicatorColumnCount == 0 then
        control:SetHidden(true)
        return
    end

    local labelWidth = LABEL_MIN_WIDTH
    for _, baseName in ipairs(visibleNames) do
        labelWidth = math.max(labelWidth, GetTextWidth(GetEffectDisplayName(baseName)))
    end

    local contentWidth = labelWidth + LABEL_GAP + (INDICATOR_COLUMN_WIDTH * indicatorColumnCount)
    local rowHeight = GetRowHeight()
    local contentHeight = (#visibleNames * rowHeight) + (math.max(#visibleNames - 1, 0) * ROW_GAP)
    local width = contentWidth + (WINDOW_PADDING_X * 2)
    local height = contentHeight + (WINDOW_PADDING_Y * 2)

    control:SetDimensions(width, height)
    ApplyBackgroundOpacity()

    for index, baseName in ipairs(visibleNames) do
        local row = GetRowControl(baseName)
        local y = (index - 1) * (rowHeight + ROW_GAP)

        row:SetHidden(false)
        row:ClearAnchors()
        row:SetDimensions(contentWidth, rowHeight)
        row:SetAnchor(TOPLEFT, control, TOPLEFT, WINDOW_PADDING_X, WINDOW_PADDING_Y + y)

        row.minorSlot:ClearAnchors()
        row.majorSlot:ClearAnchors()
        row.minorIcon:ClearAnchors()
        row.majorIcon:ClearAnchors()
        row.minorMarker:ClearAnchors()
        row.majorMarker:ClearAnchors()
        row.label:ClearAnchors()

        row.minorSlot:SetDimensions(SLOT_SIZE, SLOT_SIZE)
        row.majorSlot:SetDimensions(SLOT_SIZE, SLOT_SIZE)
        row.minorIcon:SetDimensions(ICON_SIZE, ICON_SIZE)
        row.majorIcon:SetDimensions(ICON_SIZE, ICON_SIZE)
        row.minorMarker:SetDimensions(SLOT_SIZE, SLOT_SIZE)
        row.majorMarker:SetDimensions(SLOT_SIZE, SLOT_SIZE)
        SetTextureColor(row.minorSlot, EMPTY_SLOT_COLOR)
        SetTextureColor(row.majorSlot, EMPTY_SLOT_COLOR)

        local nextColumn = 0
        local showMinorColumn = settings.monitorMinor == true
        local showMajorColumn = settings.monitorMajor == true

        row.minorSlot:SetHidden(not showMinorColumn)
        row.majorSlot:SetHidden(not showMajorColumn)

        if showMinorColumn then
            row.minorSlot:SetAnchor(CENTER, row, TOPLEFT, (nextColumn * INDICATOR_COLUMN_WIDTH) + (INDICATOR_COLUMN_WIDTH / 2), rowHeight / 2)
            nextColumn = nextColumn + 1
        end

        if showMajorColumn then
            row.majorSlot:SetAnchor(CENTER, row, TOPLEFT, (nextColumn * INDICATOR_COLUMN_WIDTH) + (INDICATOR_COLUMN_WIDTH / 2), rowHeight / 2)
            nextColumn = nextColumn + 1
        end

        row.minorIcon:SetAnchor(CENTER, row.minorSlot, CENTER, 0, 0)
        row.majorIcon:SetAnchor(CENTER, row.majorSlot, CENTER, 0, 0)
        row.minorMarker:SetAnchor(CENTER, row.minorSlot, CENTER, 0, 0)
        row.majorMarker:SetAnchor(CENTER, row.majorSlot, CENTER, 0, 0)

        row.label:SetDimensions(labelWidth, rowHeight)
        row.label:SetAnchor(LEFT, row, LEFT, (INDICATOR_COLUMN_WIDTH * indicatorColumnCount) + LABEL_GAP, 0)
        row.label:SetFont(ResolveFont())
        row.label:SetText(GetEffectDisplayName(baseName))

        UpdateRowIcons(baseName)
    end

    control:SetHidden(false)
    ApplyPosition()
end

local function ClearTable(values)
    for key in pairs(values) do
        values[key] = nil
    end
end

local function PopulateEffectData(
    effectData,
    effectSlot,
    effectDefinition,
    buffName,
    timeStarted,
    timeEnding,
    stackCount,
    iconFilename,
    effectType,
    abilityId
)
    local duration = (timeEnding or 0) - (timeStarted or 0)
    effectSequence = effectSequence + 1
    effectData.effectSlot = effectSlot
    effectData.baseName = effectDefinition.baseName
    effectData.tier = effectDefinition.tier
    effectData.buffName = buffName
    effectData.timeStarted = timeStarted
    effectData.timeEnding = timeEnding
    effectData.duration = duration
    effectData.permanent = duration == 0
    effectData.stackCount = stackCount
    effectData.iconFilename = iconFilename
    effectData.effectType = effectType
    effectData.abilityId = abilityId
    effectData.sequence = effectSequence
    return effectData
end

local function RebuildEffectGroup(baseName, tier)
    if not baseName or not tier then
        return
    end

    local selectedEffect
    for _, effectData in pairs(activeEffectSlots) do
        if effectData.baseName == baseName
            and effectData.tier == tier
            and (not selectedEffect or effectData.sequence > selectedEffect.sequence)
        then
            selectedEffect = effectData
        end
    end

    local effects = activeEffects[baseName]
    if selectedEffect then
        if not effects then
            effects = {}
            activeEffects[baseName] = effects
        end
        effects[tier] = selectedEffect
    elseif effects then
        effects[tier] = nil
        if next(effects) == nil then
            activeEffects[baseName] = nil
        end
    end
end

local function ScanEffects()
    ClearTable(activeEffects)
    ClearTable(activeEffectSlots)

    if not GetNumBuffs or not GetUnitBuffInfo then
        return
    end

    local buffCount = GetNumBuffs("player") or 0
    for buffIndex = 1, buffCount do
        local buffName, timeStarted, timeEnding, effectSlot, stackCount, iconFilename, _, effectType, _, _, abilityId =
            GetUnitBuffInfo("player", buffIndex)
        local effectDefinition = GetEffectDefinition(abilityId)
        if effectDefinition and IsMatchingEnabled(effectType, effectDefinition.tier) then
            effectSlot = effectSlot or buffIndex
            local effectData = PopulateEffectData(
                {},
                effectSlot,
                effectDefinition,
                buffName,
                timeStarted,
                timeEnding,
                stackCount,
                iconFilename,
                effectType,
                abilityId
            )
            activeEffectSlots[effectSlot] = effectData
            local effects = activeEffects[effectDefinition.baseName]
            if not effects then
                effects = {}
                activeEffects[effectDefinition.baseName] = effects
            end
            effects[effectDefinition.tier] = effectData
        end
    end
end

local function Refresh()
    refreshQueued = false
    effectLayoutDirty = false
    ClearTable(dirtyEffectRows)
    ScanEffects()
    Render()
end

local function QueueRefresh()
    if refreshQueued then
        return
    end

    refreshQueued = true
    if zo_callLater then
        zo_callLater(Refresh, 0)
    else
        Refresh()
    end
end

local function FlushEffectRefresh()
    effectRefreshQueued = false
    if refreshQueued then
        return
    end

    if effectLayoutDirty then
        effectLayoutDirty = false
        ClearTable(dirtyEffectRows)
        Render()
        return
    end

    if ShouldShow() then
        for baseName in pairs(dirtyEffectRows) do
            UpdateRowIcons(baseName)
        end
    else
        HideControl()
    end
    ClearTable(dirtyEffectRows)
end

local function QueueEffectRefresh(baseName, layoutChanged)
    if baseName then
        dirtyEffectRows[baseName] = true
    end
    effectLayoutDirty = effectLayoutDirty or layoutChanged == true

    if effectRefreshQueued or refreshQueued then
        return
    end

    effectRefreshQueued = true
    if zo_callLater then
        zo_callLater(FlushEffectRefresh, 0)
    else
        FlushEffectRefresh()
    end
end

local function OnEffectChanged(
    eventCode,
    changeType,
    effectSlot,
    effectName,
    unitTag,
    beginTime,
    endTime,
    stackCount,
    iconFilename,
    deprecatedBuffType,
    effectType,
    abilityType,
    statusEffectType,
    unitName,
    unitId,
    abilityId
)
    if unitTag ~= "player" then
        return
    end

    if changeType == EFFECT_RESULT_FULL_REFRESH then
        QueueRefresh()
        return
    end

    local previousEffect = type(effectSlot) == "number" and activeEffectSlots[effectSlot] or nil
    local effectDefinition = GetEffectDefinition(abilityId)
    if changeType == EFFECT_RESULT_TRANSFER then
        if previousEffect or effectDefinition then
            QueueRefresh()
        end
        return
    end

    if type(effectSlot) ~= "number"
        or (changeType ~= EFFECT_RESULT_GAINED
            and changeType ~= EFFECT_RESULT_UPDATED
            and changeType ~= EFFECT_RESULT_FADED)
    then
        if effectDefinition then
            QueueRefresh()
        end
        return
    end

    if not previousEffect and not effectDefinition then
        return
    end

    local previousBaseName = previousEffect and previousEffect.baseName or nil
    local previousTier = previousEffect and previousEffect.tier or nil
    local incomingBaseName
    local incomingTier
    if changeType ~= EFFECT_RESULT_FADED
        and effectDefinition
        and IsMatchingEnabled(effectType, effectDefinition.tier)
    then
        incomingBaseName = effectDefinition.baseName
        incomingTier = effectDefinition.tier
    end

    local previousRowEnabled = previousBaseName and IsRowEnabled(previousBaseName) or false
    local incomingRowEnabled = previousRowEnabled
    if incomingBaseName and incomingBaseName ~= previousBaseName then
        incomingRowEnabled = IsRowEnabled(incomingBaseName)
    end

    if incomingBaseName then
        local effectData = previousEffect or {}
        activeEffectSlots[effectSlot] = PopulateEffectData(
            effectData,
            effectSlot,
            effectDefinition,
            effectName,
            beginTime,
            endTime,
            stackCount,
            iconFilename,
            effectType,
            abilityId
        )
    else
        activeEffectSlots[effectSlot] = nil
    end

    RebuildEffectGroup(previousBaseName, previousTier)
    if incomingBaseName ~= previousBaseName or incomingTier ~= previousTier then
        RebuildEffectGroup(incomingBaseName, incomingTier)
    end

    local layoutChanged = previousBaseName
        and previousRowEnabled ~= IsRowEnabled(previousBaseName)
        or false
    if incomingBaseName and incomingBaseName ~= previousBaseName then
        layoutChanged = layoutChanged or incomingRowEnabled ~= IsRowEnabled(incomingBaseName)
    end

    QueueEffectRefresh(previousBaseName, layoutChanged)
    if incomingBaseName ~= previousBaseName then
        QueueEffectRefresh(incomingBaseName, layoutChanged)
    end
end

local function RegisterEvents()
    if eventsRegistered then
        return
    end

    eventsRegistered = true
    EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE .. "_EffectChanged", EVENT_EFFECT_CHANGED, OnEffectChanged)
    EVENT_MANAGER:AddFilterForEvent(EVENT_NAMESPACE .. "_EffectChanged", EVENT_EFFECT_CHANGED, REGISTER_FILTER_UNIT_TAG, "player")
    EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE .. "_EffectsFullUpdate", EVENT_EFFECTS_FULL_UPDATE, QueueRefresh)
    EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE .. "_Activated", EVENT_PLAYER_ACTIVATED, QueueRefresh)
    EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE .. "_ScreenResized", EVENT_SCREEN_RESIZED, function()
        Render()
    end)
end

local function UnregisterEvents()
    if not eventsRegistered or not EVENT_MANAGER then
        return
    end

    eventsRegistered = false
    EVENT_MANAGER:UnregisterForEvent(EVENT_NAMESPACE .. "_EffectChanged", EVENT_EFFECT_CHANGED)
    EVENT_MANAGER:UnregisterForEvent(EVENT_NAMESPACE .. "_EffectsFullUpdate", EVENT_EFFECTS_FULL_UPDATE)
    EVENT_MANAGER:UnregisterForEvent(EVENT_NAMESPACE .. "_Activated", EVENT_PLAYER_ACTIVATED)
    EVENT_MANAGER:UnregisterForEvent(EVENT_NAMESPACE .. "_ScreenResized", EVENT_SCREEN_RESIZED)
end

local function InstallSceneCallback()
    if sceneCallbackInstalled or not SCENE_MANAGER or not SCENE_MANAGER.RegisterCallback then
        return
    end

    sceneCallbackInstalled = true
    SCENE_MANAGER:RegisterCallback("SceneStateChanged", function()
        if ShouldShow() then
            QueueRefresh()
        else
            HideControl()
        end
    end)
end

local function InstallDialogCallback()
    if dialogCallbackInstalled or not CALLBACK_MANAGER or not CALLBACK_MANAGER.RegisterCallback then
        return
    end

    dialogCallbackInstalled = true
    CALLBACK_MANAGER:RegisterCallback("OnGamepadDialogShowing", HideControl)
    CALLBACK_MANAGER:RegisterCallback("AllDialogsHidden", function()
        if ShouldShow() then
            QueueRefresh()
        else
            HideControl()
        end
    end)
end

function BuffsDebuffs.InitializeSavedVariables()
    savedVariables = NQOL.Settings.NewAccountWide(defaults)
    local settings = GetSettings()
    settings.selectedBuffs = NQOL.Settings.EnsureTable(settings, "selectedBuffs")
    settings.selectedDebuffs = NQOL.Settings.EnsureTable(settings, "selectedDebuffs")
    settings.selectedBuffs.Sorcery = nil
    settings.selectedBuffs.Prophecy = nil
    settings.selectedDebuffs.Sorcery = nil
    settings.selectedDebuffs.Prophecy = nil
    NQOL.Settings.Boolean(settings, defaults.buffsDebuffs, "enabled")
    NQOL.Settings.Boolean(settings, defaults.buffsDebuffs, "monitorMajor")
    NQOL.Settings.Boolean(settings, defaults.buffsDebuffs, "monitorMinor")
    NQOL.Settings.Boolean(settings, defaults.buffsDebuffs, "showInSettings")
    NQOL.Settings.Boolean(settings, defaults.buffsDebuffs, "useGameIcons")
    if not NQOL.Util.IsFontChoice(settings.font) then
        settings.font = defaults.buffsDebuffs.font
    end
    NQOL.Settings.ClampedNumber(settings, defaults.buffsDebuffs, "fontSize", FONT_SIZE_MIN, FONT_SIZE_MAX, true)
    NQOL.Settings.ClampedNumber(settings, defaults.buffsDebuffs, "backgroundOpacity", BACKGROUND_OPACITY_MIN, BACKGROUND_OPACITY_MAX, true)
    NQOL.Settings.Choice(settings, defaults.buffsDebuffs, "stack", VALID_STACK_DIRECTIONS)
    NQOL.Settings.Choice(settings, defaults.buffsDebuffs, "trackerMode", VALID_TRACKER_MODES)
    NQOL.Settings.ClampedNumber(settings, defaults.buffsDebuffs, "horizontalPosition", 0, 100)
    NQOL.Settings.ClampedNumber(settings, defaults.buffsDebuffs, "verticalPosition", 0, 100)

    for _, baseName in ipairs(EFFECT_NAMES) do
        NQOL.Settings.DefaultFrom(settings.selectedBuffs, baseName, true)
        NQOL.Settings.DefaultFrom(settings.selectedDebuffs, baseName, true)
    end
end

function BuffsDebuffs.Initialize()
    local settings = GetSettings()
    if settings.enabled ~= true and not (settingsPanelVisible and settings.showInSettings == true) then
        return
    end

    if initialized then
        InstallDialogCallback()
        if settings.enabled == true then
            RegisterEvents()
        end
        QueueRefresh()
        return
    end

    initialized = true
    EnsureControls()
    if settings.enabled == true then
        RegisterEvents()
    end
    InstallSceneCallback()
    InstallDialogCallback()
    QueueRefresh()
end

function BuffsDebuffs.SetSettingsPanelVisible(value)
    settingsPanelVisible = value == true
    if settingsPanelVisible and GetSettings().showInSettings == true then
        BuffsDebuffs.Initialize()
    end
    QueueRefresh()
end

function BuffsDebuffs.GetEnabled()
    return GetSettings().enabled
end

function BuffsDebuffs.GetEnabledDefault()
    return defaults.buffsDebuffs.enabled
end

function BuffsDebuffs.SetEnabled(value)
    GetSettings().enabled = value == true

    if GetSettings().enabled == true then
        BuffsDebuffs.Initialize()
    else
        UnregisterEvents()
        if settingsPanelVisible and GetSettings().showInSettings == true then
            BuffsDebuffs.Initialize()
            QueueRefresh()
        else
            HideControl()
        end
    end
end

function BuffsDebuffs.GetMonitorMajor()
    return GetSettings().monitorMajor
end

function BuffsDebuffs.GetMonitorMajorDefault()
    return defaults.buffsDebuffs.monitorMajor
end

function BuffsDebuffs.SetMonitorMajor(value)
    GetSettings().monitorMajor = value == true
    QueueRefresh()
end

function BuffsDebuffs.GetMonitorMinor()
    return GetSettings().monitorMinor
end

function BuffsDebuffs.GetMonitorMinorDefault()
    return defaults.buffsDebuffs.monitorMinor
end

function BuffsDebuffs.SetMonitorMinor(value)
    GetSettings().monitorMinor = value == true
    QueueRefresh()
end

function BuffsDebuffs.GetHorizontalPosition()
    return GetSettings().horizontalPosition
end

function BuffsDebuffs.GetHorizontalPositionDefault()
    return defaults.buffsDebuffs.horizontalPosition
end

function BuffsDebuffs.SetHorizontalPosition(value)
    GetSettings().horizontalPosition = Clamp(value, 0, 100)
    ApplyPosition()
end

function BuffsDebuffs.GetVerticalPosition()
    return GetSettings().verticalPosition
end

function BuffsDebuffs.GetVerticalPositionDefault()
    return defaults.buffsDebuffs.verticalPosition
end

function BuffsDebuffs.SetVerticalPosition(value)
    GetSettings().verticalPosition = Clamp(value, 0, 100)
    ApplyPosition()
end

function BuffsDebuffs.GetShowInSettings()
    return GetSettings().showInSettings
end

function BuffsDebuffs.SetShowInSettings(value)
    GetSettings().showInSettings = value == true
    if settingsPanelVisible and GetSettings().showInSettings == true then
        BuffsDebuffs.Initialize()
    end
    QueueRefresh()
end

function BuffsDebuffs.GetUseGameIcons()
    return GetSettings().useGameIcons
end

function BuffsDebuffs.GetUseGameIconsDefault()
    return defaults.buffsDebuffs.useGameIcons
end

function BuffsDebuffs.SetUseGameIcons(value)
    GetSettings().useGameIcons = value == true
    QueueRefresh()
end

function BuffsDebuffs.GetFontChoices()
    return NQOL.Util.GetFontChoices()
end

function BuffsDebuffs.GetFontChoiceNames()
    return NQOL.Util.GetFontChoiceNames()
end

function BuffsDebuffs.GetFont()
    return GetSettings().font
end

function BuffsDebuffs.SetFont(value)
    if not NQOL.Util.IsFontChoice(value) then
        value = NQOL.Util.GetDefaultFont()
    end

    GetSettings().font = value
    QueueRefresh()
end

function BuffsDebuffs.GetFontSize()
    return GetSettings().fontSize
end

function BuffsDebuffs.SetFontSize(value)
    GetSettings().fontSize = Clamp(Round(value), FONT_SIZE_MIN, FONT_SIZE_MAX)
    QueueRefresh()
end

function BuffsDebuffs.GetBackgroundOpacity()
    return GetSettings().backgroundOpacity
end

function BuffsDebuffs.SetBackgroundOpacity(value)
    GetSettings().backgroundOpacity = Clamp(Round(value), BACKGROUND_OPACITY_MIN, BACKGROUND_OPACITY_MAX)
    QueueRefresh()
end

function BuffsDebuffs.GetBackgroundOpacityMin()
    return BACKGROUND_OPACITY_MIN
end

function BuffsDebuffs.GetBackgroundOpacityMax()
    return BACKGROUND_OPACITY_MAX
end

function BuffsDebuffs.GetStack()
    return GetSettings().stack
end

function BuffsDebuffs.SetStack(value)
    if VALID_STACK_DIRECTIONS[value] then
        GetSettings().stack = value
        QueueRefresh()
    end
end

function BuffsDebuffs.GetStackChoices()
    return STACK_CHOICES
end

function BuffsDebuffs.GetStackChoiceNames()
    return STACK_CHOICE_NAMES
end

function BuffsDebuffs.GetTrackerMode()
    return GetSettings().trackerMode
end

function BuffsDebuffs.SetTrackerMode(value)
    if VALID_TRACKER_MODES[value] then
        GetSettings().trackerMode = value
        QueueRefresh()
    end
end

function BuffsDebuffs.GetTrackerModeChoices()
    return TRACKER_MODE_CHOICES
end

function BuffsDebuffs.GetTrackerModeChoiceNames()
    return TRACKER_MODE_CHOICE_NAMES
end

function BuffsDebuffs.IsTrackSelectedMode()
    return GetSettings().trackerMode == TRACKER_MODE_SELECTED
end

function BuffsDebuffs.GetEffectNames()
    return GetSortedEffectNames()
end

function BuffsDebuffs.GetSelectedBuff(baseName)
    return GetSettings().selectedBuffs[baseName] == true
end

function BuffsDebuffs.SetSelectedBuff(baseName, value)
    GetSettings().selectedBuffs[baseName] = value == true
    QueueRefresh()
end

function BuffsDebuffs.GetSelectedDebuff(baseName)
    return GetSettings().selectedDebuffs[baseName] == true
end

function BuffsDebuffs.SetSelectedDebuff(baseName, value)
    GetSettings().selectedDebuffs[baseName] = value == true
    QueueRefresh()
end

function BuffsDebuffs.GetEnabledLabel()
    return NQOL.L("features.buffs_debuffs.enabled_label")
end

function BuffsDebuffs.GetEnabledTooltip()
    return NQOL.L("features.buffs_debuffs.enabled_tooltip")
end

function BuffsDebuffs.GetMonitorMajorLabel()
    return NQOL.L("features.buffs_debuffs.monitor_major_label")
end

function BuffsDebuffs.GetMonitorMajorTooltip()
    return NQOL.L("features.buffs_debuffs.monitor_major_tooltip")
end

function BuffsDebuffs.GetMonitorMinorLabel()
    return NQOL.L("features.buffs_debuffs.monitor_minor_label")
end

function BuffsDebuffs.GetMonitorMinorTooltip()
    return NQOL.L("features.buffs_debuffs.monitor_minor_tooltip")
end

function BuffsDebuffs.GetHorizontalPositionLabel()
    return NQOL.L("features.buffs_debuffs.horizontal_position_label")
end

function BuffsDebuffs.GetHorizontalPositionTooltip()
    return NQOL.L("features.buffs_debuffs.horizontal_position_tooltip")
end

function BuffsDebuffs.GetVerticalPositionLabel()
    return NQOL.L("features.buffs_debuffs.vertical_position_label")
end

function BuffsDebuffs.GetVerticalPositionTooltip()
    return NQOL.L("features.buffs_debuffs.vertical_position_tooltip")
end

function BuffsDebuffs.GetShowInSettingsLabel()
    return NQOL.L("features.buffs_debuffs.show_in_settings_label")
end

function BuffsDebuffs.GetShowInSettingsTooltip()
    return NQOL.L("features.buffs_debuffs.show_in_settings_tooltip")
end

function BuffsDebuffs.GetUseGameIconsLabel()
    return NQOL.L("features.buffs_debuffs.use_game_icons_label")
end

function BuffsDebuffs.GetUseGameIconsTooltip()
    return NQOL.L("features.buffs_debuffs.use_game_icons_tooltip")
end

function BuffsDebuffs.GetFontLabel()
    return NQOL.L("features.buffs_debuffs.font_label")
end

function BuffsDebuffs.GetFontTooltip()
    return NQOL.L("features.buffs_debuffs.font_tooltip")
end

function BuffsDebuffs.GetFontSizeLabel()
    return NQOL.L("features.buffs_debuffs.font_size_label")
end

function BuffsDebuffs.GetFontSizeTooltip()
    return NQOL.L("features.buffs_debuffs.font_size_tooltip")
end

function BuffsDebuffs.GetBackgroundOpacityLabel()
    return NQOL.L("features.buffs_debuffs.background_opacity_label")
end

function BuffsDebuffs.GetBackgroundOpacityTooltip()
    return NQOL.L("features.buffs_debuffs.background_opacity_tooltip")
end

function BuffsDebuffs.GetFontSizeMin()
    return FONT_SIZE_MIN
end

function BuffsDebuffs.GetFontSizeMax()
    return FONT_SIZE_MAX
end

function BuffsDebuffs.GetStackLabel()
    return NQOL.L("features.buffs_debuffs.stack_label")
end

function BuffsDebuffs.GetStackTooltip()
    return NQOL.L("features.buffs_debuffs.stack_tooltip")
end

function BuffsDebuffs.GetTrackerModeLabel()
    return NQOL.L("features.buffs_debuffs.tracker_mode_label")
end

function BuffsDebuffs.GetTrackerModeTooltip()
    return NQOL.L("features.buffs_debuffs.tracker_mode_tooltip")
end

function BuffsDebuffs.GetSelectedBuffTooltip(baseName)
    return NQOL.L("features.buffs_debuffs.selected_buff", GetEffectDisplayName(baseName))
end

function BuffsDebuffs.GetSelectedDebuffTooltip(baseName)
    return NQOL.L("features.buffs_debuffs.selected_debuff", GetEffectDisplayName(baseName))
end

BuffsDebuffs.GetEffectDisplayName = GetEffectDisplayName

NQOL.Features.BuffsDebuffs = BuffsDebuffs
