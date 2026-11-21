-- Ref: docs/adr/0003-integracion-nativa-ui-diario-mapa-y-hud.md
-- Ref: docs/adr/0004-objetivos-multiples-inferidos-por-reticula.md
-- Ref: docs/adr/0005-separacion-misiones-preparacion-y-juego.md
-- Ref: docs/adr/0006-puntos-de-descubrimiento-ocultos.md
-- Ref: docs/adr/0007-dialogos-inyectados-en-npcs-nativos.md

RPQuest = RPQuest or {}
local Addon = RPQuest

Addon.JournalTab = {}
local JournalTab = Addon.JournalTab

local PANEL_NAME = "RPQuest_JournalPanel"
local MAX_VISIBLE_ROWS = 15

local VIEW_MODE = {
    DETAIL = "DETAIL",
    EDITOR = "EDITOR",
    IMPORT = "IMPORT",
}

local function CreateStyledButton(name, parent, width, height, text, onClick)
    local btn = WINDOW_MANAGER:CreateControl(name, parent, CT_BUTTON)
    btn:SetDimensions(width, height)
    btn:SetMouseEnabled(true)
    btn:SetFont("ZoFontGameBold")
    btn:SetNormalFontColor(0.91, 0.83, 0.63, 1)
    btn:SetMouseOverFontColor(1, 1, 1, 1)

    local bg = WINDOW_MANAGER:CreateControl(name .. "_Bg", btn, CT_BACKDROP)
    bg:SetDimensions(width, height)
    bg:SetAnchor(TOPLEFT, btn, TOPLEFT, 0, 0)
    bg:SetCenterColor(0.08, 0.08, 0.08, 0.78)
    bg:SetEdgeColor(0.65, 0.56, 0.34, 0.85)
    btn._bg = bg

    btn:SetText(text or "")
    btn:SetHandler("OnClicked", function()
        if PlaySound and SOUNDS and SOUNDS.DEFAULT_CLICK then
            PlaySound(SOUNDS.DEFAULT_CLICK)
        end
        if onClick then onClick() end
    end)
    return btn
end

local function SetReadOnlyEditText(edit, text)
    if not edit then return end
    local value = text or ""
    edit._readOnlyValue = value
    edit._readOnlySyncing = true
    edit:SetText(value)
    edit._readOnlySyncing = false
end

local function CreateEditBoxWithBackdrop(name, parent, width, height, maxChars, isMultiLine, onTextChanged, selectAllOnFocus, isReadOnly)
    local bg = WINDOW_MANAGER:CreateControl(name .. "_Bg", parent, CT_BACKDROP)
    bg:SetDimensions(width, height)
    bg:SetMouseEnabled(true)
    bg:SetCenterColor(0.04, 0.04, 0.04, 0.82)
    bg:SetEdgeColor(0.68, 0.58, 0.36, 0.80)

    local edit = WINDOW_MANAGER:CreateControl(name, bg, CT_EDITBOX)
    edit:SetDimensions(width - 12, height - 8)
    edit:SetAnchor(TOPLEFT, bg, TOPLEFT, 6, 4)
    edit:SetMouseEnabled(true)
    edit:SetEditEnabled(true)
    edit:SetFont("ZoFontGame")
    edit:SetColor(1, 1, 1, 1)
    edit:SetMaxInputChars(maxChars or 256)
    edit:SetMultiLine(isMultiLine)
    edit:SetNewLineEnabled(isMultiLine)
    if selectAllOnFocus and edit.SetSelectAllOnFocus then
        edit:SetSelectAllOnFocus(true)
    end
    edit._isReadOnly = isReadOnly and true or false
    edit._readOnlyValue = ""
    edit:SetText("")

    local function FocusEditBox()
        edit:SetEditEnabled(true)
        edit:TakeFocus()
    end

    bg:SetHandler("OnMouseDown", FocusEditBox)
    edit:SetHandler("OnMouseDown", FocusEditBox)
    edit:SetHandler("OnEscape", function(ctrl)
        ctrl:LoseFocus()
    end)
    if not isMultiLine then
        edit:SetHandler("OnEnter", function(ctrl)
            ctrl:LoseFocus()
        end)
    end
    edit:SetHandler("OnFocusGained", function()
        edit._focused = true
        bg:SetEdgeColor(0.95, 0.85, 0.50, 1.0)
        if selectAllOnFocus and edit.SelectAll then
            edit:SelectAll()
        end
        if PlaySound and SOUNDS and SOUNDS.EDIT_CLICK then
            PlaySound(SOUNDS.EDIT_CLICK)
        end
    end)
    edit:SetHandler("OnFocusLost", function()
        edit._focused = false
        bg:SetEdgeColor(0.68, 0.58, 0.36, 0.80)
    end)
    if isReadOnly then
        edit:SetHandler("OnTextChanged", function(ctrl)
            if ctrl._readOnlySyncing then return end
            local expected = ctrl._readOnlyValue or ""
            if ctrl:GetText() ~= expected then
                ctrl._readOnlySyncing = true
                ctrl:SetText(expected)
                if selectAllOnFocus and ctrl.SelectAll then
                    ctrl:SelectAll()
                end
                ctrl._readOnlySyncing = false
            end
        end)
    elseif onTextChanged then
        edit:SetHandler("OnTextChanged", function(ctrl)
            onTextChanged(ctrl:GetText())
        end)
    end

    return bg, edit
end

function JournalTab:Initialize()
    if self.isInitialized or not WINDOW_MANAGER or not GuiRoot then
        return
    end

    self.viewMode = VIEW_MODE.DETAIL
    self.collapsedSections = {
        missions = false,
        completed = true,
        preparing = true,
    }
    self.editorSectionsCollapsed = {
        target = true,
        discovery = true,
        dialogue = true,
        options = true,
    }
    self.selectedQuestId = nil
    self.listOffset = 0

    local panel = WINDOW_MANAGER:CreateControl(PANEL_NAME, GuiRoot, CT_TOPLEVELCONTROL)
    panel:SetDimensions(980, 680)
    if ZO_QuestJournal then
        panel:SetAnchor(TOPLEFT, ZO_QuestJournal, TOPLEFT, 0, 0)
        panel:SetAnchor(BOTTOMRIGHT, ZO_QuestJournal, BOTTOMRIGHT, 0, 0)
    else
        panel:SetAnchor(TOPRIGHT, GuiRoot, TOPRIGHT, -30, 95)
    end
    panel:SetHidden(true)
    self.panel = panel

    self:BuildLeftColumn(panel)
    self:BuildRightColumn(panel)

    -- Use ZO_SimpleSceneFragment instead of ZO_FadeSceneFragment so ESO does not create
    -- per-instance animation OnStop closures in untrusted addon context (which taints
    -- transitions to protected scenes such as TamrielTomesSceneKeyboard).
    if ZO_SimpleSceneFragment then
        self.fragment = ZO_SimpleSceneFragment:New(panel)
    end

    self:IntegrateIntoQuestJournalModeBar()

    Addon.QuestRepository:RegisterListener(function(eventType, quest)
        if eventType == "QUEST_CREATED" or eventType == "QUEST_UPDATED" then
            if quest and quest.id then
                if quest.role == Addon.Constants.QUEST_ROLE.PREPARED then
                    self.collapsedSections.preparing = false
                elseif quest.completed then
                    self.collapsedSections.completed = false
                else
                    self.collapsedSections.missions = false
                end
                self.listOffset = 0
                self.selectedQuestId = quest.id
            end
            self.viewMode = VIEW_MODE.DETAIL
        elseif eventType == "QUEST_IMPORTED" then
            if quest and quest.id then
                self.collapsedSections.missions = false
                self.listOffset = 0
                self.selectedQuestId = quest.id
            end
            self.viewMode = VIEW_MODE.DETAIL
        elseif eventType == "QUEST_DELETED" then
            if quest and self.selectedQuestId == quest.id then
                self.selectedQuestId = nil
            end
            SetReadOnlyEditText(self.shareEdit, "")
            SetReadOnlyEditText(self.deliveryEdit, "")
            if self.validateEdit then self.validateEdit:SetText("") end
            if self.validateResultLabel then self.validateResultLabel:SetText("") end
        elseif eventType == "DRAFT_TARGET_CAPTURED" then
            if self.viewMode ~= VIEW_MODE.EDITOR then
                self.viewMode = VIEW_MODE.EDITOR
            end
        elseif eventType == "DRAFT_UPDATED" or eventType == "LAST_NPC_UPDATED" then
            if self.viewMode == VIEW_MODE.EDITOR and not self.panel:IsHidden() then
                self:RefreshEditorPane()
            else
                self._dirty = true
            end
            return
        end
        if self.panel:IsHidden() then
            self._dirty = true
        else
            self:Refresh()
        end
    end)

    self.isInitialized = true
    self._dirty = true
end

function JournalTab:BuildLeftColumn(panel)
    local leftCol = WINDOW_MANAGER:CreateControl(PANEL_NAME .. "_LeftCol", panel, CT_CONTROL)
    leftCol:SetDimensions(335, 620)
    leftCol:SetAnchor(TOPLEFT, panel, TOPLEFT, 5, 7)
    leftCol:SetMouseEnabled(true)
    leftCol:SetHandler("OnMouseWheel", function(_, delta)
        self:ScrollQuestList(-delta)
    end)
    self.leftCol = leftCol

    self.importBtn = CreateStyledButton(
        PANEL_NAME .. "_ImportBtn",
        leftCol,
        165,
        28,
        Addon.Locale:Get("BTN_IMPORT_CODE"),
        function()
            self:OpenImportView()
        end
    )
    self.importBtn:SetAnchor(TOPLEFT, leftCol, TOPLEFT, 4, 4)

    self.newBtn = CreateStyledButton(
        PANEL_NAME .. "_NewBtn",
        leftCol,
        125,
        28,
        Addon.Locale:Get("BTN_NEW_QUEST"),
        function()
            self:OpenCreateEditor()
        end
    )
    self.newBtn:SetAnchor(TOPLEFT, leftCol, TOPLEFT, 179, 4)

    local emptyLabel = WINDOW_MANAGER:CreateControl(PANEL_NAME .. "_EmptyList", leftCol, CT_LABEL)
    emptyLabel:SetDimensions(310, 80)
    emptyLabel:SetAnchor(TOPLEFT, leftCol, TOPLEFT, 4, 44)
    if emptyLabel.SetFont then emptyLabel:SetFont("ZoFontGame") end
    if emptyLabel.SetColor then emptyLabel:SetColor(0.75, 0.75, 0.75, 1) end
    emptyLabel:SetHidden(true)
    self.emptyLabel = emptyLabel

    self.rowControls = {}
    self.rowBindings = {}

    for i = 1, MAX_VISIBLE_ROWS do
        local rowBtn = WINDOW_MANAGER:CreateControl(PANEL_NAME .. "_Row" .. i, leftCol, CT_BUTTON)
        rowBtn:SetDimensions(320, 28)
        rowBtn:SetAnchor(TOPLEFT, leftCol, TOPLEFT, 0, 42 + ((i - 1) * 30))
        if rowBtn.SetFont then rowBtn:SetFont("ZoFontHeader") end
        if rowBtn.SetHorizontalAlignment and TEXT_ALIGN_LEFT then
            rowBtn:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
        end
        if rowBtn.SetVerticalAlignment and TEXT_ALIGN_CENTER then
            rowBtn:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        end
        local rowIndex = i
        rowBtn:SetHandler("OnClicked", function()
            local binding = self.rowBindings[rowIndex]
            if not binding then return end
            if binding.isHeader and binding.sectionKey then
                if PlaySound and SOUNDS and SOUNDS.DEFAULT_CLICK then
                    PlaySound(SOUNDS.DEFAULT_CLICK)
                end
                self:ToggleSection(binding.sectionKey)
            elseif binding.questId then
                if PlaySound and SOUNDS and SOUNDS.DEFAULT_CLICK then
                    PlaySound(SOUNDS.DEFAULT_CLICK)
                end
                self:SelectQuest(binding.questId)
            end
        end)
        rowBtn:SetHidden(true)
        self.rowControls[i] = rowBtn
    end

    self.btnListPrev = CreateStyledButton(PANEL_NAME .. "_ListPrevBtn", leftCol, 60, 26, "<", function()
        self:ScrollQuestList(-1)
    end)
    self.btnListPrev:SetAnchor(TOPLEFT, leftCol, TOPLEFT, 0, 554)
    self.btnListPrev:SetHidden(true)

    local scrollInfoLabel = WINDOW_MANAGER:CreateControl(PANEL_NAME .. "_ListScrollInfo", leftCol, CT_LABEL)
    scrollInfoLabel:SetDimensions(180, 26)
    scrollInfoLabel:SetAnchor(TOPLEFT, leftCol, TOPLEFT, 66, 558)
    if scrollInfoLabel.SetFont then scrollInfoLabel:SetFont("ZoFontGame") end
    if scrollInfoLabel.SetColor then scrollInfoLabel:SetColor(0.82, 0.82, 0.82, 1) end
    scrollInfoLabel:SetHidden(true)
    self.scrollInfoLabel = scrollInfoLabel

    self.btnListNext = CreateStyledButton(PANEL_NAME .. "_ListNextBtn", leftCol, 60, 26, ">", function()
        self:ScrollQuestList(1)
    end)
    self.btnListNext:SetAnchor(TOPLEFT, leftCol, TOPLEFT, 250, 554)
    self.btnListNext:SetHidden(true)
