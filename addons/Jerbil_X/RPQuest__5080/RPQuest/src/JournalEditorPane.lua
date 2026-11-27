-- Ref: docs/adr/0001-arquitectura-modular-zero-dependency-y-savedvars-por-personaje.md
-- Ref: docs/adr/0003-integracion-nativa-ui-diario-mapa-y-hud.md
-- Ref: docs/adr/0004-objetivos-multiples-inferidos-por-reticula.md
-- Ref: docs/adr/0006-puntos-de-descubrimiento-ocultos.md
-- Ref: docs/adr/0007-dialogos-inyectados-en-npcs-nativos.md
-- Ref: docs/adr/0014-areas-por-objetivo-mensajes-eliminacion-y-visibilidad-mapa.md
-- Ref: docs/adr/0016-limites-texto-y-entidades-presupuesto-correo.md

RPQuest = RPQuest or {}
local Addon = RPQuest

Addon.JournalEditorPane = {}
local EditorPane = Addon.JournalEditorPane

function EditorPane.Build(tab, parent)
    local EditorSections = Addon.JournalEditorSections
    local panelName = Addon.JournalWidgets.PANEL_NAME
    local pane = WINDOW_MANAGER:CreateControl(panelName .. "_EditorPane", parent, CT_CONTROL)
    pane:SetDimensions(550, 580)
    pane:SetAnchor(TOPLEFT, parent, TOPLEFT, 0, 0)
    pane:SetHidden(true)
    tab.editorPane = pane

    local header = WINDOW_MANAGER:CreateControl(panelName .. "_EditorHeader", pane, CT_LABEL)
    header:SetAnchor(TOPLEFT, pane, TOPLEFT, 0, 0)
    if header.SetFont then header:SetFont("ZoFontWinH2") end
    if header.SetColor then header:SetColor(0.95, 0.88, 0.65, 1) end
    tab.editorHeader = header

    local formParent = pane
    local scrollContainer = WINDOW_MANAGER.CreateControlFromVirtual
        and WINDOW_MANAGER:CreateControlFromVirtual(panelName .. "_EditorScroll", pane, "ZO_ScrollContainer")
    if scrollContainer then
        scrollContainer:SetAnchor(TOPLEFT, pane, TOPLEFT, 0, 32)
        scrollContainer:SetDimensions(550, 474)
        local scrollChild = scrollContainer.GetNamedChild and scrollContainer:GetNamedChild("ScrollChild")
        if scrollChild then
            scrollChild:SetDimensions(526, 474)
            formParent = scrollChild
            tab.editorScrollChild = scrollChild
        end
        tab.editorScroll = scrollContainer
    end
    tab.editorFormParent = formParent

    tab.editorSections = {}
    tab.editorSectionsByKey = {}

    local headerSec = EditorSections.CreateAccordionSection(tab, formParent, panelName, "header", "LABEL_HEADER_SECTION", 284)
    EditorSections.BuildBaseFields(tab, headerSec.body, panelName)

    local optionsSec = EditorSections.CreateAccordionSection(tab, formParent, panelName, "options", "LABEL_OPTIONS_SECTION", 186)
    EditorSections.BuildOptionsSection(tab, optionsSec.body, panelName)

    local targetSec = EditorSections.CreateAccordionSection(tab, formParent, panelName, "target", "LABEL_TARGET_SECTION", 364)
    EditorSections.BuildTargetAreaControls(tab, targetSec.body, panelName)
    EditorSections.BuildTargetConfigControls(tab, targetSec.body, panelName)

    local discoverySec = EditorSections.CreateAccordionSection(tab, formParent, panelName, "discovery", "LABEL_DISCOVERY_SECTION", 184)
    EditorSections.BuildDiscoveryControls(tab, discoverySec.body, panelName)
    EditorSections.BuildDiscoveryInputs(tab, discoverySec.body, panelName)

    local dialogueSec = EditorSections.CreateAccordionSection(tab, formParent, panelName, "dialogue", "LABEL_DIALOGUE_SECTION", 300)
    EditorSections.BuildDialogueControls(tab, dialogueSec.body, panelName)
    EditorSections.BuildDialogueInputs(tab, dialogueSec.body, panelName)

    EditorPane.LayoutSections(tab)
    EditorSections.BuildFooterButtons(tab, pane, panelName)

    Addon.JournalWidgets.RegisterTabChain({
        tab.titleEdit,
        tab.descEdit,
        tab.recipientEdit,
        tab.recipientCharEdit,
        tab.completionEdit,
        tab.targetCustomEdit,
        tab.discoveryMsgEdit,
        tab.clueEdit,
        tab.dlgResponseEdit,
    }, tab.editorScroll)
