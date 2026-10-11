local Addon = LarvalTearMod
local Log = Addon.Common.Log
local LTM_UI = Addon.UI
local LTM_UI_STRINGS = Addon.UI.Strings
local LTM_UI_DISPATCH = Addon.UI.Dispatch
local LTM_UI_LAYOUT = Addon.UI.LayoutConstants
local LTM_UI_RIGHT_PANE_LIST_LAYOUT = LTM_UI_LAYOUT.RightPaneList
local LTM_UI_RIGHT_PANE_ICON_LAYOUT = LTM_UI_LAYOUT.RightPaneIconStrip

local UI_CURRENT_BOTTOM_BODY_SIDE_INSET = 10
local UI_CURRENT_EQUIPMENT_ROW_HEIGHT = LTM_UI_RIGHT_PANE_LIST_LAYOUT.EQUIPMENT_ROW_HEIGHT
local UI_CURRENT_CP_ROW_HEIGHT = LTM_UI_RIGHT_PANE_LIST_LAYOUT.CP_ROW_HEIGHT
local UI_CURRENT_LIST_ROW_GAP = LTM_UI_RIGHT_PANE_LIST_LAYOUT.ROW_GAP
local UI_CURRENT_CP_GROUP_GAP = LTM_UI_RIGHT_PANE_LIST_LAYOUT.CP_GROUP_GAP
local UI_CURRENT_CP_ICON_SIZE = LTM_UI_RIGHT_PANE_LIST_LAYOUT.CP_ICON_SIZE
local UI_CURRENT_CP_FRAME_SIZE = LTM_UI_RIGHT_PANE_LIST_LAYOUT.CP_FRAME_SIZE
local UI_CURRENT_EQUIPMENT_WIDTH = LTM_UI_RIGHT_PANE_LIST_LAYOUT.EQUIPMENT_WIDTH
local UI_EQUIPMENT_MISSING_COLOR = LTM_UI_RIGHT_PANE_LIST_LAYOUT.EQUIPMENT_MISSING_COLOR
local UI_EQUIPMENT_MISSING_TRAIT_COLOR = LTM_UI_RIGHT_PANE_LIST_LAYOUT.EQUIPMENT_MISSING_TRAIT_COLOR
local UI_CURRENT_MASTERY_ICON_SIZE = 40
local UI_CURRENT_MASTERY_ICON_GAP = 3
local RIGHT_PANE_ROLE_ICON_TEXTURES = LTM_UI_LAYOUT.RoleIconTextures
local RIGHT_PANE_ATTRIBUTE_LAYOUTS = LTM_UI_LAYOUT.AttributeLayouts

local CURRENT_CP_GROUP_LAYOUTS = {
    {
        id = "warfare",
        color = { 0.35, 0.73, 0.91, 1.0 },
        disciplineKey = "combat",
    },
    {
        id = "fitness",
        color = { 0.91, 0.41, 0.19, 1.0 },
        disciplineKey = "conditioning",
    },
    {
        id = "craft",
        color = { 0.65, 0.86, 0.32, 1.0 },
        disciplineKey = "world",
    },
}

local function GetText(key, params)
    return LTM_UI_STRINGS:GetText(key, params)
end

local function SetLabelText(control, text)
    if control ~= nil and type(control.SetText) == "function" then
        control:SetText(text or "")
    end
end

local function BuildCurrentSkillLinesText(summary)
    local currentSkillLineNames = type(summary) == "table" and summary.currentSkillLineNames or nil
    if type(currentSkillLineNames) ~= "table" or #currentSkillLineNames == 0 then
        return GetText("current.skill_lines.none")
    end

    return table.concat(currentSkillLineNames, " / ")
end

local function GetRightPaneModeLabel(mode)
    if mode == "target" then
        return GetText("target.title")
    end

    return GetText("current.title")
end

local function BuildRightPaneOutfitDisplayText(outfitName)
    return string.format("%s: %s", GetText("common.outfit"), outfitName or GetText("common.none"))
end

local function ResolveRightPaneRoleIconTexture(roleState)
    local selectedRole = type(roleState) == "table" and tonumber(roleState.selectedRole) or nil
    if selectedRole ~= LFG_ROLE_TANK and selectedRole ~= LFG_ROLE_HEAL and selectedRole ~= LFG_ROLE_DPS then
        return nil
    end

    return RIGHT_PANE_ROLE_ICON_TEXTURES[selectedRole]