end

function JournalTab:ScrollQuestList(step)
    local delta = tonumber(step) or 0
    if delta == 0 then return end
    local prevOffset = self.listOffset or 0
    local maxOffset = self._maxListOffset or 0
    local nextOffset = math.min(math.max(0, prevOffset + delta), maxOffset)
    if nextOffset == prevOffset then return end
    self.listOffset = nextOffset
    self:RefreshQuestList()
end

function JournalTab:BuildRightColumn(panel)
    local rightCol = WINDOW_MANAGER:CreateControl(PANEL_NAME .. "_RightCol", panel, CT_CONTROL)
    rightCol:SetDimensions(550, 600)
    rightCol:SetAnchor(TOPRIGHT, panel, TOPRIGHT, -33, 60)
    rightCol:SetAnchor(BOTTOMRIGHT, panel, BOTTOMRIGHT, -33, -25)
    self.rightCol = rightCol

    self:BuildDetailPane(rightCol)
    self:BuildEditorPane(rightCol)
    self:BuildImportPane(rightCol)
end

function JournalTab:BuildDetailPane(parent)
    local pane = WINDOW_MANAGER:CreateControl(PANEL_NAME .. "_DetailPane", parent, CT_CONTROL)
    pane:SetDimensions(550, 600)
    pane:SetAnchor(TOPLEFT, parent, TOPLEFT, 0, 0)
    pane:SetAnchor(BOTTOMRIGHT, parent, BOTTOMRIGHT, 0, 0)
    self.detailPane = pane

    local scrollContainer = WINDOW_MANAGER.CreateControlFromVirtual
        and WINDOW_MANAGER:CreateControlFromVirtual(PANEL_NAME .. "_DetailScroll", pane, "ZO_ScrollContainer")
        or nil
    local contentParent = pane
    if scrollContainer then
        scrollContainer:SetDimensions(550, 565)
        scrollContainer:SetAnchor(TOPLEFT, pane, TOPLEFT, 0, 0)
        scrollContainer:SetAnchor(BOTTOMRIGHT, pane, BOTTOMRIGHT, 0, -5)
        local scrollChild = scrollContainer.GetNamedChild and scrollContainer:GetNamedChild("ScrollChild")
        if scrollChild then
            scrollChild:SetDimensions(526, 650)
            contentParent = scrollChild
            self.detailScrollChild = scrollChild
        end
        self.detailScroll = scrollContainer
    end

    local titleLabel = WINDOW_MANAGER:CreateControl(PANEL_NAME .. "_DetailTitle", contentParent, CT_LABEL)
    titleLabel:SetDimensions(500, 34)
    titleLabel:SetAnchor(TOPLEFT, contentParent, TOPLEFT, 0, 0)
    if titleLabel.SetFont then titleLabel:SetFont("ZoFontWinH2") end
    if titleLabel.SetColor then titleLabel:SetColor(1, 1, 1, 1) end
    if titleLabel.SetModifyTextType and TEXT_MODIFY_TYPE_UPPERCASE then
        titleLabel:SetModifyTextType(TEXT_MODIFY_TYPE_UPPERCASE)
    end
    self.detailTitle = titleLabel

    local statusLabel = WINDOW_MANAGER:CreateControl(PANEL_NAME .. "_DetailStatus", contentParent, CT_LABEL)
    statusLabel:SetDimensions(500, 22)
    statusLabel:SetAnchor(TOPLEFT, titleLabel, BOTTOMLEFT, 0, 5)
    if statusLabel.SetFont then statusLabel:SetFont("ZoFontWinH4") end
    self.detailStatus = statusLabel

    local locLabel = WINDOW_MANAGER:CreateControl(PANEL_NAME .. "_DetailLoc", contentParent, CT_LABEL)
    locLabel:SetDimensions(500, 22)
    locLabel:SetAnchor(TOPLEFT, statusLabel, BOTTOMLEFT, 0, 2)
    if locLabel.SetFont then locLabel:SetFont("ZoFontWinH4") end
    if locLabel.SetColor then locLabel:SetColor(0.77, 0.76, 0.62, 1) end
    self.detailLocation = locLabel

    local descBody = WINDOW_MANAGER:CreateControl(PANEL_NAME .. "_DetailDescBody", contentParent, CT_LABEL)
    descBody:SetDimensions(495, 104)
    descBody:SetAnchor(TOPLEFT, titleLabel, BOTTOMLEFT, 25, 54)
    if descBody.SetFont then descBody:SetFont("ZoFontWinH4") end
    if descBody.SetColor then descBody:SetColor(0.77, 0.76, 0.62, 1) end
    if descBody.SetMaxLineCount then descBody:SetMaxLineCount(5) end
    self.detailDescBody = descBody

    local divider = WINDOW_MANAGER:CreateControl(PANEL_NAME .. "_DetailDivider", contentParent, CT_TEXTURE)
    divider:SetDimensions(512, 4)
    divider:SetAnchor(TOPLEFT, contentParent, TOPLEFT, 0, 210)
    divider:SetTexture(Addon.Constants.UI.DIVIDER_TEXTURE)

    local objHeader = WINDOW_MANAGER:CreateControl(PANEL_NAME .. "_DetailObjHeader", contentParent, CT_LABEL)
    objHeader:SetDimensions(500, 24)
    objHeader:SetAnchor(TOPLEFT, divider, BOTTOMLEFT, 0, 10)
    if objHeader.SetFont then objHeader:SetFont("ZoFontWinH3") end
    if objHeader.SetColor then objHeader:SetColor(1, 1, 1, 1) end
    if objHeader.SetModifyTextType and TEXT_MODIFY_TYPE_UPPERCASE then
        objHeader:SetModifyTextType(TEXT_MODIFY_TYPE_UPPERCASE)
    end
    objHeader:SetText(Addon.Locale:Get("LABEL_OBJECTIVE_HEADER"))
    self.detailObjHeader = objHeader

    local objText = WINDOW_MANAGER:CreateControl(PANEL_NAME .. "_DetailObjText", contentParent, CT_LABEL)
    objText:SetDimensions(495, 48)
    objText:SetAnchor(TOPLEFT, objHeader, BOTTOMLEFT, 25, 10)
    if objText.SetFont then objText:SetFont("ZoFontWinH4") end
    if objText.SetColor then objText:SetColor(1, 1, 1, 1) end
    self.detailObjText = objText

    -- Grupo 1: Botones de acción de la misión
    self.btnActivate = CreateStyledButton(PANEL_NAME .. "_BtnActivate", contentParent, 160, 32, "", function()
        self:OnToggleActiveClicked()
    end)
    self.btnActivate:SetAnchor(TOPLEFT, objText, BOTTOMLEFT, -25, 16)

    self.btnEdit = CreateStyledButton(PANEL_NAME .. "_BtnEdit", contentParent, 160, 32, Addon.Locale:Get("BTN_EDIT"), function()
        self:OpenEditEditor(self.selectedQuestId)
    end)
    self.btnEdit:SetAnchor(TOPLEFT, self.btnActivate, TOPRIGHT, 12, 0)

    self.btnReset = CreateStyledButton(PANEL_NAME .. "_BtnReset", contentParent, 160, 32, Addon.Locale:Get("BTN_RESET"), function()
        if self.selectedQuestId and Addon.QuestRepository:ResetQuest(self.selectedQuestId) then
            Addon.Announcements:ShowAlert(Addon.Locale:Get("ALERT_QUEST_RESET"), false)
        end
    end)
    self.btnReset:SetAnchor(TOPLEFT, self.btnActivate, BOTTOMLEFT, 0, 10)

    if ESO_Dialogs and not ESO_Dialogs["RPQUEST_ABANDON_QUEST"] then
        ESO_Dialogs["RPQUEST_ABANDON_QUEST"] = {
            title = {
                text = SI_PROMPT_TITLE_ABANDON_QUEST,
            },
            mainText = {
                text = SI_CONFIRM_ABANDON_QUEST,
            },
            buttons = {
                {
                    text = SI_ABANDON_QUEST_CONFIRM,
                    callback = function(dialog)
                        local qId = dialog and dialog.data and dialog.data.questId
                        if qId and Addon.QuestRepository:DeleteQuest(qId) then
                            Addon.Announcements:ShowAlert(Addon.Locale:Get("ALERT_QUEST_DELETED"), false)
                        end
                    end,
                },
                {
                    text = SI_DIALOG_CANCEL,
                },
            },
        }
    end

    self.abandonQuestDescriptor = {
        name = (GetString and SI_QUEST_JOURNAL_ABANDON) and GetString(SI_QUEST_JOURNAL_ABANDON) or Addon.Locale:Get("BTN_DELETE"),
        keybind = "UI_SHORTCUT_NEGATIVE",
        callback = function()
            if self.selectedQuestId then
                self:ConfirmAbandonQuest(self.selectedQuestId)
            end
        end,
        visible = function()
            return self.viewMode == VIEW_MODE.DETAIL and self.selectedQuestId ~= nil
        end,
    }

    -- Keybind nativo [M] Show On Map (igual al Quest Journal vanilla)
    self.showOnMapDescriptor = {
        name = (GetString and SI_QUEST_JOURNAL_SHOW_ON_MAP) and GetString(SI_QUEST_JOURNAL_SHOW_ON_MAP) or Addon.Locale:Get("BTN_SHOW_ON_MAP"),
        keybind = "UI_SHORTCUT_SHOW_QUEST_ON_MAP",
        ethereal = true,
        callback = function()
            local q = Addon.QuestRepository:GetQuestById(self.selectedQuestId)
            if q then
                Addon.WorldMapArea:ShowQuestOnMap(q)
            end
        end,
        visible = function()
            return self.viewMode == VIEW_MODE.DETAIL and self.selectedQuestId ~= nil
        end,
    }
    self.keybindStripDescriptor = {
        alignment = KEYBIND_STRIP_ALIGN_CENTER or 1,
        self.abandonQuestDescriptor,
        self.showOnMapDescriptor,
    }

    local showOnMapBtn = WINDOW_MANAGER.CreateControlFromVirtual
        and WINDOW_MANAGER:CreateControlFromVirtual(PANEL_NAME .. "_ShowOnMap", pane, "ZO_KeybindButton")
        or WINDOW_MANAGER:CreateControl(PANEL_NAME .. "_ShowOnMap", pane, CT_CONTROL)
    if ApplyTemplateToControl then
        ApplyTemplateToControl(showOnMapBtn, "ZO_KeybindButton_Keyboard_Template")
    end
    if showOnMapBtn.SetKeybindButtonDescriptor then
        showOnMapBtn:SetKeybindButtonDescriptor(self.showOnMapDescriptor)
    end
    showOnMapBtn:SetAnchor(TOPLEFT, pane, BOTTOMLEFT, 0, 0)
    self.showOnMapKeybindButton = showOnMapBtn

    -- Separador horizontal entre botones de misión y sección de códigos
    local codeDivider = WINDOW_MANAGER:CreateControl(PANEL_NAME .. "_CodeDivider", contentParent, CT_TEXTURE)
    codeDivider:SetDimensions(512, 4)
    codeDivider:SetAnchor(TOPLEFT, self.btnActivate, BOTTOMLEFT, 0, 48)
    codeDivider:SetTexture(Addon.Constants.UI.DIVIDER_TEXTURE)
    self.codeDivider = codeDivider

    -- Grupo 2: Código para compartir siempre visible y sección de entrega/validación
    local shareHeader = WINDOW_MANAGER:CreateControl(PANEL_NAME .. "_ShareHeader", contentParent, CT_LABEL)
    shareHeader:SetDimensions(520, 20)
    shareHeader:SetAnchor(TOPLEFT, codeDivider, BOTTOMLEFT, 0, 8)
    if shareHeader.SetFont then shareHeader:SetFont("ZoFontGameBold") end
    if shareHeader.SetColor then shareHeader:SetColor(0.91, 0.83, 0.63, 1) end
    shareHeader:SetText(Addon.Locale:Get("LABEL_SHARE_CODE_HEADER"))
    self.shareHeader = shareHeader

    local shareBg, shareEdit = CreateEditBoxWithBackdrop(PANEL_NAME .. "_ShareEdit", contentParent, 510, 32, 4096, false, nil, true, true)
    shareBg:SetAnchor(TOPLEFT, shareHeader, BOTTOMLEFT, 0, 2)
    self.shareBg = shareBg
    self.shareEdit = shareEdit

    local deliveryHeader = WINDOW_MANAGER:CreateControl(PANEL_NAME .. "_DeliveryHeader", contentParent, CT_LABEL)
    deliveryHeader:SetDimensions(520, 20)
    deliveryHeader:SetAnchor(TOPLEFT, shareBg, BOTTOMLEFT, 0, 8)
    if deliveryHeader.SetFont then deliveryHeader:SetFont("ZoFontGameBold") end
    if deliveryHeader.SetColor then deliveryHeader:SetColor(0.91, 0.83, 0.63, 1) end
    deliveryHeader:SetText(Addon.Locale:Get("LABEL_COMPLETION_CODE_HEADER"))
    deliveryHeader:SetHidden(true)
    self.deliveryHeader = deliveryHeader

    local deliveryBg, deliveryEdit = CreateEditBoxWithBackdrop(PANEL_NAME .. "_DeliveryEdit", contentParent, 510, 32, 4096, false, nil, true, true)
    deliveryBg:SetAnchor(TOPLEFT, deliveryHeader, BOTTOMLEFT, 0, 2)
    deliveryBg:SetHidden(true)
    self.deliveryBg = deliveryBg
    self.deliveryEdit = deliveryEdit

    local validateHeader = WINDOW_MANAGER:CreateControl(PANEL_NAME .. "_ValidateHeader", contentParent, CT_LABEL)
    validateHeader:SetDimensions(520, 20)
    validateHeader:SetAnchor(TOPLEFT, shareBg, BOTTOMLEFT, 0, 8)
    if validateHeader.SetFont then validateHeader:SetFont("ZoFontGameBold") end
    if validateHeader.SetColor then validateHeader:SetColor(0.91, 0.83, 0.63, 1) end
    validateHeader:SetText(Addon.Locale:Get("LABEL_VALIDATE_BOX_HEADER"))
    validateHeader:SetHidden(true)
    self.validateHeader = validateHeader

    local validateBg, validateEdit = CreateEditBoxWithBackdrop(PANEL_NAME .. "_ValidateEdit", contentParent, 340, 32, 4096, false)
    validateBg:SetAnchor(TOPLEFT, validateHeader, BOTTOMLEFT, 0, 2)
    validateBg:SetHidden(true)
    self.validateBg = validateBg
    self.validateEdit = validateEdit

    self.btnValidateDelivery = CreateStyledButton(PANEL_NAME .. "_BtnValidateDelivery", contentParent, 160, 32, Addon.Locale:Get("BTN_VALIDATE_DELIVERY"), function()
        self:OnValidateDeliveryClicked()
    end)
    self.btnValidateDelivery:SetAnchor(TOPLEFT, validateBg, TOPRIGHT, 10, 0)
    self.btnValidateDelivery:SetHidden(true)

    local resultLabel = WINDOW_MANAGER:CreateControl(PANEL_NAME .. "_ValidateResult", contentParent, CT_LABEL)
    resultLabel:SetDimensions(510, 56)
    resultLabel:SetAnchor(TOPLEFT, validateBg, BOTTOMLEFT, 0, 4)
    if resultLabel.SetFont then resultLabel:SetFont("ZoFontGame") end
    if resultLabel.SetVerticalAlignment and TEXT_ALIGN_TOP then
        resultLabel:SetVerticalAlignment(TEXT_ALIGN_TOP)
    end
    resultLabel:SetText("")
    self.validateResultLabel = resultLabel
