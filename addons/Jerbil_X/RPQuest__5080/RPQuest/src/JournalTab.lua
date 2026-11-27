-- Ref: docs/adr/0003-integracion-nativa-ui-diario-mapa-y-hud.md
-- Ref: docs/adr/0004-objetivos-multiples-inferidos-por-reticula.md
-- Ref: docs/adr/0005-separacion-misiones-preparacion-y-juego.md
-- Ref: docs/adr/0006-puntos-de-descubrimiento-ocultos.md
-- Ref: docs/adr/0007-dialogos-inyectados-en-npcs-nativos.md
-- Ref: docs/adr/0015-separacion-ciclo-de-vida-y-estado-de-resolucion.md

RPQuest = RPQuest or {}
local Addon = RPQuest

Addon.JournalTab = {}
local JournalTab = Addon.JournalTab

local PANEL_NAME = Addon.JournalWidgets.PANEL_NAME
local MAX_VISIBLE_ROWS = 15
local ROW_HEIGHT = 28
local ROW_STEP = 30
local LIST_WIDTH = 320
local LIST_VIEWPORT_HEIGHT = 506
local QUEST_SECTIONS = { "pending", "missions", "completed", "preparing", "sent" }

local VIEW_MODE = {
    DETAIL = "DETAIL",
    EDITOR = "EDITOR",
    MAIL_SEND = "MAIL_SEND",
}
JournalTab.VIEW_MODE = VIEW_MODE

local CreateStyledButton = Addon.JournalWidgets.CreateStyledButton

local function IsValidSectionKey(sectionKey)
    if not sectionKey then return false end
    for _, key in ipairs(QUEST_SECTIONS) do
        if key == sectionKey then
            return true
        end
    end
    return false
end

local function SetSelectedQuestId(self, questId)
    self.selectedQuestId = questId
    if Addon.QuestRepository and Addon.QuestRepository.SetLastSelectedQuestId then
        Addon.QuestRepository:SetLastSelectedQuestId(questId)
    end
end

local function GetExpandedSectionKey(self)
    if not self.collapsedSections then return nil end
    for _, key in ipairs(QUEST_SECTIONS) do
        if self.collapsedSections[key] == false then
            return key
        end
    end
    return nil
end

local function ExpandOnlySection(self, sectionKey)
    if not sectionKey or not self.collapsedSections then return end
    for _, key in ipairs(QUEST_SECTIONS) do
        self.collapsedSections[key] = (key ~= sectionKey)
    end
    if Addon.QuestRepository and Addon.QuestRepository.SetLastSectionKey then
        Addon.QuestRepository:SetLastSectionKey(sectionKey)
    end
end

local function GetQuestSectionKey(quest)
    if not quest then return nil end
    if Addon.QuestRepository:IsPreparedQuest(quest) then
        local lifecycle = Addon.QuestRepository:GetQuestLifecycle(quest)
        return (lifecycle == Addon.Constants.QUEST_LIFECYCLE.DRAFT) and "preparing" or "sent"
    elseif Addon.QuestRepository:IsOfferedQuest(quest) then
        return "pending"
    elseif quest.completed then
        return "completed"
    end
    return "missions"
end

local function EnsureExpandedSectionWithQuests(self, buckets, activeQuest)
    if not self.collapsedSections then return end
    for _, key in ipairs(QUEST_SECTIONS) do
        if #buckets[key] > 0 and self.collapsedSections[key] == false then
            return
        end
    end

    local targetKey = nil
    if self.selectedQuestId then
        local selected = Addon.QuestRepository:GetQuestById(self.selectedQuestId)
        local selectedKey = GetQuestSectionKey(selected)
        if selectedKey and buckets[selectedKey] and #buckets[selectedKey] > 0 then
            targetKey = selectedKey
        end
    end

    if not targetKey and activeQuest then
        local activeKey = GetQuestSectionKey(activeQuest)
        if activeKey and buckets[activeKey] and #buckets[activeKey] > 0 then
            targetKey = activeKey
        end
    end

    if not targetKey then
        for _, key in ipairs(QUEST_SECTIONS) do
            if #buckets[key] > 0 then
                targetKey = key
                break
            end
        end
    end

    if targetKey then
        ExpandOnlySection(self, targetKey)
    end
end