end

function LTM_UI:RefreshTransformIcons(controls, entries, mode, cardId)
    controls = type(controls) == "table" and controls or {}
    entries = type(entries) == "table" and entries or {}
    local byKind = {}
    for _, entry in ipairs(entries) do
        if type(entry) == "table" then
            byKind[entry.kind] = entry
        end
    end

    for _, control in ipairs(controls) do
        local entry = byKind[control.ltmTransformKind]
        if type(entry) == "table"
            and type(entry.iconTexture) == "string"
            and entry.iconTexture ~= "" then
            control:SetTexture(entry.iconTexture)
            if type(control.SetDesaturation) == "function" then
                control:SetDesaturation(mode == "target" and entry.apply ~= true and 1 or 0)
            end
            control:SetColor(
                mode == "target" and entry.apply ~= true and 0.38 or 1.0,
                mode == "target" and entry.apply ~= true and 0.38 or 1.0,
                mode == "target" and entry.apply ~= true and 0.38 or 1.0,
                1.0
            )
            control.ltmTransformCardId = cardId
            control:SetHidden(false)
        else
            control.ltmTransformCardId = nil
            control:SetHidden(true)
        end
    end
end

local function ClearAbilityTooltip()
    if type(ClearTooltip) == "function" then
        if AbilityTooltip then
            ClearTooltip(AbilityTooltip)
        end
        if InformationTooltip then
            ClearTooltip(InformationTooltip)
        end
    end
end

local function ShowAbilityTooltip(control, entry, allowFallbackText)
    if type(entry) ~= "table" or control == nil then
        return
    end

    local abilityId = tonumber(entry.abilityId)
    if abilityId ~= nil and abilityId > 0 and AbilityTooltip and type(InitializeTooltip) == "function" then
        InitializeTooltip(AbilityTooltip, control, RIGHT, 0, 0, LEFT)
        if type(AbilityTooltip.SetAbilityId) == "function" and pcall(AbilityTooltip.SetAbilityId, AbilityTooltip, abilityId) then
            return
        end
        if type(AbilityTooltip.SetAbility) == "function" and pcall(AbilityTooltip.SetAbility, AbilityTooltip, abilityId) then
            return
        end
        ClearAbilityTooltip()
    end

    if allowFallbackText ~= true then
        return
    end

    local abilityName = type(entry.abilityName) == "string" and entry.abilityName or nil
    if type(abilityName) == "string" and abilityName ~= "" and InformationTooltip and type(InitializeTooltip) == "function" then
        InitializeTooltip(InformationTooltip, control, RIGHT, 0, 0, LEFT)
        if type(SetTooltipText) == "function" then
            SetTooltipText(InformationTooltip, abilityName)
        end
    end
end

function LTM_UI:ClearClassMasteryAbilityTooltip()
    ClearAbilityTooltip()
end

function LTM_UI:ShowClassMasteryAbilityTooltip(control, entry)
    ShowAbilityTooltip(control, entry, true)
end

function LTM_UI:ClearRightPaneAbilityTooltip()
    ClearAbilityTooltip()
end

function LTM_UI:ShowRightPaneAbilityTooltip(control, entry)
    ShowAbilityTooltip(control, entry, false)
end

local function FindChampionGroupState(championState, groupId)
    local groups = type(championState) == "table" and championState.groups or nil
    for _, group in ipairs(groups or {}) do
        if type(group) == "table" and group.id == groupId then
            return group
        end
    end

    return nil
end

local function ResolveChampionDisciplineType(disciplineKey)
    if disciplineKey == "combat" then
        return rawget(_G, "CHAMPION_DISCIPLINE_TYPE_COMBAT")
    end

    if disciplineKey == "conditioning" then
        return rawget(_G, "CHAMPION_DISCIPLINE_TYPE_CONDITIONING")
    end

    if disciplineKey == "world" then
        return rawget(_G, "CHAMPION_DISCIPLINE_TYPE_WORLD")
    end

    return nil
end

local function ResolveChampionDisciplineSlottedTexture(disciplineType)
    local barTextures = type(ZO_GetChampionBarDisciplineTextures) == "function"
        and ZO_GetChampionBarDisciplineTextures(disciplineType)
        or nil
    local backgroundTexture = type(barTextures) == "table" and barTextures.slotted or nil
    if type(backgroundTexture) == "string" and backgroundTexture ~= "" then
        return backgroundTexture
    end

    if disciplineType == 0 then
        return "EsoUI/Art/Champion/ActionBar/champion_bar_combat_slotted.dds"
    end

    if disciplineType == 1 then
        return "EsoUI/Art/Champion/ActionBar/champion_bar_conditioning_slotted.dds"
    end

    if disciplineType == 2 then
        return "EsoUI/Art/Champion/ActionBar/champion_bar_world_slotted.dds"
    end

    return nil