end

function JournalTab:BuildEditorPane(parent)
    local pane = WINDOW_MANAGER:CreateControl(PANEL_NAME .. "_EditorPane", parent, CT_CONTROL)
    pane:SetDimensions(550, 580)
    pane:SetAnchor(TOPLEFT, parent, TOPLEFT, 0, 0)
    pane:SetHidden(true)
    self.editorPane = pane

    local header = WINDOW_MANAGER:CreateControl(PANEL_NAME .. "_EditorHeader", pane, CT_LABEL)
    header:SetAnchor(TOPLEFT, pane, TOPLEFT, 0, 0)
    if header.SetFont then header:SetFont("ZoFontWinH2") end
    if header.SetColor then header:SetColor(0.95, 0.88, 0.65, 1) end
    self.editorHeader = header

    local formParent = pane
    local scrollContainer = WINDOW_MANAGER.CreateControlFromVirtual
        and WINDOW_MANAGER:CreateControlFromVirtual(PANEL_NAME .. "_EditorScroll", pane, "ZO_ScrollContainer")
    if scrollContainer then
        scrollContainer:SetAnchor(TOPLEFT, pane, TOPLEFT, 0, 32)
        scrollContainer:SetDimensions(550, 474)
        local scrollChild = scrollContainer.GetNamedChild and scrollContainer:GetNamedChild("ScrollChild")
        if scrollChild then
            scrollChild:SetDimensions(526, 474)
            formParent = scrollChild
            self.editorScrollChild = scrollChild
        end
        self.editorScroll = scrollContainer
    end
    self.editorFormParent = formParent

    local lblTitle = WINDOW_MANAGER:CreateControl(PANEL_NAME .. "_LblInputTitle", formParent, CT_LABEL)
    lblTitle:SetAnchor(TOPLEFT, formParent, TOPLEFT, 0, 0)
    if lblTitle.SetFont then lblTitle:SetFont("ZoFontGameBold") end
    lblTitle:SetText(Addon.Locale:Get("LABEL_INPUT_TITLE"))
    self.lblInputTitle = lblTitle

    local titleBg, titleEdit = CreateEditBoxWithBackdrop(
        PANEL_NAME .. "_TitleEdit",
        formParent,
        510,
        30,
        90,
        false,
        function(val)
            Addon.QuestRepository:UpdateDraftFields({ title = val }, true)
        end
    )
    titleBg:SetAnchor(TOPLEFT, formParent, TOPLEFT, 0, 22)
    self.titleBg = titleBg
    self.titleEdit = titleEdit

    local lblDesc = WINDOW_MANAGER:CreateControl(PANEL_NAME .. "_LblInputDesc", formParent, CT_LABEL)
    lblDesc:SetAnchor(TOPLEFT, formParent, TOPLEFT, 0, 64)
    if lblDesc.SetFont then lblDesc:SetFont("ZoFontGameBold") end
    lblDesc:SetText(Addon.Locale:Get("LABEL_INPUT_DESCRIPTION"))
    self.lblInputDesc = lblDesc

    local descBg, descEdit = CreateEditBoxWithBackdrop(
        PANEL_NAME .. "_DescEdit",
        formParent,
        510,
        72,
        400,
        true,
        function(val)
            Addon.QuestRepository:UpdateDraftFields({ description = val }, true)
        end
    )
    descBg:SetAnchor(TOPLEFT, formParent, TOPLEFT, 0, 86)
    self.descBg = descBg
    self.descEdit = descEdit

    self.editorSections = {}
    self.editorSectionsByKey = {}

    local function CreateAccordionSection(key, localeKey, bodyHeight)
        local divider = WINDOW_MANAGER:CreateControl(PANEL_NAME .. "_EdDiv_" .. key, formParent, CT_TEXTURE)
        divider:SetDimensions(512, 4)
        divider:SetTexture(Addon.Constants.UI.DIVIDER_TEXTURE)

        local headerBtn = WINDOW_MANAGER:CreateControl(PANEL_NAME .. "_EdHdr_" .. key, formParent, CT_BUTTON)
        headerBtn:SetDimensions(510, 28)
        headerBtn:SetMouseEnabled(true)
        headerBtn:SetFont("ZoFontGameBold")
        if headerBtn.SetHorizontalAlignment and TEXT_ALIGN_LEFT then
            headerBtn:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
        end
        headerBtn:SetNormalFontColor(0.91, 0.83, 0.63, 1)
        headerBtn:SetMouseOverFontColor(1, 1, 1, 1)

        local hdrBg = WINDOW_MANAGER:CreateControl(PANEL_NAME .. "_EdHdrBg_" .. key, headerBtn, CT_BACKDROP)
        hdrBg:SetDimensions(510, 28)
        hdrBg:SetAnchor(TOPLEFT, headerBtn, TOPLEFT, 0, 0)
        hdrBg:SetCenterColor(0.08, 0.08, 0.10, 0.65)
        hdrBg:SetEdgeColor(0.45, 0.39, 0.24, 0.55)

        headerBtn:SetHandler("OnClicked", function()
            if PlaySound and SOUNDS and SOUNDS.DEFAULT_CLICK then
                PlaySound(SOUNDS.DEFAULT_CLICK)
            end
            self:ToggleEditorSection(key)
        end)

        local body = WINDOW_MANAGER:CreateControl(PANEL_NAME .. "_EdBody_" .. key, formParent, CT_CONTROL)
        body:SetDimensions(510, bodyHeight)
        body:SetAnchor(TOPLEFT, headerBtn, BOTTOMLEFT, 0, 10)

        local sec = {
            key = key,
            localeKey = localeKey,
            divider = divider,
            headerBtn = headerBtn,
            body = body,
            bodyHeight = bodyHeight,
        }
        table.insert(self.editorSections, sec)
        self.editorSectionsByKey[key] = sec
        return sec
    end

    -- Sección 1: Objetivo (NPC) y Área de Búsqueda
    local targetSec = CreateAccordionSection("target", "LABEL_TARGET_SECTION", 124)
    local targetBody = targetSec.body

    local lblCapturedTarget = WINDOW_MANAGER:CreateControl(PANEL_NAME .. "_LblCapturedTarget", targetBody, CT_LABEL)
    lblCapturedTarget:SetDimensions(360, 28)
    lblCapturedTarget:SetAnchor(TOPLEFT, targetBody, TOPLEFT, 4, 2)
    if lblCapturedTarget.SetFont then lblCapturedTarget:SetFont("ZoFontGame") end
    self.lblCapturedTarget = lblCapturedTarget

    self.btnClearTargets = CreateStyledButton(PANEL_NAME .. "_BtnClearTargets", targetBody, 140, 24, Addon.Locale:Get("BTN_CLEAR_TARGETS"), function()
        Addon.QuestRepository:ClearDraftTargets()
    end)
    self.btnClearTargets:SetAnchor(TOPLEFT, targetBody, TOPLEFT, 370, 0)
    self.btnClearTargets:SetHidden(true)

    local lblAreaSize = WINDOW_MANAGER:CreateControl(PANEL_NAME .. "_LblAreaSize", targetBody, CT_LABEL)
    lblAreaSize:SetAnchor(TOPLEFT, targetBody, TOPLEFT, 0, 36)
    if lblAreaSize.SetFont then lblAreaSize:SetFont("ZoFontGameBold") end
    lblAreaSize:SetText(Addon.Locale:Get("LABEL_AREA_SIZE"))
    self.lblAreaSize = lblAreaSize

    local radii = Addon.Constants.AREA_RADIUS

    self.btnRadiusSmall = CreateStyledButton(PANEL_NAME .. "_BtnRadSmall", targetBody, 110, 26, "", function()
        Addon.QuestRepository:UpdateDraftFields({ areaRadius = radii.SMALL })
    end)
    self.btnRadiusSmall:SetAnchor(TOPLEFT, targetBody, TOPLEFT, 0, 58)

    self.btnRadiusMedium = CreateStyledButton(PANEL_NAME .. "_BtnRadMedium", targetBody, 110, 26, "", function()
        Addon.QuestRepository:UpdateDraftFields({ areaRadius = radii.MEDIUM })
    end)
    self.btnRadiusMedium:SetAnchor(TOPLEFT, targetBody, TOPLEFT, 120, 58)

    self.btnRadiusLarge = CreateStyledButton(PANEL_NAME .. "_BtnRadLarge", targetBody, 110, 26, "", function()
        Addon.QuestRepository:UpdateDraftFields({ areaRadius = radii.LARGE })
    end)
    self.btnRadiusLarge:SetAnchor(TOPLEFT, targetBody, TOPLEFT, 240, 58)

    self.btnHideMapArea = CreateStyledButton(PANEL_NAME .. "_BtnHideMapArea", targetBody, 280, 26, Addon.Locale:Get("OPT_HIDE_MAP_AREA"), function()
        local d = Addon.QuestRepository:GetDraft()
        Addon.QuestRepository:UpdateDraftFields({ hideMapArea = not (d and d.hideMapArea) })
    end)
    self.btnHideMapArea:SetAnchor(TOPLEFT, targetBody, TOPLEFT, 0, 94)

    -- Sección 2: Puntos de Descubrimiento Ocultos
    local discoverySec = CreateAccordionSection("discovery", "LABEL_DISCOVERY_SECTION", 142)
    local discBody = discoverySec.body

    self.btnCaptureDiscovery = CreateStyledButton(PANEL_NAME .. "_BtnCaptureDiscovery", discBody, 130, 26, Addon.Locale:Get("BTN_CAPTURE_DISCOVERY"), function()
        local draft = Addon.QuestRepository:GetDraft()
        local hasExisting = #(draft.discoveries or {}) > 0
        local msgText = (not hasExisting and self.discoveryMsgEdit) and self.discoveryMsgEdit:GetText() or nil
        local _, count = Addon.TargetCapture:CaptureDiscoveryPoint(msgText)
        if count and count > 0 then
            self.selectedDiscoveryIndex = count
            Addon.QuestRepository:UpdateDraftFields({ discoveryMessage = "" }, true)
            self:RefreshEditorPane()
        end
    end)
    self.btnCaptureDiscovery:SetAnchor(TOPLEFT, discBody, TOPLEFT, 0, 0)

    self.btnClearDiscoveries = CreateStyledButton(PANEL_NAME .. "_BtnClearDiscoveries", discBody, 100, 26, Addon.Locale:Get("BTN_CLEAR_DISCOVERIES"), function()
        self.selectedDiscoveryIndex = nil
        Addon.QuestRepository:ClearDraftDiscoveries()
    end)
    self.btnClearDiscoveries:SetAnchor(TOPLEFT, discBody, TOPLEFT, 140, 0)
    self.btnClearDiscoveries:SetHidden(true)

    local function CycleEditorIndex(currentIndex, totalCount, delta)
        if totalCount <= 0 then return nil end
        local cur = currentIndex or 1
        if delta < 0 then
            return (cur > 1) and (cur - 1) or totalCount
        end
        return (cur < totalCount) and (cur + 1) or 1
    end

    self.btnDiscPrev = CreateStyledButton(PANEL_NAME .. "_BtnDiscPrev", discBody, 28, 26, "<", function()
        local draft = Addon.QuestRepository:GetDraft()
        local total = #(draft.discoveries or {})
        local nextIdx = CycleEditorIndex(self.selectedDiscoveryIndex, total, -1)
        if nextIdx then
            self.selectedDiscoveryIndex = nextIdx
            self:RefreshEditorPane()
        end
    end)
    self.btnDiscPrev:SetAnchor(TOPLEFT, discBody, TOPLEFT, 256, 0)
    self.btnDiscPrev:SetHidden(true)

    local lblDiscIndex = WINDOW_MANAGER:CreateControl(PANEL_NAME .. "_LblDiscIndex", discBody, CT_LABEL)
    lblDiscIndex:SetDimensions(66, 26)
    lblDiscIndex:SetAnchor(TOPLEFT, discBody, TOPLEFT, 288, 3)
    if lblDiscIndex.SetFont then lblDiscIndex:SetFont("ZoFontGameBold") end
    if lblDiscIndex.SetHorizontalAlignment then lblDiscIndex:SetHorizontalAlignment(TEXT_ALIGN_CENTER) end
    self.lblDiscIndex = lblDiscIndex
    self.lblDiscIndex:SetHidden(true)

    self.btnDiscNext = CreateStyledButton(PANEL_NAME .. "_BtnDiscNext", discBody, 28, 26, ">", function()
        local draft = Addon.QuestRepository:GetDraft()
        local total = #(draft.discoveries or {})
        local nextIdx = CycleEditorIndex(self.selectedDiscoveryIndex, total, 1)
        if nextIdx then
            self.selectedDiscoveryIndex = nextIdx
            self:RefreshEditorPane()
        end
    end)
    self.btnDiscNext:SetAnchor(TOPLEFT, discBody, TOPLEFT, 358, 0)
    self.btnDiscNext:SetHidden(true)

    self.btnDiscRemove = CreateStyledButton(PANEL_NAME .. "_BtnDiscRemove", discBody, 114, 26, Addon.Locale:Get("BTN_REMOVE_DISCOVERY"), function()
        local idx = self.selectedDiscoveryIndex
        if idx then
            local draft = Addon.QuestRepository:RemoveDraftDiscoveryPoint(idx)
            local total = draft and #(draft.discoveries or {}) or 0
            if total == 0 then
                self.selectedDiscoveryIndex = nil
            elseif idx > total then
                self.selectedDiscoveryIndex = total
            end
            self:RefreshEditorPane()
        end
    end)
    self.btnDiscRemove:SetAnchor(TOPLEFT, discBody, TOPLEFT, 396, 0)
    self.btnDiscRemove:SetHidden(true)

    local function SetSelectedDiscoveryRadius(radius)
        local draft = Addon.QuestRepository:GetDraft()
        local idx = self.selectedDiscoveryIndex
        if idx and draft.discoveries and draft.discoveries[idx] then
            Addon.QuestRepository:UpdateDraftDiscoveryPoint(idx, { radius = radius })
        else
            Addon.QuestRepository:UpdateDraftFields({ discoveryRadius = radius })
        end
    end

    local discRadii = Addon.Constants.DISCOVERY_RADIUS
    self.btnDiscRadSmall = CreateStyledButton(PANEL_NAME .. "_BtnDiscRadSmall", discBody, 68, 24, "", function()
        SetSelectedDiscoveryRadius(discRadii.SMALL)
    end)
    self.btnDiscRadSmall:SetAnchor(TOPLEFT, discBody, TOPLEFT, 0, 36)

    self.btnDiscRadMedium = CreateStyledButton(PANEL_NAME .. "_BtnDiscRadMedium", discBody, 68, 24, "", function()
        SetSelectedDiscoveryRadius(discRadii.MEDIUM)
    end)
    self.btnDiscRadMedium:SetAnchor(TOPLEFT, discBody, TOPLEFT, 74, 36)

    self.btnDiscRadLarge = CreateStyledButton(PANEL_NAME .. "_BtnDiscRadLarge", discBody, 68, 24, "", function()
        SetSelectedDiscoveryRadius(discRadii.LARGE)
    end)
    self.btnDiscRadLarge:SetAnchor(TOPLEFT, discBody, TOPLEFT, 148, 36)

    local discMsgBg, discMsgEdit = CreateEditBoxWithBackdrop(
        PANEL_NAME .. "_DiscoveryMsgEdit",
        discBody,
        510,
        30,
        160,
        false,
        function(val)
            local draft = Addon.QuestRepository:GetDraft()
            local idx = self.selectedDiscoveryIndex
            if idx and draft.discoveries and draft.discoveries[idx] then
                Addon.QuestRepository:UpdateDraftDiscoveryPoint(idx, { message = val }, true)
            else
                Addon.QuestRepository:UpdateDraftFields({ discoveryMessage = val }, true)
            end
        end
    )
    discMsgBg:SetAnchor(TOPLEFT, discBody, TOPLEFT, 0, 68)
    self.discoveryMsgBg = discMsgBg
    self.discoveryMsgEdit = discMsgEdit

    local lblCapturedDiscoveries = WINDOW_MANAGER:CreateControl(PANEL_NAME .. "_LblCapturedDiscoveries", discBody, CT_LABEL)
    lblCapturedDiscoveries:SetDimensions(510, 32)
    lblCapturedDiscoveries:SetAnchor(TOPLEFT, discBody, TOPLEFT, 4, 106)
    if lblCapturedDiscoveries.SetFont then lblCapturedDiscoveries:SetFont("ZoFontGame") end
    self.lblCapturedDiscoveries = lblCapturedDiscoveries

    -- Sección 3: Diálogos con NPCs Nativos (0-3)
    local dialogueSec = CreateAccordionSection("dialogue", "LABEL_DIALOGUE_SECTION", 240)
    local dlgBody = dialogueSec.body

    self.btnAddLastNpc = CreateStyledButton(PANEL_NAME .. "_BtnAddLastNpc", dlgBody, 130, 26, Addon.Locale:Get("BTN_ADD_LAST_NPC"), function()
        local _, resultOrErr = Addon.QuestRepository:AddDraftDialogueFromLastNpc("")
        if type(resultOrErr) == "number" then
            self.selectedDialogueIndex = resultOrErr
            local draft = Addon.QuestRepository:GetDraft()
            local entry = draft.dialogues and draft.dialogues[resultOrErr]
            if entry then
                Addon.Announcements:ShowAlert(Addon.Locale:Get("ALERT_DIALOGUE_ADDED", entry.npcName), false)
            end
            self:RefreshEditorPane()
        elseif type(resultOrErr) == "string" then
            Addon.Announcements:ShowAlert(resultOrErr, true)
        end
    end)
    self.btnAddLastNpc:SetAnchor(TOPLEFT, dlgBody, TOPLEFT, 0, 0)

    self.btnClearDialogues = CreateStyledButton(PANEL_NAME .. "_BtnClearDialogues", dlgBody, 100, 26, Addon.Locale:Get("BTN_CLEAR_DIALOGUES"), function()
        self.selectedDialogueIndex = nil
        Addon.QuestRepository:ClearDraftDialogues()
    end)
    self.btnClearDialogues:SetAnchor(TOPLEFT, dlgBody, TOPLEFT, 140, 0)
    self.btnClearDialogues:SetHidden(true)

    self.btnDlgPrev = CreateStyledButton(PANEL_NAME .. "_BtnDlgPrev", dlgBody, 28, 26, "<", function()
        local draft = Addon.QuestRepository:GetDraft()
        local count = #(draft.dialogues or {})
        local nextIdx = CycleEditorIndex(self.selectedDialogueIndex, count, -1)
        if nextIdx then
            self.selectedDialogueIndex = nextIdx
            self:RefreshEditorPane()
        end
    end)
    self.btnDlgPrev:SetAnchor(TOPLEFT, dlgBody, TOPLEFT, 256, 0)
    self.btnDlgPrev:SetHidden(true)

    local lblDlgIndex = WINDOW_MANAGER:CreateControl(PANEL_NAME .. "_LblDlgIndex", dlgBody, CT_LABEL)
    lblDlgIndex:SetDimensions(60, 26)
    lblDlgIndex:SetAnchor(TOPLEFT, dlgBody, TOPLEFT, 288, 3)
    if lblDlgIndex.SetFont then lblDlgIndex:SetFont("ZoFontGameBold") end
    if lblDlgIndex.SetHorizontalAlignment then lblDlgIndex:SetHorizontalAlignment(TEXT_ALIGN_CENTER) end
    lblDlgIndex:SetHidden(true)
    self.lblDlgIndex = lblDlgIndex

    self.btnDlgNext = CreateStyledButton(PANEL_NAME .. "_BtnDlgNext", dlgBody, 28, 26, ">", function()
        local draft = Addon.QuestRepository:GetDraft()
        local count = #(draft.dialogues or {})
        local nextIdx = CycleEditorIndex(self.selectedDialogueIndex, count, 1)
        if nextIdx then
            self.selectedDialogueIndex = nextIdx
            self:RefreshEditorPane()
        end
    end)
    self.btnDlgNext:SetAnchor(TOPLEFT, dlgBody, TOPLEFT, 352, 0)
    self.btnDlgNext:SetHidden(true)

    self.btnDlgRemove = CreateStyledButton(PANEL_NAME .. "_BtnDlgRemove", dlgBody, 28, 26, "X", function()
        local idx = self.selectedDialogueIndex
        if idx then
            Addon.QuestRepository:RemoveDraftDialogue(idx)
            local draft = Addon.QuestRepository:GetDraft()
            local count = #(draft.dialogues or {})
            self.selectedDialogueIndex = (count > 0) and math.min(idx, count) or nil
            self:RefreshEditorPane()
        end
    end)
    self.btnDlgRemove:SetAnchor(TOPLEFT, dlgBody, TOPLEFT, 388, 0)
    self.btnDlgRemove:SetHidden(true)

    local lblLastNpc = WINDOW_MANAGER:CreateControl(PANEL_NAME .. "_LblLastNpc", dlgBody, CT_LABEL)
    lblLastNpc:SetDimensions(510, 22)
    lblLastNpc:SetAnchor(TOPLEFT, dlgBody, TOPLEFT, 4, 34)
    if lblLastNpc.SetFont then lblLastNpc:SetFont("ZoFontGame") end
    self.lblLastNpc = lblLastNpc

    local lblClue = WINDOW_MANAGER:CreateControl(PANEL_NAME .. "_LblInputClue", dlgBody, CT_LABEL)
    lblClue:SetAnchor(TOPLEFT, dlgBody, TOPLEFT, 0, 64)
    if lblClue.SetFont then lblClue:SetFont("ZoFontGameBold") end
    lblClue:SetText(Addon.Locale:Get("LABEL_INPUT_CLUE"))
    self.lblInputClue = lblClue

    local clueBg, clueEdit = CreateEditBoxWithBackdrop(
        PANEL_NAME .. "_ClueEdit",
        dlgBody,
        510,
        30,
        100,
        false,
        function(val)
            Addon.QuestRepository:UpdateDraftFields({ clue = val }, true)
        end
    )
    clueBg:SetAnchor(TOPLEFT, dlgBody, TOPLEFT, 0, 86)
    self.clueBg = clueBg
    self.clueEdit = clueEdit

    local lblDlgResponse = WINDOW_MANAGER:CreateControl(PANEL_NAME .. "_LblDlgResponse", dlgBody, CT_LABEL)
    lblDlgResponse:SetAnchor(TOPLEFT, dlgBody, TOPLEFT, 0, 126)
    if lblDlgResponse.SetFont then lblDlgResponse:SetFont("ZoFontGameBold") end
    lblDlgResponse:SetText(Addon.Locale:Get("LABEL_DIALOGUE_RESPONSE"))
    self.lblDlgResponse = lblDlgResponse

    local dlgResponseBg, dlgResponseEdit = CreateEditBoxWithBackdrop(
        PANEL_NAME .. "_DlgResponseEdit",
        dlgBody,
        510,
        52,
        300,
        true,
        function(val)
            local draft = Addon.QuestRepository:GetDraft()
            local idx = self.selectedDialogueIndex
            if idx and draft.dialogues and draft.dialogues[idx] then
                Addon.QuestRepository:UpdateDraftDialogue(idx, { response = val }, true)
            end
        end
    )
    dlgResponseBg:SetAnchor(TOPLEFT, dlgBody, TOPLEFT, 0, 148)
    self.dlgResponseBg = dlgResponseBg
    self.dlgResponseEdit = dlgResponseEdit

    local lblCapturedDialogues = WINDOW_MANAGER:CreateControl(PANEL_NAME .. "_LblCapturedDialogues", dlgBody, CT_LABEL)
    lblCapturedDialogues:SetDimensions(510, 28)
    lblCapturedDialogues:SetAnchor(TOPLEFT, dlgBody, TOPLEFT, 4, 208)
    if lblCapturedDialogues.SetFont then lblCapturedDialogues:SetFont("ZoFontGame") end
    self.lblCapturedDialogues = lblCapturedDialogues

    -- Sección 4: Opciones de Entrega y Sigilo (Opcional)
    local optionsSec = CreateAccordionSection("options", "LABEL_OPTIONS_SECTION", 96)
    local optBody = optionsSec.body

    local lblCompletionMsg = WINDOW_MANAGER:CreateControl(PANEL_NAME .. "_LblInputCompletionMsg", optBody, CT_LABEL)
    lblCompletionMsg:SetAnchor(TOPLEFT, optBody, TOPLEFT, 0, 0)
    if lblCompletionMsg.SetFont then lblCompletionMsg:SetFont("ZoFontGameBold") end
    lblCompletionMsg:SetText(Addon.Locale:Get("LABEL_INPUT_COMPLETION_MSG"))
    self.lblInputCompletionMsg = lblCompletionMsg

    local compBg, compEdit = CreateEditBoxWithBackdrop(
        PANEL_NAME .. "_CompletionEdit",
        optBody,
        510,
        30,
        140,
        false,
        function(val)
            Addon.QuestRepository:UpdateDraftFields({ completionMessage = val }, true)
        end
    )
    compBg:SetAnchor(TOPLEFT, optBody, TOPLEFT, 0, 22)
    self.completionBg = compBg
    self.completionEdit = compEdit

    self.btnRequireUndetected = CreateStyledButton(PANEL_NAME .. "_BtnRequireUndetected", optBody, 280, 26, Addon.Locale:Get("OPT_REQUIRE_UNDETECTED"), function()
        local d = Addon.QuestRepository:GetDraft()
        Addon.QuestRepository:UpdateDraftFields({ requireUndetected = not (d and d.requireUndetected) })
    end)
    self.btnRequireUndetected:SetAnchor(TOPLEFT, optBody, TOPLEFT, 0, 62)

    self:LayoutEditorSections()

    self.btnSaveEditor = CreateStyledButton(PANEL_NAME .. "_BtnSaveEditor", pane, 180, 34, Addon.Locale:Get("BTN_SAVE"), function()
        self:OnSaveDraftClicked()
    end)
    self.btnSaveEditor:SetAnchor(TOPLEFT, pane, TOPLEFT, 0, 514)

    self.btnCancelEditor = CreateStyledButton(PANEL_NAME .. "_BtnCancelEditor", pane, 150, 34, Addon.Locale:Get("BTN_CANCEL"), function()
        self.viewMode = VIEW_MODE.DETAIL
        Addon.QuestRepository:ResetDraft()
        self:ClearEditorInputs()
        self:Refresh()
    end)
    self.btnCancelEditor:SetAnchor(TOPLEFT, pane, TOPLEFT, 195, 514)

    self.btnShowMapEditor = CreateStyledButton(PANEL_NAME .. "_BtnShowMapEditor", pane, 155, 34, Addon.Locale:Get("BTN_SHOW_ON_MAP"), function()
        local draft = Addon.QuestRepository:GetDraft()
        if draft and draft.mapId and draft.mapId > 0 then
            Addon.WorldMapArea:ShowQuestOnMap(draft)
        end
    end)
    self.btnShowMapEditor:SetAnchor(TOPLEFT, pane, TOPLEFT, 360, 514)
    self.btnShowMapEditor:SetHidden(true)
