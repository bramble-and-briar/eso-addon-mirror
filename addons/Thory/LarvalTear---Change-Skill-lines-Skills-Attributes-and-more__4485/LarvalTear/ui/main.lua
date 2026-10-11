local Addon = LarvalTearMod
local Log = Addon.Common.Log
local LTM_UI = Addon.UI
local LTM_UI_STRINGS = Addon.UI.Strings
local LTM_UI_DISPATCH = Addon.UI.Dispatch
local LTM_UI_QUICK_SETTINGS = Addon.UI.QuickSettings
local LTM_UI_SKILL_SETTINGS = Addon.UI.SkillSettings
local LTM_UI_LAYOUT = Addon.UI.LayoutConstants
local LTM_UI_CARD_LAYOUT = LTM_UI_LAYOUT.Card
local LTM_UI_DIALOG_LAYOUT = LTM_UI_LAYOUT.Dialog
local LTM_UI_RIGHT_PANE_LIST_LAYOUT = LTM_UI_LAYOUT.RightPaneList
local LTM_UI_RIGHT_PANE_ICON_LAYOUT = LTM_UI_LAYOUT.RightPaneIconStrip

local UI_WINDOW_WIDTH = 1080
local UI_WINDOW_HEIGHT = 720
local UI_WINDOW_PADDING = 18
local UI_TITLEBAR_HEIGHT = 44
local UI_CONTENT_GAP = 16
local UI_MAIN_TAB_BUTTON_WIDTH = 132
local UI_MAIN_TAB_BUTTON_HEIGHT = 24
local UI_MAIN_TAB_BUTTON_GAP = 6
local UI_LEFT_PANE_WIDTH = 430
local UI_PANE_GAP = 18
local UI_SECTION_GAP = 8
local UI_PAGE_HEADER_HEIGHT = 74
local UI_NEW_CARD_AREA_HEIGHT = 58
local UI_PAGE_NAV_BUTTON_WIDTH = 33
local UI_PAGE_NAV_BUTTON_HEIGHT = 33
local UI_PAGE_SELECT_DROPDOWN_WIDTH = 218
local UI_PAGE_ACTION_MENU_WIDTH = 188
local UI_CURRENT_SUMMARY_ROW_HEIGHT = 24
local UI_CURRENT_HEADER_TOP_PADDING = 10
local UI_CURRENT_HEADER_SIDE_PADDING = 12
local UI_CURRENT_HEADER_TITLE_ROW_HEIGHT = 24
local UI_CURRENT_HEADER_ROW_GAP = 6
local UI_CURRENT_HEADER_BOTTOM_PADDING = 8
local UI_CURRENT_SUMMARY_HEIGHT = UI_CURRENT_SUMMARY_ROW_HEIGHT
local UI_CURRENT_HEADER_HEIGHT = UI_CURRENT_HEADER_TOP_PADDING + UI_CURRENT_HEADER_TITLE_ROW_HEIGHT + UI_CURRENT_HEADER_ROW_GAP + UI_CURRENT_SUMMARY_HEIGHT + UI_CURRENT_HEADER_BOTTOM_PADDING
local UI_ACTION_SECTION_HEIGHT = 72
local UI_CARD_SPACING = LTM_UI_CARD_LAYOUT.SPACING
local UI_CARD_HEADER_HEIGHT = LTM_UI_CARD_LAYOUT.HEADER_HEIGHT
local UI_CARD_TITLE_LEFT = LTM_UI_CARD_LAYOUT.TITLE_LEFT
local UI_CARD_ORDINAL_WIDTH = LTM_UI_CARD_LAYOUT.ORDINAL_WIDTH
local UI_CARD_SUMMARY_HEIGHT = LTM_UI_CARD_LAYOUT.SUMMARY_HEIGHT
local UI_CARD_SUMMARY_BLOCK_HEIGHT = LTM_UI_CARD_LAYOUT.SUMMARY_BLOCK_HEIGHT
local UI_CARD_SUMMARY_VALUE_HEIGHT = LTM_UI_CARD_LAYOUT.SUMMARY_VALUE_HEIGHT
local UI_CARD_SUMMARY_TOP_PADDING = LTM_UI_CARD_LAYOUT.SUMMARY_TOP_PADDING
local UI_CARD_STATUS_TOP = LTM_UI_CARD_LAYOUT.STATUS_TOP
local UI_CARD_SUMMARY_CHECKBOX_TOP = LTM_UI_CARD_LAYOUT.SUMMARY_CHECKBOX_TOP
local UI_CARD_LINK_ROW_TOP = LTM_UI_CARD_LAYOUT.LINK_ROW_TOP
local UI_CARD_LINK_ROW_HEIGHT = LTM_UI_CARD_LAYOUT.LINK_ROW_HEIGHT
local UI_CARD_LINK_QS_DROPDOWN_X = LTM_UI_CARD_LAYOUT.LINK_QS_DROPDOWN_X
local UI_CARD_LINK_FOOD_DROPDOWN_X = LTM_UI_CARD_LAYOUT.LINK_FOOD_DROPDOWN_X
local UI_CARD_LINK_DROPDOWN_WIDTH = LTM_UI_CARD_LAYOUT.LINK_DROPDOWN_WIDTH
local UI_CARD_SKILL_SETTINGS_WIDTH = LTM_UI_CARD_LAYOUT.SKILL_SETTINGS_WIDTH
local UI_CARD_SKILL_HEIGHT = LTM_UI_CARD_LAYOUT.SKILL_HEIGHT
local UI_CARD_ATTRIBUTE_WIDTH = LTM_UI_CARD_LAYOUT.ATTRIBUTE_WIDTH
local UI_CARD_ATTRIBUTE_ROW_HEIGHT = LTM_UI_CARD_LAYOUT.ATTRIBUTE_ROW_HEIGHT
local UI_CARD_ATTRIBUTE_ROW_GAP = LTM_UI_CARD_LAYOUT.ATTRIBUTE_ROW_GAP
local UI_CARD_EXPANDED_HEIGHT = LTM_UI_CARD_LAYOUT.EXPANDED_HEIGHT
local UI_CARD_SKILL_SECTION_OFFSET_Y = LTM_UI_CARD_LAYOUT.SKILL_SECTION_OFFSET_Y
local UI_CARD_LIST_SCROLLBAR_GUTTER = LTM_UI_CARD_LAYOUT.LIST_SCROLLBAR_GUTTER
local UI_CARD_LIST_SECTION_BOTTOM_EXTENSION = LTM_UI_CARD_LAYOUT.LIST_SECTION_BOTTOM_EXTENSION
local UI_ACTION_MENU_WIDTH = LTM_UI_CARD_LAYOUT.ACTION_MENU_WIDTH
local UI_ACTION_MENU_ROW_HEIGHT = LTM_UI_CARD_LAYOUT.ACTION_MENU_ROW_HEIGHT
local UI_ACTION_MENU_ROW_GAP = LTM_UI_CARD_LAYOUT.ACTION_MENU_ROW_GAP
local UI_CARD_SUBCLASS_SUMMARY_FONT = "$(MEDIUM_FONT)|15|soft-shadow-thin"
local UI_ACTION_MENU_PADDING_X = 10
local UI_ACTION_MENU_PADDING_Y = 5
local UI_DIALOG_WIDTH = LTM_UI_DIALOG_LAYOUT.WIDTH
local UI_DIALOG_CONFIRM_HEIGHT = LTM_UI_DIALOG_LAYOUT.CONFIRM_HEIGHT
local UI_DIALOG_BODY_CONFIRM_HEIGHT = LTM_UI_DIALOG_LAYOUT.BODY_CONFIRM_HEIGHT
local UI_DIALOG_OUTER_PADDING = LTM_UI_DIALOG_LAYOUT.OUTER_PADDING
local UI_DIALOG_BUTTON_WIDTH = LTM_UI_DIALOG_LAYOUT.BUTTON_WIDTH
local UI_DIALOG_OVERWRITE_OPTION_HEIGHT = LTM_UI_DIALOG_LAYOUT.OVERWRITE_OPTION_HEIGHT
local UI_DIALOG_OVERWRITE_OPTION_GAP = LTM_UI_DIALOG_LAYOUT.OVERWRITE_OPTION_GAP
local UI_DIALOG_PAGE_REORDER_PANEL_HEIGHT = LTM_UI_DIALOG_LAYOUT.PAGE_REORDER_PANEL_HEIGHT
local UI_DIALOG_PAGE_REORDER_ROW_GAP = LTM_UI_DIALOG_LAYOUT.PAGE_REORDER_ROW_GAP
local UI_SLOT_SIZE = 32
local UI_SLOT_GAP = 6
local UI_CURRENT_SLOT_SIZE = 40
local UI_CURRENT_SLOT_GAP = 6
local UI_CURRENT_MASTERY_ICON_SIZE = 40
local UI_CURRENT_MASTERY_ICON_GAP = 3
local UI_CURRENT_ROLE_ICON_LEFT_GAP = 20
local UI_SKILL_BAR_HEADER_HEIGHT = 18
local UI_SKILL_BAR_ROW_GAP = 4
local UI_PANEL_INSET = 12
local UI_LEFT_PANE_INNER_HEIGHT = UI_WINDOW_HEIGHT - UI_TITLEBAR_HEIGHT - UI_CONTENT_GAP - (UI_WINDOW_PADDING * 2)
local UI_LEFT_PANE_SECTION_HEIGHT = UI_LEFT_PANE_INNER_HEIGHT - (UI_CONTENT_GAP * 2)
local UI_CARD_LIST_SECTION_HEIGHT = UI_LEFT_PANE_SECTION_HEIGHT - UI_PAGE_HEADER_HEIGHT - UI_NEW_CARD_AREA_HEIGHT - (UI_SECTION_GAP * 2)
local UI_LEFT_PANE_RIGHT_INSET = UI_CARD_LIST_SCROLLBAR_GUTTER + 4
local UI_RIGHT_PANE_INNER_HEIGHT = UI_LEFT_PANE_INNER_HEIGHT
local UI_RIGHT_PANE_SECTION_HEIGHT = UI_RIGHT_PANE_INNER_HEIGHT - (UI_CONTENT_GAP * 2)
local UI_CURRENT_BODY_HEIGHT = UI_RIGHT_PANE_SECTION_HEIGHT - UI_CURRENT_HEADER_HEIGHT - UI_ACTION_SECTION_HEIGHT - (UI_SECTION_GAP * 2)
local UI_CURRENT_SKILL_ROW_GAP = 8
local UI_CURRENT_SKILL_TOP_PADDING = 10
local UI_CURRENT_SKILL_BOTTOM_PADDING = 10
local UI_CURRENT_SKILL_HEIGHT = UI_CURRENT_SKILL_TOP_PADDING + UI_CURRENT_SLOT_SIZE + UI_CURRENT_SKILL_ROW_GAP + UI_CURRENT_SLOT_SIZE + UI_CURRENT_SKILL_BOTTOM_PADDING
local UI_CURRENT_ATTRIBUTE_WIDTH = 138
local UI_CURRENT_ATTRIBUTE_ROW_HEIGHT = 18
local UI_CURRENT_ATTRIBUTE_ROW_GAP = 6
local UI_CURRENT_BOTTOM_HEIGHT = UI_CURRENT_BODY_HEIGHT - UI_CURRENT_SKILL_HEIGHT - UI_SECTION_GAP
local UI_CURRENT_BOTTOM_BOX_TRIM = 4
local UI_CURRENT_BOTTOM_TITLE_TOP = 8
local UI_CURRENT_BOTTOM_BODY_TOP_GAP = 4
local UI_CURRENT_BOTTOM_BODY_SIDE_INSET = 10
local UI_CURRENT_BOTTOM_BODY_BOTTOM_INSET = 8
local UI_CURRENT_EQUIPMENT_WIDTH = LTM_UI_RIGHT_PANE_LIST_LAYOUT.EQUIPMENT_WIDTH
local UI_CURRENT_DETAIL_TITLE_HEIGHT = LTM_UI_RIGHT_PANE_LIST_LAYOUT.DETAIL_TITLE_HEIGHT
local UI_CURRENT_EQUIPMENT_FETCH_BUTTON_SIZE = 32
local UI_CURRENT_EQUIPMENT_FETCH_BUTTON_GAP = 6
local UI_ACTION_PARTIAL_BUTTON_GAP = 6
local UI_ACTION_PARTIAL_ROW_WIDTH = 132 + 148 + 136 + 112 + (UI_ACTION_PARTIAL_BUTTON_GAP * 3)
local UI_ACTION_APPLY_ROW_BOTTOM_OFFSET = 0
local UI_ACTION_PARTIAL_ROW_BOTTOM_OFFSET = -38
local UI_EFFECT_REFRESH_DEBOUNCE_MS = 50
local UI_EFFECT_REFRESH_UPDATE_NAME = "LTM_UI_CurrentEffectRefreshDebounce"
local UI_POST_APPLY_REFRESH_DELAY_MS = 250
local UI_POST_APPLY_REFRESH_ATTEMPTS = 4
local UI_EQUIPMENT_WITHDRAW_ICON_TEXTURE_PREFIX = LTM_UI_RIGHT_PANE_LIST_LAYOUT.EQUIPMENT_WITHDRAW_ICON_TEXTURE_PREFIX
local UI_EQUIPMENT_DEPOSIT_ICON_TEXTURE_PREFIX = LTM_UI_RIGHT_PANE_LIST_LAYOUT.EQUIPMENT_DEPOSIT_ICON_TEXTURE_PREFIX
local CURRENT_ATTRIBUTE_LAYOUTS = LTM_UI_LAYOUT.AttributeLayouts

local function GetText(key, params)
    return LTM_UI_STRINGS:GetText(key, params)
end

local function ResolveSkillPointPlan(precheck)
    local diagnostics = type(precheck) == "table" and precheck.diagnostics or nil
    return type(diagnostics) == "table" and diagnostics.skillPointPlan or nil
end

local function GetSkillPointPlanValue(plan, key)
    local value = type(plan) == "table" and tonumber(plan[key]) or nil
    return value ~= nil and value or 0
end

local function GetSkillPointExpectedResultText(plan, skillSettings)
    local result = type(plan) == "table" and plan.expectedResult or nil
    local key = "dialog.skill_budget.expected_result.other"
    if result == "skill_phase_skip" then
        local activeShortage = type(skillSettings) == "table" and skillSettings.activeShortage or nil
        key = "dialog.skill_budget.expected_result.active_" .. tostring(activeShortage)
    elseif result == "passive_partial" then
        local passiveShortage = type(skillSettings) == "table" and skillSettings.passiveShortage or nil
        key = "dialog.skill_budget.expected_result.passive_" .. tostring(passiveShortage)
    end
    local text = GetText(key)
    if text == key then
        text = GetText("dialog.skill_budget.expected_result.other")
    end
    return text
end

local function BuildSkillPointShortageDialog(precheck)
    local plan = ResolveSkillPointPlan(precheck)
    if type(plan) ~= "table" then
        return nil, nil
    end

    local dialogId = plan.expectedResult == "skill_phase_skip"
        and "ROUTE_B_BUDGET_SHORT_CONFIRM"
        or "SKILL_BUDGET_SHORT_CONFIRM"
    -- The Evaluator already includes both Active and Morph costs in activeRequired.
    local refundPoints = GetSkillPointPlanValue(plan, "subclassRefund")
        + GetSkillPointPlanValue(plan, "activeRefund")
        + GetSkillPointPlanValue(plan, "passiveRefund")
    local activeRequiredPoints = GetSkillPointPlanValue(plan, "activeRequired")
    local passiveRequestedPoints = GetSkillPointPlanValue(plan, "passiveRequested")
    return dialogId, {
        currentAvailablePoints = tostring(GetSkillPointPlanValue(plan, "availableBefore")),
        refundPoints = tostring(refundPoints),
        activeRequiredPoints = tostring(activeRequiredPoints),
        totalRequiredPoints = tostring(activeRequiredPoints + passiveRequestedPoints),
        expectedResult = GetSkillPointExpectedResultText(plan, precheck.skillSettings),
    }
end

local function LogSkillPointPrecheckSummary(message, cardId, precheck)
    if Log.IsSummaryDebugEnabled() ~= true then
        return
    end

    local plan = ResolveSkillPointPlan(precheck)
    Log.LogDebugSummary(
        message,
        "cardId=" .. tostring(cardId),
        "expectedResult=" .. tostring(type(plan) == "table" and plan.expectedResult or nil),
        "availableBefore=" .. tostring(type(plan) == "table" and plan.availableBefore or nil),
        "subclassRefund=" .. tostring(type(plan) == "table" and plan.subclassRefund or nil),
        "activeRefund=" .. tostring(type(plan) == "table" and plan.activeRefund or nil),
        "activeRequired=" .. tostring(type(plan) == "table" and plan.activeRequired or nil),
        "passiveRefund=" .. tostring(type(plan) == "table" and plan.passiveRefund or nil),
        "passiveRequested=" .. tostring(type(plan) == "table" and plan.passiveRequested or nil),
        "passiveSpendLimit=" .. tostring(type(plan) == "table" and plan.passiveSpendLimit or nil),
        "shortage=" .. tostring(type(plan) == "table" and plan.shortage or nil)
    )
end

local function GetChampionRespecCostForDisplay()
    if type(GetChampionRespecCost) ~= "function" then
        return 3000
    end

    local ok, cost = pcall(GetChampionRespecCost)
    if ok and type(cost) == "number" and cost >= 0 then
        return math.floor(cost)
    end

    return 3000
end

local function BuildForceChampionRespecLabel()
    return GetText("card.force_cp_respec", {
        cost = tostring(GetChampionRespecCostForDisplay()),
    })
end

local function ResolveSavedBaseAbilityId(abilityId)
    if type(abilityId) ~= "number" or abilityId <= 0 then
        return nil
    end

    local progressionData = type(SKILLS_DATA_MANAGER) == "table"
        and type(SKILLS_DATA_MANAGER.GetProgressionDataByAbilityId) == "function"
        and SKILLS_DATA_MANAGER:GetProgressionDataByAbilityId(abilityId)
        or nil
    local skillData = progressionData ~= nil and type(progressionData.GetSkillData) == "function" and progressionData:GetSkillData() or nil
    local morphData = skillData ~= nil and type(skillData.GetMorphData) == "function" and skillData:GetMorphData(MORPH_SLOT_BASE) or nil
    local baseAbilityId = morphData ~= nil and type(morphData.GetAbilityId) == "function" and morphData:GetAbilityId() or nil

    if type(baseAbilityId) == "number" and baseAbilityId > 0 then
        return baseAbilityId
    end

    return abilityId
end

local function ResolvePickupSkillKeys(abilityId)
    local baseAbilityId = ResolveSavedBaseAbilityId(tonumber(abilityId))
    if type(baseAbilityId) ~= "number" or baseAbilityId <= 0 or type(GetSpecificSkillAbilityKeysByAbilityId) ~= "function" then
        return nil, nil, nil
    end

    return GetSpecificSkillAbilityKeysByAbilityId(baseAbilityId)
end

local function ResolveDroppedCardAbilityId(abilityId, hotbarCategory)
    abilityId = tonumber(abilityId)
    hotbarCategory = tonumber(hotbarCategory)
    if abilityId == nil or abilityId <= 0 or hotbarCategory == nil then
        return nil
    end

    local progressionData = type(SKILLS_DATA_MANAGER) == "table"
        and type(SKILLS_DATA_MANAGER.GetProgressionDataByAbilityId) == "function"
        and SKILLS_DATA_MANAGER:GetProgressionDataByAbilityId(abilityId)
        or nil
    if progressionData == nil then
        return nil
    end

    local skillData = type(progressionData.GetSkillData) == "function" and progressionData:GetSkillData() or nil
    if skillData == nil then
        return nil
    end

    if type(skillData.IsPassive) == "function" and skillData:IsPassive() then
        return nil
    end

    local normalizedAbilityId = abilityId
    if type(progressionData.IsChainingAbility) == "function"
        and progressionData:IsChainingAbility()
        and type(GetEffectiveAbilityIdForAbilityOnHotbar) == "function" then
        local isCraftedAbility = type(skillData.IsCraftedAbility) == "function" and skillData:IsCraftedAbility() or false
        if isCraftedAbility then
            return normalizedAbilityId
        end

        normalizedAbilityId = GetEffectiveAbilityIdForAbilityOnHotbar(abilityId, hotbarCategory) or normalizedAbilityId
    end

    return normalizedAbilityId
end

local function FindPageEntryById(pageEntries, pageId)
    if type(pageId) ~= "string" or pageId == "" then
        return nil
    end

    for _, entry in ipairs(pageEntries or {}) do
        if type(entry) == "table" and entry.pageId == pageId then
            return entry
        end
    end

    return nil
end

local function BuildSlotOrdinalText(slotIndex)
    if type(slotIndex) ~= "number" then
        return ""
    end

    return tostring(slotIndex - 2)
end

local function BuildPageDisplayText(pageName)
    if type(pageName) ~= "string" or pageName == "" then
        return GetText("page.header.value")
    end

    return pageName
end

local function BuildPageSelectDisplayText(entry, index)
    local pageName = type(entry) == "table" and entry.name or nil
    if type(pageName) == "string" and pageName ~= "" then
        return pageName
    end

    return string.format("Page %d", tonumber(index) or 1)
end

local CONTROL_NAME_FRAGMENT_PREFIX_MAX = 14
local CONTROL_NAME_FRAGMENT_HASH_MOD = 2176782336

local function BuildControlNameShortId(value)
    local hash = 0
    for index = 1, #value do
        hash = (hash * 131 + string.byte(value, index)) % CONTROL_NAME_FRAGMENT_HASH_MOD
    end

    local digits = "0123456789abcdefghijklmnopqrstuvwxyz"
    local encoded = ""
    repeat
        local digitIndex = (hash % 36) + 1
        encoded = string.sub(digits, digitIndex, digitIndex) .. encoded
        hash = math.floor(hash / 36)
    until hash == 0

    while #encoded < 6 do
        encoded = "0" .. encoded
    end

    if #encoded > 6 then
        encoded = string.sub(encoded, -6)
    end

    return encoded
end

local function BuildControlNameFragment(value)
    value = tostring(value or "")
    local sanitized = value:gsub("[^%w_]", "_")
    sanitized = sanitized:gsub("_+", "_")
    sanitized = sanitized:gsub("^_+", ""):gsub("_+$", "")
    if sanitized == "" then
        sanitized = "unknown"
    end

    local prefix = string.sub(sanitized, 1, CONTROL_NAME_FRAGMENT_PREFIX_MAX)
    if prefix == "" then
        prefix = "unknown"
    end

    return prefix .. "_" .. BuildControlNameShortId(value)
end

