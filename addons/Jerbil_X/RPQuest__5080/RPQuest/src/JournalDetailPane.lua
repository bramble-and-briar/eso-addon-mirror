-- Ref: docs/adr/0001-arquitectura-modular-zero-dependency-y-savedvars-por-personaje.md
-- Ref: docs/adr/0003-integracion-nativa-ui-diario-mapa-y-hud.md
-- Ref: docs/adr/0011-flujo-solo-correo-1-a-1-y-eliminacion-codigos-manuales.md

RPQuest = RPQuest or {}
local Addon = RPQuest

Addon.JournalDetailPane = {}
local DetailPane = Addon.JournalDetailPane

local function CreateDetailScrollContainer(tab, pane, panelName)
    local scrollContainer = WINDOW_MANAGER.CreateControlFromVirtual
        and WINDOW_MANAGER:CreateControlFromVirtual(panelName .. "_DetailScroll", pane, "ZO_ScrollContainer")
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
            tab.detailScrollChild = scrollChild
        end
        tab.detailScroll = scrollContainer
    end
    return contentParent
end

local function CreateDetailLabel(parent, name, width, height, font, anchorTo, anchorPoint, offsetX, offsetY)
    local label = WINDOW_MANAGER:CreateControl(name, parent, CT_LABEL)
    label:SetDimensions(width, height)
    label:SetAnchor(TOPLEFT, anchorTo, anchorPoint, offsetX, offsetY)
    if label.SetFont then label:SetFont(font) end
    return label
end

local function BuildDetailHeaderAndBody(tab, pane, panelName)
    local contentParent = CreateDetailScrollContainer(tab, pane, panelName)

    local titleLabel = CreateDetailLabel(contentParent, panelName .. "_DetailTitle", 500, 34, "ZoFontWinH2", contentParent, TOPLEFT, 0, 0)
    if titleLabel.SetColor then titleLabel:SetColor(1, 1, 1, 1) end
    if titleLabel.SetModifyTextType then titleLabel:SetModifyTextType(MODIFY_TEXT_TYPE_UPPERCASE) end
    tab.detailTitle = titleLabel

    tab.detailStatus = CreateDetailLabel(contentParent, panelName .. "_DetailStatus", 500, 22, "ZoFontWinH4", titleLabel, BOTTOMLEFT, 0, 5)

    local fromLabel = CreateDetailLabel(contentParent, panelName .. "_DetailFrom", 500, 20, "ZoFontWinH4", tab.detailStatus, BOTTOMLEFT, 0, 2)
    if fromLabel.SetColor then fromLabel:SetColor(0.77, 0.76, 0.62, 1) end
    tab.detailFrom = fromLabel

    local toLabel = CreateDetailLabel(contentParent, panelName .. "_DetailTo", 500, 20, "ZoFontWinH4", fromLabel, BOTTOMLEFT, 0, 2)
    if toLabel.SetColor then toLabel:SetColor(0.77, 0.76, 0.62, 1) end
    tab.detailTo = toLabel

    local locLabel = CreateDetailLabel(contentParent, panelName .. "_DetailLoc", 500, 22, "ZoFontWinH4", toLabel, BOTTOMLEFT, 0, 8)
    if locLabel.SetColor then locLabel:SetColor(0.77, 0.76, 0.62, 1) end
    tab.detailLocation = locLabel

    local descBody = CreateDetailLabel(contentParent, panelName .. "_DetailDescBody", 495, 104, "ZoFontWinH4", locLabel, BOTTOMLEFT, 25, 8)
    if descBody.SetColor then descBody:SetColor(0.77, 0.76, 0.62, 1) end
    if descBody.SetMaxLineCount then descBody:SetMaxLineCount(5) end
    tab.detailDescBody = descBody

    local divider = WINDOW_MANAGER:CreateControl(panelName .. "_DetailDivider", contentParent, CT_TEXTURE)
    divider:SetDimensions(512, 4)
    divider:SetAnchor(TOPLEFT, descBody, BOTTOMLEFT, -25, 14)
    divider:SetTexture(Addon.Constants.UI.DIVIDER_TEXTURE)

    local objHeader = CreateDetailLabel(contentParent, panelName .. "_DetailObjHeader", 500, 24, "ZoFontWinH3", divider, BOTTOMLEFT, 0, 10)
    if objHeader.SetColor then objHeader:SetColor(1, 1, 1, 1) end
    if objHeader.SetModifyTextType then objHeader:SetModifyTextType(MODIFY_TEXT_TYPE_UPPERCASE) end
    objHeader:SetText(Addon.Locale:Get("LABEL_OBJECTIVE_HEADER"))
    tab.detailObjHeader = objHeader

    local objText = CreateDetailLabel(contentParent, panelName .. "_DetailObjText", 495, 48, "ZoFontWinH4", objHeader, BOTTOMLEFT, 25, 10)
    if objText.SetColor then objText:SetColor(1, 1, 1, 1) end
    tab.detailObjText = objText

    return contentParent
