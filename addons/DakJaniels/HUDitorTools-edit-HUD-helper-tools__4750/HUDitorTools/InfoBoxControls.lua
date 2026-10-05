-- -----------------------------------------------------------------------------
-- HUDitorTools - GridSnap inject settings into the ZOS HUD Editor info box popup
-- Observed host: ZO_HUDEditor_Keyboard_TLInfoBox (hudeditor_keyboard.xml)
-- -----------------------------------------------------------------------------
local HT = HUDitorTools

local MIN_GRID_SIZE = 2
local MAX_GRID_SIZE = 100

local infoBoxSection

local HE_KB = HUD_EDITOR_KEYBOARD

local function ClampGridSize(value)
    value = zo_floor(tonumber(value) or HT.SV.gridSize)
    if value < MIN_GRID_SIZE then
        return MIN_GRID_SIZE
    end
    if value > MAX_GRID_SIZE then
        return MAX_GRID_SIZE
    end
    return value
end

local function GetInfoBox()
    return HE_KB.control:GetNamedChild("InfoBox")
end
HT.GetInfoBox = GetInfoBox

local function ApplyGridSizeFromEdit()
    local row = infoBoxSection:GetNamedChild("GridSizeRow")
    local editBox = row:GetNamedChild("Backdrop"):GetNamedChild("Edit")
    local size = ClampGridSize(editBox:GetText())
    HT.SV.gridSize = size
    editBox:SetText(tostring(size))
    HT.RefreshGridOverlay()
end

local function updateEnabledStateOfCheckbutton(checkButton, isEnabled)
    ZO_CheckButton_SetEnableState(checkButton, isEnabled)
end

local function RefreshInfoBoxControlState()
    local sv = HT.SV
    local snapCheck = infoBoxSection:GetNamedChild("SnapCheck")
    local showGridCheck = infoBoxSection:GetNamedChild("ShowGridCheck")
    local showColorPickerCheck = infoBoxSection:GetNamedChild("ShowColorPickerCheck")
    local editBox = infoBoxSection:GetNamedChild("GridSizeRow"):GetNamedChild("Backdrop"):GetNamedChild("Edit")

    ZO_CheckButton_SetCheckState(showGridCheck, sv.showGrid)
    ZO_CheckButton_SetCheckState(snapCheck, sv.gridSnap)
    updateEnabledStateOfCheckbutton(snapCheck, sv.showGrid)
    ZO_CheckButton_SetCheckState(showColorPickerCheck, sv.showColorPicker)
    editBox:SetText(tostring(sv.gridSize))
end

local function UpdateInfoBoxSectionAnchors(isContextMenuSettingsButtonActive)
    if not infoBoxSection then return end
    local infoBox = GetInfoBox()
    local coordinates = infoBox:GetNamedChild("Coordinates")
    local customOptions = infoBox:GetNamedChild("CustomOptions")

    infoBoxSection:ClearAnchors()
    if not isContextMenuSettingsButtonActive then
        infoBoxSection:SetAnchor(TOPLEFT, coordinates, BOTTOMLEFT, 0, 10)
        infoBoxSection:SetAnchor(TOPRIGHT, coordinates, BOTTOMRIGHT, 0, 10)
        customOptions:ClearAnchors()
        customOptions:SetAnchor(TOPLEFT, infoBoxSection, BOTTOMLEFT, 0, 10)
        customOptions:SetAnchor(TOPRIGHT, infoBoxSection, BOTTOMRIGHT, 0, 10)
    else
        infoBoxSection:SetHeight(0)
        customOptions:ClearAnchors()
        customOptions:SetAnchor(TOPLEFT, coordinates, BOTTOMLEFT, 0, 10)
        customOptions:SetAnchor(TOPRIGHT, coordinates, BOTTOMRIGHT, 0, 10)
    end
    infoBoxSection:SetMouseEnabled(not isContextMenuSettingsButtonActive)
end