local function ClonePageEntries(pageEntries, selectedPageId)
    local clonedEntries = {}

    for index, entry in ipairs(pageEntries or {}) do
        if type(entry) == "table" and type(entry.pageId) == "string" and entry.pageId ~= "" then
            clonedEntries[#clonedEntries + 1] = {
                index = index,
                id = entry.id or entry.pageId,
                pageId = entry.pageId,
                name = entry.name or entry.pageId,
                isCurrent = entry.pageId == selectedPageId,
            }
        end
    end

    return clonedEntries
end

local function CloneMoveTargetPageEntries(pageEntries, sourcePageId, selectedTargetPageId)
    local clonedEntries = {}

    for index, entry in ipairs(pageEntries or {}) do
        if type(entry) == "table"
            and type(entry.pageId) == "string"
            and entry.pageId ~= ""
            and entry.pageId ~= sourcePageId then
            clonedEntries[#clonedEntries + 1] = {
                index = index,
                id = entry.pageId,
                pageId = entry.pageId,
                name = entry.name or entry.pageId,
                isCurrent = entry.pageId == selectedTargetPageId,
            }
        end
    end

    return clonedEntries
end

local function CloneBuildEntries(buildEntries, selectedBuildId)
    local clonedEntries = {}

    for index, entry in ipairs(buildEntries or {}) do
        if type(entry) == "table" and type(entry.buildId) == "string" and entry.buildId ~= "" then
            clonedEntries[#clonedEntries + 1] = {
                index = index,
                id = entry.buildId,
                buildId = entry.buildId,
                name = entry.displayName or entry.buildId,
                isCurrent = entry.buildId == selectedBuildId,
            }
        end
    end

    return clonedEntries
end

local function CreateBackdrop(parent, name, centerR, centerG, centerB, centerA, edgeR, edgeG, edgeB, edgeA)
    local control = WINDOW_MANAGER:CreateControlFromVirtual(name, parent, "ZO_DefaultBackdrop")
    control:SetCenterColor(centerR, centerG, centerB, centerA)
    control:SetEdgeColor(edgeR, edgeG, edgeB, edgeA)
    return control
end

local function CreatePlainBackdrop(parent, centerR, centerG, centerB, centerA, edgeR, edgeG, edgeB, edgeA)
    local control = WINDOW_MANAGER:CreateControl(nil, parent, CT_BACKDROP)
    control:SetCenterColor(centerR, centerG, centerB, centerA)
    control:SetEdgeColor(edgeR, edgeG, edgeB, edgeA)
    return control
end

local function CreateHeaderLabel(parent, name, text, font)
    local label = WINDOW_MANAGER:CreateControl(name, parent, CT_LABEL)
    label:SetFont(font or "ZoFontHeader")
    label:SetColor(0.88, 0.88, 0.92, 1.0)
    label:SetText(text)
    return label
end

local SetTextTooltip

local function SetCardLinkDrawOrder(control, drawLevel)
    if control == nil then
        return
    end

    if type(control.SetDrawTier) == "function" then
        control:SetDrawTier(DT_HIGH)
    end
    if type(control.SetDrawLayer) == "function" then
        control:SetDrawLayer(DL_CONTROLS)
    end
    if type(control.SetDrawLevel) == "function" then
        control:SetDrawLevel(drawLevel)
    end
end

local function CreateCardLinkComboBox(parent, name, left, text, tooltipText, top, width)
    local dropdown = WINDOW_MANAGER:CreateControlFromVirtual(name, parent, "ZO_ComboBox")
    dropdown:ClearAnchors()
    dropdown:SetAnchor(TOPLEFT, parent, TOPLEFT, left, top or UI_CARD_LINK_ROW_TOP)
    dropdown:SetDimensions(width or UI_CARD_LINK_DROPDOWN_WIDTH, UI_CARD_LINK_ROW_HEIGHT)
    SetTextTooltip(dropdown, tooltipText)
    SetCardLinkDrawOrder(dropdown, 7)
    SetCardLinkDrawOrder(dropdown:GetNamedChild("BG"), 8)
    local selectedItemText = dropdown:GetNamedChild("SelectedItemText")
    SetCardLinkDrawOrder(selectedItemText, 9)
    SetCardLinkDrawOrder(dropdown:GetNamedChild("OpenDropdown"), 9)
    if selectedItemText ~= nil then
        if type(selectedItemText.SetMaxLineCount) == "function" then
            selectedItemText:SetMaxLineCount(1)
        end
        if type(selectedItemText.SetWrapMode) == "function" and TEXT_WRAP_MODE_ELLIPSIS then
            selectedItemText:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
        end
    end

    local comboBox = ZO_ComboBox_ObjectFromContainer(dropdown)
    if comboBox ~= nil then
        comboBox:SetSortsItems(false)
        comboBox:ClearItems()
        comboBox:AddItem(comboBox:CreateItemEntry(text, function()
        end))
        comboBox:SetSelectedItemText(text)
    end

    dropdown.comboBox = comboBox
    return dropdown
end

local function CreateValueLabel(parent, name)
    local label = WINDOW_MANAGER:CreateControl(name, parent, CT_LABEL)
    label:SetFont("ZoFontGame")
    label:SetColor(1.0, 1.0, 1.0, 1.0)
    return label
end

SetTextTooltip = function(control, text)
    if control == nil then
        return
    end

    control.ltmTooltipText = text or ""

    control:SetHandler("OnMouseEnter", function(self)
        if type(InitializeTooltip) == "function" and InformationTooltip and type(self.ltmTooltipText) == "string" and self.ltmTooltipText ~= "" then
            InitializeTooltip(InformationTooltip, self, TOP, 0, 0, BOTTOM)
            if type(SetTooltipText) == "function" then
                SetTooltipText(InformationTooltip, self.ltmTooltipText)
            end
        end
    end)

    control:SetHandler("OnMouseExit", function()
        if type(ClearTooltip) == "function" and InformationTooltip then
            ClearTooltip(InformationTooltip)
        end
    end)
end

local function SetCheckButtonTooltip(control, text)
    if control == nil or type(text) ~= "string" or text == "" then
        return
    end

    SetTextTooltip(control, text)

    if type(control.GetNamedChild) ~= "function" then
        return
    end

    local label = control:GetNamedChild("Text") or control:GetNamedChild("Label")
    if label ~= nil then
        SetTextTooltip(label, text)
    end
end

local function CreateIconButton(parent, name, size, anchorPoint, anchorTarget, anchorTargetPoint, offsetX, offsetY, texturePrefix, tooltipText)
    local button = WINDOW_MANAGER:CreateControl(name, parent, CT_BUTTON)
    button:ClearAnchors()
    button:SetAnchor(anchorPoint, anchorTarget, anchorTargetPoint, offsetX, offsetY)
    button:SetDimensions(size, size)
    button:SetClickSound(SOUNDS.DEFAULT_CLICK)
    button.ltmTexturePrefix = texturePrefix
    button:SetNormalTexture(texturePrefix .. "_up.dds")
    button:SetMouseOverTexture(texturePrefix .. "_over.dds")
    button:SetPressedTexture(texturePrefix .. "_down.dds")
    button:SetDisabledTexture(texturePrefix .. "_disabled.dds")
    SetTextTooltip(button, tooltipText)
    return button
end

local function SetControlDrawOrder(control, drawTier, drawLayer, drawLevel)
    if control == nil then
        return
    end

    if drawTier ~= nil and type(control.SetDrawTier) == "function" then
        control:SetDrawTier(drawTier)
    end

    if drawLayer ~= nil and type(control.SetDrawLayer) == "function" then
        control:SetDrawLayer(drawLayer)
    end

    if drawLevel ~= nil and type(control.SetDrawLevel) == "function" then
        control:SetDrawLevel(drawLevel)
    end
end

local function BindCardSelectionMouseUp(control, cardId)
    if control == nil or type(cardId) ~= "string" or cardId == "" then
        return
    end

    if type(control.SetMouseEnabled) == "function" then
        control:SetMouseEnabled(true)
    end

    control:SetHandler("OnMouseUp", function(_, mouseButton, upInside)
        if upInside ~= true then
            return
        end

        if mouseButton ~= MOUSE_BUTTON_INDEX_LEFT then
            return
        end

        LTM_UI:SelectCard(cardId)
    end)
end

local function IsCheckButtonChecked(checkButton)
    if checkButton == nil then
        return false
    end

    if type(ZO_CheckButton_IsChecked) == "function" then
        return ZO_CheckButton_IsChecked(checkButton) == true
    end

    return checkButton.checked == true
end

function LTM_UI:SetCardForceChampionRespecEnabled(cardId, enabled)
    if type(cardId) ~= "string" or cardId == "" then
        return false
    end

    local savedValue = LTM_UI_DISPATCH:SetCardForceChampionRespec(cardId, enabled == true)
    return savedValue == true
end

function LTM_UI:IsCardForceChampionRespecEnabled(cardId)
    return type(cardId) == "string"
        and cardId ~= ""
        and LTM_UI_DISPATCH:GetCardForceChampionRespec(cardId) == true
end

function LTM_UI:RefreshForceChampionRespecControl()
    local checkButton = self.forceChampionRespecCheckbox
    if checkButton == nil then
        return
    end

    local selectedCardId = self.selectedCardId
    local hasSelection = type(selectedCardId) == "string" and selectedCardId ~= ""
    local visible = self:GetRightPaneMode() == "target"
    local enabled = hasSelection and self:IsCardForceChampionRespecEnabled(selectedCardId) == true

    checkButton:SetHidden(not visible)
    if self.forceChampionRespecLabel ~= nil then
        self.forceChampionRespecLabel:SetHidden(not visible)
    end
    if not visible then
        return
    end

    checkButton.ltmSuppressToggle = true
    if type(ZO_CheckButton_SetCheckState) == "function" then
        ZO_CheckButton_SetCheckState(checkButton, enabled)
    end
    if type(ZO_CheckButton_SetEnableState) == "function" then
        ZO_CheckButton_SetEnableState(checkButton, hasSelection)
    elseif type(checkButton.SetEnabled) == "function" then
        checkButton:SetEnabled(hasSelection)
    end
    checkButton.ltmSuppressToggle = false

    local label = self.forceChampionRespecLabel
    if label ~= nil then
        label:SetText(BuildForceChampionRespecLabel())
        label:SetColor(hasSelection and 0.92 or 0.52, hasSelection and 0.90 or 0.52, hasSelection and 0.78 or 0.54, 1.0)
    end
end

local function CreatePageNavButton(parent, name, texturePrefix, tooltipText)
    return CreateIconButton(
        parent,
        name,
        UI_PAGE_NAV_BUTTON_WIDTH,
        TOPLEFT,
        parent,
        TOPLEFT,
        0,
        0,
        texturePrefix,
        tooltipText
    )
end

local function CreatePageSelectComboBox(parent, name)
    local dropdown = WINDOW_MANAGER:CreateControlFromVirtual(name, parent, "ZO_ComboBox")
    dropdown:ClearAnchors()
    dropdown:SetAnchor(CENTER, parent, CENTER, 0, 0)
    dropdown:SetDimensions(UI_PAGE_SELECT_DROPDOWN_WIDTH, UI_PAGE_NAV_BUTTON_HEIGHT)
    SetTextTooltip(dropdown, GetText("page.header.label"))
    SetControlDrawOrder(dropdown, DT_HIGH, DL_CONTROLS, 4)
    SetControlDrawOrder(dropdown:GetNamedChild("BG"), DT_HIGH, DL_CONTROLS, 5)
    SetControlDrawOrder(dropdown:GetNamedChild("SelectedItemText"), DT_HIGH, DL_CONTROLS, 6)
    SetControlDrawOrder(dropdown:GetNamedChild("OpenDropdown"), DT_HIGH, DL_CONTROLS, 6)

    local selectedItemText = dropdown:GetNamedChild("SelectedItemText")
    if selectedItemText ~= nil then
        if type(selectedItemText.SetMaxLineCount) == "function" then
            selectedItemText:SetMaxLineCount(1)
        end
        if type(selectedItemText.SetWrapMode) == "function" and TEXT_WRAP_MODE_ELLIPSIS then
            selectedItemText:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
        end
    end

    local comboBox = ZO_ComboBox_ObjectFromContainer(dropdown)
    if comboBox ~= nil then
        comboBox:SetSortsItems(false)
        comboBox:ClearItems()
    end

    dropdown.comboBox = comboBox
    return dropdown
end

local function SetPageSelectDropdownEnabled(dropdown, enabled)
    if dropdown == nil then
        return
    end

    enabled = enabled == true
    if type(dropdown.SetMouseEnabled) == "function" then
        dropdown:SetMouseEnabled(enabled)
    end
    if type(dropdown.SetEnabled) == "function" then
        dropdown:SetEnabled(enabled)
    end
    if dropdown.comboBox ~= nil and type(dropdown.comboBox.SetEnabled) == "function" then
        dropdown.comboBox:SetEnabled(enabled)
    end

    local alpha = enabled and 1.0 or 0.55
    if type(dropdown.SetAlpha) == "function" then
        dropdown:SetAlpha(alpha)
    end
end

function LTM_UI:GetSelectedPageId()
    return LTM_UI_DISPATCH:GetSelectedPageId()
end

function LTM_UI:SyncSelectedBuildCardState(buildId, pageId, options)
    if type(buildId) ~= "string" or buildId == "" then
        return false
    end

    if self:GetSelectedPageId() ~= pageId then
        self.selectedBuildId = buildId
        self.selectedCardId = buildId
        self.expandedCardId = nil
        self.openActionMenuCardId = nil
        self.openPageActionMenu = false
        self.pendingCardListScroll = nil
        self:RefreshCardList()
        return true
    end

    self:SelectCard(buildId)
    return true
end

function LTM_UI:RefreshPageHeader()
    local navigationState = LTM_UI_DISPATCH:GetPageNavigationState()
    self.pageNavigationState = navigationState

    self:RefreshPageSelectDropdown(navigationState)

    if self.pagePrevButton and type(self.pagePrevButton.SetEnabled) == "function" then
        self.pagePrevButton:SetEnabled(type(navigationState.previousPageId) == "string")
    end

    if self.pageNextButton and type(self.pageNextButton.SetEnabled) == "function" then
        self.pageNextButton:SetEnabled(type(navigationState.nextPageId) == "string")
    end

    if self.pageActionMenu then
        self.pageActionMenu:SetHidden(self.openPageActionMenu ~= true)
    end
end