end

function JournalTab:BuildImportPane(parent)
    local pane = WINDOW_MANAGER:CreateControl(PANEL_NAME .. "_ImportPane", parent, CT_CONTROL)
    pane:SetDimensions(550, 580)
    pane:SetAnchor(TOPLEFT, parent, TOPLEFT, 0, 0)
    pane:SetHidden(true)
    self.importPane = pane

    local header = WINDOW_MANAGER:CreateControl(PANEL_NAME .. "_ImportHeader", pane, CT_LABEL)
    header:SetAnchor(TOPLEFT, pane, TOPLEFT, 0, 0)
    if header.SetFont then header:SetFont("ZoFontWinH2") end
    if header.SetColor then header:SetColor(0.95, 0.88, 0.65, 1) end
    header:SetText(Addon.Locale:Get("IMPORT_VIEW_TITLE"))
    self.importHeader = header

    local instr = WINDOW_MANAGER:CreateControl(PANEL_NAME .. "_ImportInstr", pane, CT_LABEL)
    instr:SetDimensions(510, 48)
    instr:SetAnchor(TOPLEFT, pane, TOPLEFT, 0, 44)
    if instr.SetFont then instr:SetFont("ZoFontGame") end
    instr:SetText(Addon.Locale:Get("IMPORT_INSTRUCTIONS"))
    self.importInstr = instr

    local codeBg, codeEdit = CreateEditBoxWithBackdrop(PANEL_NAME .. "_ImportCodeEdit", pane, 510, 80, 4096, true)
    codeBg:SetAnchor(TOPLEFT, pane, TOPLEFT, 0, 96)
    self.importCodeBg = codeBg
    self.importCodeEdit = codeEdit

    self.btnConfirmImport = CreateStyledButton(PANEL_NAME .. "_BtnConfirmImport", pane, 180, 36, Addon.Locale:Get("BTN_CONFIRM_IMPORT"), function()
        self:OnConfirmImportClicked()
    end)
    self.btnConfirmImport:SetAnchor(TOPLEFT, pane, TOPLEFT, 0, 196)

    self.btnCancelImport = CreateStyledButton(PANEL_NAME .. "_BtnCancelImport", pane, 150, 36, Addon.Locale:Get("BTN_CANCEL"), function()
        self.importCodeEdit:SetText("")
        self.viewMode = VIEW_MODE.DETAIL
        self:Refresh()
    end)
    self.btnCancelImport:SetAnchor(TOPLEFT, pane, TOPLEFT, 195, 196)