local function CreateInfoBoxSection()
    local infoBox = GetInfoBox()
    local coordinates = infoBox:GetNamedChild("Coordinates")
    local customOptions = infoBox:GetNamedChild("CustomOptions")

    infoBoxSection = CreateControlFromVirtual(infoBox:GetName() .. "HUDitorToolsSection", infoBox, "HUDitorTools_InfoBoxSection")
    UpdateInfoBoxSectionAnchors(HT.SV.HUDEditorShowInfoBoxSettingsButton)


    local showGridCheck = infoBoxSection:GetNamedChild("ShowGridCheck")
    local snapCheck = infoBoxSection:GetNamedChild("SnapCheck")
    local showColorPickerCheck = infoBoxSection:GetNamedChild("ShowColorPickerCheck")
    local editBox = infoBoxSection:GetNamedChild("GridSizeRow"):GetNamedChild("Backdrop"):GetNamedChild("Edit")

    ZO_CheckButton_SetLabelText(showGridCheck, GetString(SI_HUDITORTOOLS_HUD_EDITOR_GRID_LAM))
    ZO_CheckButton_SetToggleFunction(showGridCheck, function (_, checked)
        HT.SV.showGrid = checked
        updateEnabledStateOfCheckbutton(snapCheck, checked)
        HT.RefreshGridOverlay()
    end)

    ZO_CheckButton_SetLabelText(snapCheck, GetString(SI_HUDITORTOOLS_HUD_EDITOR_GRID_SNAP_LAM))
    ZO_CheckButton_SetToggleFunction(snapCheck, function (_, checked)
        HT.SV.gridSnap = checked
    end)

    ZO_CheckButton_SetLabelText(showColorPickerCheck, GetString(SI_HUDITORTOOLS_CNTXT_SHOW_COLOR_PICKER))
    ZO_CheckButton_SetToggleFunction(showColorPickerCheck, function (_, checked)
        HT.SetColorPickerVisible(checked)
    end)

    editBox:SetHandler("OnFocusLost", ApplyGridSizeFromEdit)
    editBox:SetHandler("OnEnter", function ()
        editBox:LoseFocus()
        ApplyGridSizeFromEdit()
    end)

    RefreshInfoBoxControlState()
end

function HT.UpdateInfoBoxSectionVisibility()
    local infoBox = GetInfoBox()
    local HUDEditorShowInfoBoxSettingsButton = HT.SV.HUDEditorShowInfoBoxSettingsButton

    infoBoxSection:SetHidden(HUDEditorShowInfoBoxSettingsButton or infoBox:IsHidden())
    if not HUDEditorShowInfoBoxSettingsButton and not infoBox:IsHidden() then
        RefreshInfoBoxControlState()
    end
    UpdateInfoBoxSectionAnchors(HUDEditorShowInfoBoxSettingsButton)
end

function HT.InstallInfoBoxControls()
    CreateInfoBoxSection()
end

-- -----------------------------------------------------------------------------
-- Selected-element scale, font, and resource-bar group
-- -----------------------------------------------------------------------------

local appearanceSection
local fontComboBox
local outlineComboBox
local suppressAppearanceComboCallback = false

local function GetSelectedElementData()
    if not HE_KB or not HE_KB.GetSelectedElement then
        return nil
    end
    local selectedElement = HE_KB:GetSelectedElement()
    if not selectedElement or not selectedElement.GetElementData then
        return nil
    end
    return selectedElement:GetElementData()
end

local function GetScaleEdit()
    return appearanceSection:GetNamedChild("ScaleRow"):GetNamedChild("Backdrop"):GetNamedChild("Edit")
end

local function GetFontSizeEdit()
    return appearanceSection:GetNamedChild("FontSizeRow"):GetNamedChild("Backdrop"):GetNamedChild("Edit")
end

local function GetResourceWidthEdit()
    return appearanceSection:GetNamedChild("ResourceGroup"):GetNamedChild("WidthRow"):GetNamedChild("Backdrop"):GetNamedChild("Edit")
end