end

local function GetSectionBadge(draft, key)
    if key == "target" then
        local count = #(draft.targets or {})
        local maxTargets = (Addon.Constants and Addon.Constants.TARGET and Addon.Constants.TARGET.MAX_TARGETS) or 4
        return count > 0 and string.format("  |c33FF33[%d/%d]|r", count, maxTargets) or ""
    elseif key == "discovery" then
        local count = #(draft.discoveries or {})
        local maxPoints = (Addon.Constants and Addon.Constants.DISCOVERY and Addon.Constants.DISCOVERY.MAX_POINTS) or 10
        if count > 0 then
            if Addon.QuestRepository:HasMissingDiscoveryMessage(draft) then
                return string.format("  |cFF5555[%d/%d !]|r", count, maxPoints)
            end
            return string.format("  |c33FF33[%d/%d]|r", count, maxPoints)
        end
        return ""
    elseif key == "dialogue" then
        local count = #(draft.dialogues or {})
        local maxNpcs = (Addon.Constants and Addon.Constants.DIALOGUE and Addon.Constants.DIALOGUE.MAX_NPCS) or 4
        if count > 0 then
            return string.format("  |c33FF33[%d/%d]|r", count, maxNpcs)
        elseif (draft.clue or "") ~= "" then
            return "  |c33FF33[*]|r"
        end
        return ""
    elseif key == "options" then
        local modes = Addon.Constants.STEALTH_MODE
        local stealthMode = draft.stealthMode or modes.DISABLED
        if (draft.completionMessage or "") ~= "" or stealthMode ~= modes.DISABLED or draft.recommendHideMapAreas == false then
            return "  |c33FF33[*]|r"
        end
        return ""
    end
    return ""
end

function EditorPane.LayoutSections(tab)
    if not tab.editorSections or not tab.editorFormParent then return end
    local draft = Addon.QuestRepository and Addon.QuestRepository:GetDraft() or {}
    local collapsedMap = tab.editorSectionsCollapsed or {}
    local y = 0

    for _, sec in ipairs(tab.editorSections) do
        local isCollapsed = collapsedMap[sec.key] and true or false
        local arrowTex = isCollapsed and "/esoui/art/buttons/tree_closed_up.dds" or "/esoui/art/buttons/tree_open_up.dds"
        local titleColor = isCollapsed and "|cC5C29E" or "|cFFFFFF"
        local badge = GetSectionBadge(draft, sec.key)

        sec.divider:ClearAnchors()
        sec.divider:SetAnchor(TOPLEFT, tab.editorFormParent, TOPLEFT, 0, y)

        sec.headerBtn:ClearAnchors()
        sec.headerBtn:SetAnchor(TOPLEFT, tab.editorFormParent, TOPLEFT, 0, y + 8)
        sec.headerBtn:SetText(string.format(" |t22:22:%s|t %s%s|r%s", arrowTex, titleColor, Addon.Locale:Get(sec.localeKey), badge))

        local openPct = sec.openPercentage
        if openPct == nil then
            openPct = isCollapsed and 0 or 1
        end
        local currentHeight = math.floor((sec.bodyHeight or 0) * openPct + 0.5)
        if currentHeight <= 0 then
            sec.body:SetDimensions(510, 0)
            sec.body:SetHidden(true)
            y = y + 54
        else
            local extraPad = math.floor(12 * openPct + 0.5)
            sec.body:SetDimensions(510, currentHeight)
            sec.body:SetHidden(false)
            y = y + 54 + currentHeight + extraPad
        end
    end

    if tab.editorScrollChild then
        tab.editorScrollChild:SetDimensions(526, math.max(474, y + 8))
    end
end

local function SetSectionOpenPercentage(tab, sec, openPercentage)
    sec.openPercentage = openPercentage
    EditorPane.LayoutSections(tab)