function LTM_UI:RefreshPageSelectDropdown(navigationState)
    local dropdown = self.pageSelectDropdown
    local comboBox = self.pageSelectComboBox
    if dropdown == nil or comboBox == nil then
        return
    end

    navigationState = type(navigationState) == "table" and navigationState or self.pageNavigationState or {}
    local pageEntries = LTM_UI_DISPATCH:GetPageEntries()
    local selectedPageId = navigationState.selectedPageId
    local selectedDisplayText = BuildPageDisplayText(navigationState.selectedPageName)

    comboBox:SetSortsItems(false)
    comboBox:ClearItems()

    for index, entry in ipairs(pageEntries) do
        local pageId = type(entry) == "table" and entry.pageId or nil
        if type(pageId) == "string" and pageId ~= "" then
            local displayText = BuildPageSelectDisplayText(entry, index)
            local capturedPageId = pageId
            comboBox:AddItem(comboBox:CreateItemEntry(displayText, function()
                LTM_UI:SelectPage(capturedPageId)
            end))
            if pageId == selectedPageId then
                selectedDisplayText = displayText
            end
        end
    end

    comboBox:SetSelectedItemText(selectedDisplayText)
    SetPageSelectDropdownEnabled(dropdown, tonumber(navigationState.pageCount) ~= 1 and #pageEntries > 1)
end

function LTM_UI:HandleAddPage()
    local page, err = LTM_UI_DISPATCH:CreatePage()

    if type(page) ~= "table" then
        self:LogActionError("page.action.add", err)
        return
    end

    self.selectedBuildId = nil
    self.selectedCardId = nil
    self.expandedCardId = nil
    self.openActionMenuCardId = nil
    self.openPageActionMenu = false
    self.pendingCardListScroll = nil
    self:SetCardListScrollOffset(0)
    self:RefreshCardList()
end

function LTM_UI:HandleRenamePage()
    local navigationState = self.pageNavigationState or {}
    local selectedPageId = navigationState.selectedPageId
    if type(selectedPageId) ~= "string" or selectedPageId == "" then
        self:LogActionError("page.action.rename", "page_not_found")
        return
    end

    self:ShowDialog("RENAME_PAGE_INPUT", {
        pageId = selectedPageId,
        pageName = navigationState.selectedPageName or GetText("common.none"),
        initialValue = navigationState.selectedPageName or "",
    })
end

function LTM_UI:HandleDeletePage()
    local navigationState = self.pageNavigationState or {}
    local selectedPageId = navigationState.selectedPageId
    if type(selectedPageId) ~= "string" or selectedPageId == "" then
        self:LogActionError("page.action.delete", "page_not_found")
        return
    end

    self:ShowDialog("DELETE_PAGE_CONFIRM", {
        pageId = selectedPageId,
        pageName = navigationState.selectedPageName or GetText("common.none"),
    })
end

function LTM_UI:HandleReorderPages()
    local pageEntries = LTM_UI_DISPATCH:GetPageEntries()
    local selectedPageId = self:GetSelectedPageId()
    local selectedPageEntry = FindPageEntryById(pageEntries, selectedPageId)

    self:ShowDialog("REORDER_PAGES", {
        selectedPageId = selectedPageId,
        reorderEntries = ClonePageEntries(pageEntries, selectedPageId),
        currentTextKey = "dialog.reorder_pages.current",
        emptyTextKey = "dialog.reorder_pages.empty",
        pageName = type(selectedPageEntry) == "table" and selectedPageEntry.name or nil,
    })
end

function LTM_UI:HandleReorderBuilds()
    local navigationState = self.pageNavigationState or {}
    local selectedPageId = navigationState.selectedPageId or self:GetSelectedPageId()
    if type(selectedPageId) ~= "string" or selectedPageId == "" then
        self:LogActionError("page.action.sort", "page_not_found")
        return
    end

    local buildEntries = self:GetCardEntries()
    self:ShowDialog("REORDER_BUILDS", {
        selectedPageId = selectedPageId,
        selectedBuildId = self.selectedBuildId,
        pageName = navigationState.selectedPageName or GetText("common.none"),
        reorderEntries = CloneBuildEntries(buildEntries, self.selectedBuildId),
        currentTextKey = "dialog.reorder_builds.current",
        emptyTextKey = "dialog.reorder_builds.empty",
    })
end

function LTM_UI:HandleMoveBuildToPage(cardId)
    if type(cardId) ~= "string" or cardId == "" then
        self:LogActionError("card.action.move_page", "build_id_missing")
        return
    end

    local pageEntries = LTM_UI_DISPATCH:GetPageEntries()
    local sourcePageId = self:GetSelectedPageId()
    if type(sourcePageId) ~= "string" or sourcePageId == "" then
        self:LogActionError("card.action.move_page", "page_not_found")
        return
    end

    local targetEntries = CloneMoveTargetPageEntries(pageEntries, sourcePageId, nil)
    local build = LTM_UI_DISPATCH:GetBuildById(cardId)

    self:ShowDialog("MOVE_BUILD_TO_PAGE", {
        cardId = cardId,
        cardName = self:GetBuildDisplayName(cardId, build),
        sourcePageId = sourcePageId,
        reorderEntries = targetEntries,
        selectedEntryId = targetEntries[1] and targetEntries[1].id or nil,
        currentTextKey = "dialog.move_build.selected",
        emptyTextKey = "dialog.move_build.empty",
        rowMode = "picker",
    })
end

function LTM_UI:TogglePageActionMenu()
    self.openPageActionMenu = self.openPageActionMenu ~= true
    if self.openPageActionMenu then
        self.openActionMenuCardId = nil
    end
    self:RefreshSelectionState()
end

function LTM_UI:SelectPage(targetPageId)
    if type(targetPageId) ~= "string" or targetPageId == "" then
        return
    end
    if targetPageId == self:GetSelectedPageId() then
        self.openPageActionMenu = false
        self:RefreshPageHeader()
        return
    end

    local ok = LTM_UI_DISPATCH:SetSelectedPageId(targetPageId)
    if not ok then
        return
    end

    self.selectedBuildId = LTM_UI_DISPATCH:GetSelectedBuildIdForPage(targetPageId)
    self.selectedCardId = self.selectedBuildId
    self.expandedCardId = nil
    self.openActionMenuCardId = nil
    self.openPageActionMenu = false
    self.pendingCardListScroll = nil
    self:SetCardListScrollOffset(0)
    self:RefreshCardList()
end

function LTM_UI:ChangePage(direction)
    local navigationState = self.pageNavigationState or {}
    local targetPageId = direction == "previous" and navigationState.previousPageId or navigationState.nextPageId
    self:SelectPage(targetPageId)
end

function LTM_UI:HasOpenActionMenu()
    return self.openPageActionMenu == true
        or self.openActionMenuCardId ~= nil
        or LTM_UI_QUICK_SETTINGS:HasOpenQuickSlotSettingsMenu()
end

function LTM_UI:CloseActionMenus()
    if not self:HasOpenActionMenu() then
        return
    end

    self.openActionMenuCardId = nil
    self.openPageActionMenu = false
    LTM_UI_QUICK_SETTINGS:HideQuickSlotSettingsMenu()
    self:RefreshSelectionState()
end

function LTM_UI:RefreshActionMenuDismissLayer()
    if self.actionMenuDismissLayer then
        self.actionMenuDismissLayer:SetHidden(not self:HasOpenActionMenu())
    end
end

function LTM_UI:IsArmoryStationTabActive()
    return self.activeMainTab ~= "quick_settings"
end

local function IsCurrentEffectPaneVisible(self)
    return self.window ~= nil
        and not self.window:IsHidden()
        and self:IsArmoryStationTabActive()
        and self:GetRightPaneMode() == "current"
end

function LTM_UI:CancelCurrentEffectRefreshDebounce()
    if self.currentEffectRefreshPending ~= true then
        return
    end

    self.currentEffectRefreshPending = false
    self.currentEffectRefreshGeneration = (self.currentEffectRefreshGeneration or 0) + 1
    if type(EVENT_MANAGER) == "table" and type(EVENT_MANAGER.UnregisterForUpdate) == "function" then
        EVENT_MANAGER:UnregisterForUpdate(UI_EFFECT_REFRESH_UPDATE_NAME)
    end
end

function LTM_UI:ScheduleCurrentEffectRefresh()
    if not IsCurrentEffectPaneVisible(self) then
        return
    end

    if type(EVENT_MANAGER) ~= "table"
        or type(EVENT_MANAGER.RegisterForUpdate) ~= "function"
        or type(EVENT_MANAGER.UnregisterForUpdate) ~= "function" then
        self:RefreshCurrentStatePanel(true)
        return
    end

    if self.currentEffectRefreshPending == true then
        EVENT_MANAGER:UnregisterForUpdate(UI_EFFECT_REFRESH_UPDATE_NAME)
    end

    self.currentEffectRefreshPending = true
    self.currentEffectRefreshGeneration = (self.currentEffectRefreshGeneration or 0) + 1
    local generation = self.currentEffectRefreshGeneration

    -- Player effect changes commonly arrive in short bursts. Use one named,
    -- trailing update so a burst produces one full Current Snapshot refresh.
    EVENT_MANAGER:RegisterForUpdate(UI_EFFECT_REFRESH_UPDATE_NAME, UI_EFFECT_REFRESH_DEBOUNCE_MS, function()
        if LTM_UI.currentEffectRefreshGeneration ~= generation then
            return
        end

        EVENT_MANAGER:UnregisterForUpdate(UI_EFFECT_REFRESH_UPDATE_NAME)
        LTM_UI.currentEffectRefreshPending = false
        if IsCurrentEffectPaneVisible(LTM_UI) then
            LTM_UI:RefreshCurrentStatePanel(true)
        end
    end)
end

function LTM_UI:RefreshMainTabButtons()
    local armoryActive = self:IsArmoryStationTabActive()
    if self.armoryStationTabButton and type(self.armoryStationTabButton.SetEnabled) == "function" then
        self.armoryStationTabButton:SetEnabled(not armoryActive)
    end
    if self.quickSettingsTabButton and type(self.quickSettingsTabButton.SetEnabled) == "function" then
        self.quickSettingsTabButton:SetEnabled(armoryActive)
    end
end

function LTM_UI:ApplyMainTabVisibility()
    local armoryActive = self:IsArmoryStationTabActive()
    if self.armoryStationContent then
        self.armoryStationContent:SetHidden(not armoryActive)
    end
    if self.quickSettingsContent then
        self.quickSettingsContent:SetHidden(armoryActive)
    end
    self:RefreshMainTabButtons()
end

function LTM_UI:SetMainTab(tabId)
    local normalizedTabId = tabId == "quick_settings" and "quick_settings" or "armory_station"
    if self.activeMainTab == normalizedTabId then
        return
    end

    self.activeMainTab = normalizedTabId
    self.openActionMenuCardId = nil
    self.openPageActionMenu = false
    LTM_UI_QUICK_SETTINGS:HideQuickSlotSettingsMenu()
    self:RefreshActionMenuDismissLayer()
    self:HideDialog()
    self:ApplyMainTabVisibility()

    if self:IsArmoryStationTabActive() then
        self:RefreshCardList(self:GetRightPaneMode() == "current")
    else
        self:CancelCurrentEffectRefreshDebounce()
    end
end

local function AppendCurrentSnapshotSignatureValue(parts, value)
    local text = value == nil and "<nil>" or tostring(value)
    parts[#parts + 1] = tostring(#text)
    parts[#parts + 1] = ":"
    parts[#parts + 1] = text
    parts[#parts + 1] = ";"
end

local function AppendCurrentSnapshotSignatureEntries(parts, entries, fields)
    entries = type(entries) == "table" and entries or {}
    AppendCurrentSnapshotSignatureValue(parts, #entries)
    for _, entry in ipairs(entries) do
        entry = type(entry) == "table" and entry or { [1] = entry }
        for _, field in ipairs(fields) do
            AppendCurrentSnapshotSignatureValue(parts, entry[field])
        end
    end
end

local function BuildCurrentSnapshotDisplaySignature(summary, skillBars)
    if type(summary) ~= "table" or type(skillBars) ~= "table" then
        return nil
    end

    local parts = {}
    local attributes = type(summary.attributes) == "table" and summary.attributes or {}
    local skillCounts = type(summary.skillCounts) == "table" and summary.skillCounts or {}
    local effectState = type(summary.effectState) == "table" and summary.effectState or {}
    local equipmentState = type(summary.equipmentState) == "table" and summary.equipmentState or {}
    local championState = type(summary.championState) == "table" and summary.championState or {}
    local role = type(summary.role) == "table" and summary.role or {}
    local classMasteryState = type(summary.classMasteryState) == "table" and summary.classMasteryState or {}

    -- These are the ordered values consumed by the Current Snapshot pane. This
    -- deliberately uses stable display data instead of the freshly allocated
    -- snapshot tables returned by each refresh.
    AppendCurrentSnapshotSignatureEntries(parts, summary.currentSkillLineNames, { 1 })
    AppendCurrentSnapshotSignatureValue(parts, attributes.health)
    AppendCurrentSnapshotSignatureValue(parts, attributes.magicka)
    AppendCurrentSnapshotSignatureValue(parts, attributes.stamina)
    AppendCurrentSnapshotSignatureValue(parts, skillCounts.front)
    AppendCurrentSnapshotSignatureValue(parts, skillCounts.back)
    AppendCurrentSnapshotSignatureValue(parts, effectState.hasActiveEffect)
    AppendCurrentSnapshotSignatureValue(parts, effectState.activeEffectCount)
    AppendCurrentSnapshotSignatureValue(parts, effectState.primaryEffectName)
    AppendCurrentSnapshotSignatureValue(parts, effectState.foodIconTexture)
    AppendCurrentSnapshotSignatureValue(parts, effectState.foodEffectName)
    AppendCurrentSnapshotSignatureValue(parts, effectState.hasFoodEffect)
    AppendCurrentSnapshotSignatureValue(parts, summary.outfitName)
    AppendCurrentSnapshotSignatureValue(parts, role.selectedRole)

    AppendCurrentSnapshotSignatureValue(parts, equipmentState.isConnected)
    AppendCurrentSnapshotSignatureEntries(parts, equipmentState.entries, {
        "slot", "itemLink", "itemName", "traitName", "isOwnedNow",
    })

    AppendCurrentSnapshotSignatureValue(parts, championState.isConnected)
    local championGroups = type(championState.groups) == "table" and championState.groups or {}
    AppendCurrentSnapshotSignatureValue(parts, #championGroups)
    for _, group in ipairs(championGroups) do
        group = type(group) == "table" and group or {}
        AppendCurrentSnapshotSignatureValue(parts, group.id)
        AppendCurrentSnapshotSignatureEntries(parts, group.entries, {
            "slot", "championSkillId", "skillName", "iconTexture", "disciplineType",
        })
    end

    AppendCurrentSnapshotSignatureValue(parts, classMasteryState.targetSkillLineId)
    AppendCurrentSnapshotSignatureEntries(parts, classMasteryState.entries, {
        "abilityId", "abilityName", "iconTexture",
    })
    for _, transformEntry in ipairs(type(summary.transformEntries) == "table" and summary.transformEntries or {}) do
        AppendCurrentSnapshotSignatureValue(parts, transformEntry.kind)
        AppendCurrentSnapshotSignatureValue(parts, transformEntry.skillLineId)
        AppendCurrentSnapshotSignatureValue(parts, transformEntry.apply)
        AppendCurrentSnapshotSignatureEntries(parts, transformEntry.skills, {
            "progressionId", "purchased", "morphSlot", "rank",
        })
    end
    AppendCurrentSnapshotSignatureEntries(parts, skillBars.front, {
        "hotbarCategory", "slot", "abilityId", "abilityName", "iconTexture", "isEmpty", "isPseudoCryptCanonUltimate",
    })
    AppendCurrentSnapshotSignatureEntries(parts, skillBars.back, {
        "hotbarCategory", "slot", "abilityId", "abilityName", "iconTexture", "isEmpty", "isPseudoCryptCanonUltimate",
    })

    return table.concat(parts)
end

function LTM_UI:RefreshCurrentStatePanel(forceSnapshot)
    if not self:IsArmoryStationTabActive() then
        return
    end

    if forceSnapshot == true then
        self:CancelCurrentEffectRefreshDebounce()
        local summary, skillBars = LTM_UI_DISPATCH:RefreshCurrentSnapshot()
        self:RefreshRightPanePanel()
        return BuildCurrentSnapshotDisplaySignature(summary, skillBars)
    end

    self:RefreshRightPanePanel()
end

function LTM_UI:SchedulePostApplyRefreshes()
    if type(zo_callLater) ~= "function" then
        return
    end

    self.postApplyRefreshGeneration = (self.postApplyRefreshGeneration or 0) + 1
    local generation = self.postApplyRefreshGeneration
    local previousSignature = nil

    local function Refresh(attemptIndex)
        if self.postApplyRefreshGeneration ~= generation then
            return
        end

        if not (self.window and not self.window:IsHidden()) then
            return
        end

        local signature = self:RefreshCurrentStatePanel(true)

        -- A single delayed snapshot may still precede a server-side update.
        -- Stop only after two consecutive delayed snapshots have the same
        -- display state; otherwise preserve the existing bounded fallback.
        if signature ~= nil and previousSignature ~= nil and signature == previousSignature then
            return
        end
        previousSignature = signature

        if attemptIndex >= UI_POST_APPLY_REFRESH_ATTEMPTS then
            return
        end

        zo_callLater(function()
            Refresh(attemptIndex + 1)
        end, UI_POST_APPLY_REFRESH_DELAY_MS)
    end

    zo_callLater(function()
        Refresh(1)
    end, UI_POST_APPLY_REFRESH_DELAY_MS)
end

function LTM_UI:OnApplyCompleted(success, err)
    LTM_UI_DISPATCH:RefreshCurrentSnapshot()

    if self.window and not self.window:IsHidden() then
        self:RefreshRightPanePanel()
    end
    self:SchedulePostApplyRefreshes()
end

function LTM_UI:LogActionError(actionKey, reason)
    if reason == "activity_disallowed" then
        return
    end

    Log.WriteChat(GetText("status.error", {
        action = GetText(actionKey),
        reason = Log.LocalizeErrorReason(reason),
    }))
end

local function CreateActionMenuButton(parent, nameSuffix, anchorTo, textKey, onClick)
    local row = WINDOW_MANAGER:CreateControl(parent:GetName() .. nameSuffix .. "Row", parent, CT_CONTROL)
    local rowIndex = #(parent.ltmRows or {})
    local rowTop = UI_ACTION_MENU_PADDING_Y + (rowIndex * (UI_ACTION_MENU_ROW_HEIGHT + UI_ACTION_MENU_ROW_GAP))
    row:ClearAnchors()
    row:SetAnchor(TOPLEFT, parent, TOPLEFT, UI_ACTION_MENU_PADDING_X, rowTop)
    row:SetAnchor(TOPRIGHT, parent, TOPRIGHT, -UI_ACTION_MENU_PADDING_X, rowTop)
    row:SetHeight(UI_ACTION_MENU_ROW_HEIGHT)
    row:SetMouseEnabled(true)
    SetControlDrawOrder(row, DT_HIGH, DL_OVERLAY, 3)

    local background = WINDOW_MANAGER:CreateControl("$(parent)Background", row, CT_BACKDROP)
    background:ClearAnchors()
    background:SetAnchorFill(row)
    background:SetCenterColor(0.0, 0.0, 0.0, 0.0)
    background:SetEdgeColor(0.0, 0.0, 0.0, 0.0)
    SetControlDrawOrder(background, DT_HIGH, DL_OVERLAY, 3)
    row.background = background

    local label = WINDOW_MANAGER:CreateControl("$(parent)Label", row, CT_LABEL)
    label:ClearAnchors()
    label:SetAnchor(LEFT, row, LEFT, 10, 0)
    label:SetAnchor(RIGHT, row, RIGHT, -10, 0)
    label:SetFont("ZoFontGame")
    label:SetColor(0.96, 0.97, 1.0, 1.0)
    if type(label.SetVerticalAlignment) == "function" then
        label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    end
    label:SetText(GetText(textKey))
    if type(label.SetMaxLineCount) == "function" then
        label:SetMaxLineCount(1)
    end
    if type(label.SetWrapMode) == "function" and TEXT_WRAP_MODE_ELLIPSIS then
        label:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    end
    SetControlDrawOrder(label, DT_HIGH, DL_OVERLAY, 5)
    row.label = label
    row.ltmTooltipText = GetText(textKey)

    local function SetRowVisualState(isHover)
        if isHover then
            background:SetCenterColor(0.14, 0.40, 0.70, 0.92)
            background:SetEdgeColor(0.30, 0.58, 0.82, 1.0)
            label:SetColor(1.0, 1.0, 1.0, 1.0)
        else
            background:SetCenterColor(0.0, 0.0, 0.0, 0.0)
            background:SetEdgeColor(0.0, 0.0, 0.0, 0.0)
            label:SetColor(0.96, 0.97, 1.0, 1.0)
        end
    end

    row:SetHandler("OnMouseEnter", function()
        SetRowVisualState(true)
        if type(InitializeTooltip) == "function"
            and InformationTooltip
            and type(row.ltmTooltipText) == "string"
            and row.ltmTooltipText ~= "" then
            InitializeTooltip(InformationTooltip, row, TOP, 0, 0, BOTTOM)
            if type(SetTooltipText) == "function" then
                SetTooltipText(InformationTooltip, row.ltmTooltipText)
            end
        end
    end)
    row:SetHandler("OnMouseExit", function()
        SetRowVisualState(false)
        if type(ClearTooltip) == "function" and InformationTooltip then
            ClearTooltip(InformationTooltip)
        end
    end)
    row:SetHandler("OnMouseUp", function(_, upInside)
        if upInside and type(onClick) == "function" then
            onClick()
        end
    end)

    if type(label.SetMouseEnabled) == "function" then
        label:SetMouseEnabled(false)
    end

    SetRowVisualState(false)
    parent.ltmRows = parent.ltmRows or {}
    parent.ltmRows[#parent.ltmRows + 1] = row
    return row
end

local function CreateSummaryBlock(parent, namePrefix, titleKey, topOffset, blockHeight)
    local block = WINDOW_MANAGER:CreateControl(namePrefix .. "Block", parent, CT_CONTROL)
    block:ClearAnchors()
    block:SetAnchor(TOPLEFT, parent, TOPLEFT, 0, topOffset)
    block:SetAnchor(TOPRIGHT, parent, TOPRIGHT, 0, topOffset)
    block:SetHeight(blockHeight)

    local valueRow = WINDOW_MANAGER:CreateControl(namePrefix .. "ValueRow", block, CT_CONTROL)
    valueRow:ClearAnchors()
    valueRow:SetAnchor(TOPLEFT, block, TOPLEFT, 0, 0)
    valueRow:SetAnchor(TOPRIGHT, block, TOPRIGHT, 0, 0)
    valueRow:SetHeight(UI_CARD_SUMMARY_VALUE_HEIGHT)

    local value = WINDOW_MANAGER:CreateControl(namePrefix .. "Value", valueRow, CT_LABEL)
    value:ClearAnchors()
    value:SetAnchor(LEFT, valueRow, LEFT, UI_PANEL_INSET, 0)
    value:SetAnchor(RIGHT, valueRow, RIGHT, -UI_PANEL_INSET, 0)
    value:SetFont("ZoFontGame")
    value:SetColor(0.94, 0.95, 0.98, 1.0)
    value:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)

    return {
        block = block,
        valueRow = valueRow,
        value = value,
    }
end

local function SetSummaryBlockFont(summaryValueControl, fontName)
    if summaryValueControl == nil or type(fontName) ~= "string" or fontName == "" then
        return
    end

    if type(summaryValueControl.SetFont) == "function" then
        summaryValueControl:SetFont(fontName)
    end
end

local function CreateSlotGrid(parent, namePrefix, slotSize, slotGap)
    local slots = {}
    local previousSlot = nil
    local resolvedSlotSize = slotSize or UI_SLOT_SIZE
    local resolvedSlotGap = slotGap or UI_SLOT_GAP

    for index = 1, 6 do
        local slot = WINDOW_MANAGER:CreateControl(namePrefix .. "Slot" .. tostring(index), parent, CT_CONTROL)
        slot:SetDimensions(resolvedSlotSize, resolvedSlotSize)
        slot:ClearAnchors()
        if previousSlot then
            slot:SetAnchor(TOPLEFT, previousSlot, TOPRIGHT, resolvedSlotGap, 0)
        else
            slot:SetAnchor(TOPLEFT, parent, TOPLEFT, 0, 0)
        end
        slot:SetMouseEnabled(true)

        local background = CreatePlainBackdrop(slot, 0.12, 0.12, 0.14, 0.98, 0.34, 0.36, 0.40, 1.0)
        background:ClearAnchors()
        background:SetAnchorFill(slot)
        if type(background.SetMouseEnabled) == "function" then
            background:SetMouseEnabled(false)
        end
        slot.background = background

        local marker = WINDOW_MANAGER:CreateControl("$(parent)Marker", slot, CT_LABEL)
        marker:ClearAnchors()
        marker:SetAnchor(CENTER, slot, CENTER, 0, 0)
        marker:SetFont("ZoFontGameSmall")
        marker:SetColor(0.50, 0.54, 0.60, 1.0)
        marker:SetText(tostring(index))
        if type(marker.SetMouseEnabled) == "function" then
            marker:SetMouseEnabled(false)
        end
        slot.marker = marker

        local icon = WINDOW_MANAGER:CreateControl("$(parent)Icon", slot, CT_TEXTURE)
        icon:ClearAnchors()
        icon:SetAnchor(TOPLEFT, slot, TOPLEFT, 2, 2)
        icon:SetAnchor(BOTTOMRIGHT, slot, BOTTOMRIGHT, -2, -2)
        icon:SetDrawLayer(DL_CONTROLS)
        icon:SetHidden(true)
        if type(icon.SetMouseEnabled) == "function" then
            icon:SetMouseEnabled(false)
        end
        slot.icon = icon

        local fallbackLabel = WINDOW_MANAGER:CreateControl("$(parent)FallbackLabel", slot, CT_LABEL)
        fallbackLabel:ClearAnchors()
        fallbackLabel:SetAnchor(TOPLEFT, slot, TOPLEFT, 3, 3)
        fallbackLabel:SetAnchor(BOTTOMRIGHT, slot, BOTTOMRIGHT, -3, -3)
        fallbackLabel:SetFont("ZoFontGameSmall")
        fallbackLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        fallbackLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        fallbackLabel:SetColor(0.86, 0.88, 0.92, 1.0)
        fallbackLabel:SetHidden(true)
        if type(fallbackLabel.SetMouseEnabled) == "function" then
            fallbackLabel:SetMouseEnabled(false)
        end
        slot.fallbackLabel = fallbackLabel
        slot.displayIndex = index

        slots[index] = slot
        previousSlot = slot
    end

    return slots
end

local function SetSkillSlotVisual(slotControl, slotState)
    if slotControl == nil then
        return
    end

    local marker = slotControl.marker
    local icon = slotControl.icon
    local fallbackLabel = slotControl.fallbackLabel
    local isEmpty = type(slotState) ~= "table" or slotState.isEmpty ~= false
    local hasIcon = type(slotState) == "table" and type(slotState.iconTexture) == "string" and slotState.iconTexture ~= ""
    local abilityName = type(slotState) == "table" and slotState.abilityName or nil
    local slotText = BuildSlotOrdinalText(type(slotState) == "table" and slotState.slot or (slotControl.displayIndex and slotControl.displayIndex + 2))
    local abilityId = type(slotState) == "table" and tonumber(slotState.abilityId) or nil

    if abilityId ~= nil and abilityId > 0 then
        slotControl.ltmAbilityTooltipEntry = {
            abilityId = abilityId,
            abilityName = abilityName,
        }
    else
        slotControl.ltmAbilityTooltipEntry = nil
    end

    if icon then
        if hasIcon then
            icon:SetTexture(slotState.iconTexture)
            icon:SetHidden(false)
        else
            icon:SetHidden(true)
        end
    end

    if marker then
        marker:SetText(slotText)
        marker:SetHidden(not isEmpty)
    end

    if fallbackLabel then
        if not isEmpty and not hasIcon and type(abilityName) == "string" and abilityName ~= "" then
            fallbackLabel:SetText(abilityName)
            fallbackLabel:SetHidden(false)
        else
            fallbackLabel:SetHidden(true)
            fallbackLabel:SetText("")
        end
    end

    if isEmpty then
        if slotControl.background ~= nil then
            slotControl.background:SetCenterColor(0.12, 0.12, 0.14, 0.98)
            slotControl.background:SetEdgeColor(0.34, 0.36, 0.40, 1.0)
        end
    else
        if slotControl.background ~= nil then
            slotControl.background:SetCenterColor(0.06, 0.07, 0.08, 0.98)
            slotControl.background:SetEdgeColor(0.52, 0.56, 0.62, 1.0)
        end
    end
end

function LTM_UI:RefreshSkillBarSlots(slotControls, slotEntries)
    if type(slotControls) ~= "table" then
        return
    end

    for index, slotControl in ipairs(slotControls) do
        SetSkillSlotVisual(slotControl, type(slotEntries) == "table" and slotEntries[index] or nil)
    end
end

function LTM_UI:RefreshCardSkillEditor()
    self:RefreshCardList()
end

function LTM_UI:HandleCardSkillSlotDragStart(cardId, hotbarCategory, slotIndex, slotControl)
    if IsUnitInCombat("player") then
        return
    end

    if type(GetCursorContentType) ~= "function" or GetCursorContentType() ~= MOUSE_CONTENT_EMPTY then
        return
    end

    local abilityId, err = LTM_UI_DISPATCH:GetCardSkillSlotAbility(cardId, hotbarCategory, slotIndex)
    if type(abilityId) ~= "number" or abilityId <= 0 then
        return
    end

    -- Crypt Canon's equipment-provided ultimate is not a normal draggable skill
    -- target; overwriting the equipment/card state is required instead.
    if abilityId == 195031 then
        Log.WriteChat(LTM.GetStringText("SI_LTM_STATUS_CRYPTCANON_OVERWRITE_REQUIRED"))
        return
    end

    local skillType, skillLine, skillIndex = ResolvePickupSkillKeys(abilityId)
    if type(skillType) ~= "number" or type(skillLine) ~= "number" or type(skillIndex) ~= "number" then
        self:LogActionError("common.save", err or "skill_pickup_unavailable")
        return
    end

    if type(CallSecureProtected) ~= "function"
        or not CallSecureProtected("PickupAbilityBySkillLine", skillType, skillLine, skillIndex) then
        return
    end

    local updateResult, updateErr = LTM_UI_DISPATCH:SetCardSkillSlotAbility(cardId, hotbarCategory, slotIndex, 0)
    if type(updateResult) ~= "table" then
        if type(ClearCursor) == "function" then
            ClearCursor()
        end
        self:LogActionError("common.save", updateErr)
        return
    end

    if slotControl ~= nil and type(slotControl.GetHandler) == "function" then
        local onMouseExit = slotControl:GetHandler("OnMouseExit")
        if type(onMouseExit) == "function" then
            onMouseExit()
        end
    end
    self:SelectCard(cardId)
    self.expandedCardId = cardId
    self:RefreshCardSkillEditor()
end

function LTM_UI:HandleCardSkillSlotReceive(cardId, hotbarCategory, slotIndex, slotControl)
    if IsUnitInCombat("player") then
        return false
    end

    if type(GetCursorContentType) ~= "function" or GetCursorContentType() ~= MOUSE_CONTENT_ACTION then
        return false
    end

    local cursorAbilityId = type(GetCursorAbilityId) == "function" and GetCursorAbilityId() or nil
    local progressionData = type(SKILLS_DATA_MANAGER) == "table"
        and type(SKILLS_DATA_MANAGER.GetProgressionDataByAbilityId) == "function"
        and SKILLS_DATA_MANAGER:GetProgressionDataByAbilityId(cursorAbilityId)
        or nil
    if progressionData == nil then
        return false
    end

    if type(progressionData.IsUltimate) == "function" then
        local isUltimate = progressionData:IsUltimate()
        if (isUltimate and slotIndex < 8) or ((not isUltimate) and slotIndex > 7) then
            return false
        end
    end

    local abilityId = ResolveDroppedCardAbilityId(cursorAbilityId, hotbarCategory)
    if type(abilityId) ~= "number" or abilityId <= 0 then
        return false
    end

    local updateResult, updateErr = LTM_UI_DISPATCH:SetCardSkillSlotAbility(cardId, hotbarCategory, slotIndex, abilityId)
    if type(updateResult) ~= "table" then
        self:LogActionError("common.save", updateErr)
        return false
    end

    if type(ClearCursor) == "function" then
        ClearCursor()
    end

    local previousAbilityId = type(updateResult.previousAbilityId) == "number" and updateResult.previousAbilityId or 0
    if previousAbilityId > 0 and previousAbilityId ~= abilityId and type(CallSecureProtected) == "function" then
        local skillType, skillLine, skillIndex = ResolvePickupSkillKeys(previousAbilityId)
        if type(skillType) == "number" and type(skillLine) == "number" and type(skillIndex) == "number" then
            CallSecureProtected("PickupAbilityBySkillLine", skillType, skillLine, skillIndex)
        end
    end

    if slotControl ~= nil and type(slotControl.GetHandler) == "function" then
        local onMouseExit = slotControl:GetHandler("OnMouseExit")
        if type(onMouseExit) == "function" then
            onMouseExit()
        end
    end
    self:SelectCard(cardId)
    self.expandedCardId = cardId
    self:RefreshCardSkillEditor()
    return true
end

function LTM_UI:BindCardSkillSlotHandlers(slotControl, cardId, hotbarCategory, slotIndex)
    if slotControl == nil or type(cardId) ~= "string" or cardId == "" then
        return
    end

    if type(slotControl.SetMouseEnabled) == "function" then
        slotControl:SetMouseEnabled(true)
    end

    slotControl:SetHandler("OnDragStart", function(selfControl)
        LTM_UI:HandleCardSkillSlotDragStart(cardId, hotbarCategory, slotIndex, selfControl)
    end)
    slotControl:SetHandler("OnReceiveDrag", function(selfControl)
        LTM_UI:HandleCardSkillSlotReceive(cardId, hotbarCategory, slotIndex, selfControl)
    end)
    slotControl:SetHandler("OnMouseUp", function(selfControl)
        if MouseIsOver(selfControl, 0, 0, 0, 0)
            and LTM_UI:HandleCardSkillSlotReceive(cardId, hotbarCategory, slotIndex, selfControl) then
            return
        end

        LTM_UI:SelectCard(cardId)
    end)
end

function LTM_UI:BindRightPaneSkillSlotTooltipHandlers(slotControl)
    if slotControl == nil then
        return
    end

    if type(slotControl.SetMouseEnabled) == "function" then
        slotControl:SetMouseEnabled(true)
    end

    slotControl:SetHandler("OnMouseEnter", function(control)
        LTM_UI:ShowRightPaneAbilityTooltip(control, control.ltmAbilityTooltipEntry)
    end)
    slotControl:SetHandler("OnMouseExit", function()
        LTM_UI:ClearRightPaneAbilityTooltip()
    end)
end

local function CreateSkillBarBlock(parent, namePrefix, titleKey, topOffset, options)
    local layout = type(options) == "table" and options or {}
    local showHeader = layout.showHeader ~= false
    local slotSize = layout.slotSize or UI_SLOT_SIZE
    local slotGap = layout.slotGap or UI_SLOT_GAP
    local sideInset = layout.sideInset or UI_PANEL_INSET
    local rowGap = layout.rowGap
    if rowGap == nil then
        rowGap = showHeader and UI_SKILL_BAR_ROW_GAP or 0
    end

    local container = WINDOW_MANAGER:CreateControl(namePrefix .. "Container", parent, CT_CONTROL)
    container:ClearAnchors()
    container:SetAnchor(TOPLEFT, parent, TOPLEFT, 0, topOffset)
    container:SetAnchor(TOPRIGHT, parent, TOPRIGHT, 0, topOffset)
    container:SetHeight((showHeader and (UI_SKILL_BAR_HEADER_HEIGHT + rowGap) or 0) + slotSize)

    local header = nil
    local label = nil
    local hint = nil

    if showHeader then
        header = WINDOW_MANAGER:CreateControl(namePrefix .. "Header", container, CT_CONTROL)
        header:ClearAnchors()
        header:SetAnchor(TOPLEFT, container, TOPLEFT, 0, 0)
        header:SetAnchor(TOPRIGHT, container, TOPRIGHT, 0, 0)
        header:SetHeight(UI_SKILL_BAR_HEADER_HEIGHT)

        label = CreateHeaderLabel(header, namePrefix .. "Label", GetText(titleKey), "ZoFontGame")
        label:ClearAnchors()
        label:SetAnchor(TOPLEFT, header, TOPLEFT, sideInset, 0)
        label:SetColor(0.72, 0.76, 0.82, 1.0)

        hint = WINDOW_MANAGER:CreateControl(namePrefix .. "Hint", header, CT_LABEL)
        hint:ClearAnchors()
        hint:SetAnchor(TOPRIGHT, header, TOPRIGHT, -sideInset, 0)
        hint:SetFont("ZoFontGameSmall")
        hint:SetColor(0.74, 0.78, 0.84, 1.0)
    end

    local slotContainer = WINDOW_MANAGER:CreateControl(namePrefix .. "SlotContainer", container, CT_CONTROL)
    slotContainer:ClearAnchors()
    if showHeader then
        slotContainer:SetAnchor(TOPLEFT, header, BOTTOMLEFT, sideInset, rowGap)
    else
        slotContainer:SetAnchor(TOPLEFT, container, TOPLEFT, sideInset, 0)
    end
    slotContainer:SetWidth((slotSize * 6) + (slotGap * 5))
    slotContainer:SetHeight(slotSize)

    local slots = CreateSlotGrid(slotContainer, namePrefix, slotSize, slotGap)

    return {
        header = header,
        label = label,
        hint = hint,
        container = container,
        slotContainer = slotContainer,
        slots = slots,
    }
end

function LTM_UI:CreateCurrentDetailBox(parent, namePrefix, titleKey, options)
    local layout = type(options) == "table" and options or {}
    local reserveExtraTitle = layout.reserveExtraTitle == true
    local box = CreateBackdrop(parent, namePrefix .. "Box", 0.09, 0.10, 0.12, 0.98, 0.28, 0.30, 0.34, 1.0)

    local title = CreateHeaderLabel(box, namePrefix .. "Title", GetText(titleKey), "ZoFontGame")
    title:ClearAnchors()
    title:SetAnchor(TOPLEFT, box, TOPLEFT, UI_PANEL_INSET, UI_CURRENT_BOTTOM_TITLE_TOP)
    title:SetColor(0.72, 0.76, 0.82, 1.0)

    local extraTitle = nil
    if reserveExtraTitle then
        extraTitle = WINDOW_MANAGER:CreateControl(namePrefix .. "ExtraTitle", box, CT_LABEL)
        extraTitle:ClearAnchors()
        extraTitle:SetAnchor(TOPRIGHT, box, TOPRIGHT, -UI_PANEL_INSET, UI_CURRENT_BOTTOM_TITLE_TOP)
        extraTitle:SetWidth(180)
        extraTitle:SetHeight(20)
        extraTitle:SetFont("ZoFontGameSmall")
        extraTitle:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
        extraTitle:SetColor(0.82, 0.84, 0.88, 1.0)
        extraTitle:SetText("")
        extraTitle:SetMaxLineCount(1)
        extraTitle:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
        SetTextTooltip(extraTitle, "")

        title:SetAnchor(RIGHT, extraTitle, LEFT, -8, 0)
    else
        title:SetAnchor(TOPRIGHT, box, TOPRIGHT, -UI_PANEL_INSET, UI_CURRENT_BOTTOM_TITLE_TOP)
    end
    title:SetHeight(UI_CURRENT_DETAIL_TITLE_HEIGHT)
    if type(title.SetVerticalAlignment) == "function" then
        title:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    end
    if type(title.SetMaxLineCount) == "function" then
        title:SetMaxLineCount(1)
    end
    if type(title.SetWrapMode) == "function" and TEXT_WRAP_MODE_ELLIPSIS then
        title:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    end
    SetTextTooltip(title, GetText(titleKey))

    local body = WINDOW_MANAGER:CreateControl(namePrefix .. "Body", box, CT_CONTROL)
    body:ClearAnchors()
    body:SetAnchor(TOPLEFT, title, BOTTOMLEFT, 0, UI_CURRENT_BOTTOM_BODY_TOP_GAP)
    body:SetAnchor(BOTTOMRIGHT, box, BOTTOMRIGHT, -UI_CURRENT_BOTTOM_BODY_SIDE_INSET, -UI_CURRENT_BOTTOM_BODY_BOTTOM_INSET)

    return {
        box = box,
        title = title,
        extraTitle = extraTitle,
        body = body,
    }
end

function LTM_UI:CreateCurrentDynamicContent(parent, namePrefix)
    local content = WINDOW_MANAGER:CreateControl(namePrefix .. "Content", parent, CT_CONTROL)
    content:ClearAnchors()
    content:SetAnchorFill(parent)
    return content
end

function LTM_UI:CreateAttributeRows(parent, rowPrefix, options)
    local layout = type(options) == "table" and options or {}
    local rows = {}
    local rowHeight = layout.rowHeight or UI_CURRENT_ATTRIBUTE_ROW_HEIGHT
    local rowGap = layout.rowGap or UI_CURRENT_ATTRIBUTE_ROW_GAP
    local nameWidth = layout.nameWidth or 24
    local showNameLabel = layout.showNameLabel ~= false
    local valueFont = layout.valueFont or "ZoFontWinT2"
    local valueAlign = layout.valueAlign or TEXT_ALIGN_RIGHT
    local valueLeftOffset = layout.valueLeftOffset or 8

    for index, attributeLayout in ipairs(CURRENT_ATTRIBUTE_LAYOUTS) do
        local row = WINDOW_MANAGER:CreateControl(rowPrefix .. "Row" .. tostring(index), parent, CT_CONTROL)
        row:ClearAnchors()
        if index == 1 then
            row:SetAnchor(TOPLEFT, parent, TOPLEFT, 0, 0)
            row:SetAnchor(TOPRIGHT, parent, TOPRIGHT, 0, 0)
        else
            row:SetAnchor(TOPLEFT, rows[index - 1], BOTTOMLEFT, 0, rowGap)
            row:SetAnchor(TOPRIGHT, rows[index - 1], BOTTOMRIGHT, 0, rowGap)
        end
        row:SetHeight(rowHeight)

        local dotTexture = WINDOW_MANAGER:CreateControl("$(parent)Dot", row, CT_TEXTURE)
        dotTexture:ClearAnchors()
        dotTexture:SetAnchor(LEFT, row, LEFT, 1, 0)
        dotTexture:SetDimensions(9, 9)
        dotTexture:SetTexture("/esoui/art/antiquities/bullet_active.dds")
        dotTexture:SetDrawLayer(DL_CONTROLS)

        local nameLabel = WINDOW_MANAGER:CreateControl("$(parent)Name", row, CT_LABEL)
        nameLabel:ClearAnchors()
        nameLabel:SetAnchor(LEFT, dotTexture, RIGHT, 5, 0)
        nameLabel:SetWidth(nameWidth)
        nameLabel:SetFont("ZoFontGameSmall")
        nameLabel:SetText(GetText(attributeLayout.shortLabelKey))
        nameLabel:SetHidden(not showNameLabel)

        local valueLabel = WINDOW_MANAGER:CreateControl("$(parent)Value", row, CT_LABEL)
        valueLabel:ClearAnchors()
        if showNameLabel then
            valueLabel:SetAnchor(LEFT, nameLabel, RIGHT, valueLeftOffset, 0)
        else
            valueLabel:SetAnchor(LEFT, dotTexture, RIGHT, 6, 0)
        end
        valueLabel:SetAnchor(RIGHT, row, RIGHT, 0, 0)
        valueLabel:SetFont(valueFont)
        valueLabel:SetColor(0.96, 0.97, 0.99, 1.0)
        valueLabel:SetHorizontalAlignment(valueAlign)
        valueLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)

        row.dotTexture = dotTexture
        row.nameLabel = nameLabel
        row.valueLabel = valueLabel
        rows[index] = row
    end

    return rows
end

function LTM_UI:CreateCardControl(index, cardId)
    local controlNameSuffix = BuildControlNameFragment(cardId)
    self.cardControlInstanceId = (tonumber(self.cardControlInstanceId) or 0) + 1
    local controlInstanceSuffix = controlNameSuffix .. "_" .. BuildControlNameShortId(tostring(self.cardControlInstanceId))
    local card = CreateBackdrop(self.cardListContainer, "LTM_UI_Card_" .. controlInstanceSuffix, 0.08, 0.08, 0.10, 0.94, 0.30, 0.32, 0.36, 1.0)
    card:SetMouseEnabled(true)
    card:SetDrawTier(DT_HIGH)
    card:SetDrawLayer(DL_CONTROLS)

    local header = WINDOW_MANAGER:CreateControl("$(parent)CardHeader", card, CT_CONTROL)
    header:ClearAnchors()
    header:SetAnchor(TOPLEFT, card, TOPLEFT, 0, 0)
    header:SetAnchor(TOPRIGHT, card, TOPRIGHT, 0, 0)
    header:SetHeight(UI_CARD_HEADER_HEIGHT)
    card.cardHeader = header

    local headerButton = WINDOW_MANAGER:CreateControl("$(parent)SelectButton", header, CT_BUTTON)
    headerButton:ClearAnchors()
    headerButton:SetAnchorFill(header)
    headerButton:SetHandler("OnClicked", function()
        LTM_UI:SelectCard(cardId)
    end)

    local ordinalLabel = CreateHeaderLabel(header, "$(parent)Ordinal", "", "ZoFontWinH4")
    ordinalLabel:ClearAnchors()
    ordinalLabel:SetAnchor(TOPLEFT, header, TOPLEFT, UI_CARD_TITLE_LEFT, 12)
    ordinalLabel:SetDimensions(UI_CARD_ORDINAL_WIDTH, 20)
    ordinalLabel:SetColor(0.72, 0.80, 0.88, 1.0)
    ordinalLabel:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    card.ordinalLabel = ordinalLabel

    local roleIcon = WINDOW_MANAGER:CreateControl("$(parent)RoleIcon", header, CT_TEXTURE)
    roleIcon:SetColor(1.0, 1.0, 1.0, 1.0)
    roleIcon:SetAlpha(1.0)
    SetControlDrawOrder(roleIcon, DT_HIGH, DL_OVERLAY, 4)
    roleIcon:SetHidden(true)
    card.roleIcon = roleIcon

    card.transformIcons = {}
    for transformIndex, kind in ipairs({ "werewolf", "vampire" }) do
        local transformIcon = WINDOW_MANAGER:CreateControl(
            "$(parent)Transform" .. tostring(transformIndex),
            header,
            CT_TEXTURE
        )
        transformIcon:ClearAnchors()
        transformIcon:SetAnchor(TOPRIGHT, header, TOPRIGHT, -86 - ((transformIndex - 1) * 22), 11)
        transformIcon:SetDimensions(20, 20)
        transformIcon:SetMouseEnabled(true)
        SetTextTooltip(transformIcon, GetText("transform.settings.tooltip"))
        transformIcon.ltmTransformKind = kind
        transformIcon:SetHandler("OnMouseUp", function(control, mouseButton, upInside)
            if upInside == true and mouseButton == MOUSE_BUTTON_INDEX_LEFT then
                LTM_UI:ShowTransformSkillsPopup(control.ltmTransformKind, cardId)
            end
        end)
        SetControlDrawOrder(transformIcon, DT_HIGH, DL_OVERLAY, 6)
        transformIcon:SetHidden(true)
        card.transformIcons[#card.transformIcons + 1] = transformIcon
    end

    local outfitIcon = WINDOW_MANAGER:CreateControl("$(parent)OutfitIcon", header, CT_TEXTURE)
    outfitIcon:SetAnchor(TOPRIGHT, header, TOPRIGHT, -64, 11)
    outfitIcon:SetDimensions(20, 20)
    outfitIcon:SetTexture("EsoUI/Art/Collections/collections_tabIcon_outfitStyles_up.dds")
    outfitIcon:SetMouseEnabled(true)
    SetTextTooltip(outfitIcon, "")
    outfitIcon:SetHandler("OnMouseUp", function(control, mouseButton, upInside)
        if upInside == true and mouseButton == MOUSE_BUTTON_INDEX_LEFT then
            LTM_UI:ShowCardOutfitMenu(cardId, control)
        end
    end)
    SetControlDrawOrder(outfitIcon, DT_HIGH, DL_OVERLAY, 6)
    card.outfitIcon = outfitIcon

    local titleLabel = CreateHeaderLabel(header, "$(parent)Title", "", "ZoFontWinH4")
    titleLabel:SetMaxLineCount(1)
    titleLabel:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    titleLabel:SetColor(1.0, 1.0, 1.0, 1.0)
    card.titleLabel = titleLabel
    self:ApplyBuildCardHeaderLayout(card, false)

    local toggleButton = CreateIconButton(
        header,
        "$(parent)ToggleButton",
        16,
        TOPRIGHT,
        header,
        TOPRIGHT,
        -44,
        13,
        "/esoui/art/buttons/scrollbox_downarrow",
        GetText("card.expand")
    )
    toggleButton:SetHandler("OnClicked", function()
        LTM_UI:ToggleCardExpanded(cardId)
    end)
    card.toggleButton = toggleButton

    local actionButton = CreateIconButton(
        header,
        "$(parent)ActionButton",
        24,
        TOPRIGHT,
        header,
        TOPRIGHT,
        -12,
        9,
        "/esoui/art/buttons/edit",
        GetText("card.action.menu")
    )
    actionButton:SetHandler("OnClicked", function()
        if LTM_UI.selectedBuildId ~= cardId then
            LTM_UI:SelectCard(cardId)
        end
        LTM_UI:ToggleActionMenu(cardId)
    end)
    card.actionButton = actionButton

    local body = WINDOW_MANAGER:CreateControl("$(parent)CardBody", card, CT_CONTROL)
    body:ClearAnchors()
    body:SetAnchor(TOPLEFT, header, BOTTOMLEFT, 0, 0)
    body:SetAnchor(TOPRIGHT, header, BOTTOMRIGHT, 0, 0)
    body:SetHeight(UI_CARD_EXPANDED_HEIGHT)
    body:SetHidden(true)
    card.cardBody = body
    BindCardSelectionMouseUp(body, cardId)

    local summarySection = CreateBackdrop(body, "$(parent)SummarySection", 0.09, 0.10, 0.12, 0.98, 0.28, 0.30, 0.34, 1.0)
    summarySection:ClearAnchors()
    summarySection:SetAnchor(TOPLEFT, body, TOPLEFT, 0, 0)
    summarySection:SetAnchor(TOPRIGHT, body, TOPRIGHT, 0, 0)
    summarySection:SetHeight(UI_CARD_SUMMARY_HEIGHT)
    card.summarySection = summarySection
    BindCardSelectionMouseUp(summarySection, cardId)

    local subclassRow = CreateSummaryBlock(summarySection, "$(parent)Subclass", "card.section.subclass", UI_CARD_SUMMARY_TOP_PADDING, UI_CARD_SUMMARY_BLOCK_HEIGHT)
    card.subclassValue = subclassRow.value
    SetSummaryBlockFont(card.subclassValue, UI_CARD_SUBCLASS_SUMMARY_FONT)
    if type(card.subclassValue.SetMaxLineCount) == "function" then
        card.subclassValue:SetMaxLineCount(1)
    end
    if type(card.subclassValue.SetWrapMode) == "function" and TEXT_WRAP_MODE_TRUNCATE then
        card.subclassValue:SetWrapMode(TEXT_WRAP_MODE_TRUNCATE)
    end
    SetTextTooltip(card.subclassValue, "")
    BindCardSelectionMouseUp(subclassRow.block, cardId)
    BindCardSelectionMouseUp(subclassRow.valueRow, cardId)
    BindCardSelectionMouseUp(card.subclassValue, cardId)

    local skillSnapshotLabel = WINDOW_MANAGER:CreateControl("$(parent)SkillSnapshotLabel", summarySection, CT_LABEL)
    skillSnapshotLabel:ClearAnchors()
    skillSnapshotLabel:SetAnchor(TOPLEFT, summarySection, TOPLEFT, UI_PANEL_INSET, UI_CARD_STATUS_TOP)
    skillSnapshotLabel:SetAnchor(TOPRIGHT, summarySection, TOPRIGHT, -UI_PANEL_INSET, UI_CARD_STATUS_TOP)
    skillSnapshotLabel:SetHeight(UI_CARD_SUMMARY_BLOCK_HEIGHT)
    skillSnapshotLabel:SetFont("ZoFontGameSmall")
    skillSnapshotLabel:SetColor(0.72, 0.76, 0.82, 1.0)
    skillSnapshotLabel:SetText(GetText("card.skill_settings.snapshots", {
        active = GetText("card.skill_settings.snapshot.active"),
        passive = GetText("card.skill_settings.snapshot.passive"),
    }))
    if type(skillSnapshotLabel.SetMaxLineCount) == "function" then
        skillSnapshotLabel:SetMaxLineCount(1)
    end
    if type(skillSnapshotLabel.SetWrapMode) == "function" and TEXT_WRAP_MODE_ELLIPSIS then
        skillSnapshotLabel:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    end
    SetTextTooltip(skillSnapshotLabel, GetText("card.skill_settings.snapshots.tooltip"))
    card.skillSnapshotLabel = skillSnapshotLabel
    BindCardSelectionMouseUp(skillSnapshotLabel, cardId)

    local skillSettingsRow = WINDOW_MANAGER:CreateControl("$(parent)SkillSettingsRow", summarySection, CT_CONTROL)
    skillSettingsRow:ClearAnchors()
    skillSettingsRow:SetAnchor(
        TOPLEFT,
        summarySection,
        TOPLEFT,
        UI_PANEL_INSET,
        UI_CARD_SUMMARY_CHECKBOX_TOP
    )
    skillSettingsRow:SetDimensions(UI_CARD_SKILL_SETTINGS_WIDTH, UI_CARD_LINK_ROW_HEIGHT)
    skillSettingsRow:SetMouseEnabled(true)

    local skillSettingsLabel = WINDOW_MANAGER:CreateControl("$(parent)Label", skillSettingsRow, CT_LABEL)
    skillSettingsLabel:ClearAnchors()
    skillSettingsLabel:SetAnchor(TOPLEFT, skillSettingsRow, TOPLEFT, 0, 0)
    skillSettingsLabel:SetAnchor(BOTTOMRIGHT, skillSettingsRow, BOTTOMRIGHT, -30, 0)
    skillSettingsLabel:SetFont("ZoFontGame")
    skillSettingsLabel:SetColor(0.88, 0.90, 0.94, 1.0)
    skillSettingsLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    skillSettingsLabel:SetText(GetText("card.skill_settings.title"))
    if type(skillSettingsLabel.SetMaxLineCount) == "function" then
        skillSettingsLabel:SetMaxLineCount(1)
    end
    if type(skillSettingsLabel.SetWrapMode) == "function" and TEXT_WRAP_MODE_ELLIPSIS then
        skillSettingsLabel:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    end
    local skillSettingsTooltip = GetText("card.skill_settings.tooltip")
    SetTextTooltip(skillSettingsLabel, skillSettingsTooltip)
    skillSettingsLabel:SetMouseEnabled(true)

    local skillSettingsButton = CreateIconButton(
        skillSettingsRow,
        "$(parent)Button",
        24,
        RIGHT,
        skillSettingsRow,
        RIGHT,
        0,
        0,
        "/esoui/art/buttons/edit",
        skillSettingsTooltip
    )
    local function OpenSkillSettings()
        if LTM_UI.selectedBuildId ~= cardId then
            LTM_UI:SelectCard(cardId)
        end
        LTM_UI_SKILL_SETTINGS:Open(cardId)
    end
    skillSettingsRow:SetHandler("OnMouseUp", function(_, mouseButton, upInside)
        if upInside == true and mouseButton == MOUSE_BUTTON_INDEX_LEFT then
            OpenSkillSettings()
        end
    end)
    skillSettingsLabel:SetHandler("OnMouseUp", function(_, mouseButton, upInside)
        if upInside == true and mouseButton == MOUSE_BUTTON_INDEX_LEFT then
            OpenSkillSettings()
        end
    end)
    skillSettingsButton:SetHandler("OnClicked", OpenSkillSettings)
    card.skillSettingsRow = skillSettingsRow
    card.skillSettingsLabel = skillSettingsLabel
    card.skillSettingsButton = skillSettingsButton

    local quickSlotLinkDropdown = CreateCardLinkComboBox(
        summarySection,
        "$(parent)QuickSlotLinkDropdown",
        UI_PANEL_INSET + UI_CARD_LINK_QS_DROPDOWN_X,
        GetText("card.link.quickslot"),
        GetText("card.link.quickslot.tooltip")
    )
    local foodLinkDropdown = CreateCardLinkComboBox(
        summarySection,
        "$(parent)FoodLinkDropdown",
        UI_PANEL_INSET + UI_CARD_LINK_FOOD_DROPDOWN_X,
        GetText("card.link.food"),
        GetText("card.link.food.tooltip")
    )
    card.quickSlotLinkDropdown = quickSlotLinkDropdown
    card.quickSlotLinkComboBox = quickSlotLinkDropdown.comboBox
    card.foodLinkDropdown = foodLinkDropdown
    card.foodLinkComboBox = foodLinkDropdown.comboBox

    local skillSection = CreateBackdrop(body, "$(parent)SkillSection", 0.09, 0.10, 0.12, 0.98, 0.28, 0.30, 0.34, 1.0)
    skillSection:ClearAnchors()
    skillSection:SetAnchor(TOPLEFT, summarySection, BOTTOMLEFT, 0, UI_CARD_SKILL_SECTION_OFFSET_Y)
    skillSection:SetAnchor(TOPRIGHT, summarySection, BOTTOMRIGHT, 0, UI_CARD_SKILL_SECTION_OFFSET_Y)
    skillSection:SetHeight(UI_CARD_SKILL_HEIGHT)
    card.skillSection = skillSection
    BindCardSelectionMouseUp(skillSection, cardId)

    local cardAttributeColumn = WINDOW_MANAGER:CreateControl("$(parent)AttributeColumn", skillSection, CT_CONTROL)
    cardAttributeColumn:ClearAnchors()
    cardAttributeColumn:SetAnchor(TOPRIGHT, skillSection, TOPRIGHT, -UI_PANEL_INSET, 10)
    cardAttributeColumn:SetWidth(UI_CARD_ATTRIBUTE_WIDTH)
    cardAttributeColumn:SetHeight((UI_CARD_ATTRIBUTE_ROW_HEIGHT * 3) + (UI_CARD_ATTRIBUTE_ROW_GAP * 2))
    card.attributeColumn = cardAttributeColumn
    BindCardSelectionMouseUp(cardAttributeColumn, cardId)

    card.attributeRows = self:CreateAttributeRows(cardAttributeColumn, "$(parent)Attribute", {
        rowHeight = UI_CARD_ATTRIBUTE_ROW_HEIGHT,
        rowGap = UI_CARD_ATTRIBUTE_ROW_GAP,
        showNameLabel = true,
        nameWidth = 24,
        valueFont = "ZoFontWinT2",
        valueAlign = TEXT_ALIGN_LEFT,
        valueLeftOffset = 8,
    })

    local cardSkillBarsColumn = WINDOW_MANAGER:CreateControl("$(parent)SkillBarsColumn", skillSection, CT_CONTROL)
    cardSkillBarsColumn:ClearAnchors()
    cardSkillBarsColumn:SetAnchor(TOPLEFT, skillSection, TOPLEFT, 0, 0)
    cardSkillBarsColumn:SetAnchor(BOTTOMRIGHT, cardAttributeColumn, BOTTOMLEFT, -UI_SECTION_GAP, 0)
    card.skillBarsColumn = cardSkillBarsColumn
    BindCardSelectionMouseUp(cardSkillBarsColumn, cardId)

    local cardSkillBarOptions = {
        showHeader = false,
        slotSize = UI_SLOT_SIZE,
        slotGap = UI_SLOT_GAP,
        sideInset = UI_PANEL_INSET,
    }
    local frontBar = CreateSkillBarBlock(cardSkillBarsColumn, "$(parent)FrontBar", nil, 10, cardSkillBarOptions)
    local backBar = CreateSkillBarBlock(cardSkillBarsColumn, "$(parent)BackBar", nil, 46, cardSkillBarOptions)
    card.frontBarSlots = frontBar.slots
    card.backBarSlots = backBar.slots
    for index, slotControl in ipairs(card.frontBarSlots or {}) do
        self:BindCardSkillSlotHandlers(slotControl, cardId, 0, index + 2)
    end
    for index, slotControl in ipairs(card.backBarSlots or {}) do
        self:BindCardSkillSlotHandlers(slotControl, cardId, 1, index + 2)
    end
    BindCardSelectionMouseUp(frontBar.container, cardId)
    BindCardSelectionMouseUp(frontBar.slotContainer, cardId)
    BindCardSelectionMouseUp(backBar.container, cardId)
    BindCardSelectionMouseUp(backBar.slotContainer, cardId)

    local actionMenuParent = self.frontOverlayRoot or self.layoutRoot or card
    local actionMenu = CreateBackdrop(actionMenuParent, "LTM_UI_ActionMenu_" .. controlInstanceSuffix, 0.10, 0.10, 0.12, 0.98, 0.48, 0.52, 0.58, 1.0)
    actionMenu:SetDimensions(UI_ACTION_MENU_WIDTH + (UI_ACTION_MENU_PADDING_X * 2), (6 * UI_ACTION_MENU_ROW_HEIGHT) + (5 * UI_ACTION_MENU_ROW_GAP) + (UI_ACTION_MENU_PADDING_Y * 2))
    actionMenu:ClearAnchors()
    actionMenu:SetAnchor(TOPRIGHT, actionButton, BOTTOMRIGHT, 0, 4)
    actionMenu:SetHidden(true)
    SetControlDrawOrder(actionMenu, DT_HIGH, DL_OVERLAY, 2)
    card.actionMenu = actionMenu

    local copyButton = CreateActionMenuButton(actionMenu, "Copy", nil, "card.action.copy", function()
        local result, err = LTM_UI_DISPATCH:DuplicateCard(cardId)
        LTM_UI.openActionMenuCardId = nil
        if type(result) ~= "table" then
            LTM_UI:LogActionError("card.action.copy", err)
            return
        end

        LTM_UI.selectedCardId = result.copiedBuildId
        LTM_UI.selectedBuildId = result.copiedBuildId
        LTM_UI.expandedCardId = result.copiedBuildId
        LTM_UI:QueueCardListScroll(result.copiedBuildId, "center")
        LTM_UI:RefreshCardList()
        Log.WriteChat(GetText("status.copied", {
            cardName = result.copiedBuildName or result.copiedBuildId,
        }))
    end)
    local movePageButton = CreateActionMenuButton(actionMenu, "MovePage", copyButton, "card.action.move_page", function()
        LTM_UI.openActionMenuCardId = nil
        LTM_UI:HandleMoveBuildToPage(cardId)
    end)
    local overwriteButton = CreateActionMenuButton(actionMenu, "Overwrite", movePageButton, "card.action.overwrite", function()
        local build = LTM_UI_DISPATCH:GetBuildById(cardId)
        LTM_UI.openActionMenuCardId = nil
        LTM_UI:ShowDialog("OVERWRITE_CARD_PICKER", {
            cardId = cardId,
            cardName = LTM_UI:GetBuildDisplayName(cardId, build),
        })
    end)
    local renameButton = CreateActionMenuButton(actionMenu, "Rename", overwriteButton, "card.action.rename", function()
        local build = LTM_UI_DISPATCH:GetBuildById(cardId)
        LTM_UI.openActionMenuCardId = nil
        LTM_UI:ShowDialog("RENAME_CARD_INPUT", {
            cardId = cardId,
            cardName = LTM_UI:GetBuildDisplayName(cardId, build),
            initialValue = LTM_UI:GetBuildDisplayName(cardId, build),
        })
    end)
    local deleteButton = CreateActionMenuButton(actionMenu, "Delete", renameButton, "card.action.delete", function()
        local build = LTM_UI_DISPATCH:GetBuildById(cardId)
        LTM_UI.openActionMenuCardId = nil
        LTM_UI:ShowDialog("DELETE_CARD_CONFIRM", {
            cardId = cardId,
            cardName = LTM_UI:GetBuildDisplayName(cardId, build),
        })
    end)
    CreateActionMenuButton(actionMenu, "LinkGearToChat", deleteButton, "card.action.link_gear_to_chat", function()
        LTM_UI:CloseActionMenus()
        local ok, err = LTM_UI_DISPATCH:LinkGearToChat(cardId)
        if ok ~= true and err ~= "gamepad_unavailable" and err ~= "target_equipment_missing" and err ~= "gear_link_empty" then
            LTM_UI:LogActionError("card.action.link_gear_to_chat", err)
        end
    end)

    return card
end

local function CreateMainWindow(self)
    if self.window then
        return
    end

    self.rightPaneMode = "target"
    self.activeMainTab = "armory_station"

    local window = WINDOW_MANAGER:CreateTopLevelWindow("LTM_MainWindow")
    window:SetDimensions(UI_WINDOW_WIDTH, UI_WINDOW_HEIGHT)
    window:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
    window:SetClampedToScreen(true)
    window:SetMovable(true)
    window:SetMouseEnabled(true)
    window:SetDrawTier(DT_HIGH)
    window:SetHidden(true)
    self.window = window

    if type(SCENE_MANAGER.RegisterTopLevel) == "function" then
        SCENE_MANAGER:RegisterTopLevel(window, false)
    end

    local layoutRoot = WINDOW_MANAGER:CreateControl("$(parent)LayoutRoot", window, CT_CONTROL)
    layoutRoot:ClearAnchors()
    layoutRoot:SetAnchorFill(window)
    self.layoutRoot = layoutRoot

    local backdrop = CreateBackdrop(layoutRoot, "$(parent)Backdrop", 0.04, 0.05, 0.06, 0.97, 0.72, 0.76, 0.80, 1.0)
    backdrop:ClearAnchors()
    backdrop:SetAnchorFill(layoutRoot)
    self.backdrop = backdrop

    local frontOverlayRoot = WINDOW_MANAGER:CreateControl("$(parent)FrontOverlay", layoutRoot, CT_CONTROL)
    frontOverlayRoot:ClearAnchors()
    frontOverlayRoot:SetAnchorFill(layoutRoot)
    frontOverlayRoot:SetMouseEnabled(false)
    SetControlDrawOrder(frontOverlayRoot, DT_HIGH, DL_OVERLAY, 0)
    self.frontOverlayRoot = frontOverlayRoot

    local actionMenuDismissLayer = WINDOW_MANAGER:CreateControl("$(parent)ActionMenuDismissLayer", frontOverlayRoot, CT_CONTROL)
    actionMenuDismissLayer:ClearAnchors()
    actionMenuDismissLayer:SetAnchorFill(frontOverlayRoot)
    actionMenuDismissLayer:SetMouseEnabled(true)
    actionMenuDismissLayer:SetHidden(true)
    SetControlDrawOrder(actionMenuDismissLayer, DT_HIGH, DL_OVERLAY, 1)
    actionMenuDismissLayer:SetHandler("OnMouseUp", function(_, mouseButton, upInside)
        if upInside == false then
            return
        end

        if mouseButton ~= nil and mouseButton ~= MOUSE_BUTTON_INDEX_LEFT then
            return
        end

        LTM_UI:CloseActionMenus()
    end)
    self.actionMenuDismissLayer = actionMenuDismissLayer

    local titleBar = WINDOW_MANAGER:CreateControl("$(parent)TitleBar", layoutRoot, CT_CONTROL)
    titleBar:ClearAnchors()
    titleBar:SetAnchor(TOPLEFT, layoutRoot, TOPLEFT, 0, 0)
    titleBar:SetAnchor(TOPRIGHT, layoutRoot, TOPRIGHT, 0, 0)
    titleBar:SetHeight(UI_TITLEBAR_HEIGHT)
    self.titleBar = titleBar

    local title = CreateHeaderLabel(titleBar, "$(parent)Title", GetText("window.title"), "ZoFontWinH1")
    title:ClearAnchors()
    title:SetAnchor(TOPLEFT, titleBar, TOPLEFT, UI_WINDOW_PADDING, UI_WINDOW_PADDING)
    title:SetColor(1.0, 1.0, 1.0, 1.0)
    self.titleLabel = title

    local closeButton = CreateIconButton(
        titleBar,
        "$(parent)CloseButton",
        24,
        TOPRIGHT,
        titleBar,
        TOPRIGHT,
        -UI_WINDOW_PADDING,
        UI_WINDOW_PADDING - 2,
        "/esoui/art/buttons/decline",
        GetText("common.close")
    )
    closeButton:SetHandler("OnClicked", function()
        LTM_UI:HideMainWindow()
    end)
    self.closeButton = closeButton

    local currentSkillSnapshotButton = CreateIconButton(
        titleBar,
        "$(parent)CurrentSkillSnapshotButton",
        24,
        TOPRIGHT,
        closeButton,
        TOPLEFT,
        -30,
        0,
        "/esoui/art/buttons/edit",
        GetText("current.snapshot.button")
    )
    currentSkillSnapshotButton:SetHandler("OnClicked", function()
        local report = LTM_UI_DISPATCH:GetCurrentSkillSnapshotReport()
        local snapshotText = type(report) == "table" and report.text or "snapshot unavailable"
        LTM_UI:ShowDialog("CURRENT_SKILL_SNAPSHOT", {
            snapshotText = snapshotText,
        })
    end)
    currentSkillSnapshotButton:SetHidden(true)
    self.currentSkillSnapshotButton = currentSkillSnapshotButton

    local quickSettingsTabButton = WINDOW_MANAGER:CreateControlFromVirtual("$(parent)QuickSettingsTab", titleBar, "ZO_DefaultButton")
    quickSettingsTabButton:ClearAnchors()
    quickSettingsTabButton:SetAnchor(RIGHT, currentSkillSnapshotButton, LEFT, -UI_MAIN_TAB_BUTTON_GAP, 0)
    quickSettingsTabButton:SetDimensions(UI_MAIN_TAB_BUTTON_WIDTH, UI_MAIN_TAB_BUTTON_HEIGHT)
    quickSettingsTabButton:SetFont("ZoFontGameSmall")
    quickSettingsTabButton:SetText(GetText("tab.quick_settings"))
    quickSettingsTabButton:SetHandler("OnClicked", function()
        LTM_UI:SetMainTab("quick_settings")
    end)
    self.quickSettingsTabButton = quickSettingsTabButton

    local armoryStationTabButton = WINDOW_MANAGER:CreateControlFromVirtual("$(parent)ArmoryStationTab", titleBar, "ZO_DefaultButton")
    armoryStationTabButton:ClearAnchors()
    armoryStationTabButton:SetAnchor(RIGHT, quickSettingsTabButton, LEFT, -UI_MAIN_TAB_BUTTON_GAP, 0)
    armoryStationTabButton:SetDimensions(UI_MAIN_TAB_BUTTON_WIDTH, UI_MAIN_TAB_BUTTON_HEIGHT)
    armoryStationTabButton:SetFont("ZoFontGameSmall")
    armoryStationTabButton:SetText(GetText("tab.armory_station"))
    armoryStationTabButton:SetHandler("OnClicked", function()
        LTM_UI:SetMainTab("armory_station")
    end)
    self.armoryStationTabButton = armoryStationTabButton

    local contentRoot = WINDOW_MANAGER:CreateControl("$(parent)ContentRoot", layoutRoot, CT_CONTROL)
    contentRoot:ClearAnchors()
    contentRoot:SetAnchor(TOPLEFT, titleBar, BOTTOMLEFT, UI_WINDOW_PADDING, UI_CONTENT_GAP)
    contentRoot:SetAnchor(BOTTOMRIGHT, layoutRoot, BOTTOMRIGHT, -UI_WINDOW_PADDING, -UI_WINDOW_PADDING)
    self.contentRoot = contentRoot

    local armoryStationContent = WINDOW_MANAGER:CreateControl("$(parent)ArmoryStationContent", contentRoot, CT_CONTROL)
    armoryStationContent:ClearAnchors()
    armoryStationContent:SetAnchorFill(contentRoot)
    self.armoryStationContent = armoryStationContent

    local quickSettingsContent = WINDOW_MANAGER:CreateControl("$(parent)QuickSettingsContent", contentRoot, CT_CONTROL)
    quickSettingsContent:ClearAnchors()
    quickSettingsContent:SetAnchorFill(contentRoot)
    quickSettingsContent:SetHidden(true)
    self.quickSettingsContent = quickSettingsContent
    LTM_UI_QUICK_SETTINGS:CreateContent(quickSettingsContent)

    local leftPane = CreateBackdrop(armoryStationContent, "$(parent)LeftPane", 0.07, 0.08, 0.09, 0.94, 0.28, 0.30, 0.34, 1.0)
    leftPane:ClearAnchors()
    leftPane:SetAnchor(TOPLEFT, armoryStationContent, TOPLEFT, 0, 0)
    leftPane:SetAnchor(BOTTOMLEFT, armoryStationContent, BOTTOMLEFT, 0, 0)
    leftPane:SetWidth(UI_LEFT_PANE_WIDTH)
    self.leftPane = leftPane

    local pageHeaderSection = CreateBackdrop(leftPane, "$(parent)PageHeaderSection", 0.11, 0.12, 0.14, 0.96, 0.36, 0.38, 0.42, 1.0)
    pageHeaderSection:ClearAnchors()
    pageHeaderSection:SetAnchor(TOPLEFT, leftPane, TOPLEFT, UI_CONTENT_GAP, UI_CONTENT_GAP)
    pageHeaderSection:SetAnchor(TOPRIGHT, leftPane, TOPRIGHT, -(UI_CONTENT_GAP + UI_LEFT_PANE_RIGHT_INSET), UI_CONTENT_GAP)
    pageHeaderSection:SetHeight(UI_PAGE_HEADER_HEIGHT)
    self.pageHeaderSection = pageHeaderSection

    local pageLabel = CreateHeaderLabel(pageHeaderSection, "$(parent)Label", GetText("page.header.label"), "ZoFontHeader")
    pageLabel:ClearAnchors()
    pageLabel:SetAnchor(TOPLEFT, pageHeaderSection, TOPLEFT, UI_PANEL_INSET, 10)

    local pageActionButton = CreateIconButton(
        pageHeaderSection,
        "$(parent)ActionButton",
        24,
        TOPRIGHT,
        pageHeaderSection,
        TOPRIGHT,
        -UI_PANEL_INSET,
        10,
        "/esoui/art/buttons/edit",
        GetText("page.action.menu")
    )
    pageActionButton:SetHandler("OnClicked", function()
        LTM_UI:TogglePageActionMenu()
    end)
    self.pageActionButton = pageActionButton

    local pageNavRow = WINDOW_MANAGER:CreateControl("$(parent)NavRow", pageHeaderSection, CT_CONTROL)
    pageNavRow:ClearAnchors()
    pageNavRow:SetAnchor(TOPLEFT, pageHeaderSection, TOPLEFT, UI_PANEL_INSET, 33)
    pageNavRow:SetAnchor(TOPRIGHT, pageHeaderSection, TOPRIGHT, -UI_PANEL_INSET, 33)
    pageNavRow:SetHeight(UI_PAGE_NAV_BUTTON_HEIGHT)
    self.pageNavRow = pageNavRow

    local pageSelectDropdown = CreatePageSelectComboBox(pageNavRow, "$(parent)PageSelect")
    self.pageSelectDropdown = pageSelectDropdown
    self.pageSelectComboBox = pageSelectDropdown.comboBox

    local pagePrevButton = CreatePageNavButton(pageNavRow, "$(parent)PrevButton", "/esoui/art/buttons/large_leftarrow", GetText("page.nav.previous"))
    pagePrevButton:ClearAnchors()
    pagePrevButton:SetAnchor(RIGHT, pageSelectDropdown, LEFT, -8, 0)
    pagePrevButton:SetHandler("OnClicked", function()
        LTM_UI:ChangePage("previous")
    end)
    self.pagePrevButton = pagePrevButton

    local pageNextButton = CreatePageNavButton(pageNavRow, "$(parent)NextButton", "/esoui/art/buttons/large_rightarrow", GetText("page.nav.next"))
    pageNextButton:ClearAnchors()
    pageNextButton:SetAnchor(LEFT, pageSelectDropdown, RIGHT, 8, 0)
    pageNextButton:SetHandler("OnClicked", function()
        LTM_UI:ChangePage("next")
    end)
    self.pageNextButton = pageNextButton

    local pageActionMenuParent = self.frontOverlayRoot or self.layoutRoot or pageHeaderSection
    local pageActionMenu = CreateBackdrop(pageActionMenuParent, "LTM_UI_PageActionMenu", 0.10, 0.10, 0.12, 0.98, 0.48, 0.52, 0.58, 1.0)
    pageActionMenu:SetDimensions(UI_PAGE_ACTION_MENU_WIDTH + (UI_ACTION_MENU_PADDING_X * 2), (5 * UI_ACTION_MENU_ROW_HEIGHT) + (4 * UI_ACTION_MENU_ROW_GAP) + (UI_ACTION_MENU_PADDING_Y * 2))
    pageActionMenu:ClearAnchors()
    pageActionMenu:SetAnchor(TOPRIGHT, pageActionButton, BOTTOMRIGHT, 0, 4)
    pageActionMenu:SetHidden(true)
    SetControlDrawOrder(pageActionMenu, DT_HIGH, DL_OVERLAY, 2)
    self.pageActionMenu = pageActionMenu

    local addPageButton = CreateActionMenuButton(pageActionMenu, "AddPage", nil, "page.action.add", function()
        LTM_UI:HandleAddPage()
    end)
    local renamePageButton = CreateActionMenuButton(pageActionMenu, "RenamePage", addPageButton, "page.action.rename", function()
        LTM_UI:HandleRenamePage()
    end)
    local reorderPagesButton = CreateActionMenuButton(pageActionMenu, "ReorderPages", renamePageButton, "page.action.reorder_pages", function()
        LTM_UI:HandleReorderPages()
    end)
    local sortPageButton = CreateActionMenuButton(pageActionMenu, "SortPage", reorderPagesButton, "page.action.sort", function()
        LTM_UI:HandleReorderBuilds()
    end)
    CreateActionMenuButton(pageActionMenu, "DeletePage", sortPageButton, "page.action.delete", function()
        LTM_UI:HandleDeletePage()
    end)

    local cardListSection = WINDOW_MANAGER:CreateControl("$(parent)CardListSection", leftPane, CT_CONTROL)
    local newCardButtonContainer = WINDOW_MANAGER:CreateControl("$(parent)NewCardButtonContainer", leftPane, CT_CONTROL)
    newCardButtonContainer:ClearAnchors()
    newCardButtonContainer:SetAnchor(BOTTOMLEFT, leftPane, BOTTOMLEFT, UI_CONTENT_GAP, -UI_CONTENT_GAP)
    newCardButtonContainer:SetAnchor(BOTTOMRIGHT, leftPane, BOTTOMRIGHT, -UI_CONTENT_GAP, -UI_CONTENT_GAP)
    newCardButtonContainer:SetHeight(UI_NEW_CARD_AREA_HEIGHT)
    self.newCardButtonArea = newCardButtonContainer
    self.newCardButtonContainer = newCardButtonContainer

    cardListSection:ClearAnchors()
    cardListSection:SetAnchor(TOPLEFT, pageHeaderSection, BOTTOMLEFT, 0, UI_SECTION_GAP)
    cardListSection:SetAnchor(BOTTOMRIGHT, newCardButtonContainer, TOPRIGHT, 0, -UI_SECTION_GAP + UI_CARD_LIST_SECTION_BOTTOM_EXTENSION)
    self.cardListSection = cardListSection

    local cardListScrollContainer = WINDOW_MANAGER:CreateControlFromVirtual("$(parent)ScrollContainer", cardListSection, "ZO_ScrollContainer")
    cardListScrollContainer:ClearAnchors()
    cardListScrollContainer:SetAnchorFill(cardListSection)
    if type(ZO_Scroll_SetUseFadeGradient) == "function" then
        ZO_Scroll_SetUseFadeGradient(cardListScrollContainer, false)
    end
    if type(ZO_Scroll_SetHideScrollbarOnDisable) == "function" then
        ZO_Scroll_SetHideScrollbarOnDisable(cardListScrollContainer, true)
    end
    self.cardListScrollContainer = cardListScrollContainer
    self.cardListScrollBar = cardListScrollContainer:GetNamedChild("ScrollBar")
    if self.cardListScrollBar and type(ZO_VerticalScrollbarBase_OnMouseExit) == "function" then
        ZO_VerticalScrollbarBase_OnMouseExit(self.cardListScrollBar)
    end

    local cardListContainer = cardListScrollContainer:GetNamedChild("ScrollChild")
    if cardListContainer and type(cardListContainer.SetResizeToFitPadding) == "function" then
        cardListContainer:SetResizeToFitPadding(0, UI_CARD_SPACING)
    end
    self.cardListContainer = cardListContainer
    self:ApplyCardListContainerLayout(false, UI_CARD_LIST_SECTION_HEIGHT)

    local emptyStateControl = CreateBackdrop(cardListContainer, "$(parent)EmptyState", 0.09, 0.09, 0.11, 0.95, 0.26, 0.28, 0.32, 1.0)
    emptyStateControl:ClearAnchors()
    emptyStateControl:SetAnchor(TOPLEFT, cardListContainer, TOPLEFT, 0, 0)
    emptyStateControl:SetAnchor(TOPRIGHT, cardListContainer, TOPRIGHT, 0, 0)
    emptyStateControl:SetHeight(120)
    self.emptyStateControl = emptyStateControl

    local emptyTitle = CreateHeaderLabel(emptyStateControl, "$(parent)Title", GetText("card.empty_title"), "ZoFontWinH4")
    emptyTitle:ClearAnchors()
    emptyTitle:SetAnchor(TOPLEFT, emptyStateControl, TOPLEFT, UI_PANEL_INSET, 14)
    emptyTitle:SetColor(1.0, 1.0, 1.0, 1.0)

    local emptyBody = WINDOW_MANAGER:CreateControl("$(parent)Body", emptyStateControl, CT_LABEL)
    emptyBody:ClearAnchors()
    emptyBody:SetAnchor(TOPLEFT, emptyTitle, BOTTOMLEFT, 0, 8)
    emptyBody:SetAnchor(TOPRIGHT, emptyStateControl, TOPRIGHT, -UI_PANEL_INSET, 44)
    emptyBody:SetHeight(52)
    emptyBody:SetFont("ZoFontGame")
    emptyBody:SetColor(0.78, 0.82, 0.86, 1.0)
    if type(emptyBody.SetVerticalAlignment) == "function" then
        emptyBody:SetVerticalAlignment(TEXT_ALIGN_TOP)
    end
    emptyBody:SetText(GetText("card.empty_body"))

    local addCardButton = WINDOW_MANAGER:CreateControlFromVirtual("$(parent)AddCardButton", newCardButtonContainer, "ZO_DefaultButton")
    addCardButton:ClearAnchors()
    addCardButton:SetAnchor(BOTTOMLEFT, newCardButtonContainer, BOTTOMLEFT, 0, 0)
    addCardButton:SetAnchor(BOTTOMRIGHT, newCardButtonContainer, BOTTOMRIGHT, -UI_LEFT_PANE_RIGHT_INSET, 0)
    addCardButton:SetHeight(32)
    addCardButton:SetFont("ZoFontGame")
    if type(addCardButton.SetTextHorizontalAlignment) == "function" then
        addCardButton:SetTextHorizontalAlignment(TEXT_ALIGN_CENTER)
    end
    addCardButton:SetText(GetText("page.add_card"))
    addCardButton:SetHandler("OnClicked", function()
        local build, err = LTM_UI_DISPATCH:AddNewCard()
        if type(build) ~= "table" then
            LTM_UI:LogActionError("common.save", err)
            return
        end

        LTM_UI.selectedCardId = build.id
        LTM_UI.selectedBuildId = build.id
        LTM_UI.expandedCardId = build.id
        LTM_UI:QueueCardListScroll(build.id, "center")
        LTM_UI:RefreshCardList()
        Log.WriteChat(GetText("status.saved", { cardName = build.displayName or build.name or build.id }))
    end)
    self.addCardButton = addCardButton

    local rightPane = CreateBackdrop(armoryStationContent, "$(parent)RightPane", 0.07, 0.08, 0.09, 0.94, 0.28, 0.30, 0.34, 1.0)
    rightPane:ClearAnchors()
    rightPane:SetAnchor(TOPLEFT, leftPane, TOPRIGHT, UI_PANE_GAP, 0)
    rightPane:SetAnchor(BOTTOMRIGHT, armoryStationContent, BOTTOMRIGHT, 0, 0)
    self.rightPane = rightPane

    local currentContainer = WINDOW_MANAGER:CreateControl("LTM_AS_CurrentContainer", rightPane, CT_CONTROL)
    currentContainer:ClearAnchors()
    currentContainer:SetAnchor(TOPLEFT, rightPane, TOPLEFT, UI_CONTENT_GAP, UI_CONTENT_GAP)
    currentContainer:SetAnchor(BOTTOMRIGHT, rightPane, BOTTOMRIGHT, -UI_CONTENT_GAP, -UI_CONTENT_GAP)
    self.currentContainer = currentContainer

    local currentHeaderSection = CreateBackdrop(currentContainer, "$(parent)CurrentHeader", 0.09, 0.10, 0.12, 0.98, 0.28, 0.30, 0.34, 1.0)
    currentHeaderSection:ClearAnchors()
    currentHeaderSection:SetAnchor(TOPLEFT, currentContainer, TOPLEFT, 0, 0)
    currentHeaderSection:SetAnchor(TOPRIGHT, currentContainer, TOPRIGHT, 0, 0)
    currentHeaderSection:SetHeight(UI_CURRENT_HEADER_HEIGHT)
    self.currentHeaderSection = currentHeaderSection

    local headerTitleRow = WINDOW_MANAGER:CreateControl("$(parent)HeaderTitleRow", currentHeaderSection, CT_CONTROL)
    headerTitleRow:ClearAnchors()
    headerTitleRow:SetAnchor(TOPLEFT, currentHeaderSection, TOPLEFT, 0, UI_CURRENT_HEADER_TOP_PADDING)
    headerTitleRow:SetAnchor(TOPRIGHT, currentHeaderSection, TOPRIGHT, 0, UI_CURRENT_HEADER_TOP_PADDING)
    headerTitleRow:SetHeight(UI_CURRENT_HEADER_TITLE_ROW_HEIGHT)
    self.headerTitleRow = headerTitleRow

    local currentTitle = CreateHeaderLabel(headerTitleRow, "$(parent)Title", GetText("current.title"), "ZoFontWinH2")
    currentTitle:ClearAnchors()
    currentTitle:SetAnchor(TOPLEFT, headerTitleRow, TOPLEFT, UI_CURRENT_HEADER_SIDE_PADDING, 0)
    currentTitle:SetAnchor(TOPRIGHT, headerTitleRow, TOPRIGHT, -144, 0)
    currentTitle:SetColor(1.0, 1.0, 1.0, 1.0)
    self.currentTitle = currentTitle

    local rightPaneModeButton = WINDOW_MANAGER:CreateControlFromVirtual("$(parent)ModeButton", headerTitleRow, "ZO_DefaultButton")
    rightPaneModeButton:ClearAnchors()
    rightPaneModeButton:SetAnchor(TOPRIGHT, headerTitleRow, TOPRIGHT, -UI_CURRENT_HEADER_SIDE_PADDING, -2)
    rightPaneModeButton:SetDimensions(132, 24)
    rightPaneModeButton:SetFont("ZoFontGameSmall")
    rightPaneModeButton:SetText(GetText("current.toggle.show_target"))
    rightPaneModeButton:SetHandler("OnClicked", function()
        LTM_UI:ToggleRightPaneMode()
    end)
    self.rightPaneModeButton = rightPaneModeButton

    local currentSummaryArea = WINDOW_MANAGER:CreateControl("$(parent)SummaryArea", currentHeaderSection, CT_CONTROL)
    currentSummaryArea:ClearAnchors()
    currentSummaryArea:SetAnchor(TOPLEFT, headerTitleRow, BOTTOMLEFT, 0, UI_CURRENT_HEADER_ROW_GAP)
    currentSummaryArea:SetAnchor(TOPRIGHT, headerTitleRow, BOTTOMRIGHT, 0, UI_CURRENT_HEADER_ROW_GAP)
    currentSummaryArea:SetHeight(UI_CURRENT_SUMMARY_HEIGHT)
    self.currentSummaryArea = currentSummaryArea

    local currentSkillLinesRow = WINDOW_MANAGER:CreateControl("$(parent)SummaryRow1", currentSummaryArea, CT_CONTROL)
    currentSkillLinesRow:ClearAnchors()
    currentSkillLinesRow:SetAnchor(TOPLEFT, currentSummaryArea, TOPLEFT, 0, 0)
    currentSkillLinesRow:SetAnchor(TOPRIGHT, currentSummaryArea, TOPRIGHT, 0, 0)
    currentSkillLinesRow:SetHeight(UI_CURRENT_SUMMARY_ROW_HEIGHT)
    self.currentSubclassSection = currentSkillLinesRow
    local currentSkillLinesValue = CreateValueLabel(currentSkillLinesRow, "$(parent)Value")
    currentSkillLinesValue:ClearAnchors()
    currentSkillLinesValue:SetAnchor(LEFT, currentSkillLinesRow, LEFT, UI_CURRENT_HEADER_SIDE_PADDING, 0)
    currentSkillLinesValue:SetAnchor(RIGHT, currentSkillLinesRow, RIGHT, -UI_CURRENT_HEADER_SIDE_PADDING, 0)
    currentSkillLinesValue:SetFont("ZoFontWinT2")
    currentSkillLinesValue:SetColor(0.92, 0.94, 0.98, 1.0)
    if type(currentSkillLinesValue.SetMaxLineCount) == "function" then
        currentSkillLinesValue:SetMaxLineCount(1)
    end
    if type(currentSkillLinesValue.SetWrapMode) == "function" and TEXT_WRAP_MODE_ELLIPSIS then
        currentSkillLinesValue:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    end
    SetTextTooltip(currentSkillLinesValue, GetText("common.none"))
    self.currentSubclassValue = currentSkillLinesValue

    local currentBodySection = CreateBackdrop(currentContainer, "$(parent)CurrentBody", 0.08, 0.09, 0.11, 0.98, 0.28, 0.30, 0.34, 1.0)
    currentBodySection:ClearAnchors()
    currentBodySection:SetAnchor(TOPLEFT, currentHeaderSection, BOTTOMLEFT, 0, UI_SECTION_GAP)
    currentBodySection:SetAnchor(TOPRIGHT, currentHeaderSection, BOTTOMRIGHT, 0, UI_SECTION_GAP)
    currentBodySection:SetHeight(UI_CURRENT_BODY_HEIGHT)
    self.currentBodySection = currentBodySection

    local currentTopSection = WINDOW_MANAGER:CreateControl("$(parent)TopSection", currentBodySection, CT_CONTROL)
    currentTopSection:ClearAnchors()
    currentTopSection:SetAnchor(TOPLEFT, currentBodySection, TOPLEFT, UI_PANEL_INSET, UI_PANEL_INSET)
    currentTopSection:SetAnchor(TOPRIGHT, currentBodySection, TOPRIGHT, -UI_PANEL_INSET, UI_PANEL_INSET)
    currentTopSection:SetHeight(UI_CURRENT_SKILL_HEIGHT)
    self.currentTopSection = currentTopSection

    local currentAttributeBox = self:CreateCurrentDetailBox(currentTopSection, "LTM_UI_CurrentAttributes", "current.section.attributes")
    currentAttributeBox.box:ClearAnchors()
    currentAttributeBox.box:SetAnchor(TOPRIGHT, currentTopSection, TOPRIGHT, 0, 0)
    currentAttributeBox.box:SetAnchor(BOTTOMRIGHT, currentTopSection, BOTTOMRIGHT, 0, 0)
    currentAttributeBox.box:SetWidth(UI_CURRENT_ATTRIBUTE_WIDTH)
    self.currentAttributeBox = currentAttributeBox.box

    self.currentAttributeRows = self:CreateAttributeRows(currentAttributeBox.body, "LTM_UI_CurrentAttributes", {
        rowHeight = UI_CURRENT_ATTRIBUTE_ROW_HEIGHT,
        rowGap = UI_CURRENT_ATTRIBUTE_ROW_GAP,
        nameWidth = 24,
        showNameLabel = true,
        valueFont = "ZoFontWinT2",
        valueAlign = TEXT_ALIGN_RIGHT,
        valueLeftOffset = 8,
    })

    local currentSkillSection = CreateBackdrop(currentTopSection, "$(parent)SkillSection", 0.09, 0.10, 0.12, 0.98, 0.28, 0.30, 0.34, 1.0)
    currentSkillSection:ClearAnchors()
    currentSkillSection:SetAnchor(TOPLEFT, currentTopSection, TOPLEFT, 0, 0)
    currentSkillSection:SetAnchor(BOTTOMRIGHT, currentAttributeBox.box, BOTTOMLEFT, -UI_SECTION_GAP, 0)
    self.currentSkillSection = currentSkillSection

    local currentSkillBarOptions = {
        showHeader = false,
        slotSize = UI_CURRENT_SLOT_SIZE,
        slotGap = UI_CURRENT_SLOT_GAP,
        sideInset = UI_PANEL_INSET,
    }
    local currentFrontBar = CreateSkillBarBlock(currentSkillSection, "LTM_UI_CurrentFrontBar", nil, UI_CURRENT_SKILL_TOP_PADDING, currentSkillBarOptions)
    local currentBackBar = CreateSkillBarBlock(currentSkillSection, "LTM_UI_CurrentBackBar", nil, UI_CURRENT_SKILL_TOP_PADDING + UI_CURRENT_SLOT_SIZE + UI_CURRENT_SKILL_ROW_GAP, currentSkillBarOptions)
    self.currentFrontBarSlots = currentFrontBar.slots
    self.currentBackBarSlots = currentBackBar.slots
    for _, slotControl in ipairs(self.currentFrontBarSlots or {}) do
        self:BindRightPaneSkillSlotTooltipHandlers(slotControl)
    end
    for _, slotControl in ipairs(self.currentBackBarSlots or {}) do
        self:BindRightPaneSkillSlotTooltipHandlers(slotControl)
    end

    local currentRoleArea = WINDOW_MANAGER:CreateControl("$(parent)RoleArea", currentSkillSection, CT_CONTROL)
    currentRoleArea:ClearAnchors()
    currentRoleArea:SetAnchor(TOPLEFT, currentFrontBar.slotContainer, TOPRIGHT, UI_CURRENT_ROLE_ICON_LEFT_GAP, 0)
    currentRoleArea:SetAnchor(BOTTOMRIGHT, currentSkillSection, BOTTOMRIGHT, -UI_PANEL_INSET, 0)
    self.currentRoleArea = currentRoleArea

    local currentRoleIcon = WINDOW_MANAGER:CreateControl("$(parent)RoleIcon", currentRoleArea, CT_TEXTURE)
    currentRoleIcon:ClearAnchors()
    currentRoleIcon:SetAnchor(
        TOPRIGHT,
        currentRoleArea,
        TOPRIGHT,
        LTM_UI_RIGHT_PANE_ICON_LAYOUT.ROLE_RIGHT_OFFSET,
        LTM_UI_RIGHT_PANE_ICON_LAYOUT.ROLE_TOP_OFFSET
    )
    currentRoleIcon:SetDimensions(
        LTM_UI_RIGHT_PANE_ICON_LAYOUT.ROLE_ICON_SIZE,
        LTM_UI_RIGHT_PANE_ICON_LAYOUT.ROLE_ICON_SIZE
    )
    currentRoleIcon:SetColor(1.0, 1.0, 1.0, 1.0)
    currentRoleIcon:SetAlpha(1.0)
    SetControlDrawOrder(currentRoleIcon, DT_HIGH, DL_OVERLAY, 4)
    currentRoleIcon:SetHidden(true)
    self.currentRoleIcon = currentRoleIcon

    self.currentTransformIcons = {}
    for transformIndex, kind in ipairs({ "werewolf", "vampire" }) do
        local transformIcon = WINDOW_MANAGER:CreateControl(
            "LTM_RP_TransformIcon" .. tostring(transformIndex),
            currentRoleArea,
            CT_TEXTURE
        )
        transformIcon:ClearAnchors()
        transformIcon:SetAnchor(
            TOPRIGHT,
            currentRoleArea,
            TOPRIGHT,
            LTM_UI_RIGHT_PANE_ICON_LAYOUT.TRANSFORM_RIGHT_OFFSETS[kind],
            LTM_UI_RIGHT_PANE_ICON_LAYOUT.TRANSFORM_TOP_OFFSET
        )
        transformIcon:SetDimensions(
            LTM_UI_RIGHT_PANE_ICON_LAYOUT.TRANSFORM_ICON_SIZE,
            LTM_UI_RIGHT_PANE_ICON_LAYOUT.TRANSFORM_ICON_SIZE
        )
        transformIcon:SetMouseEnabled(true)
        SetTextTooltip(transformIcon, GetText("transform.settings.tooltip"))
        transformIcon.ltmTransformKind = kind
        transformIcon:SetHandler("OnMouseUp", function(control, mouseButton, upInside)
            if upInside == true and mouseButton == MOUSE_BUTTON_INDEX_LEFT then
                LTM_UI:ShowTransformSkillsPopup(
                    control.ltmTransformKind,
                    control.ltmTransformCardId
                )
            end
        end)
        SetControlDrawOrder(transformIcon, DT_HIGH, DL_OVERLAY, 6)
        transformIcon:SetHidden(true)
        self.currentTransformIcons[#self.currentTransformIcons + 1] = transformIcon
    end

    local currentClassMasteryArea = WINDOW_MANAGER:CreateControl("LTM_RP_CM_Area", currentRoleArea, CT_CONTROL)
    currentClassMasteryArea:ClearAnchors()
    currentClassMasteryArea:SetAnchor(
        TOP,
        currentRoleIcon,
        BOTTOM,
        LTM_UI_RIGHT_PANE_ICON_LAYOUT.CLASS_MASTERY_OFFSET_X,
        15
    )
    currentClassMasteryArea:SetDimensions((UI_CURRENT_MASTERY_ICON_SIZE * 2) + UI_CURRENT_MASTERY_ICON_GAP, UI_CURRENT_MASTERY_ICON_SIZE)
    self.currentClassMasteryArea = currentClassMasteryArea
    self.currentClassMasteryIcons = {}
    for index = 1, 2 do
        local masteryIcon = WINDOW_MANAGER:CreateControl("LTM_RP_CM_Icon" .. tostring(index), currentClassMasteryArea, CT_TEXTURE)
        masteryIcon:ClearAnchors()
        masteryIcon:SetDimensions(UI_CURRENT_MASTERY_ICON_SIZE, UI_CURRENT_MASTERY_ICON_SIZE)
        masteryIcon:SetColor(1.0, 1.0, 1.0, 1.0)
        masteryIcon:SetAlpha(1.0)
        SetControlDrawOrder(masteryIcon, DT_HIGH, DL_OVERLAY, 5)
        if type(masteryIcon.SetMouseEnabled) == "function" then
            masteryIcon:SetMouseEnabled(true)
        end
        masteryIcon:SetHandler("OnMouseEnter", function(control)
            LTM_UI:ShowClassMasteryAbilityTooltip(control, control.ltmClassMasteryEntry)
        end)
        masteryIcon:SetHandler("OnMouseExit", function()
            LTM_UI:ClearClassMasteryAbilityTooltip()
        end)
        masteryIcon:SetHidden(true)
        self.currentClassMasteryIcons[index] = masteryIcon
    end

    local currentBottomSection = WINDOW_MANAGER:CreateControl("$(parent)BottomSection", currentBodySection, CT_CONTROL)
    currentBottomSection:ClearAnchors()
    currentBottomSection:SetAnchor(TOPLEFT, currentTopSection, BOTTOMLEFT, 0, UI_SECTION_GAP)
    currentBottomSection:SetAnchor(TOPRIGHT, currentTopSection, BOTTOMRIGHT, 0, UI_SECTION_GAP)
    currentBottomSection:SetHeight(UI_CURRENT_BOTTOM_HEIGHT)
    self.currentBottomSection = currentBottomSection

    local currentEquipmentBox = self:CreateCurrentDetailBox(currentBottomSection, "LTM_UI_CurrentEquipment", "current.section.equipment", {
        reserveExtraTitle = true,
    })
    currentEquipmentBox.box:ClearAnchors()
    currentEquipmentBox.box:SetAnchor(TOPLEFT, currentBottomSection, TOPLEFT, 0, 0)
    currentEquipmentBox.box:SetAnchor(BOTTOMLEFT, currentBottomSection, BOTTOMLEFT, 0, -UI_CURRENT_BOTTOM_BOX_TRIM)
    currentEquipmentBox.box:SetWidth(UI_CURRENT_EQUIPMENT_WIDTH)
    currentEquipmentBox.title:ClearAnchors()
    currentEquipmentBox.title:SetAnchor(TOPLEFT, currentEquipmentBox.box, TOPLEFT, UI_PANEL_INSET, UI_CURRENT_BOTTOM_TITLE_TOP)
    currentEquipmentBox.title:SetDimensions(112, 20)

    local currentCpBox = self:CreateCurrentDetailBox(currentBottomSection, "LTM_UI_CurrentCp", "current.section.cp")
    currentCpBox.box:ClearAnchors()
    currentCpBox.box:SetAnchor(TOPLEFT, currentEquipmentBox.box, TOPRIGHT, UI_SECTION_GAP, 0)
    currentCpBox.box:SetAnchor(BOTTOMRIGHT, currentBottomSection, BOTTOMRIGHT, 0, -UI_CURRENT_BOTTOM_BOX_TRIM)

    self.currentEquipmentContent = self:CreateCurrentDynamicContent(currentEquipmentBox.body, "LTM_UI_CurrentEquipment")
    self.currentEquipmentOutfitLabel = currentEquipmentBox.extraTitle
    local equipmentDepositButton = CreateIconButton(
        currentEquipmentBox.box,
        "LTM_UI_CurrentEquipmentDeposit",
        UI_CURRENT_EQUIPMENT_FETCH_BUTTON_SIZE,
        TOPRIGHT,
        currentEquipmentBox.box,
        TOPRIGHT,
        -UI_PANEL_INSET + 3,
        UI_CURRENT_BOTTOM_TITLE_TOP - 7,
        UI_EQUIPMENT_DEPOSIT_ICON_TEXTURE_PREFIX,
        GetText("current.equipment.deposit.tooltip.disabled")
    )
    equipmentDepositButton:SetDisabledTexture(UI_EQUIPMENT_DEPOSIT_ICON_TEXTURE_PREFIX .. "_up.dds")
    equipmentDepositButton:SetHidden(true)
    equipmentDepositButton:SetHandler("OnClicked", function()
        if equipmentDepositButton.ltmDepositEnabled ~= true then
            return
        end

        local cardId = LTM_UI.selectedCardId
        local ok, err, summary = LTM_UI_DISPATCH:DepositUnusedEquipment(cardId, function(success, completionErr, completionSummary)
            LTM_UI:HandleEquipmentDepositResult(success, completionErr, completionSummary)
        end)
        if ok == true and err == "deferred" then
            LTM_UI:RefreshRightPanePanel()
            return
        end
        if ok == true then
            LTM_UI:HandleEquipmentDepositResult(true, err, summary)
            return
        end

        LTM_UI:HandleEquipmentDepositResult(false, err, summary)
    end)
    self.currentEquipmentDepositButton = equipmentDepositButton

    local equipmentFetchButton = CreateIconButton(
        currentEquipmentBox.box,
        "LTM_UI_CurrentEquipmentFetch",
        UI_CURRENT_EQUIPMENT_FETCH_BUTTON_SIZE,
        TOPRIGHT,
        equipmentDepositButton,
        TOPLEFT,
        -UI_CURRENT_EQUIPMENT_FETCH_BUTTON_GAP + 4,
        0,
        UI_EQUIPMENT_WITHDRAW_ICON_TEXTURE_PREFIX,
        GetText("current.equipment.fetch.tooltip.disabled")
    )
    equipmentFetchButton:SetDisabledTexture(UI_EQUIPMENT_WITHDRAW_ICON_TEXTURE_PREFIX .. "_up.dds")
    equipmentFetchButton:SetHidden(true)
    equipmentFetchButton:SetHandler("OnClicked", function()
        if equipmentFetchButton.ltmFetchEnabled ~= true then
            return
        end

        local cardId = LTM_UI.selectedCardId
        if type(cardId) ~= "string" or cardId == "" then
            return
        end

        local ok, err, summary = LTM_UI_DISPATCH:FetchMissingSelectedTargetEquipment(cardId, function(success, completionErr, completionSummary)
            LTM_UI:HandleEquipmentFetchResult(success, completionErr, completionSummary)
        end)
        if ok == true and err == "deferred" then
            LTM_UI:RefreshRightPanePanel()
            return
        end
        if ok == true then
            LTM_UI:HandleEquipmentFetchResult(true, err, summary)
            return
        end

        LTM_UI:HandleEquipmentFetchResult(false, err, summary)
    end)
    self.currentEquipmentFetchButton = equipmentFetchButton
    if self.currentEquipmentOutfitLabel ~= nil then
        self.currentEquipmentOutfitLabel:ClearAnchors()
        self.currentEquipmentOutfitLabel:SetAnchor(
            TOPRIGHT,
            currentEquipmentBox.box,
            TOPRIGHT,
            -(UI_PANEL_INSET + (UI_CURRENT_EQUIPMENT_FETCH_BUTTON_SIZE * 2) + (UI_CURRENT_EQUIPMENT_FETCH_BUTTON_GAP * 2)),
            UI_CURRENT_BOTTOM_TITLE_TOP
        )
    end
    self.currentEquipmentRows = {}
    self.currentChampionContent = self:CreateCurrentDynamicContent(currentCpBox.body, "LTM_UI_CurrentCp")
    self.currentChampionContent:ClearAnchors()
    self.currentChampionContent:SetAnchor(TOPLEFT, currentCpBox.body, TOPLEFT, 0, 0)
    self.currentChampionContent:SetAnchor(BOTTOMRIGHT, currentCpBox.body, BOTTOMRIGHT, 0, -20)
    self.currentChampionRows = {}

    local forceChampionRespecCheckbox = WINDOW_MANAGER:CreateControlFromVirtual("$(parent)ForceChampionRespec", currentCpBox.body, "ZO_CheckButton")
    forceChampionRespecCheckbox:ClearAnchors()
    forceChampionRespecCheckbox:SetAnchor(BOTTOMLEFT, currentCpBox.body, BOTTOMLEFT, 0, -5)
    forceChampionRespecCheckbox:SetDimensions(18, 18)
    if type(ZO_CheckButton_SetLabelText) == "function" then
        ZO_CheckButton_SetLabelText(forceChampionRespecCheckbox, "")
    end
    SetCheckButtonTooltip(forceChampionRespecCheckbox, GetText("card.force_cp_respec.tooltip"))

    local forceChampionRespecLabel = WINDOW_MANAGER:CreateControl("$(parent)ForceChampionRespecDisplayText", currentCpBox.body, CT_LABEL)
    forceChampionRespecLabel:ClearAnchors()
    forceChampionRespecLabel:SetAnchor(TOPLEFT, forceChampionRespecCheckbox, TOPRIGHT, 8, 0)
    forceChampionRespecLabel:SetAnchor(BOTTOMRIGHT, currentCpBox.body, BOTTOMRIGHT, 0, -2)
    forceChampionRespecLabel:SetHeight(18)
    forceChampionRespecLabel:SetFont("ZoFontGameSmall")
    forceChampionRespecLabel:SetColor(0.92, 0.90, 0.78, 1.0)
    forceChampionRespecLabel:SetText(BuildForceChampionRespecLabel())
    if type(forceChampionRespecLabel.SetMaxLineCount) == "function" then
        forceChampionRespecLabel:SetMaxLineCount(1)
    end
    if type(forceChampionRespecLabel.SetWrapMode) == "function" and TEXT_WRAP_MODE_ELLIPSIS then
        forceChampionRespecLabel:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    end
    if type(forceChampionRespecLabel.SetVerticalAlignment) == "function" then
        forceChampionRespecLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    end
    SetTextTooltip(forceChampionRespecLabel, GetText("card.force_cp_respec.tooltip"))
    local forceChampionRespecToggleCallback = function(button, isChecked)
        if button.ltmSuppressToggle == true then
            return
        end

        local cardId = LTM_UI.selectedCardId
        if type(cardId) ~= "string" or cardId == "" then
            if type(ZO_CheckButton_SetCheckState) == "function" then
                ZO_CheckButton_SetCheckState(button, false)
            end
            return
        end

        LTM_UI:SetCardForceChampionRespecEnabled(cardId, isChecked == true)
        LTM_UI:RefreshForceChampionRespecControl()
    end
    if type(ZO_CheckButton_SetToggleFunction) == "function" then
        ZO_CheckButton_SetToggleFunction(forceChampionRespecCheckbox, forceChampionRespecToggleCallback)
    end
    if type(forceChampionRespecLabel.SetMouseEnabled) == "function" then
        forceChampionRespecLabel:SetMouseEnabled(true)
    end
    forceChampionRespecLabel:SetHandler("OnMouseUp", function(_, mouseButton, upInside)
        if upInside ~= true or mouseButton ~= MOUSE_BUTTON_INDEX_LEFT then
            return
        end

        local cardId = LTM_UI.selectedCardId
        if type(cardId) ~= "string" or cardId == "" then
            return
        end

        local isChecked = not IsCheckButtonChecked(forceChampionRespecCheckbox)
        if type(ZO_CheckButton_SetCheckState) == "function" then
            ZO_CheckButton_SetCheckState(forceChampionRespecCheckbox, isChecked)
        end
        forceChampionRespecToggleCallback(forceChampionRespecCheckbox, isChecked)
    end)
    self.forceChampionRespecCheckbox = forceChampionRespecCheckbox
    self.forceChampionRespecLabel = forceChampionRespecLabel

    local actionSection = CreateBackdrop(currentContainer, "$(parent)CurrentActions", 0.10, 0.10, 0.12, 0.96, 0.34, 0.36, 0.40, 1.0)
    actionSection:ClearAnchors()
    actionSection:SetAnchor(BOTTOMLEFT, currentContainer, BOTTOMLEFT, 0, 0)
    actionSection:SetAnchor(BOTTOMRIGHT, currentContainer, BOTTOMRIGHT, 0, 0)
    actionSection:SetHeight(UI_ACTION_SECTION_HEIGHT)
    actionSection:SetEdgeColor(0.34, 0.36, 0.40, 0.0)
    self.actionSection = actionSection

    currentBodySection:ClearAnchors()
    currentBodySection:SetAnchor(TOPLEFT, currentHeaderSection, BOTTOMLEFT, 0, UI_SECTION_GAP)
    currentBodySection:SetAnchor(BOTTOMRIGHT, actionSection, TOPRIGHT, 0, -UI_SECTION_GAP)

    local actionsBody = WINDOW_MANAGER:CreateControl("$(parent)Body", actionSection, CT_CONTROL)
    actionsBody:ClearAnchors()
    actionsBody:SetAnchorFill(actionSection)
    self.actionsBody = actionsBody

    local partialButtonsRow = WINDOW_MANAGER:CreateControl("LTM_AS_PartialRow", actionsBody, CT_CONTROL)
    partialButtonsRow:ClearAnchors()
    partialButtonsRow:SetAnchor(BOTTOM, actionsBody, BOTTOM, 0, UI_ACTION_PARTIAL_ROW_BOTTOM_OFFSET)
    partialButtonsRow:SetDimensions(UI_ACTION_PARTIAL_ROW_WIDTH, 24)

    local applyButtonRow = WINDOW_MANAGER:CreateControl("$(parent)ApplyRow", actionsBody, CT_CONTROL)
    applyButtonRow:ClearAnchors()
    applyButtonRow:SetAnchor(BOTTOM, actionsBody, BOTTOM, 0, UI_ACTION_APPLY_ROW_BOTTOM_OFFSET)
    applyButtonRow:SetDimensions(UI_ACTION_PARTIAL_ROW_WIDTH, 32)

    local partialAttributeButton = WINDOW_MANAGER:CreateControlFromVirtual("$(parent)PartialAttribute", partialButtonsRow, "ZO_DefaultButton")
    partialAttributeButton:ClearAnchors()
    partialAttributeButton:SetAnchor(LEFT, partialButtonsRow, LEFT, 0, 0)
    partialAttributeButton:SetDimensions(132, 24)
    partialAttributeButton:SetFont("ZoFontGameSmall")
    partialAttributeButton:SetText(GetText("actions.partial_attributes"))
    partialAttributeButton:SetHandler("OnClicked", function()
        local cardId = LTM_UI.selectedCardId
        if type(cardId) ~= "string" or cardId == "" then
            return
        end

        local ok, err = LTM_UI_DISPATCH:ApplySelectedTargetBuildPartial(cardId, "attributes", function(success, completionErr)
            LTM_UI:OnApplyCompleted(success, completionErr)
        end)
        if not ok then
            LTM_UI:LogActionError("common.apply", err)
        end
    end)
    self.partialAttributeButton = partialAttributeButton

    local partialSkillsButton = WINDOW_MANAGER:CreateControlFromVirtual("$(parent)PartialSkills", partialButtonsRow, "ZO_DefaultButton")
    partialSkillsButton:ClearAnchors()
    partialSkillsButton:SetAnchor(LEFT, partialAttributeButton, RIGHT, UI_ACTION_PARTIAL_BUTTON_GAP, 0)
    partialSkillsButton:SetDimensions(148, 24)
    partialSkillsButton:SetFont("ZoFontGameSmall")
    partialSkillsButton:SetText(GetText("actions.partial_skills"))
    partialSkillsButton:SetHandler("OnClicked", function()
        local cardId = LTM_UI.selectedCardId
        if type(cardId) ~= "string" or cardId == "" then
            return
        end

        local function StartClassSkillsApply(acceptedPrecheck)
            local ok, err = LTM_UI_DISPATCH:ApplySelectedTargetBuildPartial(cardId, "class_skills", function(success, completionErr)
                LTM_UI:OnApplyCompleted(success, completionErr)
            end, acceptedPrecheck)
            if not ok and err ~= "skill_point_evaluator_invalid" then
                LTM_UI:LogActionError("common.apply", err)
            end
        end

        local precheck, precheckErr = LTM_UI_DISPATCH:EstimateSelectedCardRouteBPreflight(cardId, "class_skills")
        if type(precheck) ~= "table" then
            if Log.IsSummaryDebugEnabled() then
                Log.LogDebugSummary(
                    "Route B preflight popup skipped",
                    "reason=" .. tostring(precheckErr or "estimate_unavailable"),
                    "cardId=" .. tostring(cardId),
                    "scope=class_skills"
                )
            end
            StartClassSkillsApply()
            return
        end

        if precheck.action ~= "show_point_shortage_dialog" then
            StartClassSkillsApply(precheck)
            return
        end

        local dialogId, dialogParams = BuildSkillPointShortageDialog(precheck)
        if dialogId == nil then
            StartClassSkillsApply(precheck)
            return
        end

        self:ShowDialog(dialogId, {
            params = dialogParams,
            onConfirm = function()
                LogSkillPointPrecheckSummary("Skill Point precheck popup confirmed", cardId, precheck)
                StartClassSkillsApply(precheck)
            end,
            onCancel = function()
                LogSkillPointPrecheckSummary("Skill Point precheck popup cancelled", cardId, precheck)
            end,
        })
        LogSkillPointPrecheckSummary("Skill Point precheck popup shown", cardId, precheck)
    end)
    self.partialSkillsButton = partialSkillsButton

    local partialEquipmentButton = WINDOW_MANAGER:CreateControlFromVirtual("$(parent)PartialEquipment", partialButtonsRow, "ZO_DefaultButton")
    partialEquipmentButton:ClearAnchors()
    partialEquipmentButton:SetAnchor(LEFT, partialSkillsButton, RIGHT, UI_ACTION_PARTIAL_BUTTON_GAP, 0)
    partialEquipmentButton:SetDimensions(136, 24)
    partialEquipmentButton:SetFont("ZoFontGameSmall")
    partialEquipmentButton:SetText(GetText("actions.partial_equipment"))
    partialEquipmentButton:SetHandler("OnClicked", function()
        local cardId = LTM_UI.selectedCardId
        if type(cardId) ~= "string" or cardId == "" then
            return
        end

        local ok, err = LTM_UI_DISPATCH:ApplySelectedTargetBuildPartial(cardId, "equipment", function(success, completionErr)
            LTM_UI:OnApplyCompleted(success, completionErr)
        end)
        if not ok then
            LTM_UI:LogActionError("common.apply", err)
        end
    end)
    self.partialEquipmentButton = partialEquipmentButton

    local partialCpButton = WINDOW_MANAGER:CreateControlFromVirtual("$(parent)PartialCp", partialButtonsRow, "ZO_DefaultButton")
    partialCpButton:ClearAnchors()
    partialCpButton:SetAnchor(LEFT, partialEquipmentButton, RIGHT, UI_ACTION_PARTIAL_BUTTON_GAP, 0)
    partialCpButton:SetDimensions(112, 24)
    partialCpButton:SetFont("ZoFontGameSmall")
    partialCpButton:SetText(GetText("actions.partial_cp"))
    partialCpButton:SetHandler("OnClicked", function()
        local cardId = LTM_UI.selectedCardId
        if type(cardId) ~= "string" or cardId == "" then
            return
        end

        local ok, err = LTM_UI_DISPATCH:ApplySelectedTargetBuildPartial(
            cardId,
            "champion_points",
            function(success, completionErr)
                LTM_UI:OnApplyCompleted(success, completionErr)
            end
        )
        if not ok then
            LTM_UI:LogActionError("common.apply", err)
        end
    end)
    self.partialCpButton = partialCpButton

    local applyButton = WINDOW_MANAGER:CreateControlFromVirtual("$(parent)Apply", applyButtonRow, "ZO_DefaultButton")
    applyButton:ClearAnchors()
    applyButton:SetAnchor(TOPLEFT, applyButtonRow, TOPLEFT, 0, 0)
    applyButton:SetAnchor(TOPRIGHT, applyButtonRow, TOPRIGHT, 0, 0)
    applyButton:SetHeight(32)
    applyButton:SetText(GetText("actions.apply_full"))
    applyButton:SetHandler("OnClicked", function()
        local cardId = LTM_UI.selectedCardId
        if type(cardId) ~= "string" or cardId == "" then
            return
        end

        local function StartFullApply(acceptedPrecheck)
            local ok, err = LTM_UI_DISPATCH:ApplySelectedCard(
                cardId,
                function(success, completionErr)
                    LTM_UI:OnApplyCompleted(success, completionErr)
                end,
                acceptedPrecheck
            )
            if not ok and err ~= "skill_point_evaluator_invalid" then
                LTM_UI:LogActionError("common.apply", err)
            end
        end

        local precheck, precheckErr = LTM_UI_DISPATCH:EstimateSelectedCardRouteBPreflight(cardId)
        if type(precheck) ~= "table" then
            if Log.IsSummaryDebugEnabled() then
                Log.LogDebugSummary(
                    "Route B preflight popup skipped",
                    "reason=" .. tostring(precheckErr or "estimate_unavailable"),
                    "cardId=" .. tostring(cardId)
                )
            end
            StartFullApply()
            return
        end

        if precheck.action ~= "show_point_shortage_dialog" then
            StartFullApply(precheck)
            return
        end

        local dialogId, dialogParams = BuildSkillPointShortageDialog(precheck)
        if dialogId == nil then
            StartFullApply(precheck)
            return
        end

        self:ShowDialog(dialogId, {
            params = dialogParams,
            onConfirm = function()
                LogSkillPointPrecheckSummary("Skill Point precheck popup confirmed", cardId, precheck)
                StartFullApply(precheck)
            end,
            onCancel = function()
                LogSkillPointPrecheckSummary("Skill Point precheck popup cancelled", cardId, precheck)
            end,
        })
        LogSkillPointPrecheckSummary("Skill Point precheck popup shown", cardId, precheck)
    end)
    self.applyButton = applyButton

    local dialogOverlayParent = self.frontOverlayRoot or layoutRoot
    local dialogOverlay = WINDOW_MANAGER:CreateControl("$(parent)DialogOverlay", dialogOverlayParent, CT_CONTROL)
    dialogOverlay:ClearAnchors()
    dialogOverlay:SetAnchorFill(dialogOverlayParent)
    SetControlDrawOrder(dialogOverlay, DT_HIGH, DL_OVERLAY, 20)
    dialogOverlay:SetHidden(true)
    dialogOverlay:SetMouseEnabled(true)
    dialogOverlay:SetHandler("OnMouseUp", function()
    end)
    self.dialogOverlay = dialogOverlay

    local dialogShade = WINDOW_MANAGER:CreateControl("$(parent)Shade", dialogOverlay, CT_BACKDROP)
    dialogShade:ClearAnchors()
    dialogShade:SetAnchorFill(dialogOverlay)
    dialogShade:SetCenterColor(0.0, 0.0, 0.0, 0.84)
    dialogShade:SetEdgeColor(0.0, 0.0, 0.0, 0.0)
    if type(dialogShade.SetMouseEnabled) == "function" then
        dialogShade:SetMouseEnabled(true)
    end
    SetControlDrawOrder(dialogShade, DT_HIGH, DL_OVERLAY, 21)
    self.dialogShade = dialogShade

    local dialogPanel = CreateBackdrop(dialogOverlay, "LTM_Dlg_Panel", 0.05, 0.06, 0.08, 1.0, 0.70, 0.74, 0.80, 1.0)
    dialogPanel:SetDimensions(UI_DIALOG_WIDTH, UI_DIALOG_CONFIRM_HEIGHT)
    dialogPanel:ClearAnchors()
    dialogPanel:SetAnchor(CENTER, dialogOverlay, CENTER, 0, 0)
    if type(dialogPanel.SetMouseEnabled) == "function" then
        dialogPanel:SetMouseEnabled(true)
    end
    SetControlDrawOrder(dialogPanel, DT_HIGH, DL_OVERLAY, 22)
    self.dialogPanel = dialogPanel

    local dialogTitleRow = WINDOW_MANAGER:CreateControl("$(parent)TitleRow", dialogPanel, CT_CONTROL)
    if type(dialogTitleRow.SetMouseEnabled) == "function" then
        dialogTitleRow:SetMouseEnabled(false)
    end
    SetControlDrawOrder(dialogTitleRow, DT_HIGH, DL_OVERLAY, 23)
    self.dialogTitleRow = dialogTitleRow

    local dialogTitle = CreateHeaderLabel(dialogTitleRow, "$(parent)Title", "", "ZoFontWinH2")
    dialogTitle:ClearAnchors()
    dialogTitle:SetAnchor(TOPLEFT, dialogTitleRow, TOPLEFT, 0, 0)
    dialogTitle:SetAnchor(BOTTOMRIGHT, dialogTitleRow, BOTTOMRIGHT, 0, 0)
    dialogTitle:SetColor(1.0, 1.0, 1.0, 1.0)
    if type(dialogTitle.SetMaxLineCount) == "function" then
        dialogTitle:SetMaxLineCount(1)
    end
    if type(dialogTitle.SetWrapMode) == "function" and TEXT_WRAP_MODE_ELLIPSIS then
        dialogTitle:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    end
    SetTextTooltip(dialogTitle, "")
    SetControlDrawOrder(dialogTitle, DT_HIGH, DL_OVERLAY, 24)
    if type(dialogTitle.SetVerticalAlignment) == "function" then
        dialogTitle:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    end
    self.dialogTitleLabel = dialogTitle

    local dialogOverwriteCloseButton = WINDOW_MANAGER:CreateControl("$(parent)OverwriteCloseButton", dialogPanel, CT_BUTTON)
    dialogOverwriteCloseButton:ClearAnchors()
    dialogOverwriteCloseButton:SetAnchor(TOPRIGHT, dialogPanel, TOPRIGHT, -14, 14)
    dialogOverwriteCloseButton:SetDimensions(24, 24)
    dialogOverwriteCloseButton:SetClickSound(SOUNDS.DEFAULT_CLICK)
    dialogOverwriteCloseButton:SetNormalTexture("/esoui/art/buttons/decline_up.dds")
    dialogOverwriteCloseButton:SetMouseOverTexture("/esoui/art/buttons/decline_over.dds")
    dialogOverwriteCloseButton:SetPressedTexture("/esoui/art/buttons/decline_down.dds")
    dialogOverwriteCloseButton:SetDisabledTexture("/esoui/art/buttons/decline_disabled.dds")
    dialogOverwriteCloseButton:SetHidden(true)
    SetTextTooltip(dialogOverwriteCloseButton, GetText("common.close"))
    SetControlDrawOrder(dialogOverwriteCloseButton, DT_HIGH, DL_OVERLAY, 27)
    dialogOverwriteCloseButton:SetHandler("OnClicked", function()
        LTM_UI:HideDialog()
    end)
    self.dialogOverwriteCloseButton = dialogOverwriteCloseButton

    local dialogBody = WINDOW_MANAGER:CreateControl("$(parent)Body", dialogPanel, CT_LABEL)
    dialogBody:SetFont("ZoFontGame")
    dialogBody:SetColor(0.90, 0.90, 0.94, 1.0)
    if type(dialogBody.SetMouseEnabled) == "function" then
        dialogBody:SetMouseEnabled(false)
    end
    SetControlDrawOrder(dialogBody, DT_HIGH, DL_OVERLAY, 24)
    if type(dialogBody.SetHorizontalAlignment) == "function" then
        dialogBody:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    end
    if type(dialogBody.SetVerticalAlignment) == "function" then
        dialogBody:SetVerticalAlignment(TEXT_ALIGN_TOP)
    end
    if type(dialogBody.SetWrapMode) == "function" and TEXT_WRAP_MODE_DEFAULT then
        dialogBody:SetWrapMode(TEXT_WRAP_MODE_DEFAULT)
    end
    self.dialogBodyLabel = dialogBody

    local dialogBudgetShortSummaryLabels = {}
    for index = 1, 4 do
        local label = WINDOW_MANAGER:CreateControl("$(parent)BudgetShortSummary" .. tostring(index), dialogPanel, CT_LABEL)
        label:SetFont("ZoFontGame")
        label:SetColor(0.90, 0.90, 0.94, 1.0)
        if type(label.SetMouseEnabled) == "function" then
            label:SetMouseEnabled(false)
        end
        SetControlDrawOrder(label, DT_HIGH, DL_OVERLAY, 24)
        if type(label.SetHorizontalAlignment) == "function" then
            label:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
        end
        if type(label.SetVerticalAlignment) == "function" then
            label:SetVerticalAlignment(TEXT_ALIGN_TOP)
        end
        if type(label.SetWrapMode) == "function" and TEXT_WRAP_MODE_DEFAULT then
            label:SetWrapMode(TEXT_WRAP_MODE_DEFAULT)
        end
        label:SetHidden(true)
        dialogBudgetShortSummaryLabels[index] = label
    end
    self.dialogBudgetShortSummaryLabels = dialogBudgetShortSummaryLabels

    local dialogBudgetShortExpected = WINDOW_MANAGER:CreateControl("$(parent)BudgetShortExpected", dialogPanel, CT_LABEL)
    dialogBudgetShortExpected:SetFont("ZoFontGame")
    dialogBudgetShortExpected:SetColor(0.90, 0.90, 0.94, 1.0)
    if type(dialogBudgetShortExpected.SetMouseEnabled) == "function" then
        dialogBudgetShortExpected:SetMouseEnabled(false)
    end
    SetControlDrawOrder(dialogBudgetShortExpected, DT_HIGH, DL_OVERLAY, 24)
    if type(dialogBudgetShortExpected.SetHorizontalAlignment) == "function" then
        dialogBudgetShortExpected:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    end
    if type(dialogBudgetShortExpected.SetVerticalAlignment) == "function" then
        dialogBudgetShortExpected:SetVerticalAlignment(TEXT_ALIGN_TOP)
    end
    if type(dialogBudgetShortExpected.SetWrapMode) == "function" and TEXT_WRAP_MODE_DEFAULT then
        dialogBudgetShortExpected:SetWrapMode(TEXT_WRAP_MODE_DEFAULT)
    end
    dialogBudgetShortExpected:SetHidden(true)
    self.dialogBudgetShortExpectedLabel = dialogBudgetShortExpected

    local dialogInputLabel = WINDOW_MANAGER:CreateControl("$(parent)InputLabel", dialogPanel, CT_LABEL)
    dialogInputLabel:SetFont("ZoFontGame")
    dialogInputLabel:SetColor(0.82, 0.84, 0.88, 1.0)
    if type(dialogInputLabel.SetMouseEnabled) == "function" then
        dialogInputLabel:SetMouseEnabled(false)
    end
    SetControlDrawOrder(dialogInputLabel, DT_HIGH, DL_OVERLAY, 24)
    dialogInputLabel:SetHidden(true)
    self.dialogInputLabel = dialogInputLabel

    local dialogEditContainer = WINDOW_MANAGER:CreateControl("$(parent)EditContainer", dialogPanel, CT_CONTROL)
    if type(dialogEditContainer.SetMouseEnabled) == "function" then
        dialogEditContainer:SetMouseEnabled(true)
    end
    SetControlDrawOrder(dialogEditContainer, DT_HIGH, DL_OVERLAY, 24)
    dialogEditContainer:SetHidden(true)
    self.dialogEditContainer = dialogEditContainer

    local dialogEditBox = WINDOW_MANAGER:CreateControlFromVirtual("$(parent)Edit", dialogEditContainer, "ZO_DefaultEditForBackdrop")
    dialogEditBox:ClearAnchors()
    dialogEditBox:SetAnchorFill(dialogEditContainer)
    SetControlDrawOrder(dialogEditBox, DT_HIGH, DL_OVERLAY, 25)
    if dialogEditBox.SetMaxInputChars then
        dialogEditBox:SetMaxInputChars(128)
    end
    dialogEditBox:SetHandler("OnTextChanged", function(editBox)
        if editBox.ltmApplyingRenameLimit then
            return
        end

        local currentText = type(editBox.GetText) == "function" and editBox:GetText() or ""
        local clampedText = LTM_UI:TruncateTextToWeightedUnits(currentText)
        if clampedText ~= currentText and type(editBox.SetText) == "function" then
            editBox.ltmApplyingRenameLimit = true
            editBox:SetText(clampedText)
            if type(editBox.TakeFocus) == "function" then
                editBox:TakeFocus()
            end
            editBox.ltmApplyingRenameLimit = false
        end

        LTM_UI:RefreshRenameInputHint()
    end)
    self.dialogEditBox = dialogEditBox

    local dialogRenameHintLabel = WINDOW_MANAGER:CreateControl("$(parent)RenameHint", dialogPanel, CT_LABEL)
    dialogRenameHintLabel:SetFont("ZoFontGameSmall")
    dialogRenameHintLabel:SetColor(0.72, 0.76, 0.82, 1.0)
    if type(dialogRenameHintLabel.SetHorizontalAlignment) == "function" then
        dialogRenameHintLabel:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    end
    SetControlDrawOrder(dialogRenameHintLabel, DT_HIGH, DL_OVERLAY, 24)
    dialogRenameHintLabel:SetHidden(true)
    self.dialogRenameHintLabel = dialogRenameHintLabel

    local dialogButtonPanel = WINDOW_MANAGER:CreateControl("$(parent)ButtonPanel", dialogPanel, CT_CONTROL)
    dialogButtonPanel:SetHidden(true)
    if type(dialogButtonPanel.SetMouseEnabled) == "function" then
        dialogButtonPanel:SetMouseEnabled(true)
    end
    SetControlDrawOrder(dialogButtonPanel, DT_HIGH, DL_OVERLAY, 24)
    self.dialogButtonPanel = dialogButtonPanel

    local dialogOverwriteButtonPanel = WINDOW_MANAGER:CreateControl("$(parent)OverwriteButtonPanel", dialogPanel, CT_CONTROL)
    dialogOverwriteButtonPanel:SetHidden(true)
    if type(dialogOverwriteButtonPanel.SetMouseEnabled) == "function" then
        dialogOverwriteButtonPanel:SetMouseEnabled(true)
    end
    SetControlDrawOrder(dialogOverwriteButtonPanel, DT_HIGH, DL_OVERLAY, 24)
    self.dialogOverwriteButtonPanel = dialogOverwriteButtonPanel

    local dialogPageReorderPanel = WINDOW_MANAGER:CreateControl("$(parent)PageReorderPanel", dialogPanel, CT_CONTROL)
    dialogPageReorderPanel:SetHidden(true)
    if type(dialogPageReorderPanel.SetMouseEnabled) == "function" then
        dialogPageReorderPanel:SetMouseEnabled(true)
    end
    SetControlDrawOrder(dialogPageReorderPanel, DT_HIGH, DL_OVERLAY, 24)
    self.dialogPageReorderPanel = dialogPageReorderPanel

    local dialogPageReorderEmptyLabel = WINDOW_MANAGER:CreateControl("$(parent)Empty", dialogPageReorderPanel, CT_LABEL)
    dialogPageReorderEmptyLabel:ClearAnchors()
    dialogPageReorderEmptyLabel:SetAnchorFill(dialogPageReorderPanel)
    dialogPageReorderEmptyLabel:SetFont("ZoFontGame")
    dialogPageReorderEmptyLabel:SetColor(0.72, 0.76, 0.82, 1.0)
    if type(dialogPageReorderEmptyLabel.SetHorizontalAlignment) == "function" then
        dialogPageReorderEmptyLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    end
    if type(dialogPageReorderEmptyLabel.SetVerticalAlignment) == "function" then
        dialogPageReorderEmptyLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    end
    dialogPageReorderEmptyLabel:SetHidden(true)
    SetControlDrawOrder(dialogPageReorderEmptyLabel, DT_HIGH, DL_OVERLAY, 25)
    self.dialogPageReorderEmptyLabel = dialogPageReorderEmptyLabel

    local dialogPageReorderScrollContainer = WINDOW_MANAGER:CreateControlFromVirtual("$(parent)ScrollContainer", dialogPageReorderPanel, "ZO_ScrollContainer")
    dialogPageReorderScrollContainer:ClearAnchors()
    dialogPageReorderScrollContainer:SetAnchorFill(dialogPageReorderPanel)
    if type(ZO_Scroll_SetUseFadeGradient) == "function" then
        ZO_Scroll_SetUseFadeGradient(dialogPageReorderScrollContainer, false)
    end
    if type(ZO_Scroll_SetHideScrollbarOnDisable) == "function" then
        ZO_Scroll_SetHideScrollbarOnDisable(dialogPageReorderScrollContainer, true)
    end
    dialogPageReorderScrollContainer:SetHidden(true)
    SetControlDrawOrder(dialogPageReorderScrollContainer, DT_HIGH, DL_OVERLAY, 26)
    self.dialogPageReorderScrollContainer = dialogPageReorderScrollContainer
    self.dialogPageReorderScroll = dialogPageReorderScrollContainer:GetNamedChild("Scroll")
    SetControlDrawOrder(self.dialogPageReorderScroll, DT_HIGH, DL_OVERLAY, 26)
    self.dialogPageReorderScrollBar = dialogPageReorderScrollContainer:GetNamedChild("ScrollBar")
    SetControlDrawOrder(self.dialogPageReorderScrollBar, DT_HIGH, DL_OVERLAY, 27)
    if self.dialogPageReorderScrollBar and type(ZO_VerticalScrollbarBase_OnMouseExit) == "function" then
        ZO_VerticalScrollbarBase_OnMouseExit(self.dialogPageReorderScrollBar)
    end

    local dialogPageReorderScrollChild = dialogPageReorderScrollContainer:GetNamedChild("ScrollChild")
    SetControlDrawOrder(dialogPageReorderScrollChild, DT_HIGH, DL_OVERLAY, 27)
    if dialogPageReorderScrollChild and type(dialogPageReorderScrollChild.SetResizeToFitPadding) == "function" then
        dialogPageReorderScrollChild:SetResizeToFitPadding(0, UI_DIALOG_PAGE_REORDER_ROW_GAP)
    end
    if dialogPageReorderScrollChild then
        dialogPageReorderScrollChild:ClearAnchors()
        dialogPageReorderScrollChild:SetAnchor(TOPLEFT, dialogPageReorderScrollContainer, TOPLEFT, 0, 0)
        if self.dialogPageReorderScrollBar then
            dialogPageReorderScrollChild:SetAnchor(TOPRIGHT, self.dialogPageReorderScrollBar, TOPLEFT, -4, 0)
        else
            dialogPageReorderScrollChild:SetAnchor(TOPRIGHT, dialogPageReorderScrollContainer, TOPRIGHT, 0, 0)
        end
        dialogPageReorderScrollChild:SetHeight(UI_DIALOG_PAGE_REORDER_PANEL_HEIGHT)
    end
    self.dialogPageReorderScrollChild = dialogPageReorderScrollChild
    self.dialogPageReorderRows = {}
    self:PositionDialogSections(UI_DIALOG_BODY_CONFIRM_HEIGHT, false, false)
    self:CreateTransformSkillsDialogControls(dialogPanel)

    self.dialogOverwriteOptionButtons = {}
    local overwritePanelWidth = UI_DIALOG_WIDTH - (UI_DIALOG_OUTER_PADDING * 2)
    for index, option in ipairs(self:GetOverwriteDialogOptions()) do
        local overwriteType = option.id
        local optionButton = WINDOW_MANAGER:CreateControlFromVirtual(
            "$(parent)OverwriteOption" .. tostring(index),
            dialogOverwriteButtonPanel,
            "ZO_DefaultButton"
        )
        optionButton:SetText("")
        optionButton:SetHandler("OnClicked", function()
            local dialogContext = LTM_UI.currentDialogContext or {}
            LTM_UI:RunOverwrite(dialogContext.cardId, dialogContext.cardName, overwriteType)
        end)
        optionButton:ClearAnchors()
        local row = tonumber(option.row) or 1
        local column = tonumber(option.column) or 1
        local columnCount = math.max(1, tonumber(option.columnCount) or 1)
        local buttonWidth = (overwritePanelWidth - (UI_DIALOG_OVERWRITE_OPTION_GAP * (columnCount - 1))) / columnCount
        local offsetX = (column - 1) * (buttonWidth + UI_DIALOG_OVERWRITE_OPTION_GAP)
        local offsetY = (row - 1) * (UI_DIALOG_OVERWRITE_OPTION_HEIGHT + UI_DIALOG_OVERWRITE_OPTION_GAP)
        optionButton:SetAnchor(TOPLEFT, dialogOverwriteButtonPanel, TOPLEFT, offsetX, offsetY)
        optionButton:SetDimensions(buttonWidth, UI_DIALOG_OVERWRITE_OPTION_HEIGHT)
        optionButton:SetHidden(true)

        local optionLabel = WINDOW_MANAGER:CreateControl("$(parent)Text", optionButton, CT_LABEL)
        optionLabel:ClearAnchors()
        optionLabel:SetAnchor(TOPLEFT, optionButton, TOPLEFT, 8, 0)
        optionLabel:SetAnchor(BOTTOMRIGHT, optionButton, BOTTOMRIGHT, -8, 0)
        optionLabel:SetFont("ZoFontGameSmall")
        optionLabel:SetColor(0.94, 0.95, 0.98, 1.0)
        optionLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        optionLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        optionLabel:SetMouseEnabled(false)
        optionLabel:SetText(GetText(option.buttonTextKey))
        SetControlDrawOrder(optionLabel, DT_HIGH, DL_OVERLAY, 26)
        optionButton.label = optionLabel
        optionButton.textKey = option.buttonTextKey
        optionButton.overwriteType = option.id
        optionButton:SetHandler("OnMouseEnter", function(self)
            self.label:SetColor(1.0, 1.0, 1.0, 1.0)
            LTM_UI:RefreshOverwriteDialogBody(self.overwriteType)
        end)
        optionButton:SetHandler("OnMouseExit", function(self)
            self.label:SetColor(0.94, 0.95, 0.98, 1.0)
            LTM_UI:RefreshOverwriteDialogBody(nil)
        end)
        SetControlDrawOrder(optionButton, DT_HIGH, DL_OVERLAY, 25)
        self.dialogOverwriteOptionButtons[#self.dialogOverwriteOptionButtons + 1] = optionButton
    end

    local dialogConfirmButton = self:CreateDialogActionButton(dialogButtonPanel, "ConfirmButton", function()
        LTM_UI:ConfirmDialog()
    end)
    dialogConfirmButton:SetHidden(true)
    SetControlDrawOrder(dialogConfirmButton, DT_HIGH, DL_OVERLAY, 24)
    if dialogConfirmButton.background then
        SetControlDrawOrder(dialogConfirmButton.background, DT_HIGH, DL_OVERLAY, 24)
    end
    if dialogConfirmButton.label then
        SetControlDrawOrder(dialogConfirmButton.label, DT_HIGH, DL_OVERLAY, 25)
    end
    self.dialogConfirmButton = dialogConfirmButton

    local dialogCancelButton = self:CreateDialogActionButton(dialogButtonPanel, "CancelButton", function()
        LTM_UI:CancelDialog()
    end)
    dialogCancelButton:SetHidden(true)
    SetControlDrawOrder(dialogCancelButton, DT_HIGH, DL_OVERLAY, 24)
    if dialogCancelButton.background then
        SetControlDrawOrder(dialogCancelButton.background, DT_HIGH, DL_OVERLAY, 24)
    end
    if dialogCancelButton.label then
        SetControlDrawOrder(dialogCancelButton.label, DT_HIGH, DL_OVERLAY, 25)
    end
    self.dialogCancelButton = dialogCancelButton
    self:PositionDialogActionButtons(UI_DIALOG_BUTTON_WIDTH)

    self:ApplyMainTabVisibility()
end

function LTM_UI:Initialize()
    if self.initialized then
        return
    end

    self.initialized = true
    CreateMainWindow(self)
    self:RefreshHudLauncher()
    LTM_UI_DISPATCH:InitializeInventorySnapshotInvalidation()

    if type(EVENT_MANAGER) == "table" and type(EVENT_MANAGER.RegisterForEvent) == "function" then
        EVENT_MANAGER:RegisterForEvent("LTM_UI_ActionSlotUpdated", EVENT_ACTION_SLOT_UPDATED, function()
            if LTM_UI.window and not LTM_UI.window:IsHidden() and LTM_UI:IsArmoryStationTabActive() then
                LTM_UI:RefreshCurrentStatePanel(LTM_UI:GetRightPaneMode() == "current")
            end
        end)

        if self.currentEffectEventRegistered ~= true then
            EVENT_MANAGER:RegisterForEvent("LTM_UI_EffectChanged", EVENT_EFFECT_CHANGED, function(_, _, _, _, unitTag)
                if unitTag == "player" then
                    LTM_UI:ScheduleCurrentEffectRefresh()
                end
            end)
            EVENT_MANAGER:AddFilterForEvent(
                "LTM_UI_EffectChanged",
                EVENT_EFFECT_CHANGED,
                REGISTER_FILTER_UNIT_TAG,
                "player"
            )
            self.currentEffectEventRegistered = true
        end

        self:StartEquipmentFetchMonitor()
    end
end

function LTM_UI:ShowMainWindow()
    local wasHidden = self.window == nil or self.window:IsHidden()
    if not self.initialized then
        self:Initialize()
    end

    self:ApplyMainTabVisibility()
    if wasHidden and self:IsArmoryStationTabActive() then
        self:RefreshCardList(true)
    end
    if type(SCENE_MANAGER.ShowTopLevel) == "function" then
        SCENE_MANAGER:ShowTopLevel(self.window)
    else
        self.window:SetHidden(false)
    end
end

function LTM_UI:HideMainWindow()
    if not self.window then
        return
    end

    self.openActionMenuCardId = nil
    self.openPageActionMenu = false
    LTM_UI_QUICK_SETTINGS:HideQuickSlotSettingsMenu()
    self:CancelCurrentEffectRefreshDebounce()
    self:RefreshActionMenuDismissLayer()
    self:HideDialog()
    LTM_UI_DISPATCH:DestroyInventorySnapshot()

    if type(SCENE_MANAGER.HideTopLevel) == "function" then
        SCENE_MANAGER:HideTopLevel(self.window)
    else
        self.window:SetHidden(true)
    end
end

function LTM_UI:ToggleMainWindow()
    if not self.initialized then
        self:Initialize()
    end

    if self.window:IsHidden() then
        self:ShowMainWindow()
    else
        self:HideMainWindow()
    end
end
