-- -----------------------------------------------------------------------------
-- HUDitorTools - one nudge panel per HUD editor element
-- Shown under that element's selection box while it is selected.
-- The panel has a fixed size. resizeToFitDescendents on a backdrop that
-- fills its parent loops in the client and crashes when the panel is shown.
-- -----------------------------------------------------------------------------
local HT = HUDitorTools

local NUDGE_PANEL_DRAW_LEVEL = 6
local NUDGE_STEP = 1
local NUDGE_PANEL_GAP = 4
local NUDGE_PANEL_WIDTH = 302
local NUDGE_PANEL_HEIGHT = 82

local nudgePanelsInstalled = false

local NUDGE_OFFSETS =
{
    NudgeLeft = { -NUDGE_STEP, 0 },
    NudgeRight = { NUDGE_STEP, 0 },
    NudgeUp = { 0, -NUDGE_STEP },
    NudgeDown = { 0, NUDGE_STEP },
}

local function GetEditorElement(panel)
    local elementControl = panel:GetParent()
    return elementControl and elementControl.object
end

local function UpdateInfoBoxCoordinates(editorElement)
    local offsetX, offsetY = editorElement:GetRoundedOffsetsFromTopLeft()
    local editor = HUD_EDITOR_KEYBOARD
    if not editor.infoBoxXCoordsEditBox then
        return
    end
    editor.infoBoxXCoordsEditBox:SetText(tostring(offsetX))
    editor.infoBoxYCoordsEditBox:SetText(tostring(offsetY))
end

function HT.NudgeEditorElement(editorElement, offsetX, offsetY)
    if not editorElement or not editorElement.GetRoundedOffsetsFromTopLeft then
        return
    end
    local left, top = editorElement:GetRoundedOffsetsFromTopLeft()
    HT.nudgeSkipsGridSnap = true
    editorElement:SetPositionFromTopLeft(left + offsetX, top + offsetY)
    HT.nudgeSkipsGridSnap = false
    UpdateInfoBoxCoordinates(editorElement)
    HT.RefreshNudgePanel()
end

local function ResetEditorElementScale(editorElement)
    if not editorElement then
        return
    end
    local elementData = editorElement:GetElementData()
    if not elementData then
        return
    end
    local saveKey = elementData:GetSaveKey()
    local row = HT.GetAppearanceRow(saveKey) or {}
    HT.SetAppearanceRow(saveKey, {
        scale = 1,
        fontFace = row.fontFace,
        fontSize = row.fontSize,
        fontOutline = row.fontOutline,
    })
    HT.ApplyElementAppearance(elementData)
    editorElement:RefreshAnchors()
    HT.RefreshAppearanceInfoBox()
    if HT.RefreshLayoutInfoBoxSection then
        HT.RefreshLayoutInfoBoxSection()
    end
    HT.RefreshNudgePanel()
end

local function AnchorNudgePanelOnScreen(panel, elementControl)
    local elementLeft, elementTop, elementRight, elementBottom = elementControl:GetScreenRect()
    local panelWidth = panel:GetWidth()
    local panelHeight = panel:GetHeight()
    if panelWidth < 1 then
        panelWidth = NUDGE_PANEL_WIDTH
    end
    if panelHeight < 1 then
        panelHeight = NUDGE_PANEL_HEIGHT
    end
    local elementScale = elementControl:GetScale()
    if not elementScale or elementScale == 0 then
        elementScale = 1
    end
    local panelScreenWidth = panelWidth * elementScale
    local panelScreenHeight = panelHeight * elementScale
    local screenWidth = GuiRoot:GetWidth()
    local screenHeight = GuiRoot:GetHeight()
    local spaceBelow = screenHeight - elementBottom
    local spaceAbove = elementTop
    local neededHeight = panelScreenHeight + (NUDGE_PANEL_GAP * elementScale)
    local placeAbove = spaceBelow < neededHeight and spaceAbove > spaceBelow

    local elementCenterX = (elementLeft + elementRight) / 2
    local panelLeft = elementCenterX - (panelScreenWidth / 2)
    local panelRight = elementCenterX + (panelScreenWidth / 2)
    local screenShiftX = 0
    if panelLeft < 0 then
        screenShiftX = -panelLeft
    elseif panelRight > screenWidth then
        screenShiftX = screenWidth - panelRight
    end
    local offsetX = screenShiftX / elementScale

    panel:ClearAnchors()
    if placeAbove then
        panel:SetAnchor(BOTTOM, elementControl, TOP, offsetX, -NUDGE_PANEL_GAP)
    else
        panel:SetAnchor(TOP, elementControl, BOTTOM, offsetX, NUDGE_PANEL_GAP)
    end