local function FillComboBox(comboBox, values, labels, selectedValue, onSelected)
    comboBox:ClearItems()
    local selectedEntry
    for index, value in ipairs(values) do
        local appearanceValue = value
        local label = labels[index]
        local entry = comboBox:CreateItemEntry(label, function ()
            if suppressAppearanceComboCallback then
                return
            end
            onSelected(appearanceValue)
        end)
        entry.appearanceValue = appearanceValue
        comboBox:AddItem(entry, ZO_COMBOBOX_SUPPRESS_UPDATE)
        if value == selectedValue then
            selectedEntry = entry
        end
    end
    comboBox:UpdateItems()
    suppressAppearanceComboCallback = true
    if selectedEntry then
        comboBox:SelectItem(selectedEntry, true)
    else
        comboBox:SelectFirstItem(true)
    end
    suppressAppearanceComboCallback = false
end

local function CurrentAppearanceRow(elementData)
    local row = HT.GetAppearanceRow(elementData:GetSaveKey()) or {}
    return {
        scale = tonumber(row.scale) or 1,
        fontFace = row.fontFace or "",
        fontSize = tonumber(row.fontSize) or HT.APPEARANCE_FONT_SIZE_DEFAULT,
        fontOutline = row.fontOutline or HT.GetDefaultFontOutline(),
    }
end

local function CommitAppearanceRow(elementData, row)
    HT.SetAppearanceRow(elementData:GetSaveKey(), row)
    HT.ApplyElementAppearance(elementData)
    local selectedElement = HE_KB:GetSelectedElement()
    if selectedElement and selectedElement.RefreshAnchors then
        selectedElement:RefreshAnchors()
    end
    if HT.RefreshLayoutInfoBoxSection then
        HT.RefreshLayoutInfoBoxSection()
    end
end

local function ApplyScaleFromEdit(elementData)
    local percent = tonumber(GetScaleEdit():GetText())
    if percent == nil or percent <= 0 then
        percent = 100
    end
    GetScaleEdit():SetText(tostring(percent))
    local row = CurrentAppearanceRow(elementData)
    row.scale = percent / 100
    CommitAppearanceRow(elementData, row)
end

local function ApplyFontSizeFromEdit(elementData)
    local fontSize = zo_floor(tonumber(GetFontSizeEdit():GetText()) or HT.APPEARANCE_FONT_SIZE_DEFAULT)
    if fontSize < 1 then
        fontSize = 1
    end
    GetFontSizeEdit():SetText(tostring(fontSize))
    local row = CurrentAppearanceRow(elementData)
    row.fontSize = fontSize
    CommitAppearanceRow(elementData, row)
end

local function ApplyResourceWidthFromEdit()
    local healthWidth = HT.SetResourceBarGroupHealthWidth(GetResourceWidthEdit():GetText())
    GetResourceWidthEdit():SetText(tostring(healthWidth))
end

local function UpdateOptionalAppearanceRows(fontFace)
    local fontSizeRow = appearanceSection:GetNamedChild("FontSizeRow")
    local outlineLabel = appearanceSection:GetNamedChild("OutlineLabel")
    local outlineCombo = appearanceSection:GetNamedChild("OutlineCombo")
    local resetButton = appearanceSection:GetNamedChild("Reset")
    local showFontSize = fontFace ~= ""
    local showOutline = showFontSize and LibMediaProvider ~= nil

    fontSizeRow:SetHidden(not showFontSize)
    fontSizeRow:SetExcludeFromResizeToFitExtents(not showFontSize)
    outlineLabel:SetHidden(not showOutline)
    outlineLabel:SetExcludeFromResizeToFitExtents(not showOutline)
    outlineCombo:SetHidden(not showOutline)
    outlineCombo:SetExcludeFromResizeToFitExtents(not showOutline)

    resetButton:ClearAnchors()
    if showOutline then
        resetButton:SetAnchor(TOPLEFT, outlineCombo, BOTTOMLEFT, 0, 10)
    elseif showFontSize then
        resetButton:SetAnchor(TOPLEFT, fontSizeRow, BOTTOMLEFT, 0, 10)
    else
        resetButton:SetAnchor(TOPLEFT, appearanceSection:GetNamedChild("FontCombo"), BOTTOMLEFT, 0, 10)
    end