end

local function SnapSectionState(sec, targetOpen)
    local timeline = sec.timeline
    if timeline and timeline:IsPlaying() then
        timeline:Stop()
    end
    sec.isOpen = targetOpen
    sec.openPercentage = targetOpen and 1 or 0
    sec.body:SetAlpha(sec.openPercentage)
end

local function AnimateSection(tab, sec, targetOpen)
    local timeline = sec.timeline
    local isHidden = (tab.panel and tab.panel:IsHidden()) or (tab.editorPane and tab.editorPane:IsHidden())
    if not timeline or isHidden or (sec.bodyHeight or 0) == 0 then
        SnapSectionState(sec, targetOpen)
        return
    end

    sec.isOpen = targetOpen
    if timeline:IsPlaying() then
        if targetOpen then
            timeline:PlayForward()
        else
            timeline:PlayBackward()
        end
    else
        local customAnim = timeline:GetFirstAnimation()
        customAnim:SetUpdateFunction(function(_, progress)
            SetSectionOpenPercentage(tab, sec, progress)
        end)
        local numAnimations = timeline:GetNumAnimations()
        for i = 2, numAnimations do
            timeline:GetAnimation(i):SetAnimatedControl(sec.body)
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

function EditorPane.ToggleSection(tab, sectionKey)
    if not sectionKey then return end
    tab.editorSectionsCollapsed = tab.editorSectionsCollapsed or {}
    local willOpen = tab.editorSectionsCollapsed[sectionKey] and true or false
    if willOpen then
        for _, sec in ipairs(tab.editorSections or {}) do
            tab.editorSectionsCollapsed[sec.key] = (sec.key ~= sectionKey)
        end
    else
        tab.editorSectionsCollapsed[sectionKey] = true
    end

    for _, sec in ipairs(tab.editorSections or {}) do
        local targetOpen = not tab.editorSectionsCollapsed[sec.key]
        if targetOpen ~= sec.isOpen then
            AnimateSection(tab, sec, targetOpen)
        end
    end
    EditorPane.LayoutSections(tab)
end

local function SyncUnfocusedEdit(editCtrl, text)
    if editCtrl and not editCtrl._focused and editCtrl:GetText() ~= text then
        editCtrl:SetText(text)
        if editCtrl._updateScrollbar then
            editCtrl._updateScrollbar()
        end
    end
end