end

local function BuildDetailActionButtons(tab, contentParent, panelName)
    local CreateStyledButton = Addon.JournalWidgets.CreateStyledButton
    local objText = tab.detailObjText

    tab.btnActivate = CreateStyledButton(panelName .. "_BtnActivate", contentParent, 160, 32, "", function()
        tab:OnToggleActiveClicked()
    end)
    tab.btnActivate:SetAnchor(TOPLEFT, objText, BOTTOMLEFT, -25, 16)

    tab.btnComplete = CreateStyledButton(panelName .. "_BtnComplete", contentParent, 160, 32, Addon.Locale:Get("BTN_COMPLETE_QUEST"), function()
        tab:OnCompleteQuestClicked()
    end)
    tab.btnComplete:SetAnchor(TOPLEFT, tab.btnActivate, TOPRIGHT, 12, 0)
    tab.btnComplete:SetHidden(true)

    tab.btnEdit = CreateStyledButton(panelName .. "_BtnEdit", contentParent, 160, 32, Addon.Locale:Get("BTN_EDIT"), function()
        tab:OpenEditEditor(tab.selectedQuestId)
    end)
    tab.btnEdit:SetAnchor(TOPLEFT, tab.btnActivate, TOPRIGHT, 12, 0)

    tab.btnReset = CreateStyledButton(panelName .. "_BtnReset", contentParent, 160, 32, Addon.Locale:Get("BTN_RESET"), function()
        if not tab.selectedQuestId then return end
        local q = Addon.QuestRepository:GetQuestById(tab.selectedQuestId)
        if not q then return end
        local activeQuest = Addon.QuestRepository:GetActiveQuest()
        local isCurrentActive = (activeQuest and activeQuest.id == q.id)
        local resetOptions = (Addon.QuestRepository:IsPreparedQuest(q) and not isCurrentActive)
            and { activate = false }
            or nil
        if Addon.QuestRepository:ResetQuest(tab.selectedQuestId, resetOptions) then
            Addon.Announcements:ShowAlert(Addon.Locale:Get("ALERT_QUEST_RESET"), false)
        end
    end)
    tab.btnReset:SetAnchor(TOPLEFT, tab.btnActivate, BOTTOMLEFT, 0, 10)

    tab.btnSendDirect = CreateStyledButton(panelName .. "_BtnSendDirect", contentParent, 160, 32, Addon.Locale:Get("BTN_SEND_QUEST"), function()
        tab:SendSelectedPreparedQuest()
    end)
    tab.btnSendDirect:SetAnchor(TOPLEFT, tab.btnReset, TOPRIGHT, 12, 0)
    tab.btnSendDirect:SetHidden(true)

    tab.btnCopy = CreateStyledButton(panelName .. "_BtnCopy", contentParent, 160, 32, Addon.Locale:Get("BTN_COPY"), function()
        tab:DuplicateSelectedQuest()
    end)
    tab.btnCopy:SetAnchor(TOPLEFT, tab.btnReset, BOTTOMLEFT, 0, 10)
    tab.btnCopy:SetHidden(true)

    tab.btnMigrate = CreateStyledButton(panelName .. "_BtnMigrate", contentParent, 160, 32, Addon.Locale:Get("BTN_MIGRATE"), function()
        tab:MigrateSelectedQuest()
    end)
    tab.btnMigrate:SetAnchor(TOPLEFT, tab.btnActivate, TOPLEFT, 0, 0)
    tab.btnMigrate:SetHidden(true)

    tab.btnAcceptOffered = CreateStyledButton(panelName .. "_BtnAcceptOffered", contentParent, 160, 32, Addon.Locale:Get("BTN_MAIL_ACCEPT"), function()
        tab:AcceptSelectedOfferedQuest()
    end)
    tab.btnAcceptOffered:SetAnchor(TOPLEFT, objText, BOTTOMLEFT, -25, 16)
    tab.btnAcceptOffered:SetHidden(true)

    tab.btnRejectOffered = CreateStyledButton(panelName .. "_BtnRejectOffered", contentParent, 160, 32, Addon.Locale:Get("BTN_MAIL_REJECT"), function()
        tab:RejectSelectedOfferedQuest()
    end)
    tab.btnRejectOffered:SetAnchor(TOPLEFT, tab.btnAcceptOffered, TOPRIGHT, 12, 0)
    tab.btnRejectOffered:SetHidden(true)