end

local function UpdateResourceGroupBlock(saveKey)
    local resourceGroup = appearanceSection:GetNamedChild("ResourceGroup")
    local showResourceGroup = HT.IsPlayerResourceBarSaveKey(saveKey)
    local showPyramid = HT.IsPlayerAttributeFrameSaveKey(saveKey)
    resourceGroup:SetHidden(not showResourceGroup)
    resourceGroup:SetExcludeFromResizeToFitExtents(not showResourceGroup)
    local widthRow = resourceGroup:GetNamedChild("WidthRow")
    widthRow:SetHidden(true)
    widthRow:SetExcludeFromResizeToFitExtents(true)
    local enableCheck = resourceGroup:GetNamedChild("EnableCheck")
    local preventExpandCheck = resourceGroup:GetNamedChild("PreventExpandCheck")
    enableCheck:SetHidden(not showPyramid)
    enableCheck:SetExcludeFromResizeToFitExtents(not showPyramid)
    preventExpandCheck:ClearAnchors()
    if showPyramid then
        preventExpandCheck:SetAnchor(TOPLEFT, enableCheck, BOTTOMLEFT, 0, 6)
    else
        preventExpandCheck:SetAnchor(TOPLEFT, resourceGroup:GetNamedChild("Header"), BOTTOMLEFT, 0, 8)
    end
    if showResourceGroup then
        local settings = HT.SV and HT.SV.resourceBarGroup
        if type(settings) == "table" then
            ZO_CheckButton_SetCheckState(enableCheck, settings.enabled == true)
            ZO_CheckButton_SetCheckState(preventExpandCheck, settings.preventExpand == true)
        end
    end
end