end

function LTM_UI:GetRightPaneMode()
    return self.rightPaneMode == "target" and "target" or "current"
end

function LTM_UI:SetRightPaneMode(mode)
    local normalizedMode = mode == "target" and "target" or "current"
    if self.rightPaneMode == normalizedMode then
        return
    end

    self:CancelCurrentEffectRefreshDebounce()
    self.rightPaneMode = normalizedMode
    if normalizedMode == "current"
        and self.window ~= nil
        and not self.window:IsHidden()
        and self:IsArmoryStationTabActive() then
        self:RefreshCurrentStatePanel(true)
    else
        self:RefreshRightPanePanel()
    end
end

function LTM_UI:ToggleRightPaneMode()
    if self:GetRightPaneMode() == "target" then
        self:SetRightPaneMode("current")
    else
        self:SetRightPaneMode("target")
    end
end

function LTM_UI:GetEquipmentFetchMonitorState()
    local bankOpen = type(IsBankOpen) == "function" and IsBankOpen() == true or false
    local bankingBag = bankOpen and type(GetBankingBag) == "function" and GetBankingBag() or nil
    return bankOpen, bankingBag
end

function LTM_UI:ShouldRunEquipmentFetchMonitor()
    return self.window ~= nil
        and not self.window:IsHidden()
        and self:IsArmoryStationTabActive()
        and self:GetRightPaneMode() == "target"
end

function LTM_UI:StartEquipmentFetchMonitor()
    if self.equipmentFetchMonitorStarted == true then
        return
    end
    if type(EVENT_MANAGER) ~= "table" or type(EVENT_MANAGER.RegisterForUpdate) ~= "function" then
        return
    end

    -- Keep this monitor registered for the addon lifetime. The callback only
    -- refreshes the Right Pane when the main window, Armory tab, target mode,
    -- or bank/chest state makes the fetch button state relevant. The flag
    -- prevents duplicate RegisterForUpdate calls after repeated UI init paths.
    self.equipmentFetchMonitorStarted = true
    local monitorName = "LTM_UI_EquipmentFetchMonitor"
    EVENT_MANAGER:RegisterForUpdate(monitorName, 1000, function()
        if not LTM_UI:ShouldRunEquipmentFetchMonitor() then
            LTM_UI.lastEquipmentFetchMonitorOpen = nil
            LTM_UI.lastEquipmentFetchMonitorBag = nil
            return
        end

        local bankOpen, bankingBag = LTM_UI:GetEquipmentFetchMonitorState()
        if LTM_UI.lastEquipmentFetchMonitorOpen ~= bankOpen
            or LTM_UI.lastEquipmentFetchMonitorBag ~= bankingBag then
            LTM_UI.lastEquipmentFetchMonitorOpen = bankOpen
            LTM_UI.lastEquipmentFetchMonitorBag = bankingBag
            LTM_UI:RefreshRightPanePanel()
        end
    end)
end