end

local function RegisterAbandonDialogAndKeybinds(tab, pane, panelName)
    local DETAIL_MODE = tab.VIEW_MODE.DETAIL

    if not ESO_Dialogs["RPQUEST_ABANDON_QUEST"] then
        ESO_Dialogs["RPQUEST_ABANDON_QUEST"] = {
            title = { text = SI_PROMPT_TITLE_ABANDON_QUEST },
            mainText = { text = SI_CONFIRM_ABANDON_QUEST },
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
                { text = SI_DIALOG_CANCEL },
            },
        }
    end

    local function CanAbandonSelectedQuest()
        if tab.viewMode ~= DETAIL_MODE or not tab.selectedQuestId then
            return false
        end
        local quest = Addon.QuestRepository:GetQuestById(tab.selectedQuestId)
        return quest ~= nil and not Addon.QuestRepository:IsOfferedQuest(quest)
    end

    tab.abandonQuestDescriptor = {
        name = GetString(SI_QUEST_JOURNAL_ABANDON),
        keybind = "UI_SHORTCUT_NEGATIVE",
        callback = function()
            if CanAbandonSelectedQuest() then
                tab:ConfirmAbandonQuest(tab.selectedQuestId)
            end
        end,
        visible = CanAbandonSelectedQuest,
        enabled = CanAbandonSelectedQuest,
    }

    tab.showOnMapDescriptor = {
        name = GetString(SI_QUEST_JOURNAL_SHOW_ON_MAP),
        keybind = "UI_SHORTCUT_SHOW_QUEST_ON_MAP",
        ethereal = true,
        callback = function()
            local q = Addon.QuestRepository:GetQuestById(tab.selectedQuestId)
            if q then
                Addon.WorldMapArea:ShowQuestOnMap(q)
            end
        end,
        visible = function()
            return tab.viewMode == DETAIL_MODE
                and tab.selectedQuestId ~= nil
                and Addon.QuestRepository:GetQuestById(tab.selectedQuestId) ~= nil
        end,
    }
    tab.keybindStripDescriptor = {
        alignment = KEYBIND_STRIP_ALIGN_CENTER,
        tab.abandonQuestDescriptor,
        tab.showOnMapDescriptor,
    }

    local showOnMapBtn = WINDOW_MANAGER.CreateControlFromVirtual
        and WINDOW_MANAGER:CreateControlFromVirtual(panelName .. "_ShowOnMap", pane, "ZO_KeybindButton")
        or WINDOW_MANAGER:CreateControl(panelName .. "_ShowOnMap", pane, CT_CONTROL)
    ApplyTemplateToControl(showOnMapBtn, "ZO_KeybindButton_Keyboard_Template")
    if showOnMapBtn.SetKeybindButtonDescriptor then
        showOnMapBtn:SetKeybindButtonDescriptor(tab.showOnMapDescriptor)
    end
    showOnMapBtn:SetAnchor(TOPLEFT, pane, BOTTOMLEFT, 0, 0)
    tab.showOnMapKeybindButton = showOnMapBtn
end