function JournalTab:RegisterRepositoryListener()
    Addon.QuestRepository:RegisterListener(function(eventType, quest)
        if eventType == "QUEST_CREATED" or eventType == "QUEST_UPDATED" or eventType == "QUEST_SENT" then
            if quest and quest.id then
                ExpandOnlySection(self, GetQuestSectionKey(quest))
                self.listOffset = 0
                SetSelectedQuestId(self, quest.id)
            end
            self.viewMode = VIEW_MODE.DETAIL
        elseif eventType == "QUEST_DRAFT_CREATED" then
            if quest and quest.id then
                ExpandOnlySection(self, GetQuestSectionKey(quest))
                self.listOffset = 0
                SetSelectedQuestId(self, quest.id)
            end
            self.viewMode = VIEW_MODE.EDITOR
        elseif eventType == "QUEST_IMPORTED" or eventType == "QUEST_ACCEPTED" then
            if quest and quest.id then
                ExpandOnlySection(self, "missions")
                self.listOffset = 0
                SetSelectedQuestId(self, quest.id)
            end
            self.viewMode = VIEW_MODE.DETAIL
        elseif eventType == "QUEST_OFFERED" then
            if quest and quest.id then
                ExpandOnlySection(self, "pending")
                self.listOffset = 0
                if not self.selectedQuestId then
                    SetSelectedQuestId(self, quest.id)
                end
            end
        elseif eventType == "QUEST_DELETED" or eventType == "QUEST_REJECTED" then
            if quest and self.selectedQuestId == quest.id then
                SetSelectedQuestId(self, nil)
            end
            local draft = Addon.QuestRepository:GetDraft()
            if quest and (self.viewMode == VIEW_MODE.EDITOR or draft.editingQuestId == quest.id) then
                Addon.QuestRepository:ResetDraft()
                self:ClearEditorInputs()
                self.viewMode = VIEW_MODE.DETAIL
            end
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
end

function JournalTab:RestoreUiState()
    local uiState = Addon.QuestRepository and Addon.QuestRepository.GetJournalUiState and Addon.QuestRepository:GetJournalUiState() or {}
    local targetSection = IsValidSectionKey(uiState.lastSectionKey) and uiState.lastSectionKey or "missions"
    self.collapsedSections = {}
    for _, key in ipairs(QUEST_SECTIONS) do
        self.collapsedSections[key] = (key ~= targetSection)
    end
    local savedQuestId = uiState.lastSelectedQuestId
    if savedQuestId and Addon.QuestRepository and Addon.QuestRepository:GetQuestById(savedQuestId) then
        self.selectedQuestId = savedQuestId
    else
        self.selectedQuestId = nil
    end
end

function JournalTab:Initialize()
    if self.isInitialized then
        return
    end

    self.viewMode = VIEW_MODE.DETAIL
    self:RestoreUiState()
    self.editorSectionsCollapsed = {
        header = false,
        target = true,
        discovery = true,
        dialogue = true,
        options = true,
    }
    self.listOffset = 0

    local panel = WINDOW_MANAGER:CreateControl(PANEL_NAME, GuiRoot, CT_TOPLEVELCONTROL)
    panel:SetDimensions(980, 680)
    panel:SetAnchor(TOPLEFT, ZO_QuestJournal, TOPLEFT, 0, 0)
    panel:SetAnchor(BOTTOMRIGHT, ZO_QuestJournal, BOTTOMRIGHT, 0, 0)
    panel:SetHidden(true)
    panel:SetHandler("OnHide", function()
        self:AutoPreserveDraft()
    end)
    self.panel = panel

    self:BuildLeftColumn(panel)
    self:BuildRightColumn(panel)

    -- Use ZO_SimpleSceneFragment instead of ZO_FadeSceneFragment so ESO does not create
    -- per-instance animation OnStop closures in untrusted addon context (which taints
    -- transitions to protected scenes such as TamrielTomesSceneKeyboard).
    self.fragment = ZO_SimpleSceneFragment:New(panel)

    self:IntegrateIntoQuestJournalModeBar()
    self:RegisterRepositoryListener()

    if Addon.MailTransport and Addon.MailTransport.RegisterListener then
        Addon.MailTransport:RegisterListener(function(evType, payload)
            self:OnMailTransportEvent(evType, payload)
        end)
    end

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

    self.newBtn = CreateStyledButton(
        PANEL_NAME .. "_NewBtn",
        leftCol,
        320,
        28,
        Addon.Locale:Get("BTN_NEW_QUEST"),
        function()
            self:OpenCreateEditor()
        end
    )
    self.newBtn:SetAnchor(TOPLEFT, leftCol, TOPLEFT, 4, 4)

    local emptyLabel = WINDOW_MANAGER:CreateControl(PANEL_NAME .. "_EmptyList", leftCol, CT_LABEL)
    emptyLabel:SetDimensions(310, 80)
    emptyLabel:SetAnchor(TOPLEFT, leftCol, TOPLEFT, 4, 44)
    if emptyLabel.SetFont then emptyLabel:SetFont("ZoFontGame") end
    if emptyLabel.SetColor then emptyLabel:SetColor(0.75, 0.75, 0.75, 1) end
    emptyLabel:SetHidden(true)
    self.emptyLabel = emptyLabel

    self.rowBindings = {}
    self.accordionSections = {}

    local listViewport = WINDOW_MANAGER:CreateControl(PANEL_NAME .. "_ListViewport", leftCol, CT_SCROLL)
    listViewport:SetDimensions(LIST_WIDTH + 5, LIST_VIEWPORT_HEIGHT)
    listViewport:SetAnchor(TOPLEFT, leftCol, TOPLEFT, 0, 42)
    listViewport:SetHidden(true)
    self.listViewport = listViewport

    local listScrollChild = WINDOW_MANAGER:CreateControl(PANEL_NAME .. "_ListScrollChild", listViewport, CT_CONTROL)
    listScrollChild:SetDimensions(LIST_WIDTH, 1)
    listScrollChild:SetAnchor(TOPLEFT, listViewport, TOPLEFT, 0, 0)
    self.listScrollChild = listScrollChild

    for _, sectionKey in ipairs(QUEST_SECTIONS) do
        local headerBtn = WINDOW_MANAGER:CreateControl(PANEL_NAME .. "_SectionHeader_" .. sectionKey, listScrollChild, CT_BUTTON)
        headerBtn:SetDimensions(LIST_WIDTH, ROW_HEIGHT)
        if headerBtn.SetFont then headerBtn:SetFont("ZoFontHeader3") end
        if headerBtn.SetHorizontalAlignment then
            headerBtn:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
        end
        if headerBtn.SetVerticalAlignment then
            headerBtn:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        end
        local key = sectionKey
        headerBtn:SetHandler("OnClicked", function()
            PlaySound(SOUNDS.DEFAULT_CLICK)
            self:ToggleSection(key)
        end)
        headerBtn:SetHidden(true)

        local childContainer = WINDOW_MANAGER:CreateControl(PANEL_NAME .. "_SectionChildren_" .. sectionKey, listScrollChild, CT_SCROLL)
        childContainer:SetDimensions(LIST_WIDTH, 0)
        childContainer:SetHidden(true)

        local isOpen = (self.collapsedSections[sectionKey] == false)
        local timeline = ANIMATION_MANAGER:CreateTimelineFromVirtual("ZO_TreeOpenAnimation", childContainer)
        childContainer:SetAlpha(isOpen and 1 or 0)

        self.accordionSections[sectionKey] = {
            headerBtn = headerBtn,
            childContainer = childContainer,
            timeline = timeline,
            isOpen = isOpen,
            openPercentage = isOpen and 1 or 0,
            fullHeight = 0,
            hasQuests = false,
            rowPool = {},
        }
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

    local chkAutoOpen = Addon.JournalWidgets.CreateCheckButton(
        PANEL_NAME .. "_ChkAutoOpenOnReceive",
        leftCol,
        Addon.Locale:Get("CHK_AUTO_OPEN_ON_RECEIVE"),
        function(isChecked)
            if Addon.QuestRepository then
                Addon.QuestRepository:SetSetting("autoOpenJournalOnReceive", isChecked)
            end
        end
    )
    chkAutoOpen:SetAnchor(TOPLEFT, leftCol, TOPLEFT, 4, 590)
    local chkLabel = chkAutoOpen.GetNamedChild and chkAutoOpen:GetNamedChild("Label")
    if chkLabel and chkLabel.SetWidth then
        chkLabel:SetWidth(295)
    end
    ZO_CheckButton_SetCheckState(
        chkAutoOpen,
        Addon.QuestRepository and Addon.QuestRepository:GetSetting("autoOpenJournalOnReceive") == true
    )
    self.chkAutoOpenJournalOnReceive = chkAutoOpen
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
    self:BuildMailSendPane(rightCol)
end

function JournalTab:BuildDetailPane(parent)
    Addon.JournalDetailPane.Build(self, parent)
end

function JournalTab:BuildEditorPane(parent)
    Addon.JournalEditorPane.Build(self, parent)
end

function JournalTab:BuildMailSendPane(parent)
    Addon.JournalMailSendPane.Build(self, parent)
end

function JournalTab:OnMailTransportEvent(evType, payload)
    Addon.JournalMailSendPane.OnTransportEvent(self, evType, payload)
end

function JournalTab:AcceptSelectedOfferedQuest()
    if not self.selectedQuestId then return false end
    local ok, q = Addon.QuestRepository:AcceptOfferedQuest(self.selectedQuestId)
    if ok and q then
        Addon.Announcements:AnnounceQuestAccepted(q)
        return true
    end
    return false
end

function JournalTab:RejectSelectedOfferedQuest()
    if not self.selectedQuestId then return false end
    local ok, q = Addon.QuestRepository:RejectOfferedQuest(self.selectedQuestId)
    if ok and q then
        Addon.Announcements:ShowAlert(Addon.Locale:Get("ALERT_QUEST_REJECTED", q.title or ""), false)
        return true
    end
    return false
end

function JournalTab:SendSelectedPreparedQuest()
    return Addon.JournalMailSendPane.SendSelectedPrepared(self)
end

function JournalTab:DuplicateSelectedQuest()
    if not self.selectedQuestId then return nil end
    local newQuest, err = Addon.QuestRepository:DuplicateQuest(self.selectedQuestId)
    if not newQuest then
        if err then
            Addon.Announcements:ShowAlert(err, true)
        end
        return nil
    end
    Addon.Announcements:ShowAlert(Addon.Locale:Get("ALERT_QUEST_COPIED", newQuest.title or ""), false)
    return newQuest
end

function JournalTab:MigrateSelectedQuest()
    if not self.selectedQuestId then return nil end
    local newQuest, err = Addon.QuestRepository:MigratePreparedQuest(self.selectedQuestId)
    if not newQuest then
        if err then
            Addon.Announcements:ShowAlert(err, true)
        end
        return nil
    end
    SetSelectedQuestId(self, newQuest.id)
    Addon.Announcements:ShowAlert(Addon.Locale:Get("ALERT_QUEST_MIGRATED", newQuest.title or ""), false)
    self:OpenEditEditor(newQuest.id)
    return newQuest
end

function JournalTab:OpenMailSendView()
    Addon.JournalMailSendPane.OpenView(self)
end

function JournalTab:RefreshMailSendCounter()
    Addon.JournalMailSendPane.RefreshCounter(self)
end

function JournalTab:OnConfirmSendMailClicked()
    Addon.JournalMailSendPane.OnConfirmSendClicked(self)
end

function JournalTab:IntegrateIntoQuestJournalModeBar()
    local qj = QUEST_JOURNAL_KEYBOARD or SYSTEMS:GetKeyboardObject("questJournal")
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

    local pendingRPQuestMode = false

    ZO_PreHook(qj, "OnShowing", function(qjSelf)
        if self._pendingRPQuestOpen then
            pendingRPQuestMode = true
            self._pendingRPQuestOpen = false
        else
            pendingRPQuestMode = false
            if qjSelf.mode == tabDescriptor then
                if qjSelf.SetMode then
                    qjSelf:SetMode(ZO_QUEST_JOURNAL_MODE.QUESTS)
                else
                    qjSelf.mode = ZO_QUEST_JOURNAL_MODE.QUESTS
                end
            end
        end
    end)

    ZO_PostHook(qj, "OnShowing", function(qjSelf)
        EnsureTabAdded()
        if pendingRPQuestMode then
            pendingRPQuestMode = false
            if qjSelf.SetMode then
                qjSelf:SetMode(tabDescriptor)
            else
                qjSelf.mode = tabDescriptor
            end
        end
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

    ZO_PostHook(qj, "OnHiding", function(qjSelf)
        if not self._pendingRPQuestOpen and qjSelf.mode == tabDescriptor then
            if qjSelf.SetMode then
                qjSelf:SetMode(ZO_QUEST_JOURNAL_MODE.QUESTS)
            else
                qjSelf.mode = ZO_QUEST_JOURNAL_MODE.QUESTS
            end
        end
    end)
end

function JournalTab:SyncEditorInputsToDraft()
    local draft = Addon.QuestRepository:GetDraft()
    local fields = {}
    if self.titleEdit then fields.title = self.titleEdit:GetText() end
    if self.descEdit then fields.description = self.descEdit:GetText() end
    if self.recipientEdit then fields.recipientAccount = self.recipientEdit:GetText() end
    if self.recipientCharEdit then fields.recipientCharacterName = self.recipientCharEdit:GetText() end
    if self.completionEdit then fields.completionMessage = self.completionEdit:GetText() end
    if next(fields) ~= nil then
        Addon.QuestRepository:UpdateDraftFields(fields, true)
    end
    local dlgIdx = self.selectedDialogueIndex
    if dlgIdx and draft.dialogues and draft.dialogues[dlgIdx] then
        local dlgFields = {}
        if self.clueEdit then dlgFields.clue = self.clueEdit:GetText() end
        if self.dlgResponseEdit then dlgFields.response = self.dlgResponseEdit:GetText() end
        Addon.QuestRepository:UpdateDraftDialogue(dlgIdx, dlgFields, true)
    end
    local discIdx = self.selectedDiscoveryIndex
    if discIdx and draft.discoveries and draft.discoveries[discIdx] and self.discoveryMsgEdit then
        Addon.QuestRepository:UpdateDraftDiscoveryPoint(discIdx, { message = self.discoveryMsgEdit:GetText() }, true)
    end
    local targetIdx = self.selectedTargetIndex
    if targetIdx and draft.targets and draft.targets[targetIdx] then
        local targetFields = {}
        if self.targetCustomEdit then targetFields.customMessage = self.targetCustomEdit:GetText() end
        if self.targetInLocEdit then targetFields.customMessageInLocation = self.targetInLocEdit:GetText() end
        if next(targetFields) ~= nil then
            Addon.QuestRepository:UpdateDraftTarget(targetIdx, targetFields, true)
        end
    end
end

function JournalTab:AutoPreserveDraft()
    if self.viewMode ~= VIEW_MODE.EDITOR then
        return nil
    end
    local draft = Addon.QuestRepository:GetDraft()
    if not draft or not draft.editingQuestId then
        return nil
    end
    self:SyncEditorInputsToDraft()
    return Addon.QuestRepository:CommitDraftChanges()
end

function JournalTab:SelectQuest(questId)
    self:AutoPreserveDraft()
    if Addon.QuestRepository:GetDraft().editingQuestId then
        Addon.QuestRepository:ResetDraft()
    end
    SetSelectedQuestId(self, questId)
    self.viewMode = VIEW_MODE.DETAIL
    if self.detailScroll and self.detailScroll.scroll and self.detailScroll.scroll.SetVerticalScroll then
        self.detailScroll.scroll:SetVerticalScroll(0)
    end
    self:Refresh()
end

local function ApplyDraftToEditor(self, draft)
    self.selectedDiscoveryIndex = nil
    self.titleEdit:SetText(draft.title or "")
    self.descEdit:SetText(draft.description or "")
    if self.recipientEdit then self.recipientEdit:SetText(draft.recipientAccount or "") end
    if self.recipientCharEdit then self.recipientCharEdit:SetText(draft.recipientCharacterName or "") end
    if self.clueEdit then self.clueEdit:SetText("") end
    self.completionEdit:SetText(draft.completionMessage or "")
    self.selectedDialogueIndex = (#(draft.dialogues or {}) > 0) and 1 or nil
    self.editorSectionsCollapsed = {
        header = false,
        target = true,
        discovery = true,
        dialogue = true,
        options = true,
    }
    self.viewMode = VIEW_MODE.EDITOR
    self:Refresh()
end

function JournalTab:OpenCreateEditor()
    self:AutoPreserveDraft()
    local newQuest = Addon.QuestRepository:CreateNewPreparedDraft()
    if newQuest then
        ExpandOnlySection(self, GetQuestSectionKey(newQuest))
        self.listOffset = 0
        SetSelectedQuestId(self, newQuest.id)
    end
    local draft = Addon.QuestRepository:GetDraft()
    ApplyDraftToEditor(self, draft)
end

function JournalTab:ToggleSection(sectionKey)
    if not sectionKey or not self.collapsedSections then return end
    if self.collapsedSections[sectionKey] == false then
        return
    end
    ExpandOnlySection(self, sectionKey)
    self.listOffset = 0
    self:RefreshQuestList()
end

function JournalTab:OpenEditEditor(questId)
    local quest = Addon.QuestRepository:GetQuestById(questId)
    local draft, err = Addon.QuestRepository:LoadQuestIntoDraft(questId)
    if not draft then
        if err then
            Addon.Announcements:ShowAlert(err, true)
        end
        return
    end
    if quest then
        ExpandOnlySection(self, GetQuestSectionKey(quest))
        self.listOffset = 0
        SetSelectedQuestId(self, quest.id)
    end
    ApplyDraftToEditor(self, draft)
end

function JournalTab:ClearEditorInputs()
    if self.titleEdit then self.titleEdit:SetText("") end
    if self.descEdit then self.descEdit:SetText("") end
    if self.recipientEdit then self.recipientEdit:SetText("") end
    if self.recipientCharEdit then self.recipientCharEdit:SetText("") end
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
    local recipientText = self.recipientEdit and self.recipientEdit:GetText() or ""
    local recipientCharText = self.recipientCharEdit and self.recipientCharEdit:GetText() or ""
    local compMsgText = self.completionEdit and self.completionEdit:GetText() or ""
    local draft = Addon.QuestRepository:GetDraft()
    local dlgIdx = self.selectedDialogueIndex
    if dlgIdx and draft.dialogues and draft.dialogues[dlgIdx] then
        local dlgFields = {}
        if self.clueEdit then dlgFields.clue = self.clueEdit:GetText() end
        if self.dlgResponseEdit then dlgFields.response = self.dlgResponseEdit:GetText() end
        Addon.QuestRepository:UpdateDraftDialogue(dlgIdx, dlgFields, true)
    end
    local discIdx = self.selectedDiscoveryIndex
    if discIdx and draft.discoveries and draft.discoveries[discIdx] and self.discoveryMsgEdit then
        Addon.QuestRepository:UpdateDraftDiscoveryPoint(discIdx, { message = self.discoveryMsgEdit:GetText() }, true)
    end

    local savedQuest, err = Addon.QuestRepository:SaveDraft(titleText, descText, nil, compMsgText, nil, recipientText, recipientCharText)
    if not savedQuest then
        if err then
            Addon.Announcements:ShowAlert(err, true)
        end
        return
    end

    self:ClearEditorInputs()

    Addon.Announcements:ShowAlert(Addon.Locale:Get("ALERT_QUEST_SAVED", savedQuest.title), false)
end

function JournalTab:OnToggleActiveClicked()
    local q = Addon.QuestRepository:GetQuestById(self.selectedQuestId)
    if not q then return end

    local activeQuest = Addon.QuestRepository:GetActiveQuest()
    local isPrepared = Addon.QuestRepository:IsPreparedQuest(q)
    if activeQuest and activeQuest.id == q.id then
        if isPrepared then
            Addon.QuestRepository:ResetQuest(q.id, { activate = false })
        else
            Addon.QuestRepository:SetActiveQuest(nil)
        end
    else
        local activated, errKey
        if q.completed or q.failed or isPrepared then
            activated, errKey = Addon.QuestRepository:ResetQuest(q.id)
        else
            activated, errKey = Addon.QuestRepository:SetActiveQuest(q.id)
        end
        if not activated then
            if errKey then
                Addon.Announcements:ShowAlert(Addon.Locale:Get(errKey), true)
            end
            return
        end
        if isPrepared then
            Addon.Announcements:AnnounceQuestAccepted(q)
        end
    end
end

function JournalTab:OnCompleteQuestClicked()
    local q = Addon.QuestRepository:GetQuestById(self.selectedQuestId)
    if not q then return end

    local ok, resolvedQuest, questFailed, failReason = Addon.QuestRepository:CompleteQuest(q.id)
    if questFailed and resolvedQuest then
        Addon.Announcements:AnnounceQuestFailed(resolvedQuest, nil, failReason)
    elseif ok and resolvedQuest then
        Addon.Announcements:AnnounceQuestCompleted(resolvedQuest)
    end
end

function JournalTab:ConfirmAbandonQuest(questId)
    local q = Addon.QuestRepository:GetQuestById(questId)
    if not q or (Addon.QuestRepository:IsOfferedQuest(q) and q.isTutorial ~= true) then return false end

    ZO_Dialogs_ShowDialog("RPQUEST_ABANDON_QUEST", { questId = questId }, { mainTextParams = { q.title or "" } })
    return true
end

function JournalTab:OpenTab()
    if not self.isInitialized then
        self:Initialize()
    end

    local qj = QUEST_JOURNAL_KEYBOARD or SYSTEMS:GetKeyboardObject("questJournal")
    self._pendingRPQuestOpen = true
    if qj and qj.SetMode then
        qj:SetMode(self.tabDescriptor or Addon.Constants.UI.TAB_DESCRIPTOR)
    end

    local wasShowing = SCENE_MANAGER:IsShowing("questJournal")

    SCENE_MANAGER:Show("questJournal")

    -- Solo seleccionar el fragmento de forma síncrona si questJournal ya está visible;
    -- si estamos transicionando desde otra escena (p. ej. Notificaciones o Correo),
    -- OnShowing lo seleccionará cuando la escena previa termine de ocultarse y libere su keybind strip.
    local isShowingNow = SCENE_MANAGER:IsShowing("questJournal")
    if wasShowing or isShowingNow then
        self._pendingRPQuestOpen = false
        if qj and qj.tabs and qj.tabs.SelectFragment and self.tabCategoryName then
            qj.tabs:SelectFragment(self.tabCategoryName)
        elseif self.panel then
            self.panel:SetHidden(false)
        end
    end

    if self._dirty then
        self:Refresh()
    end
end

function JournalTab:ToggleTab()
    if not self.isInitialized then
        self:Initialize()
    end

    local qj = QUEST_JOURNAL_KEYBOARD or SYSTEMS:GetKeyboardObject("questJournal")
    local sceneShowing = SCENE_MANAGER:IsShowing("questJournal")

    if sceneShowing and qj and qj.mode == (self.tabDescriptor or Addon.Constants.UI.TAB_DESCRIPTOR) then
        self:AutoPreserveDraft()
        SCENE_MANAGER:Hide("questJournal")
        if self.panel then
            self.panel:SetHidden(true)
        end
    else
        self:OpenTab()
    end
end

local SENT_RESOLUTION_LOCALE_KEYS = {
    accepted = "LIST_SENT_STATUS_ACCEPTED",
    rejected = "LIST_SENT_STATUS_REJECTED",
    completed = "LIST_SENT_STATUS_COMPLETED",
    failed = "LIST_SENT_STATUS_FAILED",
}

local function PartitionQuestsBySection(allQuests)
    local lifecycles = Addon.Constants.QUEST_LIFECYCLE
    local buckets = {
        pending = {},
        missions = {},
        completed = {},
        preparing = {},
        sent = {},
    }
    for _, q in ipairs(allQuests) do
        if Addon.QuestRepository:IsPreparedQuest(q) then
            local lifecycle = Addon.QuestRepository:GetQuestLifecycle(q)
            if lifecycle == lifecycles.DRAFT then
                table.insert(buckets.preparing, q)
            else
                table.insert(buckets.sent, q)
            end
        elseif Addon.QuestRepository:IsOfferedQuest(q) then
            table.insert(buckets.pending, q)
        elseif q.completed then
            table.insert(buckets.completed, q)
        else
            table.insert(buckets.missions, q)
        end
    end
    return buckets
end

local SECTION_DEFINITIONS = {
    { key = "pending", localeKey = "SECTION_PENDING_QUESTS", isCompleted = false },
    { key = "missions", localeKey = "SECTION_ACTIVE_QUESTS", isCompleted = false },
    { key = "completed", localeKey = "SECTION_COMPLETED_QUESTS", isCompleted = true },
    { key = "preparing", localeKey = "SECTION_PREPARED_QUESTS", isCompleted = false },
    { key = "sent", localeKey = "SECTION_SENT_QUESTS", isCompleted = false },
}

local function FormatSectionHeaderText(tab, sectionKey, localeKey, count)
    local isCollapsed = tab.collapsedSections and tab.collapsedSections[sectionKey]
    local arrowTex = isCollapsed and "/esoui/art/buttons/tree_closed_up.dds" or "/esoui/art/buttons/tree_open_up.dds"
    local headerColor = isCollapsed and "|cC5C29E" or "|cFFFFFF"
    return string.format("|t28:28:%s|t %s%s|r", arrowTex, headerColor, Addon.Locale:Get(localeKey, count))
end

local function FormatQuestRowText(tab, q, sectionKey, isCompleted, activeQuest)
    local isSelected = (tab.selectedQuestId == q.id)
    local prefix, selColor
    local suffix = ""
    if isCompleted then
        prefix = "      |t16:16:/esoui/art/cadwell/check.dds|t "
        selColor = isSelected and "|cFFFFFF" or "|c8899AA"
    elseif sectionKey == "sent" then
        local resolution = Addon.QuestRepository:GetQuestResolution(q)
        if resolution == "completed" then
            prefix = "      |t16:16:/esoui/art/cadwell/check.dds|t "
        else
            prefix = "          "
        end
        selColor = isSelected and "|cFFFFFF" or "|cC5C29E"
        local statusLocaleKey = (resolution and SENT_RESOLUTION_LOCALE_KEYS[resolution]) or "LIST_SENT_STATUS_SENT"
        suffix = Addon.Locale:Get(statusLocaleKey)
    elseif Addon.QuestRepository:IsOfferedQuest(q) then
        prefix = "      |t18:18:/esoui/art/mail/mail_tabicon_inbox_up.dds|t "
        selColor = isSelected and "|cFFFFFF" or "|cFFD155"
    else
        local isAct = (activeQuest and activeQuest.id == q.id)
        prefix = isAct and "      |t18:18:/esoui/art/journal/journal_quest_selected.dds|t " or "          "
        selColor = isSelected and "|cFFFFFF" or "|cC5C29E"
        if sectionKey == "missions" then
            local resolution = Addon.QuestRepository:GetQuestResolution(q)
            if resolution == "failed" then
                suffix = Addon.Locale:Get("LIST_FAILED_SUFFIX")
            end
        end
    end
    local iconTex = Addon.QuestDraftStore and Addon.QuestDraftStore:GetQuestIconTexture(q.icon) or nil
    local iconMarkup = iconTex and string.format("|t18:18:%s|t ", iconTex) or ""
    return prefix .. iconMarkup .. selColor .. (q.title or "") .. "|r", suffix
end

function JournalTab:EnsureAccordionRow(sectionKey, section, index)
    local rowBtn = section.rowPool[index]
    if rowBtn then
        return rowBtn
    end
    local rowName = PANEL_NAME .. "_SectionRow_" .. sectionKey .. "_" .. index
    rowBtn = WINDOW_MANAGER:CreateControl(rowName, section.childContainer, CT_BUTTON)
    rowBtn:SetDimensions(LIST_WIDTH, ROW_HEIGHT)
    rowBtn:SetAnchor(TOPLEFT, section.childContainer, TOPLEFT, 0, (index - 1) * ROW_STEP)

    local statusLabel = WINDOW_MANAGER:CreateControl(rowName .. "_Status", rowBtn, CT_LABEL)
    statusLabel:SetFont("ZoFontHeader")
    statusLabel:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    statusLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    statusLabel:SetMaxLineCount(1)
    statusLabel:SetAnchor(TOPRIGHT, rowBtn, TOPRIGHT, 0, 0)
    statusLabel:SetAnchor(BOTTOMRIGHT, rowBtn, BOTTOMRIGHT, 0, 0)
    statusLabel:SetHidden(true)

    local titleLabel = WINDOW_MANAGER:CreateControl(rowName .. "_Title", rowBtn, CT_LABEL)
    titleLabel:SetFont("ZoFontHeader")
    titleLabel:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    titleLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    titleLabel:SetMaxLineCount(1)
    titleLabel:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    titleLabel:SetAnchor(TOPLEFT, rowBtn, TOPLEFT, 0, 0)
    titleLabel:SetAnchor(BOTTOMRIGHT, rowBtn, BOTTOMRIGHT, 0, 0)

    rowBtn._statusLabel = statusLabel
    rowBtn._titleLabel = titleLabel

    rowBtn:SetHandler("OnClicked", function(ctrl)
        if ctrl._questId then
            PlaySound(SOUNDS.DEFAULT_CLICK)
            self:SelectQuest(ctrl._questId)
        end
    end)
    section.rowPool[index] = rowBtn
    return rowBtn
end

function JournalTab:UpdateAccordionLayout()
    if not self.accordionSections or not self.listScrollChild then return end
    local y = 0
    for _, sectionKey in ipairs(QUEST_SECTIONS) do
        local section = self.accordionSections[sectionKey]
        if section and section.hasQuests then
            section.headerBtn:ClearAnchors()
            section.headerBtn:SetAnchor(TOPLEFT, self.listScrollChild, TOPLEFT, 0, y)
            section.headerBtn:SetHidden(false)
            y = y + ROW_STEP

            local currentHeight = math.floor((section.fullHeight or 0) * (section.openPercentage or 0) + 0.5)
            section.childContainer:ClearAnchors()
            section.childContainer:SetAnchor(TOPLEFT, self.listScrollChild, TOPLEFT, 0, y)
            section.childContainer:SetDimensions(LIST_WIDTH, currentHeight)
            section.childContainer:SetHidden(currentHeight <= 0)
            y = y + currentHeight
        elseif section then
            section.headerBtn:SetHidden(true)
            section.childContainer:SetDimensions(LIST_WIDTH, 0)
            section.childContainer:SetHidden(true)
        end
    end
    self.listScrollChild:SetDimensions(LIST_WIDTH, math.max(1, y))
    if self.listViewport then
        self.listScrollChild:ClearAnchors()
        self.listScrollChild:SetAnchor(TOPLEFT, self.listViewport, TOPLEFT, 0, -((self.listOffset or 0) * ROW_STEP))
    end
end

function JournalTab:SetSectionOpenPercentage(sectionKey, openPercentage)
    local section = self.accordionSections and self.accordionSections[sectionKey]
    if not section then return end
    section.openPercentage = openPercentage
    self:UpdateAccordionLayout()
end

function JournalTab:AnimateSection(sectionKey, section, targetOpen)
    local timeline = section.timeline
    if self.panel:IsHidden() or (section.fullHeight or 0) == 0 then
        if timeline and timeline:IsPlaying() then
            timeline:Stop()
        end
        section.isOpen = targetOpen
        section.childContainer:SetAlpha(targetOpen and 1 or 0)
        self:SetSectionOpenPercentage(sectionKey, targetOpen and 1 or 0)
        return
    end

    section.isOpen = targetOpen
    if timeline:IsPlaying() then
        if targetOpen then
            timeline:PlayForward()
        else
            timeline:PlayBackward()
        end
    else
        local customAnim = timeline:GetFirstAnimation()
        customAnim:SetUpdateFunction(function(_, progress)
            self:SetSectionOpenPercentage(sectionKey, progress)
        end)
        local numAnimations = timeline:GetNumAnimations()
        for i = 2, numAnimations do
            timeline:GetAnimation(i):SetAnimatedControl(section.childContainer)
        end
        if targetOpen then
            customAnim:SetEasingFunction(ZO_EaseOutQuadratic)
            timeline:PlayFromStart()
        else
            customAnim:SetEasingFunction(ZO_EaseInQuadratic)
            timeline:PlayFromEnd()
        end
    end
end

function JournalTab:RefreshQuestList(allQuests, activeQuest)
    if not self.panel then return end

    allQuests = allQuests or Addon.QuestRepository:GetAllQuests()
    activeQuest = activeQuest or Addon.QuestRepository:GetActiveQuest()
    self.rowBindings = {}

    if #allQuests == 0 then
        self.listOffset = 0
        self._maxListOffset = 0
        self.emptyLabel:SetText(Addon.Locale:Get("EMPTY_QUEST_LIST"))
        self.emptyLabel:SetHidden(false)
        if self.listViewport then
            self.listViewport:SetHidden(true)
        end
        if self.accordionSections then
            for _, sectionKey in ipairs(QUEST_SECTIONS) do
                local section = self.accordionSections[sectionKey]
                if section then
                    section.hasQuests = false
                    section.fullHeight = 0
                    if section.timeline and section.timeline:IsPlaying() then
                        section.timeline:Stop()
                    end
                    section.headerBtn:SetHidden(true)
                    section.childContainer:SetHidden(true)
                end
            end
        end
        if self.btnListPrev then self.btnListPrev:SetHidden(true) end
        if self.btnListNext then self.btnListNext:SetHidden(true) end
        if self.scrollInfoLabel then self.scrollInfoLabel:SetHidden(true) end
        return
    end

    self.emptyLabel:SetHidden(true)
    if self.listViewport then
        self.listViewport:SetHidden(false)
    end

    local buckets = PartitionQuestsBySection(allQuests)
    EnsureExpandedSectionWithQuests(self, buckets, activeQuest)
    local displayRows = {}

    for _, def in ipairs(SECTION_DEFINITIONS) do
        local sectionKey = def.key
        local quests = buckets[sectionKey]
        local section = self.accordionSections and self.accordionSections[sectionKey]
        local hasQuests = (#quests > 0)
        local targetOpen = hasQuests and (self.collapsedSections[sectionKey] == false)

        if hasQuests then
            local headerText = FormatSectionHeaderText(self, sectionKey, def.localeKey, #quests)
            table.insert(displayRows, {
                isHeader = true,
                sectionKey = sectionKey,
                text = headerText,
            })

            if section then
                section.hasQuests = true
                section.fullHeight = #quests * ROW_STEP
                section.headerBtn:SetText(headerText)
                section.headerBtn:SetMouseEnabled(true)
            end

            for idx, q in ipairs(quests) do
                local titleText, suffixText = FormatQuestRowText(self, q, sectionKey, def.isCompleted, activeQuest)
                local rowText = titleText .. (suffixText or "")
                if not self.collapsedSections[sectionKey] then
                    table.insert(displayRows, {
                        isHeader = false,
                        questId = q.id,
                        text = rowText,
                    })
                end
                if section then
                    local rowBtn = self:EnsureAccordionRow(sectionKey, section, idx)
                    rowBtn._questId = q.id
                    rowBtn._titleLabel:SetText(titleText)
                    local trimmedSuffix = suffixText and suffixText:gsub("^%s+", "") or ""
                    rowBtn._titleLabel:ClearAnchors()
                    rowBtn._titleLabel:SetAnchor(TOPLEFT, rowBtn, TOPLEFT, 0, 0)
                    if trimmedSuffix ~= "" then
                        rowBtn._statusLabel:SetText(trimmedSuffix)
                        rowBtn._statusLabel:SetHidden(false)
                        rowBtn._titleLabel:SetAnchor(BOTTOMRIGHT, rowBtn._statusLabel, BOTTOMLEFT, -6, 0)
                    else
                        rowBtn._statusLabel:SetText("")
                        rowBtn._statusLabel:SetHidden(true)
                        rowBtn._titleLabel:SetAnchor(BOTTOMRIGHT, rowBtn, BOTTOMRIGHT, 0, 0)
                    end
                    rowBtn:SetMouseEnabled(true)
                    rowBtn:SetHidden(false)
                end
            end

            if section then
                for idx = #quests + 1, #section.rowPool do
                    section.rowPool[idx]._questId = nil
                    section.rowPool[idx]:SetHidden(true)
                end
            end
        elseif section then
            section.hasQuests = false
            section.fullHeight = 0
            for idx = 1, #section.rowPool do
                section.rowPool[idx]._questId = nil
                section.rowPool[idx]:SetHidden(true)
            end
        end

        if section then
            if targetOpen ~= section.isOpen then
                self:AnimateSection(sectionKey, section, targetOpen)
            elseif not (section.timeline and section.timeline:IsPlaying()) then
                section.openPercentage = targetOpen and 1 or 0
                section.childContainer:SetAlpha(section.openPercentage)
            end
        end
    end

    local maxOffset = math.max(0, #displayRows - MAX_VISIBLE_ROWS)
    self._maxListOffset = maxOffset
    self.listOffset = math.min(math.max(0, self.listOffset or 0), maxOffset)

    for i = 1, MAX_VISIBLE_ROWS do
        local rowData = displayRows[self.listOffset + i]
        if rowData then
            self.rowBindings[i] = rowData
        end
    end

    self:UpdateAccordionLayout()

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

function JournalTab:UpdateShowOnMapVisibility()
    if not self.showOnMapKeybindButton then return end
    if self.showOnMapKeybindButton.UpdateVisibility then
        self.showOnMapKeybindButton:UpdateVisibility()
    else
        local visible = self.showOnMapDescriptor and self.showOnMapDescriptor.visible
        local isVisible
        if type(visible) == "function" then
            isVisible = visible(self.showOnMapKeybindButton) ~= false
        else
            isVisible = visible ~= false
        end
        self.showOnMapKeybindButton:SetHidden(not isVisible)
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
            else
                local openKey = GetExpandedSectionKey(self)
                if openKey then
                    local buckets = PartitionQuestsBySection(allQuests)
                    if buckets[openKey] and buckets[openKey][1] then
                        selectedQuest = buckets[openKey][1]
                    end
                end
                if not selectedQuest and allQuests[1] then
                    selectedQuest = allQuests[1]
                end
            end
            SetSelectedQuestId(self, selectedQuest and selectedQuest.id or nil)
        end
    end

    -- 1. Actualizar columna izquierda
    self:RefreshQuestList(allQuests, activeQuest)
    if self.chkAutoOpenJournalOnReceive then
        ZO_CheckButton_SetCheckState(
            self.chkAutoOpenJournalOnReceive,
            Addon.QuestRepository and Addon.QuestRepository:GetSetting("autoOpenJournalOnReceive") == true
        )
    end

    -- 2. Actualizar columna derecha según el modo de vista
    self.detailPane:SetHidden(true)
    self.editorPane:SetHidden(true)
    if self.mailSendPane then self.mailSendPane:SetHidden(true) end

    if self.viewMode == VIEW_MODE.EDITOR then
        self.editorPane:SetHidden(false)
        self:RefreshEditorPane()
    elseif self.viewMode == VIEW_MODE.MAIL_SEND and self.mailSendPane then
        self.mailSendPane:SetHidden(false)
        self:RefreshMailSendCounter()
        self:UpdateShowOnMapVisibility()
        if self.keybindStripDescriptor then
            KEYBIND_STRIP:UpdateKeybindButtonGroup(self.keybindStripDescriptor)
        end
    else
        self.detailPane:SetHidden(false)
        self:RefreshDetailPane(selectedQuest, activeQuest)
    end
end

function JournalTab:RefreshDetailPane(selectedQuest, activeQuest)
    Addon.JournalDetailPane.Refresh(self, selectedQuest, activeQuest)
end

function JournalTab:ToggleEditorSection(sectionKey)
    Addon.JournalEditorPane.ToggleSection(self, sectionKey)
end

function JournalTab:LayoutEditorSections()
    Addon.JournalEditorPane.LayoutSections(self)
end

function JournalTab:RefreshEditorPane()
    Addon.JournalEditorPane.Refresh(self)
    self:UpdateShowOnMapVisibility()
    if self.keybindStripDescriptor then
        KEYBIND_STRIP:UpdateKeybindButtonGroup(self.keybindStripDescriptor)
    end
end