function LTM_UI:RefreshRightPanePanel()
    if not self:IsArmoryStationTabActive() then
        return
    end

    local mode = self:GetRightPaneMode()
    local selectedBuildId = self.selectedBuildId
    local summary
    local rightPaneSkillBars

    if mode == "target" then
        summary = LTM_UI_DISPATCH:GetTargetStateSummary(selectedBuildId)
        rightPaneSkillBars = LTM_UI_DISPATCH:GetTargetSkillBarState(selectedBuildId)
    else
        summary = LTM_UI_DISPATCH:GetCurrentStateSummary()
        rightPaneSkillBars = LTM_UI_DISPATCH:GetCurrentSkillBarState()
    end

    SetLabelText(self.currentTitle, GetRightPaneModeLabel(mode))
    if self.rightPaneModeButton then
        self.rightPaneModeButton:SetText(GetText(mode == "target" and "current.toggle.show_current" or "current.toggle.show_target"))
    end

    local subclassSummaryText = nil
    if mode == "target" and summary.targetAvailable ~= true then
        subclassSummaryText = GetText("target.none")
    else
        subclassSummaryText = BuildCurrentSkillLinesText(summary)
    end
    SetLabelText(self.currentSubclassValue, subclassSummaryText)
    if self.currentSubclassValue then
        self.currentSubclassValue.ltmTooltipText = subclassSummaryText
    end

    self:RefreshCurrentAttributeList(summary)

    self:RefreshSkillBarSlots(self.currentFrontBarSlots, rightPaneSkillBars.front)
    self:RefreshSkillBarSlots(self.currentBackBarSlots, rightPaneSkillBars.back)

    self:RefreshCurrentEquipmentList(summary.equipmentState)

    self:RefreshCurrentChampionList(summary.championState)

    if self.currentEquipmentOutfitLabel then
        local outfitText = BuildRightPaneOutfitDisplayText(summary.outfitName)
        SetLabelText(self.currentEquipmentOutfitLabel, outfitText)
        self.currentEquipmentOutfitLabel.ltmTooltipText = outfitText
    end
    self:RefreshEquipmentFetchButton(summary)
    self:RefreshRightPaneRoleIcon(summary)
    self:RefreshRightPaneClassMasteryIcons(summary)
    self:RefreshTransformIcons(
        self.currentTransformIcons,
        type(summary) == "table" and summary.transformEntries or nil,
        mode,
        mode == "target" and selectedBuildId or nil
    )
    self:RefreshForceChampionRespecControl()
end

function LTM_UI:RefreshEquipmentFetchButton(summary)
    if self.currentEquipmentFetchButton == nil and self.currentEquipmentDepositButton == nil then
        return
    end

    local isTargetMode = self:GetRightPaneMode() == "target"
    local hasTarget = type(summary) == "table" and summary.targetAvailable == true
    local fetchEnabled = isTargetMode
        and hasTarget
        and type(self.selectedBuildId) == "string"
        and LTM_UI_DISPATCH:IsEquipmentFetchAvailable()
    local depositEnabled = isTargetMode
        and hasTarget
        and LTM_UI_DISPATCH:IsEquipmentDepositAvailable()

    if self.currentEquipmentFetchButton ~= nil then
        self.currentEquipmentFetchButton:SetHidden(not isTargetMode or not hasTarget)
        self.currentEquipmentFetchButton:SetEnabled(true)
        self.currentEquipmentFetchButton:SetAlpha(fetchEnabled == true and 1.0 or 0.38)
        self.currentEquipmentFetchButton.ltmFetchEnabled = fetchEnabled == true
        self.currentEquipmentFetchButton.ltmTooltipText = GetText(fetchEnabled == true
            and "current.equipment.fetch.tooltip.ready"
            or "current.equipment.fetch.tooltip.disabled")
    end

    if self.currentEquipmentDepositButton ~= nil then
        self.currentEquipmentDepositButton:SetHidden(not isTargetMode or not hasTarget)
        self.currentEquipmentDepositButton:SetEnabled(true)
        self.currentEquipmentDepositButton:SetAlpha(depositEnabled == true and 1.0 or 0.38)
        self.currentEquipmentDepositButton.ltmDepositEnabled = depositEnabled == true
        self.currentEquipmentDepositButton.ltmTooltipText = GetText(depositEnabled == true
            and "current.equipment.deposit.tooltip.ready"
            or "current.equipment.deposit.tooltip.disabled")
    end
end

function LTM_UI:RefreshRightPaneRoleIcon(summary)
    if self.currentRoleIcon == nil or self.currentRoleArea == nil then
        return
    end

    self.currentRoleIcon:ClearAnchors()
    self.currentRoleIcon:SetAnchor(
        TOPRIGHT,
        self.currentRoleArea,
        TOPRIGHT,
        LTM_UI_RIGHT_PANE_ICON_LAYOUT.ROLE_RIGHT_OFFSET,
        LTM_UI_RIGHT_PANE_ICON_LAYOUT.ROLE_TOP_OFFSET
    )
    self.currentRoleIcon:SetDimensions(
        LTM_UI_RIGHT_PANE_ICON_LAYOUT.ROLE_ICON_SIZE,
        LTM_UI_RIGHT_PANE_ICON_LAYOUT.ROLE_ICON_SIZE
    )

    local roleIconTexture = ResolveRightPaneRoleIconTexture(type(summary) == "table" and summary.role or nil)
    if type(roleIconTexture) == "string" and roleIconTexture ~= "" then
        self.currentRoleIcon:SetTexture(roleIconTexture)
        self.currentRoleIcon:SetHidden(false)
    else
        self.currentRoleIcon:SetHidden(true)
    end