function DetailPane.Build(tab, parent)
    local panelName = Addon.JournalWidgets.PANEL_NAME
    local pane = WINDOW_MANAGER:CreateControl(panelName .. "_DetailPane", parent, CT_CONTROL)
    pane:SetDimensions(550, 600)
    pane:SetAnchor(TOPLEFT, parent, TOPLEFT, 0, 0)
    pane:SetAnchor(BOTTOMRIGHT, parent, BOTTOMRIGHT, 0, 0)
    tab.detailPane = pane

    local contentParent = BuildDetailHeaderAndBody(tab, pane, panelName)
    BuildDetailActionButtons(tab, contentParent, panelName)
    RegisterAbandonDialogAndKeybinds(tab, pane, panelName)
end

local function FormatPreparedStatusText(quest)
    local pStatus, pInfo = Addon.QuestRepository:GetPreparedQuestStatus(quest)
    local recLabel = (type(quest.recipientAccount) == "string" and quest.recipientAccount ~= "")
        and quest.recipientAccount
        or Addon.Locale:Get("LABEL_NO_RECIPIENT")

    if pStatus == "completed" and type(pInfo) == "table" then
        local who = (pInfo.senderDisplayName and pInfo.senderDisplayName ~= "") and pInfo.senderDisplayName or recLabel
        local charPart = (pInfo.characterName and pInfo.characterName ~= "") and (" (" .. pInfo.characterName .. ")") or ""
        local stealthPart = ""
        if pInfo.wasDetected == false then
            stealthPart = " " .. Addon.Locale:Get("VALIDATE_STEALTH_UNDETECTED")
        elseif pInfo.wasDetected == true then
            stealthPart = " " .. Addon.Locale:Get("VALIDATE_STEALTH_DETECTED")
        end
        local optionalPart = ""
        if type(pInfo.optionalTargets) == "table" and #pInfo.optionalTargets > 0 then
            local optNames = {}
            for _, t in ipairs(quest.targets or {}) do
                if t.optional == true then
                    table.insert(optNames, t.name or "")
                end
            end
            local doneNames = {}
            local totalOpt = #pInfo.optionalTargets
            for i = 1, totalOpt do
                if pInfo.optionalTargets[i] == true then
                    table.insert(doneNames, optNames[i] or tostring(i))
                end
            end
            if #doneNames > 0 then
                optionalPart = Addon.Locale:Get("VALIDATE_OPTIONAL_COMPLETED", #doneNames, totalOpt, table.concat(doneNames, ", "))
            else
                optionalPart = Addon.Locale:Get("VALIDATE_OPTIONAL_NONE", totalOpt)
            end
        end
        return Addon.Locale:Get("PREPARED_STATUS_COMPLETED", who .. charPart .. stealthPart .. optionalPart)
    elseif pStatus == "accepted" and type(pInfo) == "table" then
        local who = (pInfo.senderDisplayName and pInfo.senderDisplayName ~= "") and pInfo.senderDisplayName or recLabel
        local charPart = (pInfo.characterName and pInfo.characterName ~= "") and (" (" .. pInfo.characterName .. ")") or ""
        return Addon.Locale:Get("PREPARED_STATUS_ACCEPTED", who .. charPart)
    elseif pStatus == "rejected" and type(pInfo) == "table" then
        local who = (pInfo.senderDisplayName and pInfo.senderDisplayName ~= "") and pInfo.senderDisplayName or recLabel
        local charPart = (pInfo.characterName and pInfo.characterName ~= "") and (" (" .. pInfo.characterName .. ")") or ""
        return Addon.Locale:Get("PREPARED_STATUS_REJECTED", who .. charPart)
    elseif pStatus == "sent" then
        return Addon.Locale:Get("PREPARED_STATUS_SENT", (pInfo and pInfo.recipient) or recLabel)
    end
    return Addon.Locale:Get("PREPARED_STATUS_DRAFT", recLabel)
end

local function ApplyDetailStatusAndActivateLabel(tab, selectedQuest, isOffered, isPrepared, isCurrentActive)
    local activateLabel = isPrepared and Addon.Locale:Get("BTN_TEST_QUEST") or Addon.Locale:Get("BTN_ACTIVATE")
    local deactivateLabel = isPrepared and Addon.Locale:Get("BTN_STOP_TEST") or Addon.Locale:Get("BTN_DEACTIVATE")

    if isOffered then
        tab.detailStatus:SetText(Addon.Locale:Get("STATUS_PENDING"))
    elseif isPrepared and selectedQuest.needsMigration then
        local statusText = Addon.Locale:Get("STATUS_NEEDS_MIGRATION")
        if type(selectedQuest.migrationReason) == "string" and selectedQuest.migrationReason ~= "" then
            statusText = statusText .. "\n|cC5C29E" .. selectedQuest.migrationReason .. "|r"
        end
        tab.detailStatus:SetText(statusText)
    elseif isPrepared then
        tab.detailStatus:SetText(FormatPreparedStatusText(selectedQuest))
        tab.btnActivate:SetText(isCurrentActive and deactivateLabel or activateLabel)
    elseif selectedQuest.failed then
        tab.detailStatus:SetText(Addon.Locale:Get("STATUS_FAILED"))
        tab.btnActivate:SetText(activateLabel)
    elseif isCurrentActive then
        tab.detailStatus:SetText(Addon.Locale:Get("STATUS_ACTIVE"))
        tab.btnActivate:SetText(deactivateLabel)
    elseif selectedQuest.completed then
        tab.detailStatus:SetText(Addon.Locale:Get("STATUS_COMPLETED"))
        tab.btnActivate:SetText(activateLabel)
    else
        tab.detailStatus:SetText(Addon.Locale:Get("STATUS_AVAILABLE"))
        tab.btnActivate:SetText(activateLabel)
    end
end

local function AppendTargetObjectiveLines(objLines, selectedQuest, isPrepared, pInfo, isSentCompleted, bullet)
    local targets = selectedQuest.targets or {}
    local maxVisibleObjLines = 4
    local totalTargets = #targets
    local limit = (totalTargets > maxVisibleObjLines) and (maxVisibleObjLines - 1) or totalTargets
    local optIdx = 0

    for i = 1, limit do
        local t = targets[i]
        local currentCount = t.currentCount or 0
        local requiredCount = t.requiredCount or 1
        local isTargetCompleted = (currentCount >= requiredCount)
        if isSentCompleted then
            if t.optional == true then
                optIdx = optIdx + 1
                isTargetCompleted = (type(pInfo.optionalTargets) == "table" and pInfo.optionalTargets[optIdx] == true)
            else
                isTargetCompleted = true
                currentCount = requiredCount
            end
        elseif t.optional == true then
            optIdx = optIdx + 1
        end
        if isTargetCompleted and currentCount < requiredCount then
            currentCount = requiredCount
        end

        local line = Addon.Locale:Get(
            "OBJECTIVE_KILL_FORMAT",
            t.name or "",
            currentCount,
            requiredCount
        ):gsub("^•%s*", bullet)
        if t.optional == true then
            line = line .. Addon.Locale:Get("OBJECTIVE_OPTIONAL_SUFFIX")
        end
        if isTargetCompleted then
            line = line .. Addon.Locale:Get("OBJECTIVE_COMPLETED_SUFFIX")
        elseif isPrepared and Addon.QuestRepository:HasTargetLocation(t) then
            local locKey = t.locationRequired and "TARGET_DETAIL_LOC_REQUIRED" or "TARGET_DETAIL_LOC_OPTIONAL"
            line = line .. Addon.Locale:Get(locKey)
        end
        objLines[i] = line
    end
    if totalTargets > maxVisibleObjLines then
        objLines[maxVisibleObjLines] = string.format("... (+%d)", totalTargets - limit)
    end
end

local function AppendExtraObjectiveLines(objLines, selectedQuest, isPrepared, pInfo, isSentCompleted, bullet)
    local discoveries = selectedQuest.discoveries or {}
    if #discoveries > 0 then
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
        local wasDetected = selectedQuest.wasDetected
        if isSentCompleted and pInfo.wasDetected ~= nil then
            wasDetected = pInfo.wasDetected
        end
        local stealthKey = wasDetected and "STEALTH_STATUS_DETECTED" or "STEALTH_STATUS_UNDETECTED"
        table.insert(objLines, bullet .. Addon.Locale:Get(stealthKey))
    end

    if isPrepared then
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
end

local function BuildObjectiveLines(selectedQuest, isPrepared)
    local objLines = {}
    local bullet = "|t16:16:/esoui/art/miscellaneous/bullet.dds|t "
    local pStatus, pInfo
    if isPrepared then
        pStatus, pInfo = Addon.QuestRepository:GetPreparedQuestStatus(selectedQuest)
    end
    local isSentCompleted = isPrepared and pStatus == "completed" and type(pInfo) == "table"

    AppendTargetObjectiveLines(objLines, selectedQuest, isPrepared, pInfo, isSentCompleted, bullet)
    AppendExtraObjectiveLines(objLines, selectedQuest, isPrepared, pInfo, isSentCompleted, bullet)

    return objLines
end

local function UpdateDetailActionButtons(tab, selectedQuest, isOffered, isPrepared)
    tab:UpdateShowOnMapVisibility()
    tab.btnReset:ClearAnchors()
    local needsMigration = isPrepared and (selectedQuest.needsMigration == true)
    if tab.btnAcceptOffered then tab.btnAcceptOffered:SetHidden(not isOffered) end
    if tab.btnRejectOffered then tab.btnRejectOffered:SetHidden(not isOffered) end
    if tab.btnSendDirect then tab.btnSendDirect:SetHidden((not isPrepared) or needsMigration) end
    if tab.btnCopy then tab.btnCopy:SetHidden((not isPrepared) or needsMigration) end
    if tab.btnMigrate then tab.btnMigrate:SetHidden(not needsMigration) end

    if isOffered then
        tab.btnActivate:SetHidden(true)
        if tab.btnComplete then tab.btnComplete:SetHidden(true) end
        tab.btnEdit:SetHidden(true)
        tab.btnReset:SetHidden(true)
    elseif needsMigration then
        tab.btnActivate:SetHidden(true)
        if tab.btnComplete then tab.btnComplete:SetHidden(true) end
        tab.btnEdit:SetHidden(true)
        tab.btnReset:SetHidden(true)
    elseif isPrepared then
        local activeQuest = Addon.QuestRepository:GetActiveQuest()
        local isCurrentActive = (activeQuest and activeQuest.id == selectedQuest.id)
        local canManualComplete = isCurrentActive and Addon.QuestRepository:CanManuallyCompleteQuest(selectedQuest)
        tab.btnActivate:SetHidden(false)
        if tab.btnComplete then tab.btnComplete:SetHidden(not canManualComplete) end
        tab.btnEdit:SetHidden(canManualComplete)
        tab.btnReset:SetAnchor(TOPLEFT, tab.btnActivate, BOTTOMLEFT, 0, 10)
        tab.btnReset:SetHidden(false)
    else
        local showCompletion = selectedQuest.completed and true or false
        local showFailed = selectedQuest.failed and true or false
        local canManualComplete = Addon.QuestRepository:CanManuallyCompleteQuest(selectedQuest)
        tab.btnActivate:SetHidden(showCompletion or showFailed)
        if tab.btnComplete then tab.btnComplete:SetHidden(not canManualComplete) end
        tab.btnEdit:SetHidden(true)
        tab.btnReset:SetHidden(not showFailed)
        if showFailed then
            tab.btnReset:SetAnchor(TOPLEFT, tab.detailObjText, BOTTOMLEFT, -25, 16)
        end
    end

    if tab.keybindStripDescriptor then
        KEYBIND_STRIP:UpdateKeybindButtonGroup(tab.keybindStripDescriptor)
    end
end

local function RenderEmptyDetailPane(tab)
    tab.detailTitle:SetText(Addon.Locale:Get("TAB_TITLE"))
    tab.detailStatus:SetText(Addon.Locale:Get("EMPTY_QUEST_LIST"))
    tab.detailFrom:SetText("")
    tab.detailTo:SetText("")
    tab.detailLocation:SetText("")
    tab.detailDescBody:SetText("")
    tab.detailObjHeader:SetHidden(true)
    tab.detailObjText:SetText("")
    tab.btnActivate:SetHidden(true)
    if tab.btnComplete then tab.btnComplete:SetHidden(true) end
    if tab.btnAcceptOffered then tab.btnAcceptOffered:SetHidden(true) end
    if tab.btnRejectOffered then tab.btnRejectOffered:SetHidden(true) end
    tab.selectedQuestId = nil
    tab:UpdateShowOnMapVisibility()
    tab.btnEdit:SetHidden(true)
    tab.btnReset:SetHidden(true)
    if tab.btnSendDirect then tab.btnSendDirect:SetHidden(true) end
    if tab.btnCopy then tab.btnCopy:SetHidden(true) end
    if tab.btnMigrate then tab.btnMigrate:SetHidden(true) end
    if tab.keybindStripDescriptor then
        KEYBIND_STRIP:UpdateKeybindButtonGroup(tab.keybindStripDescriptor)
    end
end

function DetailPane.Refresh(tab, selectedQuest, activeQuest)
    selectedQuest = selectedQuest or (tab.selectedQuestId and Addon.QuestRepository:GetQuestById(tab.selectedQuestId))
    activeQuest = activeQuest or Addon.QuestRepository:GetActiveQuest()

    if not selectedQuest then
        RenderEmptyDetailPane(tab)
        return
    end

    tab.detailObjHeader:SetHidden(false)
    tab.detailTitle:SetText((selectedQuest.title or ""):upper())

    local isPrepared = Addon.QuestRepository:IsPreparedQuest(selectedQuest)
    local isOffered = Addon.QuestRepository:IsOfferedQuest(selectedQuest)
    local isCurrentActive = (activeQuest and activeQuest.id == selectedQuest.id)

    ApplyDetailStatusAndActivateLabel(tab, selectedQuest, isOffered, isPrepared, isCurrentActive)
    local statusText = tab.detailStatus:GetText() or ""
    tab.detailStatus:SetDimensions(500, 0)
    local statusHeight = tab.detailStatus.GetTextHeight and tab.detailStatus:GetTextHeight()
    if not statusHeight then
        local _, newlines = statusText:gsub("\n", "\n")
        statusHeight = (newlines + 1) * 22
    end
    statusHeight = math.max(22, statusHeight)
    tab.detailStatus:SetDimensions(500, statusHeight)

    local fromName = (type(selectedQuest.senderCharacterName) == "string" and selectedQuest.senderCharacterName ~= "")
        and selectedQuest.senderCharacterName
        or ((type(selectedQuest.senderDisplayName) == "string" and selectedQuest.senderDisplayName ~= "")
            and selectedQuest.senderDisplayName
            or nil)
    if not fromName and isPrepared then
        local playerChar = Addon.QuestRepository:GetPlayerCharacterName()
        if playerChar ~= "" then
            fromName = playerChar
        end
    end
    tab.detailFrom:SetText(Addon.Locale:Get("MAIL_FROM_LABEL", fromName or Addon.Locale:Get("LABEL_NO_RECIPIENT")))

    local toName = (type(selectedQuest.recipientCharacterName) == "string" and selectedQuest.recipientCharacterName ~= "")
        and selectedQuest.recipientCharacterName
        or Addon.Locale:Get("LABEL_NO_RECIPIENT")
    tab.detailTo:SetText(Addon.Locale:Get("MAIL_TO_LABEL", toName))

    local locText = (selectedQuest.mapName and selectedQuest.mapName ~= "" and selectedQuest.mapName)
        or Addon.Locale:Get("LABEL_UNKNOWN_LOCATION")
    tab.detailLocation:SetText(Addon.Locale:Get("LABEL_LOCATION", locText))

    local descText = (selectedQuest.description and selectedQuest.description ~= "" and selectedQuest.description)
        or Addon.Locale:Get("LABEL_NO_DESCRIPTION")
    tab.detailDescBody:SetText(descText)

    local objLines = BuildObjectiveLines(selectedQuest, isPrepared)
    tab.detailObjText:SetDimensions(495, 0)
    tab.detailObjText:SetText(table.concat(objLines, "\n"))
    local textHeight = tab.detailObjText.GetTextHeight and tab.detailObjText:GetTextHeight()
    local objHeight = textHeight and (textHeight + 16) or (#objLines * 24)
    tab.detailObjText:SetDimensions(495, math.max(32, objHeight))
    if tab.detailScrollChild and tab.detailScrollChild.SetDimensions then
        tab.detailScrollChild:SetDimensions(526, math.max(650, 620 + objHeight + math.max(0, statusHeight - 22)))
    end

    UpdateDetailActionButtons(tab, selectedQuest, isOffered, isPrepared)
end