end

function JournalTab:IntegrateIntoQuestJournalModeBar()
    local qj = QUEST_JOURNAL_KEYBOARD or (SYSTEMS and SYSTEMS.GetKeyboardObject and SYSTEMS:GetKeyboardObject("questJournal"))
    if not qj then return end

    local tabDescriptor = Addon.Constants.UI.TAB_DESCRIPTOR
    local tabCategoryName = "SI_RPQUEST_JOURNAL_TAB_TITLE"
    ZO_CreateStringId(tabCategoryName, Addon.Locale:Get("TAB_TITLE"))
    self.tabCategoryName = _G[tabCategoryName] or tabCategoryName
    self.tabDescriptor = tabDescriptor

    local uiConsts = Addon.Constants.UI
    local tabData = {
        categoryName = self.tabCategoryName,
        descriptor = tabDescriptor,
        normal = uiConsts.ICON_TAB_UP,
        pressed = uiConsts.ICON_TAB_DOWN,
        highlight = uiConsts.ICON_TAB_OVER,
        disabled = uiConsts.ICON_TAB_DISABLED,
        callback = function()
            if qj.SetMode then
                qj:SetMode(tabDescriptor)
            end
            if self._dirty then
                self:Refresh()
            end
        end,
    }

    local function EnsureTabAdded()
        if qj.tabs and not self.isTabAdded and self.fragment then
            qj.tabs:Add(self.tabCategoryName, { self.fragment }, tabData, self.keybindStripDescriptor)
            self.isTabAdded = true
        end
    end

    if qj.initializedTabs then
        EnsureTabAdded()
    end

    ZO_PostHook(qj, "OnShowing", function(qjSelf)
        EnsureTabAdded()
        if qjSelf.mode == tabDescriptor and qjSelf.tabs and qjSelf.tabs.SelectFragment then
            qjSelf.tabs:SelectFragment(self.tabCategoryName)
            if self._dirty then
                self:Refresh()
            end
        end
        if qjSelf.tabs and qjSelf.tabs.UpdateButtons then
            qjSelf.tabs:UpdateButtons()
        end
    end)
end

function JournalTab:SelectQuest(questId)
    if Addon.QuestRepository:GetDraft().editingQuestId then
        Addon.QuestRepository:ResetDraft()
    end
    self.selectedQuestId = questId
    self.viewMode = VIEW_MODE.DETAIL
    if self.detailScroll and self.detailScroll.scroll and self.detailScroll.scroll.SetVerticalScroll then
        self.detailScroll.scroll:SetVerticalScroll(0)
    end
    if self.shareEdit then
        if self.shareEdit.LoseFocus then self.shareEdit:LoseFocus() end
        self.shareEdit._focused = false
        SetReadOnlyEditText(self.shareEdit, "")
    end
    if self.deliveryEdit then
        if self.deliveryEdit.LoseFocus then self.deliveryEdit:LoseFocus() end
        self.deliveryEdit._focused = false
        SetReadOnlyEditText(self.deliveryEdit, "")
    end
    if self.validateEdit then
        if self.validateEdit.LoseFocus then self.validateEdit:LoseFocus() end
        self.validateEdit._focused = false
        self.validateEdit:SetText("")
    end
    if self.validateResultLabel then self.validateResultLabel:SetText("") end
    self:Refresh()