end

function LTM_UI:RefreshRightPaneClassMasteryIcons(summary)
    if type(self.currentClassMasteryIcons) ~= "table" or self.currentClassMasteryArea == nil then
        return
    end

    local classMasteryState = type(summary) == "table" and summary.classMasteryState or nil
    local entries = type(classMasteryState) == "table" and classMasteryState.entries or nil
    local visibleCount = math.min(type(entries) == "table" and #entries or 0, #self.currentClassMasteryIcons)
    local totalWidth = (visibleCount * UI_CURRENT_MASTERY_ICON_SIZE) + math.max(visibleCount - 1, 0) * UI_CURRENT_MASTERY_ICON_GAP

    for index, icon in ipairs(self.currentClassMasteryIcons) do
        local entry = type(entries) == "table" and entries[index] or nil
        if type(entry) == "table" and type(entry.iconTexture) == "string" and entry.iconTexture ~= "" then
            icon:ClearAnchors()
            icon:SetAnchor(
                TOPLEFT,
                self.currentClassMasteryArea,
                TOPLEFT,
                math.floor((self.currentClassMasteryArea:GetWidth() - totalWidth) / 2) + ((index - 1) * (UI_CURRENT_MASTERY_ICON_SIZE + UI_CURRENT_MASTERY_ICON_GAP)),
                0
            )
            icon:SetTexture(entry.iconTexture)
            icon.ltmClassMasteryEntry = entry
            icon:SetHidden(false)
        else
            icon.ltmClassMasteryEntry = nil
            icon:SetHidden(true)
        end
    end
end

function LTM_UI:RefreshCurrentAttributeList(summary)
    local attributes = type(summary) == "table" and summary.attributes or {}
    self.currentAttributeRows = self.currentAttributeRows or {}

    for index, layout in ipairs(RIGHT_PANE_ATTRIBUTE_LAYOUTS) do
        local row = self.currentAttributeRows[index]
        if row ~= nil then
            local color = layout.color
            row.dotTexture:SetColor(color[1], color[2], color[3], color[4])
            row.nameLabel:SetColor(color[1] * 0.92, color[2] * 0.92, color[3] * 0.92, 1.0)
            row.nameLabel:SetText(GetText(layout.shortLabelKey))
            row.valueLabel:SetText(tostring(attributes[layout.id] or 0))
        end
    end
end

local function PositionCurrentEquipmentRow(self, row, index, fillContentWidth)
    if row == nil then
        return
    end

    local rowIndex = tonumber(index) or 1
    local yOffset = (rowIndex - 1) * (UI_CURRENT_EQUIPMENT_ROW_HEIGHT + UI_CURRENT_LIST_ROW_GAP)

    row:ClearAnchors()
    row:SetAnchor(TOPLEFT, self.currentEquipmentContent, TOPLEFT, 0, yOffset)
    if fillContentWidth then
        row:SetAnchor(TOPRIGHT, self.currentEquipmentContent, TOPRIGHT, 0, yOffset)
    else
        row:SetWidth(UI_CURRENT_EQUIPMENT_WIDTH - (UI_CURRENT_BOTTOM_BODY_SIDE_INSET * 2))
    end
    row:SetHeight(UI_CURRENT_EQUIPMENT_ROW_HEIGHT)
end

local function PositionCurrentChampionRow(self, row, yOffset)
    if row == nil then
        return
    end

    local offsetY = yOffset or 0

    row:ClearAnchors()
    row:SetAnchor(TOPLEFT, self.currentChampionContent, TOPLEFT, 0, offsetY)
    row:SetAnchor(TOPRIGHT, self.currentChampionContent, TOPRIGHT, 0, offsetY)
    row:SetHeight(UI_CURRENT_CP_ROW_HEIGHT)
end

function LTM_UI:EnsureCurrentEquipmentRow(index)
    self.currentEquipmentRows = self.currentEquipmentRows or {}

    local row = self.currentEquipmentRows[index]
    if row ~= nil then
        return row
    end

    row = WINDOW_MANAGER:CreateControl("LTM_UI_CurrentEquipmentRow" .. tostring(index), self.currentEquipmentContent, CT_CONTROL)
    PositionCurrentEquipmentRow(self, row, 1, false)
    row:SetHidden(true)

    local label = WINDOW_MANAGER:CreateControl("$(parent)Label", row, CT_LABEL)
    label:ClearAnchors()
    label:SetAnchor(TOPLEFT, row, TOPLEFT, 0, 0)
    label:SetAnchor(BOTTOMRIGHT, row, BOTTOMRIGHT, -82, 0)
    label:SetFont("ZoFontWinT2")
    label:SetColor(0.92, 0.94, 0.98, 1.0)
    label:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    row.nameLabel = label

    local traitLabel = WINDOW_MANAGER:CreateControl("$(parent)TraitLabel", row, CT_LABEL)
    traitLabel:ClearAnchors()
    traitLabel:SetAnchor(TOPRIGHT, row, TOPRIGHT, 0, 0)
    traitLabel:SetAnchor(BOTTOMRIGHT, row, BOTTOMRIGHT, 0, 0)
    traitLabel:SetWidth(78)
    traitLabel:SetFont("ZoFontGameSmall")
    traitLabel:SetColor(0.60, 0.64, 0.70, 1.0)
    traitLabel:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    traitLabel:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    row.traitLabel = traitLabel

    self.currentEquipmentRows[index] = row
    return row
end

function LTM_UI:EnsureCurrentChampionRow(index)
    self.currentChampionRows = self.currentChampionRows or {}

    local row = self.currentChampionRows[index]
    if row ~= nil then
        return row
    end

    row = WINDOW_MANAGER:CreateControl("LTM_UI_CurrentChampionRow" .. tostring(index), self.currentChampionContent, CT_CONTROL)
    PositionCurrentChampionRow(self, row, 0)
    row:SetHidden(true)

    local icon = WINDOW_MANAGER:CreateControl("$(parent)Icon", row, CT_TEXTURE)
    icon:ClearAnchors()
    icon:SetAnchor(LEFT, row, LEFT, 0, 0)
    icon:SetDimensions(UI_CURRENT_CP_ICON_SIZE, UI_CURRENT_CP_ICON_SIZE)
    icon:SetHidden(true)
    row.icon = icon

    local star = nil
    if type(WINDOW_MANAGER) == "table"
        and type(WINDOW_MANAGER.CreateControlFromVirtual) == "function" then
        star = WINDOW_MANAGER:CreateControlFromVirtual("$(parent)Star", row, "ZO_ChampionStarVisuals")
        if star ~= nil then
            star:ClearAnchors()
            star:SetAnchor(LEFT, row, LEFT, 0, 0)
            star:SetDimensions(UI_CURRENT_CP_ICON_SIZE, UI_CURRENT_CP_ICON_SIZE)
            star:SetHidden(true)
            row.star = star

            if type(ZO_ChampionStarVisuals) == "table" and type(ZO_ChampionStarVisuals.New) == "function" then
                row.starVisuals = ZO_ChampionStarVisuals:New(star)
                star:SetHandler("OnUpdate", function(_, timeSecs)
                    if row.starVisuals then
                        row.starVisuals:Update(timeSecs)
                    end
                end)
            end
        end
    end

    local frame = WINDOW_MANAGER:CreateControl("$(parent)Frame", row, CT_TEXTURE)
    frame:ClearAnchors()
    frame:SetAnchor(LEFT, row, LEFT, -1, 0)
    frame:SetDimensions(UI_CURRENT_CP_FRAME_SIZE, UI_CURRENT_CP_FRAME_SIZE)
    frame:SetTexture("/esoui/art/champion/actionbar/champion_bar_slot_frame.dds")
    frame:SetHidden(true)
    row.frame = frame

    local label = WINDOW_MANAGER:CreateControl("$(parent)Label", row, CT_LABEL)
    label:ClearAnchors()
    label:SetAnchor(TOPLEFT, row, TOPLEFT, UI_CURRENT_CP_FRAME_SIZE + 6, 0)
    label:SetAnchor(BOTTOMRIGHT, row, BOTTOMRIGHT, 0, 0)
    label:SetFont("ZoFontWinT2")
    label:SetColor(0.92, 0.94, 0.98, 1.0)
    label:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    label:SetHidden(true)
    row.label = label

    self.currentChampionRows[index] = row
    return row
end

function LTM_UI:RefreshCurrentEquipmentList(equipmentState)
    local entries = type(equipmentState) == "table" and equipmentState.entries or nil
    local emptyText = GetText("current.list.empty")
    local entryCount = type(entries) == "table" and #entries or 0
    self.currentEquipmentRows = self.currentEquipmentRows or {}

    for _, row in ipairs(self.currentEquipmentRows) do
        row:SetHidden(true)
        if row.nameLabel then
            row.nameLabel:SetText("")
        end
        if row.traitLabel then
            row.traitLabel:SetText("")
            row.traitLabel:SetHidden(true)
        end
    end

    if entryCount == 0 then
        local row = self:EnsureCurrentEquipmentRow(1)
        PositionCurrentEquipmentRow(self, row, 1, true)
        row:SetHidden(false)
        row.nameLabel:SetText(emptyText)
        row.nameLabel:SetColor(0.92, 0.94, 0.98, 1.0)
        return
    end

    for index, entry in ipairs(entries or {}) do
        local row = self:EnsureCurrentEquipmentRow(index)
        PositionCurrentEquipmentRow(self, row, index, false)
        if type(entry) == "table" and type(entry.itemName) == "string" and entry.itemName ~= "" then
            local qualityColor = type(entry.qualityColor) == "table" and entry.qualityColor or nil
            local isOwnedNow = entry.isOwnedNow ~= false
            row.nameLabel:SetText(entry.itemName)
            if isOwnedNow then
                row.nameLabel:SetColor(
                    type(qualityColor) == "table" and qualityColor.r or 0.92,
                    type(qualityColor) == "table" and qualityColor.g or 0.94,
                    type(qualityColor) == "table" and qualityColor.b or 0.98,
                    1.0
                )
            else
                row.nameLabel:SetColor(
                    UI_EQUIPMENT_MISSING_COLOR[1],
                    UI_EQUIPMENT_MISSING_COLOR[2],
                    UI_EQUIPMENT_MISSING_COLOR[3],
                    UI_EQUIPMENT_MISSING_COLOR[4]
                )
            end
            if type(entry.traitName) == "string" and entry.traitName ~= "" then
                row.traitLabel:SetText(string.format("(%s)", entry.traitName))
                if isOwnedNow then
                    row.traitLabel:SetColor(0.60, 0.64, 0.70, 1.0)
                else
                    row.traitLabel:SetColor(
                        UI_EQUIPMENT_MISSING_TRAIT_COLOR[1],
                        UI_EQUIPMENT_MISSING_TRAIT_COLOR[2],
                        UI_EQUIPMENT_MISSING_TRAIT_COLOR[3],
                        UI_EQUIPMENT_MISSING_TRAIT_COLOR[4]
                    )
                end
                row.traitLabel:SetHidden(false)
            else
                row.traitLabel:SetText("")
                row.traitLabel:SetHidden(true)
            end
            row:SetHidden(false)
        else
            row.nameLabel:SetText(emptyText)
            row.nameLabel:SetColor(0.92, 0.94, 0.98, 1.0)
            row.traitLabel:SetText("")
            row.traitLabel:SetHidden(true)
            row:SetHidden(false)
        end
    end
end

function LTM_UI:RefreshCurrentChampionList(championState)
    local emptyText = GetText("current.list.empty")
    self.currentChampionRows = self.currentChampionRows or {}

    for _, row in ipairs(self.currentChampionRows) do
        row:SetHidden(true)
        if row.label then
            row.label:SetText("")
            row.label:SetHidden(true)
        end
        if row.icon then
            row.icon:SetHidden(true)
        end
        if row.star then
            row.star:SetHidden(true)
        end
        if row.frame then
            row.frame:SetHidden(true)
        end
    end

    local rowIndex = 1
    local currentYOffset = 0

    for layoutIndex, layout in ipairs(CURRENT_CP_GROUP_LAYOUTS) do
        local groupState = FindChampionGroupState(championState, layout.id)
        local entries = type(groupState) == "table" and groupState.entries or nil
        local entryCount = type(entries) == "table" and #entries or 0

        if entryCount == 0 then
            local row = self:EnsureCurrentChampionRow(rowIndex)
            PositionCurrentChampionRow(self, row, currentYOffset)
            row:SetHidden(false)
            row.label:SetText(emptyText)
            row.label:SetColor(unpack(layout.color))
            row.label:SetHidden(false)
            rowIndex = rowIndex + 1
            currentYOffset = currentYOffset + UI_CURRENT_CP_ROW_HEIGHT + UI_CURRENT_CP_GROUP_GAP
        else
            for index, entry in ipairs(entries or {}) do
                local row = self:EnsureCurrentChampionRow(rowIndex)
                if index == 1 and layoutIndex > 1 then
                    currentYOffset = currentYOffset + UI_CURRENT_CP_GROUP_GAP
                end
                PositionCurrentChampionRow(self, row, currentYOffset)
                row:SetHidden(false)
                row.label:SetText(type(entry) == "table" and (entry.skillName or emptyText) or emptyText)
                row.label:SetColor(unpack(layout.color))
                row.label:SetHidden(false)

                local hasStarVisual = false
                local rowDisciplineType = ResolveChampionDisciplineType(layout.disciplineKey)
                local backgroundTexture = type(rowDisciplineType) == "number"
                    and ResolveChampionDisciplineSlottedTexture(rowDisciplineType)
                    or nil
                if type(entry) == "table"
                    and row.star ~= nil
                    and row.starVisuals ~= nil
                    and type(rowDisciplineType) == "number"
                    and type(ZO_CHAMPION_STAR_VISUAL_TYPE) == "table"
                    and type(ZO_CHAMPION_STAR_STATE) == "table" then
                    row.starVisuals:Setup(
                        ZO_CHAMPION_STAR_VISUAL_TYPE.SLOTTABLE,
                        ZO_CHAMPION_STAR_STATE.PURCHASED,
                        rowDisciplineType,
                        true
                    )
                    row.star:SetHidden(false)
                    hasStarVisual = true
                elseif row.star ~= nil then
                    row.star:SetHidden(true)
                end

                if type(backgroundTexture) == "string" and backgroundTexture ~= "" then
                    row.icon:SetTexture(backgroundTexture)
                    row.icon:SetHidden(false)
                    row.frame:SetHidden(false)
                elseif hasStarVisual then
                    row.icon:SetHidden(true)
                    row.frame:SetHidden(false)
                elseif type(entry) == "table"
                    and type(entry.iconTexture) == "string"
                    and entry.iconTexture ~= "" then
                    row.icon:SetTexture(entry.iconTexture)
                    row.icon:SetHidden(false)
                    row.frame:SetHidden(false)
                else
                    row.icon:SetHidden(true)
                    row.frame:SetHidden(true)
                end

                rowIndex = rowIndex + 1
                currentYOffset = currentYOffset + UI_CURRENT_CP_ROW_HEIGHT + UI_CURRENT_LIST_ROW_GAP
            end
        end
    end
end

function LTM_UI:HandleEquipmentFetchResult(success, reason, summary)
    if success ~= true then
        Log.WriteChat(GetText("status.fetched_equipment_failed", {
            reason = Log.LocalizeErrorReason(reason),
        }))
    elseif reason == "nothing_missing" then
        Log.WriteChat(GetText("status.fetched_equipment_already_owned"))
    elseif reason == "no_fetchable_items" then
        Log.WriteChat(GetText("status.fetched_equipment_none"))
    else
        Log.WriteChat(GetText("status.fetched_equipment", {
            count = tostring(type(summary) == "table" and summary.fetchedSlots or 0),
        }))
    end

    if self.window and not self.window:IsHidden() then
        self:RefreshRightPanePanel()
    end
end

function LTM_UI:HandleEquipmentDepositResult(success, reason, summary)
    local depositedCount = type(summary) == "table" and tonumber(summary.depositedSlots) or 0
    if success ~= true and reason == "deposit_storage_full" and (depositedCount or 0) > 0 then
        Log.WriteChat(GetText("status.deposited_equipment_partial_storage_full", {
            count = tostring(depositedCount or 0),
            protected = tostring(type(summary) == "table" and summary.protectedSlots or 0),
        }))
    elseif success ~= true then
        Log.WriteChat(GetText("status.deposited_equipment_failed", {
            reason = Log.LocalizeErrorReason(reason),
        }))
    elseif reason == "nothing_to_deposit" then
        Log.WriteChat(GetText("status.deposited_equipment_none", {
            protected = tostring(type(summary) == "table" and summary.protectedSlots or 0),
        }))
    else
        Log.WriteChat(GetText("status.deposited_equipment", {
            count = tostring(type(summary) == "table" and summary.depositedSlots or 0),
            protected = tostring(type(summary) == "table" and summary.protectedSlots or 0),
        }))
    end

    if self.window and not self.window:IsHidden() then
        self:RefreshRightPanePanel()
    end
end