local function RefreshEditorBaseAndArea(tab, draft)
    tab.editorHeader:SetText(Addon.Locale:Get(draft.editingQuestId and "EDITOR_EDIT_TITLE" or "EDITOR_CREATE_TITLE"))
    SyncUnfocusedEdit(tab.titleEdit, draft.title or "")
    SyncUnfocusedEdit(tab.descEdit, draft.description or "")
    SyncUnfocusedEdit(tab.recipientEdit, draft.recipientAccount or "")
    SyncUnfocusedEdit(tab.recipientCharEdit, draft.recipientCharacterName or "")
    SyncUnfocusedEdit(tab.completionEdit, draft.completionMessage or "")
    if tab.senderCharComboBox then
        local targetSender = Addon.QuestRepository:NormalizeCharacterName(draft.senderCharacterName)
        if targetSender == "" then
            targetSender = Addon.QuestRepository:GetPlayerCharacterName()
        end
        local charNames = Addon.QuestRepository:GetAccountCharacterNames()
        local hasTarget = false
        for _, name in ipairs(charNames) do
            if name == targetSender then
                hasTarget = true
                break
            end
        end
        if targetSender ~= "" and not hasTarget then
            table.insert(charNames, 1, targetSender)
        end

        local combo = tab.senderCharComboBox
        combo:ClearItems()
        for _, charName in ipairs(charNames) do
            local entry = combo:CreateItemEntry(charName, function()
                Addon.QuestRepository:UpdateDraftFields({ senderCharacterName = charName })
            end)
            entry.senderCharacterName = charName
            combo:AddItem(entry)
        end
        combo:SetEnabled(#charNames > 0)
        if targetSender ~= "" then
            combo:SetSelectedItemByEval(function(item)
                return item.senderCharacterName == targetSender
            end, true)
        end
    end
    if tab.questIconComboBox then
        local targetIcon = Addon.QuestDraftStore:NormalizeQuestIcon(draft.icon) or ""
        local selected = tab.questIconComboBox:GetSelectedItemData()
        if not selected or selected.questIconId ~= targetIcon then
            tab.questIconComboBox:SetSelectedItemByEval(function(item)
                return item.questIconId == targetIcon
            end, true)
        end
    end
end

local function SetButtonEnabled(btn, enabled)
    if not btn then return end
    if btn.SetEnabled then btn:SetEnabled(enabled) end
    if btn.SetAlpha then btn:SetAlpha(enabled and 1 or 0.45) end
end

local function RefreshTargetDropdown(tab, targets, hasTargets)
    local combo = tab.targetComboBox
    if not combo then return end
    combo:ClearItems()
    if hasTargets then
        for i, t in ipairs(targets) do
            local label = Addon.QuestRepository:FormatTargetEntry(t)
            local entry = combo:CreateItemEntry(label, function()
                tab.selectedTargetIndex = i
                tab:RefreshEditorPane()
            end)
            entry.targetIndex = i
            combo:AddItem(entry)
        end
        combo:SetEnabled(true)
        combo:SetSelectedItemByEval(function(item)
            return item.targetIndex == tab.selectedTargetIndex
        end, true)
    else
        combo:SetEnabled(false)
        combo:SetSelectedItemText(Addon.Locale:Get("TARGET_NOT_CAPTURED"))
    end
end

local function RefreshTargetMessageControls(tab, selTarget, hasTargets)
    Addon.JournalWidgets.SetEditBoxEnabled(tab.targetCustomBg, tab.targetCustomEdit, hasTargets)
    SyncUnfocusedEdit(tab.targetCustomEdit, selTarget and selTarget.customMessage or "")

    Addon.JournalWidgets.SetEditBoxEnabled(tab.targetInLocBg, tab.targetInLocEdit, hasTargets)
    SyncUnfocusedEdit(tab.targetInLocEdit, selTarget and selTarget.customMessageInLocation or "")
end

local function RefreshEditorTargetConfig(tab, draft)
    local targets = draft.targets or {}
    local totalTargets = #targets
    if totalTargets > 0 then
        if not tab.selectedTargetIndex or tab.selectedTargetIndex < 1 or tab.selectedTargetIndex > totalTargets then
            tab.selectedTargetIndex = totalTargets
        end
    else
        tab.selectedTargetIndex = nil
    end

    local hasTargets = totalTargets > 0
    local selTarget = tab.selectedTargetIndex and targets[tab.selectedTargetIndex] or nil
    local hasTargetLoc = selTarget and Addon.QuestRepository:HasTargetLocation(selTarget) or false
    local isLocRequired = hasTargetLoc and (selTarget.locationRequired == true)

    RefreshTargetDropdown(tab, targets, hasTargets)
    SetButtonEnabled(tab.btnRemoveTarget, hasTargets)
    SetButtonEnabled(tab.btnClearTargets, hasTargets)

    if tab.chkTargetOptional then
        ZO_CheckButton_SetCheckState(tab.chkTargetOptional, selTarget and selTarget.optional == true or false)
        ZO_CheckButton_SetEnableState(tab.chkTargetOptional, hasTargets)
    end

    if tab.areaSizeComboBox then
        local radii = Addon.Constants.AREA_RADIUS
        local curRad = (selTarget and selTarget.areaRadius) or draft.areaRadius or radii.MEDIUM
        tab.areaSizeComboBox:SetEnabled(hasTargets)
        tab.areaSizeComboBox:SetSelectedItemByEval(function(item)
            return math.abs(item.areaRadius - curRad) < 0.005
        end, true)
    end

    if tab.chkTargetLocRequired then
        ZO_CheckButton_SetCheckState(tab.chkTargetLocRequired, isLocRequired)
        ZO_CheckButton_SetEnableState(tab.chkTargetLocRequired, hasTargetLoc)
    end

    SetButtonEnabled(tab.btnCaptureTargetLoc, hasTargets)
    SetButtonEnabled(tab.btnClearTargetLoc, hasTargetLoc)

    if tab.targetLocRadComboBox then
        local discRadii = Addon.Constants.DISCOVERY_RADIUS
        local curTargetRad = (selTarget and selTarget.radius) or discRadii.MEDIUM
        tab.targetLocRadComboBox:SetEnabled(hasTargetLoc)
        tab.targetLocRadComboBox:SetSelectedItemByEval(function(item)
            return item.locRadius == curTargetRad
        end, true)
    end

    RefreshTargetMessageControls(tab, selTarget, hasTargets)
end

function EditorPane.RefreshDiscoveryMessageIndicator(tab, draft)
    local discoveries = draft.discoveries or {}
    local totalDisc = #discoveries
    local selectedPoint = tab.selectedDiscoveryIndex and discoveries[tab.selectedDiscoveryIndex] or nil
    local activeMsg = selectedPoint and (selectedPoint.message or "") or ""
    local trimmed = activeMsg:gsub("^%s+", ""):gsub("%s+$", "")
    local isPointMissing = (totalDisc > 0) and (trimmed == "")

    if tab.lblDiscoveryMsg then
        if totalDisc == 0 then
            tab.lblDiscoveryMsg:SetText(Addon.Locale:Get("LABEL_DISCOVERY_MSG"))
        elseif isPointMissing then
            tab.lblDiscoveryMsg:SetText(Addon.Locale:Get("LABEL_DISCOVERY_MSG_MISSING"))
        else
            tab.lblDiscoveryMsg:SetText(Addon.Locale:Get("LABEL_DISCOVERY_MSG_REQUIRED"))
        end
    end

    if tab.discoveryMsgEdit then
        tab.discoveryMsgEdit._hasWarning = isPointMissing
    end
    if tab.discoveryMsgBg and tab.discoveryMsgBg.SetEdgeColor then
        if isPointMissing then
            tab.discoveryMsgBg:SetEdgeColor(0.95, 0.28, 0.28, 1.0)
        elseif tab.discoveryMsgEdit and tab.discoveryMsgEdit._focused then
            tab.discoveryMsgBg:SetEdgeColor(0.95, 0.85, 0.50, 1.0)
        else
            tab.discoveryMsgBg:SetEdgeColor(0.68, 0.58, 0.36, 0.80)
        end
    end
end

local MAX_DISCOVERY_PREVIEW_CHARS = 42

local function TruncateDiscoveryText(text, maxChars)
    local trimmed = (text or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if trimmed == "" then return "" end
    local count = 0
    for i = 1, #trimmed do
        local b = string.byte(trimmed, i)
        if b < 128 or b >= 192 then
            count = count + 1
            if count > maxChars then
                return string.sub(trimmed, 1, i - 1) .. "..."
            end
        end
    end
    return trimmed
end

local function FormatDiscoveryDropdownEntry(index, point)
    local reqTag = (point and point.required == true) and (Addon.Locale:Get("TAG_REQUIRED_SHORT") .. " ") or ""
    local preview = TruncateDiscoveryText(point and point.message or "", MAX_DISCOVERY_PREVIEW_CHARS)
    if preview == "" then
        return string.format("#%d %s- ...", index, reqTag)
    end
    return string.format("#%d %s- %s", index, reqTag, preview)
end

function EditorPane.RefreshDiscoveryDropdown(tab, draft)
    local combo = tab.discoveryComboBox
    if not combo then return end
    local discoveries = (draft and draft.discoveries) or {}
    local hasDiscoveries = #discoveries > 0
    combo:ClearItems()
    if hasDiscoveries then
        for i, point in ipairs(discoveries) do
            local label = FormatDiscoveryDropdownEntry(i, point)
            local entry = combo:CreateItemEntry(label, function()
                tab.selectedDiscoveryIndex = i
                tab:RefreshEditorPane()
            end)
            entry.discoveryIndex = i
            combo:AddItem(entry)
        end
        combo:SetEnabled(true)
        combo:SetSelectedItemByEval(function(item)
            return item.discoveryIndex == tab.selectedDiscoveryIndex
        end, true)
    else
        combo:SetEnabled(false)
        combo:SetSelectedItemText(Addon.Locale:Get("DISCOVERY_NOT_CAPTURED"))
    end
end

local function RefreshEditorDiscoveries(tab, draft)
    local discoveries = draft.discoveries or {}
    local totalDisc = #discoveries
    if totalDisc > 0 then
        if not tab.selectedDiscoveryIndex or tab.selectedDiscoveryIndex < 1 or tab.selectedDiscoveryIndex > totalDisc then
            tab.selectedDiscoveryIndex = totalDisc
        end
    else
        tab.selectedDiscoveryIndex = nil
    end

    local hasDiscoveries = totalDisc > 0
    local selectedPoint = tab.selectedDiscoveryIndex and discoveries[tab.selectedDiscoveryIndex] or nil
    local activeDiscMsg = selectedPoint and (selectedPoint.message or "") or ""
    Addon.JournalWidgets.SetEditBoxEnabled(tab.discoveryMsgBg, tab.discoveryMsgEdit, hasDiscoveries)
    SyncUnfocusedEdit(tab.discoveryMsgEdit, activeDiscMsg)
    EditorPane.RefreshDiscoveryMessageIndicator(tab, draft)

    if tab.discRadComboBox then
        local discRadii = Addon.Constants.DISCOVERY_RADIUS
        local curDiscRad = (selectedPoint and selectedPoint.radius) or draft.discoveryRadius or discRadii.MEDIUM
        tab.discRadComboBox:SetEnabled(hasDiscoveries)
        tab.discRadComboBox:SetSelectedItemByEval(function(item)
            return item.discRadius == curDiscRad
        end, true)
    end

    EditorPane.RefreshDiscoveryDropdown(tab, draft)
    if tab.chkDiscoveryRequired then
        ZO_CheckButton_SetCheckState(tab.chkDiscoveryRequired, selectedPoint and selectedPoint.required == true or false)
        ZO_CheckButton_SetEnableState(tab.chkDiscoveryRequired, hasDiscoveries)
    end
    if tab.chkDiscoverySequential then
        ZO_CheckButton_SetCheckState(tab.chkDiscoverySequential, draft.sequentialDiscoveries == true)
    end
    SetButtonEnabled(tab.btnMoveDiscoveryUp, hasDiscoveries and tab.selectedDiscoveryIndex and tab.selectedDiscoveryIndex > 1)
    SetButtonEnabled(tab.btnMoveDiscoveryDown, hasDiscoveries and tab.selectedDiscoveryIndex and tab.selectedDiscoveryIndex < totalDisc)
    SetButtonEnabled(tab.btnRemoveDiscovery, hasDiscoveries)
    SetButtonEnabled(tab.btnClearDiscoveries, hasDiscoveries)
end

local function RefreshEditorDialoguesAndOptions(tab, draft)
    if tab.lblLastNpc then
        local lastNpc = Addon.QuestRepository:GetLastInteractedNpc()
        local lastText = (lastNpc and lastNpc.name and lastNpc.name ~= "")
            and Addon.Locale:Get("DIALOGUE_LAST_NPC_FORMAT", lastNpc.name)
            or Addon.Locale:Get("DIALOGUE_NO_LAST_NPC")
        tab.lblLastNpc:SetText(lastText)
    end

    local dialogues = draft.dialogues or {}
    local totalDlg = #dialogues
    local maxNpcs = (Addon.Constants and Addon.Constants.DIALOGUE and Addon.Constants.DIALOGUE.MAX_NPCS) or 4
    if totalDlg > 0 then
        if not tab.selectedDialogueIndex or tab.selectedDialogueIndex < 1 or tab.selectedDialogueIndex > totalDlg then
            tab.selectedDialogueIndex = totalDlg
        end
    else
        tab.selectedDialogueIndex = nil
    end

    local selectedDlg = tab.selectedDialogueIndex and dialogues[tab.selectedDialogueIndex] or nil
    SyncUnfocusedEdit(tab.clueEdit, selectedDlg and (selectedDlg.clue or "") or "")
    SyncUnfocusedEdit(tab.dlgResponseEdit, selectedDlg and (selectedDlg.response or "") or "")

    if tab.lblSelectedNpc then
        if selectedDlg then
            local npcDisplay = selectedDlg.npcName or ""
            if selectedDlg.required == true then
                npcDisplay = npcDisplay .. " " .. Addon.Locale:Get("TAG_REQUIRED_SHORT")
            end
            tab.lblSelectedNpc:SetText(Addon.Locale:Get("DIALOGUE_SELECTED_NPC_FORMAT", npcDisplay))
            tab.lblSelectedNpc:SetHidden(false)
        else
            tab.lblSelectedNpc:SetHidden(true)
        end
    end
    if tab.chkDialogueRequired then
        ZO_CheckButton_SetCheckState(tab.chkDialogueRequired, selectedDlg and selectedDlg.required == true or false)
        ZO_CheckButton_SetEnableState(tab.chkDialogueRequired, selectedDlg ~= nil)
    end
    if tab.lblInputClue then
        tab.lblInputClue:SetText(selectedDlg and Addon.Locale:Get("DIALOGUE_OPTION_FOR_NPC_FORMAT", selectedDlg.npcName or "") or Addon.Locale:Get("LABEL_INPUT_CLUE"))
    end
    if tab.lblDlgResponse then
        tab.lblDlgResponse:SetText(selectedDlg and Addon.Locale:Get("DIALOGUE_RESPONSE_FOR_NPC_FORMAT", selectedDlg.npcName or "") or Addon.Locale:Get("LABEL_DIALOGUE_RESPONSE"))
    end

    local showDlgSel = totalDlg > 0
    if tab.btnDlgPrev then tab.btnDlgPrev:SetHidden(not showDlgSel) end
    if tab.btnDlgNext then tab.btnDlgNext:SetHidden(not showDlgSel) end
    if tab.btnDlgRemove then tab.btnDlgRemove:SetHidden(not showDlgSel) end
    if tab.lblDlgIndex then
        tab.lblDlgIndex:SetHidden(not showDlgSel)
        if showDlgSel then tab.lblDlgIndex:SetText(Addon.Locale:Get("DIALOGUE_INDEX_FORMAT", tab.selectedDialogueIndex, totalDlg)) end
    end
    if tab.btnClearDialogues then tab.btnClearDialogues:SetHidden(totalDlg == 0) end
    if tab.lblCapturedDialogues then
        if totalDlg > 0 then
            local names = {}
            for i, d in ipairs(dialogues) do
                local n = d.npcName or ""
                if d.required == true then
                    n = n .. " " .. Addon.Locale:Get("TAG_REQUIRED_SHORT")
                end
                table.insert(names, (i == tab.selectedDialogueIndex) and ("|cE8D5A0[" .. n .. "]|r") or n)
            end
            tab.lblCapturedDialogues:SetText(Addon.Locale:Get("DIALOGUE_CAPTURED_FORMAT", totalDlg, maxNpcs, table.concat(names, ", ")))
        else
            tab.lblCapturedDialogues:SetText(Addon.Locale:Get("DIALOGUE_NONE_CAPTURED"))
        end
    end

    if tab.stealthComboBox then
        local targetMode = Addon.QuestDraftStore:NormalizeStealthMode(draft.stealthMode, draft.requireUndetected)
        local selected = tab.stealthComboBox:GetSelectedItemData()
        if not selected or selected.stealthMode ~= targetMode then
            tab.stealthComboBox:SetSelectedItemByEval(function(item)
                return item.stealthMode == targetMode
            end, true)
        end
    end

    if tab.chkHideMapArea then
        local recHide = (draft.recommendHideMapAreas ~= nil) and (draft.recommendHideMapAreas == true) or (draft.hideMapArea == true)
        ZO_CheckButton_SetCheckState(tab.chkHideMapArea, recHide)
    end
end

function EditorPane.Refresh(tab)
    local draft = Addon.QuestRepository:GetDraft()
    RefreshEditorBaseAndArea(tab, draft)
    RefreshEditorTargetConfig(tab, draft)
    RefreshEditorDiscoveries(tab, draft)
    RefreshEditorDialoguesAndOptions(tab, draft)

    local collapsedMap = tab.editorSectionsCollapsed or {}
    for _, sec in ipairs(tab.editorSections or {}) do
        local targetOpen = not collapsedMap[sec.key]
        if targetOpen ~= sec.isOpen then
            SnapSectionState(sec, targetOpen)
        elseif not (sec.timeline and sec.timeline:IsPlaying()) then
            sec.openPercentage = targetOpen and 1 or 0
            sec.body:SetAlpha(sec.openPercentage)
        end
    end
    EditorPane.LayoutSections(tab)
end