end

function JournalTab:OpenCreateEditor()
    local draft = Addon.QuestRepository:ResetDraft()
    self.selectedDiscoveryIndex = nil
    self.titleEdit:SetText(draft.title or "")
    self.descEdit:SetText(draft.description or "")
    if self.clueEdit then self.clueEdit:SetText(draft.clue or "") end
    self.completionEdit:SetText(draft.completionMessage or "")
    self.selectedDialogueIndex = (#(draft.dialogues or {}) > 0) and 1 or nil
    self.editorSectionsCollapsed = {
        target = true,
        discovery = true,
        dialogue = true,
        options = true,
    }
    self.viewMode = VIEW_MODE.EDITOR
    self:Refresh()
end

local function GetQuestSectionKey(quest)
    if not quest then return nil end
    if Addon.QuestRepository:IsPreparedQuest(quest) then
        return "preparing"
    elseif quest.completed then
        return "completed"
    end
    return "missions"
end

function JournalTab:IsSectionLockedExpanded(sectionKey)
    if not sectionKey then return false end
    if self.selectedQuestId then
        local selected = Addon.QuestRepository:GetQuestById(self.selectedQuestId)
        if GetQuestSectionKey(selected) == sectionKey then
            return true
        end
    end
    local activeQuest = Addon.QuestRepository:GetActiveQuest()
    if activeQuest and GetQuestSectionKey(activeQuest) == sectionKey then
        return true
    end
    return false
end

function JournalTab:ToggleSection(sectionKey)
    if not sectionKey or not self.collapsedSections then return end
    if not self.collapsedSections[sectionKey] and self:IsSectionLockedExpanded(sectionKey) then
        return
    end
    self.collapsedSections[sectionKey] = not self.collapsedSections[sectionKey]
    self.listOffset = 0
    self:RefreshQuestList()
end

function JournalTab:OpenEditEditor(questId)
    local draft, err = Addon.QuestRepository:LoadQuestIntoDraft(questId)
    if not draft then
        if err then
            Addon.Announcements:ShowAlert(err, true)
        end
        return
    end
    self.titleEdit:SetText(draft.title or "")
    self.descEdit:SetText(draft.description or "")
    if self.clueEdit then self.clueEdit:SetText(draft.clue or "") end
    self.completionEdit:SetText(draft.completionMessage or "")
    self.selectedDialogueIndex = (#(draft.dialogues or {}) > 0) and 1 or nil
    self.editorSectionsCollapsed = {
        target = true,
        discovery = true,
        dialogue = true,
        options = true,
    }
    self.viewMode = VIEW_MODE.EDITOR
    self:Refresh()
end

function JournalTab:OpenImportView()
    if Addon.QuestRepository:GetDraft().editingQuestId then
        Addon.QuestRepository:ResetDraft()
    end
    self.importCodeEdit:SetText("")
    self.viewMode = VIEW_MODE.IMPORT
    self:Refresh()
    if self.importCodeEdit.TakeFocus then
        self.importCodeEdit:TakeFocus()
    end
end

function JournalTab:ClearEditorInputs()
    if self.titleEdit then self.titleEdit:SetText("") end
    if self.descEdit then self.descEdit:SetText("") end
    if self.clueEdit then self.clueEdit:SetText("") end
    if self.completionEdit then self.completionEdit:SetText("") end
    if self.discoveryMsgEdit then self.discoveryMsgEdit:SetText("") end
    if self.dlgResponseEdit then self.dlgResponseEdit:SetText("") end
    self.selectedDialogueIndex = nil
    self.selectedDiscoveryIndex = nil
end

function JournalTab:OnSaveDraftClicked()
    local titleText = self.titleEdit:GetText()
    local descText = self.descEdit:GetText()
    local compMsgText = self.completionEdit and self.completionEdit:GetText() or ""
    if self.clueEdit then
        Addon.QuestRepository:UpdateDraftFields({ clue = self.clueEdit:GetText() }, true)
    end

    local savedQuest, err = Addon.QuestRepository:SaveDraft(titleText, descText, nil, compMsgText)
    if not savedQuest then
        Addon.Announcements:ShowAlert(err or Addon.Locale:Get("ERR_MISSING_TARGET"), true)
        return
    end

    self:ClearEditorInputs()

    Addon.Announcements:ShowAlert(Addon.Locale:Get("ALERT_QUEST_SAVED", savedQuest.title), false)
end

function JournalTab:OnConfirmImportClicked()
    local rawCode = self.importCodeEdit:GetText()
    local importedQuest, err = Addon.QuestRepository:ImportQuestFromCode(rawCode)
    if not importedQuest then
        Addon.Announcements:ShowAlert(err or Addon.Locale:Get("ERR_INVALID_CODE"), true)
        return
    end

    self.importCodeEdit:SetText("")

    Addon.Announcements:AnnounceQuestAccepted(importedQuest)
end

function JournalTab:OnToggleActiveClicked()
    local q = Addon.QuestRepository:GetQuestById(self.selectedQuestId)
    if not q then return end

    local activeQuest = Addon.QuestRepository:GetActiveQuest()
    if activeQuest and activeQuest.id == q.id then
        Addon.QuestRepository:SetActiveQuest(nil)
    else
        if q.completed then
            Addon.QuestRepository:ResetQuest(q.id)
        else
            Addon.QuestRepository:SetActiveQuest(q.id)
        end
    end
end

function JournalTab:ConfirmAbandonQuest(questId)
    local q = Addon.QuestRepository:GetQuestById(questId)
    if not q then return false end

    if ESO_Dialogs and ZO_Dialogs_ShowDialog and ESO_Dialogs["RPQUEST_ABANDON_QUEST"] then
        ZO_Dialogs_ShowDialog("RPQUEST_ABANDON_QUEST", { questId = questId }, { mainTextParams = { q.title or "" } })
        return true
    end

    if Addon.QuestRepository:DeleteQuest(questId) then
        Addon.Announcements:ShowAlert(Addon.Locale:Get("ALERT_QUEST_DELETED"), false)
        return true
    end
    return false
end

function JournalTab:OnValidateDeliveryClicked()
    if not self.selectedQuestId then return end
    local rawCode = (self.validateEdit and self.validateEdit:GetText()) or ""
    if rawCode:match("^%s*$") then
        self.validateResultLabel:SetText(Addon.Locale:Get("VALIDATE_ERR_EMPTY"))
        if self.validateEdit and self.validateEdit.TakeFocus then
            self.validateEdit:TakeFocus()
        end
        return
    end

    local isValid, resultOrErrKey = Addon.QuestRepository:ValidateCompletionCode(self.selectedQuestId, rawCode)
    if isValid and type(resultOrErrKey) == "table" then
        local msg = Addon.Locale:Get("VALIDATE_RESULT_SUCCESS", resultOrErrKey.characterName or "")
        if resultOrErrKey.wasDetected == true then
            msg = msg .. Addon.Locale:Get("VALIDATE_STEALTH_DETECTED")
        elseif resultOrErrKey.wasDetected == false then
            msg = msg .. Addon.Locale:Get("VALIDATE_STEALTH_UNDETECTED")
        end
        self.validateResultLabel:SetText(msg)
    else
        local errKey = type(resultOrErrKey) == "string" and resultOrErrKey or "VALIDATE_ERR_INVALID_CODE"
        self.validateResultLabel:SetText(Addon.Locale:Get(errKey))
    end
end

function JournalTab:OpenTab()
    if not self.isInitialized then
        self:Initialize()
    end

    local qj = QUEST_JOURNAL_KEYBOARD or (SYSTEMS and SYSTEMS.GetKeyboardObject and SYSTEMS:GetKeyboardObject("questJournal"))
    if qj and qj.SetMode then
        qj:SetMode(self.tabDescriptor or Addon.Constants.UI.TAB_DESCRIPTOR)
    end

    if SCENE_MANAGER and SCENE_MANAGER.Show then
        SCENE_MANAGER:Show("questJournal")
    end

    if qj and qj.tabs and qj.tabs.SelectFragment and self.tabCategoryName then
        qj.tabs:SelectFragment(self.tabCategoryName)
    elseif self.panel then
        self.panel:SetHidden(false)
    end

    if self._dirty then
        self:Refresh()
    end
end

function JournalTab:ToggleTab()
    if not self.isInitialized then
        self:Initialize()
    end

    local qj = QUEST_JOURNAL_KEYBOARD or (SYSTEMS and SYSTEMS.GetKeyboardObject and SYSTEMS:GetKeyboardObject("questJournal"))
    local sceneShowing = SCENE_MANAGER and SCENE_MANAGER.IsShowing and SCENE_MANAGER:IsShowing("questJournal")

    if sceneShowing and qj and qj.mode == (self.tabDescriptor or Addon.Constants.UI.TAB_DESCRIPTOR) then
        SCENE_MANAGER:Hide("questJournal")
        if self.panel then
            self.panel:SetHidden(true)
        end
    else
        self:OpenTab()
    end
end

function JournalTab:RefreshQuestList(allQuests, activeQuest)
    if not self.panel then return end

    allQuests = allQuests or Addon.QuestRepository:GetAllQuests()
    activeQuest = activeQuest or Addon.QuestRepository:GetActiveQuest()

    local roles = Addon.Constants.QUEST_ROLE
    local activeMissions = {}
    local completedMissions = {}
    local preparingMissions = {}
    for _, q in ipairs(allQuests) do
        if q.role == roles.PREPARED then
            table.insert(preparingMissions, q)
        elseif q.completed then
            table.insert(completedMissions, q)
        else
            table.insert(activeMissions, q)
        end
    end

    self.rowBindings = {}

    if #allQuests == 0 then
        self.listOffset = 0
        self._maxListOffset = 0
        self.emptyLabel:SetText(Addon.Locale:Get("EMPTY_QUEST_LIST"))
        self.emptyLabel:SetHidden(false)
        for i = 1, MAX_VISIBLE_ROWS do
            self.rowControls[i]:SetHidden(true)
        end
        if self.btnListPrev then self.btnListPrev:SetHidden(true) end
        if self.btnListNext then self.btnListNext:SetHidden(true) end
        if self.scrollInfoLabel then self.scrollInfoLabel:SetHidden(true) end
        return
    end

    self.emptyLabel:SetHidden(true)
    local displayRows = {}

    local function AppendSection(sectionKey, localeKey, quests, isCompleted)
        if #quests == 0 then return end
        local isLocked = self:IsSectionLockedExpanded(sectionKey)
        local isCollapsed = (not isLocked) and self.collapsedSections and self.collapsedSections[sectionKey]
        local arrowTex = isCollapsed and "/esoui/art/buttons/tree_closed_up.dds" or "/esoui/art/buttons/tree_open_up.dds"
        local headerColor = isCollapsed and "|cC5C29E" or "|cFFFFFF"
        table.insert(displayRows, {
            isHeader = true,
            sectionKey = sectionKey,
            text = string.format("|t28:28:%s|t %s%s|r", arrowTex, headerColor, Addon.Locale:Get(localeKey, #quests)),
        })
        if isCollapsed then return end

        for _, q in ipairs(quests) do
            local isSelected = (self.selectedQuestId == q.id)
            local prefix
            local selColor
            if isCompleted then
                prefix = "      |t16:16:/esoui/art/cadwell/check.dds|t "
                selColor = isSelected and "|cFFFFFF" or "|c8899AA"
            else
                local isAct = (activeQuest and activeQuest.id == q.id)
                prefix = isAct and "      |t18:18:/esoui/art/journal/journal_quest_selected.dds|t " or "          "
                selColor = isSelected and "|cFFFFFF" or "|cC5C29E"
            end
            table.insert(displayRows, {
                isHeader = false,
                questId = q.id,
                text = prefix .. selColor .. (q.title or "") .. "|r",
            })
        end
    end

    AppendSection("missions", "SECTION_ACTIVE_QUESTS", activeMissions, false)
    AppendSection("completed", "SECTION_COMPLETED_QUESTS", completedMissions, true)
    AppendSection("preparing", "SECTION_PREPARED_QUESTS", preparingMissions, false)

    local maxOffset = math.max(0, #displayRows - MAX_VISIBLE_ROWS)
    self._maxListOffset = maxOffset
    self.listOffset = math.min(math.max(0, self.listOffset or 0), maxOffset)

    for i = 1, MAX_VISIBLE_ROWS do
        local rowCtrl = self.rowControls[i]
        local rowData = displayRows[self.listOffset + i]
        if rowData then
            rowCtrl:SetHidden(false)
            if rowCtrl.SetFont then
                rowCtrl:SetFont(rowData.isHeader and "ZoFontHeader3" or "ZoFontHeader")
            end
            rowCtrl:SetText(rowData.text)
            rowCtrl:SetMouseEnabled(true)
            self.rowBindings[i] = rowData
        else
            rowCtrl:SetHidden(true)
        end
    end

    local needsScroll = (#displayRows > MAX_VISIBLE_ROWS)
    if self.btnListPrev then self.btnListPrev:SetHidden(not needsScroll) end
    if self.btnListNext then self.btnListNext:SetHidden(not needsScroll) end
    if self.scrollInfoLabel then
        if needsScroll then
            local firstRow = self.listOffset + 1
            local lastRow = math.min(#displayRows, self.listOffset + MAX_VISIBLE_ROWS)
            self.scrollInfoLabel:SetText(string.format("%d-%d / %d", firstRow, lastRow, #displayRows))
            self.scrollInfoLabel:SetHidden(false)
        else
            self.scrollInfoLabel:SetHidden(true)
        end
    end
end

function JournalTab:Refresh()
    if not self.panel then return end

    local allQuests = Addon.QuestRepository:GetAllQuests()
    local activeQuest = Addon.QuestRepository:GetActiveQuest()
    self._dirty = false

    local selectedQuest = nil
    if self.viewMode == VIEW_MODE.DETAIL then
        selectedQuest = self.selectedQuestId and Addon.QuestRepository:GetQuestById(self.selectedQuestId)
        if not selectedQuest then
            if activeQuest then
                selectedQuest = activeQuest
                self.selectedQuestId = activeQuest.id
            elseif allQuests[1] then
                selectedQuest = allQuests[1]
                self.selectedQuestId = allQuests[1].id
            else
                selectedQuest = nil
                self.selectedQuestId = nil
            end
        end
    end

    -- 1. Actualizar columna izquierda
    self:RefreshQuestList(allQuests, activeQuest)

    -- 2. Actualizar columna derecha según el modo de vista
    if self.viewMode == VIEW_MODE.EDITOR then
        self.detailPane:SetHidden(true)
        self.importPane:SetHidden(true)
        self.editorPane:SetHidden(false)
        self:RefreshEditorPane()
        if KEYBIND_STRIP and self.keybindStripDescriptor then
            KEYBIND_STRIP:UpdateKeybindButtonGroup(self.keybindStripDescriptor)
        end
    elseif self.viewMode == VIEW_MODE.IMPORT then
        self.detailPane:SetHidden(true)
        self.editorPane:SetHidden(true)
        self.importPane:SetHidden(false)
        if KEYBIND_STRIP and self.keybindStripDescriptor then
            KEYBIND_STRIP:UpdateKeybindButtonGroup(self.keybindStripDescriptor)
        end
    else
        self.editorPane:SetHidden(true)
        self.importPane:SetHidden(true)
        self.detailPane:SetHidden(false)
        self:RefreshDetailPane(selectedQuest, activeQuest)
    end
end

function JournalTab:RefreshDetailPane(selectedQuest, activeQuest)
    selectedQuest = selectedQuest or (self.selectedQuestId and Addon.QuestRepository:GetQuestById(self.selectedQuestId))
    activeQuest = activeQuest or Addon.QuestRepository:GetActiveQuest()

    if not selectedQuest then
        self.detailTitle:SetText(Addon.Locale:Get("TAB_TITLE"))
        self.detailStatus:SetText(Addon.Locale:Get("EMPTY_QUEST_LIST"))
        self.detailLocation:SetText("")
        self.detailDescBody:SetText("")
        self.detailObjHeader:SetHidden(true)
        self.detailObjText:SetText("")
        self.codeDivider:SetHidden(true)
        self.shareHeader:SetHidden(true)
        self.shareBg:SetHidden(true)
        self.deliveryHeader:SetHidden(true)
        self.deliveryBg:SetHidden(true)
        self.validateHeader:SetHidden(true)
        self.validateBg:SetHidden(true)
        self.validateResultLabel:SetHidden(true)
        self.btnActivate:SetHidden(true)
        if self.showOnMapKeybindButton then self.showOnMapKeybindButton:SetHidden(true) end
        self.btnEdit:SetHidden(true)
        self.btnReset:SetHidden(true)
        self.btnValidateDelivery:SetHidden(true)
        if KEYBIND_STRIP and self.keybindStripDescriptor then
            KEYBIND_STRIP:UpdateKeybindButtonGroup(self.keybindStripDescriptor)
        end
        return
    end

    self.detailObjHeader:SetHidden(false)
    self.detailTitle:SetText((selectedQuest.title or ""):upper())

    local isPrepared = Addon.QuestRepository:IsPreparedQuest(selectedQuest)
    local isCurrentActive = (activeQuest and activeQuest.id == selectedQuest.id)
    local activateLabel = isPrepared and Addon.Locale:Get("BTN_TEST_QUEST") or Addon.Locale:Get("BTN_ACTIVATE")
    local deactivateLabel = isPrepared and Addon.Locale:Get("BTN_STOP_TEST") or Addon.Locale:Get("BTN_DEACTIVATE")

    if isCurrentActive then
        self.detailStatus:SetText(Addon.Locale:Get("STATUS_ACTIVE"))
        self.btnActivate:SetText(deactivateLabel)
    elseif selectedQuest.completed then
        self.detailStatus:SetText(Addon.Locale:Get("STATUS_COMPLETED"))
        self.btnActivate:SetText(activateLabel)
    else
        self.detailStatus:SetText(Addon.Locale:Get("STATUS_AVAILABLE"))
        self.btnActivate:SetText(activateLabel)
    end

    local locText = (selectedQuest.mapName and selectedQuest.mapName ~= "" and selectedQuest.mapName)
        or Addon.Locale:Get("LABEL_UNKNOWN_LOCATION")
    self.detailLocation:SetText(Addon.Locale:Get("LABEL_LOCATION", locText))

    local descText = (selectedQuest.description and selectedQuest.description ~= "" and selectedQuest.description)
        or Addon.Locale:Get("LABEL_NO_DESCRIPTION")
    self.detailDescBody:SetText(descText)

    local targets = selectedQuest.targets or {}
    local objLines = {}
    local maxVisibleObjLines = 4
    local totalTargets = #targets
    local limit = (totalTargets > maxVisibleObjLines) and (maxVisibleObjLines - 1) or totalTargets
    for i = 1, limit do
        local t = targets[i]
        local line = Addon.Locale:Get(
            "OBJECTIVE_KILL_FORMAT",
            t.name or "",
            t.currentCount or 0,
            t.requiredCount or 1
        )
        line = line:gsub("^•%s*", "|t16:16:/esoui/art/miscellaneous/bullet.dds|t ")
        if (t.currentCount or 0) >= (t.requiredCount or 1) then
            line = line .. Addon.Locale:Get("OBJECTIVE_COMPLETED_SUFFIX")
        end
        objLines[i] = line
    end
    if totalTargets > maxVisibleObjLines then
        objLines[maxVisibleObjLines] = string.format("... (+%d)", totalTargets - limit)
    end
    local discoveries = selectedQuest.discoveries or {}
    if #discoveries > 0 then
        local bullet = "|t16:16:/esoui/art/miscellaneous/bullet.dds|t "
        if isPrepared then
            local sumLine = Addon.Locale:Get("DISCOVERY_PREPARED_SUMMARY", #discoveries):gsub("^•%s*", bullet)
            table.insert(objLines, sumLine)
        else
            for _, d in ipairs(discoveries) do
                if d.discovered then
                    local clueLine = Addon.Locale:Get("DISCOVERY_CLUE_FORMAT", d.message or ""):gsub("^•%s*", bullet)
                    table.insert(objLines, clueLine)
                end
            end
        end
    end
    if selectedQuest.requireUndetected then
        local stealthKey = selectedQuest.wasDetected and "STEALTH_STATUS_DETECTED" or "STEALTH_STATUS_UNDETECTED"
        table.insert(objLines, "|t16:16:/esoui/art/miscellaneous/bullet.dds|t " .. Addon.Locale:Get(stealthKey))
    end
    if isPrepared then
        local bullet = "|t16:16:/esoui/art/miscellaneous/bullet.dds|t "
        if selectedQuest.clue and selectedQuest.clue ~= "" then
            local clueLine = Addon.Locale:Get("DIALOGUE_DETAIL_CLUE_FORMAT", selectedQuest.clue):gsub("^•%s*", bullet)
            table.insert(objLines, clueLine)
        end
        local dialogues = selectedQuest.dialogues or {}
        if #dialogues > 0 then
            local maxNpcs = (Addon.Constants and Addon.Constants.DIALOGUE and Addon.Constants.DIALOGUE.MAX_NPCS) or 3
            local dlgLine = Addon.Locale:Get("DIALOGUE_DETAIL_NPCS_FORMAT", #dialogues, maxNpcs):gsub("^•%s*", bullet)
            table.insert(objLines, dlgLine)
        end
        if selectedQuest.hideMapArea then
            local mapHiddenLine = Addon.Locale:Get("DIALOGUE_DETAIL_MAP_HIDDEN"):gsub("^•%s*", bullet)
            table.insert(objLines, mapHiddenLine)
        end
    end
    local visibleLineCount = #objLines
    self.detailObjText:SetDimensions(495, 0)
    self.detailObjText:SetText(table.concat(objLines, "\n"))
    local textHeight = self.detailObjText.GetTextHeight and self.detailObjText:GetTextHeight()
    local objHeight = textHeight and (textHeight + 16) or (visibleLineCount * 24)
    self.detailObjText:SetDimensions(495, math.max(32, objHeight))
    if self.detailScrollChild and self.detailScrollChild.SetDimensions then
        self.detailScrollChild:SetDimensions(526, math.max(650, 540 + objHeight))
    end

    self.codeDivider:SetHidden(false)
    local shareCode = Addon.QuestRepository:ExportQuestToCode(selectedQuest.id) or ""
    if not self.shareEdit._focused and self.shareEdit:GetText() ~= shareCode then
        SetReadOnlyEditText(self.shareEdit, shareCode)
    end
    self.shareHeader:SetText(Addon.Locale:Get("LABEL_SHARE_CODE_HEADER"))
    self.shareHeader:SetHidden(false)
    self.shareBg:SetHidden(false)

    if self.showOnMapKeybindButton then
        local canShowMap = not selectedQuest.hideMapArea and selectedQuest.mapId and selectedQuest.mapId > 0 and selectedQuest.areaCenterX and selectedQuest.areaCenterY
        self.showOnMapKeybindButton:SetHidden(not canShowMap)
    end
    self.btnReset:ClearAnchors()
    self.codeDivider:ClearAnchors()
    if isPrepared then
        self.btnActivate:SetHidden(false)
        self.btnEdit:SetHidden(false)
        self.btnReset:SetAnchor(TOPLEFT, self.btnActivate, BOTTOMLEFT, 0, 10)
        self.btnReset:SetHidden(false)
        self.codeDivider:SetAnchor(TOPLEFT, self.btnActivate, BOTTOMLEFT, 0, 48)
        self.deliveryHeader:SetHidden(true)
        self.deliveryBg:SetHidden(true)
        self.validateHeader:SetHidden(false)
        self.validateBg:SetHidden(false)
        self.btnValidateDelivery:SetHidden(false)
        self.validateResultLabel:SetHidden(false)
    else
        local showCompletion = selectedQuest.completed and true or false
        self.btnActivate:SetHidden(showCompletion)
        self.btnEdit:SetHidden(true)
        self.btnReset:SetHidden(true)
        if showCompletion then
            self.codeDivider:SetAnchor(TOPLEFT, self.detailObjText, BOTTOMLEFT, -25, 16)
        else
            self.codeDivider:SetAnchor(TOPLEFT, self.btnActivate, BOTTOMLEFT, 0, 14)
        end
        self.validateHeader:SetHidden(true)
        self.validateBg:SetHidden(true)
        self.btnValidateDelivery:SetHidden(true)
        self.validateResultLabel:SetHidden(true)
        self.deliveryHeader:SetHidden(not showCompletion)
        self.deliveryBg:SetHidden(not showCompletion)
        if showCompletion then
            local deliveryCode = Addon.QuestRepository:ExportCompletionCode(selectedQuest.id) or ""
            if not self.deliveryEdit._focused and self.deliveryEdit:GetText() ~= deliveryCode then
                SetReadOnlyEditText(self.deliveryEdit, deliveryCode)
            end
        else
            SetReadOnlyEditText(self.deliveryEdit, "")
        end
    end
    if KEYBIND_STRIP and self.keybindStripDescriptor then
        KEYBIND_STRIP:UpdateKeybindButtonGroup(self.keybindStripDescriptor)
    end
end

function JournalTab:ToggleEditorSection(sectionKey)
    if not sectionKey then return end
    self.editorSectionsCollapsed = self.editorSectionsCollapsed or {}
    self.editorSectionsCollapsed[sectionKey] = not self.editorSectionsCollapsed[sectionKey]
    self:LayoutEditorSections()
end

function JournalTab:LayoutEditorSections()
    if not self.editorSections or not self.editorFormParent then return end
    local draft = Addon.QuestRepository and Addon.QuestRepository:GetDraft() or {}
    local collapsedMap = self.editorSectionsCollapsed or {}
    local y = 172

    local function GetSectionBadge(key)
        if key == "target" then
            local count = #(draft.targets or {})
            return count > 0 and string.format("  |c33FF33[%d]|r", count) or ""
        elseif key == "discovery" then
            local count = #(draft.discoveries or {})
            return count > 0 and string.format("  |c33FF33[%d]|r", count) or ""
        elseif key == "dialogue" then
            local count = #(draft.dialogues or {})
            if count > 0 then
                return string.format("  |c33FF33[%d/3]|r", count)
            elseif (draft.clue or "") ~= "" then
                return "  |c33FF33[*]|r"
            end
            return ""
        elseif key == "options" then
            if (draft.completionMessage or "") ~= "" or draft.requireUndetected then
                return "  |c33FF33[*]|r"
            end
            return ""
        end
        return ""
    end

    for _, sec in ipairs(self.editorSections) do
        local isCollapsed = collapsedMap[sec.key] and true or false
        local arrowTex = isCollapsed and "/esoui/art/buttons/tree_closed_up.dds" or "/esoui/art/buttons/tree_open_up.dds"
        local titleColor = isCollapsed and "|cC5C29E" or "|cFFFFFF"
        local badge = GetSectionBadge(sec.key)

        sec.divider:ClearAnchors()
        sec.divider:SetAnchor(TOPLEFT, self.editorFormParent, TOPLEFT, 0, y)

        sec.headerBtn:ClearAnchors()
        sec.headerBtn:SetAnchor(TOPLEFT, self.editorFormParent, TOPLEFT, 0, y + 8)
        sec.headerBtn:SetText(string.format(" |t22:22:%s|t %s%s|r%s", arrowTex, titleColor, Addon.Locale:Get(sec.localeKey), badge))

        sec.body:SetHidden(isCollapsed)
        if isCollapsed then
            y = y + 54
        else
            y = y + 44 + sec.bodyHeight + 22
        end
    end

    if self.editorScrollChild then
        self.editorScrollChild:SetDimensions(526, math.max(474, y + 8))
    end
end

function JournalTab:RefreshEditorPane()
    local draft = Addon.QuestRepository:GetDraft()

    if draft.editingQuestId then
        self.editorHeader:SetText(Addon.Locale:Get("EDITOR_EDIT_TITLE"))
    else
        self.editorHeader:SetText(Addon.Locale:Get("EDITOR_CREATE_TITLE"))
    end

    local draftTitle = draft.title or ""
    if not self.titleEdit._focused and self.titleEdit:GetText() ~= draftTitle then
        self.titleEdit:SetText(draftTitle)
    end
    local draftDesc = draft.description or ""
    if not self.descEdit._focused and self.descEdit:GetText() ~= draftDesc then
        self.descEdit:SetText(draftDesc)
    end
    local draftClue = draft.clue or ""
    if self.clueEdit and not self.clueEdit._focused and self.clueEdit:GetText() ~= draftClue then
        self.clueEdit:SetText(draftClue)
    end
    local draftCompMsg = draft.completionMessage or ""
    if self.completionEdit and not self.completionEdit._focused and self.completionEdit:GetText() ~= draftCompMsg then
        self.completionEdit:SetText(draftCompMsg)
    end

    local targets = draft.targets or {}
    local summary = Addon.QuestRepository:FormatTargetsSummary(targets)
    if summary ~= "" then
        local locName = (draft.mapName and draft.mapName ~= "" and draft.mapName)
            or Addon.Locale:Get("LABEL_UNKNOWN_LOCATION")
        self.lblCapturedTarget:SetText(Addon.Locale:Get("TARGET_CAPTURED_FORMAT", summary, locName))
        self.btnClearTargets:SetHidden(false)
    else
        self.lblCapturedTarget:SetText(Addon.Locale:Get("TARGET_NOT_CAPTURED"))
        self.btnClearTargets:SetHidden(true)
    end

    if self.btnShowMapEditor then
        local hasDraftArea = summary ~= "" and not draft.hideMapArea and draft.mapId and draft.mapId > 0 and draft.areaCenterX and draft.areaCenterY
        self.btnShowMapEditor:SetHidden(not hasDraftArea)
    end

    local radii = Addon.Constants.AREA_RADIUS
    local curRad = draft.areaRadius or radii.MEDIUM

    local function FormatSelected(label, isSelected)
        if isSelected then
            return "|c33FF33[" .. label .. "]|r"
        end
        return label
    end

    self.btnRadiusSmall:SetText(FormatSelected(Addon.Locale:Get("BTN_RADIUS_SMALL"), math.abs(curRad - radii.SMALL) < 0.005))
    self.btnRadiusMedium:SetText(FormatSelected(Addon.Locale:Get("BTN_RADIUS_MEDIUM"), math.abs(curRad - radii.MEDIUM) < 0.005))
    self.btnRadiusLarge:SetText(FormatSelected(Addon.Locale:Get("BTN_RADIUS_LARGE"), math.abs(curRad - radii.LARGE) < 0.005))

    local discoveries = draft.discoveries or {}
    local totalDisc = #discoveries
    if totalDisc > 0 then
        if not self.selectedDiscoveryIndex or self.selectedDiscoveryIndex < 1 or self.selectedDiscoveryIndex > totalDisc then
            self.selectedDiscoveryIndex = totalDisc
        end
    else
        self.selectedDiscoveryIndex = nil
    end

    local selectedPoint = self.selectedDiscoveryIndex and discoveries[self.selectedDiscoveryIndex] or nil
    local activeDiscMsg = selectedPoint and (selectedPoint.message or "") or (draft.discoveryMessage or "")
    if self.discoveryMsgEdit and not self.discoveryMsgEdit._focused and self.discoveryMsgEdit:GetText() ~= activeDiscMsg then
        self.discoveryMsgEdit:SetText(activeDiscMsg)
    end

    local discRadii = Addon.Constants.DISCOVERY_RADIUS
    local curDiscRad = (selectedPoint and selectedPoint.radius) or draft.discoveryRadius or discRadii.MEDIUM
    if self.btnDiscRadSmall then
        self.btnDiscRadSmall:SetText(FormatSelected(Addon.Locale:Get("BTN_DISCOVERY_RAD_SMALL"), curDiscRad == discRadii.SMALL))
    end
    if self.btnDiscRadMedium then
        self.btnDiscRadMedium:SetText(FormatSelected(Addon.Locale:Get("BTN_DISCOVERY_RAD_MEDIUM"), curDiscRad == discRadii.MEDIUM))
    end
    if self.btnDiscRadLarge then
        self.btnDiscRadLarge:SetText(FormatSelected(Addon.Locale:Get("BTN_DISCOVERY_RAD_LARGE"), curDiscRad == discRadii.LARGE))
    end

    local showSelector = totalDisc > 0
    if self.btnDiscPrev then self.btnDiscPrev:SetHidden(not showSelector) end
    if self.btnDiscNext then self.btnDiscNext:SetHidden(not showSelector) end
    if self.btnDiscRemove then self.btnDiscRemove:SetHidden(not showSelector) end
    if self.lblDiscIndex then
        self.lblDiscIndex:SetHidden(not showSelector)
        if showSelector then
            self.lblDiscIndex:SetText(Addon.Locale:Get("DISCOVERY_INDEX_FORMAT", self.selectedDiscoveryIndex, totalDisc))
        end
    end

    if self.lblCapturedDiscoveries then
        if totalDisc > 0 then
            local msgs = {}
            for i = 1, math.min(2, totalDisc) do
                table.insert(msgs, discoveries[i].message or "")
            end
            local preview = table.concat(msgs, " | ")
            if totalDisc > 2 then
                preview = preview .. string.format(" (+%d)", totalDisc - 2)
            end
            self.lblCapturedDiscoveries:SetText(Addon.Locale:Get("DISCOVERY_CAPTURED_FORMAT", totalDisc, preview))
        else
            self.lblCapturedDiscoveries:SetText(Addon.Locale:Get("DISCOVERY_NONE_CAPTURED"))
        end
    end
    if self.btnClearDiscoveries then
        self.btnClearDiscoveries:SetHidden(totalDisc == 0)
    end

    if self.btnHideMapArea then
        local hideKey = draft.hideMapArea and "OPT_HIDE_MAP_AREA_ACTIVE" or "OPT_HIDE_MAP_AREA"
        self.btnHideMapArea:SetText(Addon.Locale:Get(hideKey))
    end

    if self.lblLastNpc then
        local lastNpc = Addon.QuestRepository:GetLastInteractedNpc()
        if lastNpc and lastNpc.name and lastNpc.name ~= "" then
            self.lblLastNpc:SetText(Addon.Locale:Get("DIALOGUE_LAST_NPC_FORMAT", lastNpc.name))
        else
            self.lblLastNpc:SetText(Addon.Locale:Get("DIALOGUE_NO_LAST_NPC"))
        end
    end

    local dialogues = draft.dialogues or {}
    local totalDlg = #dialogues
    local maxNpcs = (Addon.Constants and Addon.Constants.DIALOGUE and Addon.Constants.DIALOGUE.MAX_NPCS) or 3
    if totalDlg > 0 then
        if not self.selectedDialogueIndex or self.selectedDialogueIndex < 1 or self.selectedDialogueIndex > totalDlg then
            self.selectedDialogueIndex = totalDlg
        end
    else
        self.selectedDialogueIndex = nil
    end

    local selectedDlg = self.selectedDialogueIndex and dialogues[self.selectedDialogueIndex] or nil
    local activeDlgResp = selectedDlg and (selectedDlg.response or "") or ""
    if self.dlgResponseEdit and not self.dlgResponseEdit._focused and self.dlgResponseEdit:GetText() ~= activeDlgResp then
        self.dlgResponseEdit:SetText(activeDlgResp)
    end

    local showDlgSel = totalDlg > 0
    if self.btnDlgPrev then self.btnDlgPrev:SetHidden(not showDlgSel) end
    if self.btnDlgNext then self.btnDlgNext:SetHidden(not showDlgSel) end
    if self.btnDlgRemove then self.btnDlgRemove:SetHidden(not showDlgSel) end
    if self.lblDlgIndex then
        self.lblDlgIndex:SetHidden(not showDlgSel)
        if showDlgSel then
            self.lblDlgIndex:SetText(Addon.Locale:Get("DIALOGUE_INDEX_FORMAT", self.selectedDialogueIndex, totalDlg))
        end
    end
    if self.btnClearDialogues then
        self.btnClearDialogues:SetHidden(totalDlg == 0)
    end
    if self.lblCapturedDialogues then
        if totalDlg > 0 then
            local names = {}
            for _, d in ipairs(dialogues) do
                table.insert(names, d.npcName or "")
            end
            self.lblCapturedDialogues:SetText(Addon.Locale:Get("DIALOGUE_CAPTURED_FORMAT", totalDlg, maxNpcs, table.concat(names, ", ")))
        else
            self.lblCapturedDialogues:SetText(Addon.Locale:Get("DIALOGUE_NONE_CAPTURED"))
        end
    end

    if self.btnRequireUndetected then
        local key = draft.requireUndetected and "OPT_REQUIRE_UNDETECTED_ACTIVE" or "OPT_REQUIRE_UNDETECTED"
        self.btnRequireUndetected:SetText(Addon.Locale:Get(key))
    end

    self:LayoutEditorSections()
end