end

local function HideNudgePanels()
    local editor = HUD_EDITOR_KEYBOARD
    if not editor.elementControls then
        return
    end
    for _, elementControl in ipairs(editor.elementControls) do
        local panel = elementControl.huditorToolsNudgePanel
        if panel then
            panel:SetHidden(true)
        end
    end
end

function HT.RefreshNudgePanel()
    local editor = HUD_EDITOR_KEYBOARD
    if not editor:IsShowing() or not editor.elementControls then
        HideNudgePanels()
        return
    end
    local selectedElement = editor:GetSelectedElement()
    local selectedControl = selectedElement and selectedElement:GetControl()
    for _, elementControl in ipairs(editor.elementControls) do
        local panel = elementControl.huditorToolsNudgePanel
        if panel then
            local isSelectedPanel = elementControl == selectedControl
            panel:SetHidden(not isSelectedPanel)
            if isSelectedPanel then
                AnchorNudgePanelOnScreen(panel, elementControl)
            end
        end
    end
end

local function CreateElementNudgePanel(elementControl)
    if elementControl.huditorToolsNudgePanel then
        return
    end
    local panel = CreateControlFromVirtual(elementControl:GetName() .. "NudgePanel", elementControl, "HUDitorTools_NudgePanel")
    elementControl.huditorToolsNudgePanel = panel
    panel:SetDrawLevel(NUDGE_PANEL_DRAW_LEVEL)
    panel:ClearAnchors()
    panel:SetAnchor(TOP, elementControl, BOTTOM, 0, 4)
    panel:SetHidden(true)

    panel:GetNamedChild("ResetPosition"):SetHandler("OnClicked", function ()
        local editorElement = GetEditorElement(panel)
        if not editorElement then
            return
        end
        editorElement:Select()
        HUD_EDITOR_KEYBOARD:ResetSelectedToDefault()
    end)
    panel:GetNamedChild("ResetScale"):SetHandler("OnClicked", function ()
        local editorElement = GetEditorElement(panel)
        if not editorElement then
            return
        end
        editorElement:Select()
        ResetEditorElementScale(editorElement)
    end)

    for buttonName, offset in pairs(NUDGE_OFFSETS) do
        local nudgeButton = panel:GetNamedChild(buttonName)
        local nudgeOffsetX = offset[1]
        local nudgeOffsetY = offset[2]
        nudgeButton:SetHandler("OnClicked", function ()
            HT.NudgeEditorElement(GetEditorElement(panel), nudgeOffsetX, nudgeOffsetY)
        end)
    end
end

function HT.InstallElementNudgePanels(editor)
    for _, elementControl in ipairs(editor.elementControls) do
        CreateElementNudgePanel(elementControl)
    end
    HT.RefreshNudgePanel()
end

function HT.InstallNudgePanel()
    if nudgePanelsInstalled then
        return
    end
    nudgePanelsInstalled = true
    SecurePostHook(ZO_HUDEditor_Keyboard, "PopulateElementControls", function (editor)
        HT.InstallElementNudgePanels(editor)
    end)
    ZO_PostHook(ZO_HUDEditor_Keyboard, "RefreshInfoBox", function ()
        HT.RefreshNudgePanel()
    end)
    SCENE_MANAGER:GetScene(HT.EDITOR_SCENE_NAME):RegisterCallback("StateChange", function (_, newState)
        if newState == SCENE_HIDING or newState == SCENE_HIDDEN then
            HideNudgePanels()
        end
    end)
end