function HT.RefreshAppearanceInfoBox()
    if not appearanceSection then
        return
    end
    local infoBox = GetInfoBox()
    local elementData = GetSelectedElementData()
    local showSection = elementData ~= nil and not infoBox:IsHidden()
    appearanceSection:SetHidden(not showSection)
    if not showSection then
        return
    end

    local row = CurrentAppearanceRow(elementData)
    GetScaleEdit():SetText(tostring(zo_round(row.scale * 100)))
    GetFontSizeEdit():SetText(tostring(row.fontSize))
    UpdateOptionalAppearanceRows(row.fontFace)

    local fontValues, fontLabels = HT.GetFontFaceChoices()
    local selectedFace = row.fontFace
    local faceFound = false
    for _, faceValue in ipairs(fontValues) do
        if faceValue == selectedFace then
            faceFound = true
            break
        end
    end
    if not faceFound and selectedFace ~= "" then
        fontValues[#fontValues + 1] = selectedFace
        fontLabels[#fontLabels + 1] = selectedFace
    end
    FillComboBox(fontComboBox, fontValues, fontLabels, selectedFace, function (fontFace)
        local currentElement = GetSelectedElementData()
        if not currentElement then
            return
        end
        local currentRow = CurrentAppearanceRow(currentElement)
        currentRow.fontFace = fontFace
        if fontFace ~= "" and (currentRow.fontOutline == nil or currentRow.fontOutline == "") then
            currentRow.fontOutline = HT.GetDefaultFontOutline()
        end
        CommitAppearanceRow(currentElement, currentRow)
        HT.RefreshAppearanceInfoBox()
    end)

    if LibMediaProvider then
        local outlineValues = {}
        local outlineLabels = {}
        for _, outlineName in ipairs(HT.APPEARANCE_FONT_OUTLINES) do
            outlineValues[#outlineValues + 1] = outlineName
            outlineLabels[#outlineLabels + 1] = outlineName
        end
        FillComboBox(outlineComboBox, outlineValues, outlineLabels, row.fontOutline, function (fontOutline)
            local currentElement = GetSelectedElementData()
            if not currentElement then
                return
            end
            local currentRow = CurrentAppearanceRow(currentElement)
            currentRow.fontOutline = fontOutline
            CommitAppearanceRow(currentElement, currentRow)
        end)
    end

    UpdateResourceGroupBlock(elementData:GetSaveKey())
end

local function CreateAppearanceSection()
    local infoBox = GetInfoBox()
    appearanceSection = CreateControlFromVirtual(infoBox:GetName() .. "HUDitorToolsAppearanceSection", infoBox, "HUDitorTools_AppearanceInfoBoxSection")
    local layoutSection = infoBox:GetNamedChild("HUDitorToolsLayoutSection")
    appearanceSection:ClearAnchors()
    if layoutSection then
        appearanceSection:SetAnchor(TOP, layoutSection, BOTTOM, 0, 16)
    else
        local globalDefaults = infoBox:GetNamedChild("GlobalDefaults")
        appearanceSection:SetAnchor(TOP, globalDefaults, BOTTOM, 0, 16)
    end

    fontComboBox = ZO_ComboBox_ObjectFromContainer(appearanceSection:GetNamedChild("FontCombo"))
    fontComboBox:SetSortsItems(false)
    outlineComboBox = ZO_ComboBox_ObjectFromContainer(appearanceSection:GetNamedChild("OutlineCombo"))
    outlineComboBox:SetSortsItems(false)

    local scaleEdit = GetScaleEdit()
    scaleEdit:SetHandler("OnFocusLost", function ()
        local elementData = GetSelectedElementData()
        if elementData then
            ApplyScaleFromEdit(elementData)
        end
    end)
    scaleEdit:SetHandler("OnEnter", function ()
        scaleEdit:LoseFocus()
    end)

    local fontSizeEdit = GetFontSizeEdit()
    fontSizeEdit:SetHandler("OnFocusLost", function ()
        local elementData = GetSelectedElementData()
        if elementData then
            ApplyFontSizeFromEdit(elementData)
        end
    end)
    fontSizeEdit:SetHandler("OnEnter", function ()
        fontSizeEdit:LoseFocus()
    end)

    appearanceSection:GetNamedChild("Reset"):SetHandler("OnClicked", function ()
        local elementData = GetSelectedElementData()
        if not elementData then
            return
        end
        HT.SetAppearanceRow(elementData:GetSaveKey(), nil)
        HT.ApplyElementAppearance(elementData)
        local selectedElement = HE_KB:GetSelectedElement()
        if selectedElement and selectedElement.RefreshAnchors then
            selectedElement:RefreshAnchors()
        end
        HT.RefreshAppearanceInfoBox()
        if HT.RefreshLayoutInfoBoxSection then
            HT.RefreshLayoutInfoBoxSection()
        end
    end)

    local resourceGroup = appearanceSection:GetNamedChild("ResourceGroup")
    local enableCheck = resourceGroup:GetNamedChild("EnableCheck")
    ZO_CheckButton_SetLabelText(enableCheck, GetString(SI_HUDITORTOOLS_RESOURCE_GROUP_ENABLE))
    ZO_CheckButton_SetToggleFunction(enableCheck, function (_, checked)
        HT.SetResourceBarGroupEnabled(checked)
    end)

    local preventExpandCheck = resourceGroup:GetNamedChild("PreventExpandCheck")
    ZO_CheckButton_SetLabelText(preventExpandCheck, GetString(SI_HUDITORTOOLS_RESOURCE_PREVENT_EXPAND))
    ZO_CheckButton_SetToggleFunction(preventExpandCheck, function (_, checked)
        HT.SetResourceBarPreventExpand(checked)
    end)

    local widthEdit = GetResourceWidthEdit()
    widthEdit:SetHandler("OnFocusLost", ApplyResourceWidthFromEdit)
    widthEdit:SetHandler("OnEnter", function ()
        widthEdit:LoseFocus()
    end)
end

function HT.InstallAppearanceInfoBoxSection()
    CreateAppearanceSection()
    ZO_PostHook(ZO_HUDEditor_Keyboard, "RefreshInfoBox", function ()
        HT.RefreshAppearanceInfoBox()
    end)
end
