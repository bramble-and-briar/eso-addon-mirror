-- Ref: docs/adr/0001-arquitectura-modular-zero-dependency-y-savedvars-por-personaje.md
-- Ref: docs/adr/0003-integracion-nativa-ui-diario-mapa-y-hud.md
-- Ref: docs/adr/0011-flujo-solo-correo-1-a-1-y-eliminacion-codigos-manuales.md
-- Ref: docs/adr/0014-areas-por-objetivo-mensajes-eliminacion-y-visibilidad-mapa.md
-- Ref: docs/adr/0015-separacion-ciclo-de-vida-y-estado-de-resolucion.md

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

    local detailIcon = WINDOW_MANAGER:CreateControl(panelName .. "_DetailIcon", contentParent, CT_TEXTURE)
    detailIcon:SetDimensions(28, 28)
    detailIcon:SetAnchor(TOPLEFT, contentParent, TOPLEFT, 0, 2)
    detailIcon:SetHidden(true)
    tab.detailIcon = detailIcon
    tab.detailTitleParent = contentParent

    local titleLabel = CreateDetailLabel(contentParent, panelName .. "_DetailTitle", 500, 34, "ZoFontWinH2", contentParent, TOPLEFT, 0, 0)
    if titleLabel.SetColor then titleLabel:SetColor(1, 1, 1, 1) end
    if titleLabel.SetModifyTextType then titleLabel:SetModifyTextType(MODIFY_TEXT_TYPE_UPPERCASE) end
    tab.detailTitle = titleLabel

    tab.detailStatus = CreateDetailLabel(contentParent, panelName .. "_DetailStatus", 500, 24, "ZoFontWinH4", contentParent, TOPLEFT, 0, 42)

    local fromLabel = CreateDetailLabel(contentParent, panelName .. "_DetailFrom", 500, 22, "ZoFontWinH4", tab.detailStatus, BOTTOMLEFT, 0, 6)
    if fromLabel.SetColor then fromLabel:SetColor(0.77, 0.76, 0.62, 1) end
    tab.detailFrom = fromLabel

    local toLabel = CreateDetailLabel(contentParent, panelName .. "_DetailTo", 500, 22, "ZoFontWinH4", fromLabel, BOTTOMLEFT, 0, 6)
    if toLabel.SetColor then toLabel:SetColor(0.77, 0.76, 0.62, 1) end
    tab.detailTo = toLabel

    local locLabel = CreateDetailLabel(contentParent, panelName .. "_DetailLoc", 500, 24, "ZoFontWinH4", toLabel, BOTTOMLEFT, 0, 10)
    if locLabel.SetColor then locLabel:SetColor(0.77, 0.76, 0.62, 1) end
    tab.detailLocation = locLabel

    local descBody = CreateDetailLabel(contentParent, panelName .. "_DetailDescBody", 495, 104, "ZoFontWinH4", locLabel, BOTTOMLEFT, 25, 12)
    if descBody.SetColor then descBody:SetColor(0.77, 0.76, 0.62, 1) end
    if descBody.SetMaxLineCount then descBody:SetMaxLineCount(5) end
    tab.detailDescBody = descBody

    local divider = WINDOW_MANAGER:CreateControl(panelName .. "_DetailDivider", contentParent, CT_TEXTURE)
    divider:SetDimensions(512, 4)
    divider:SetAnchor(TOPLEFT, descBody, BOTTOMLEFT, -25, 14)
    divider:SetTexture(Addon.Constants.UI.DIVIDER_TEXTURE)
    tab.detailDivider = divider

    local missionHeader = CreateDetailLabel(contentParent, panelName .. "_DetailMissionHeader", 500, 24, "ZoFontWinH3", divider, BOTTOMLEFT, 0, 10)
    if missionHeader.SetColor then missionHeader:SetColor(1, 1, 1, 1) end
    if missionHeader.SetModifyTextType then missionHeader:SetModifyTextType(MODIFY_TEXT_TYPE_UPPERCASE) end
    missionHeader:SetText(Addon.Locale:Get("LABEL_MISSION_DETAILS_HEADER"))
    missionHeader:SetHidden(true)
    tab.detailMissionHeader = missionHeader

    local missionText = CreateDetailLabel(contentParent, panelName .. "_DetailMissionText", 495, 24, "ZoFontWinH4", missionHeader, BOTTOMLEFT, 25, 10)
    if missionText.SetColor then missionText:SetColor(1, 1, 1, 1) end
    missionText:SetHidden(true)
    tab.detailMissionText = missionText

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

local function IsQuestMapOptionEnabled(quest, key)
    if not quest then return false end
    if quest[key] ~= nil then
        return quest[key] == true
    end
    return Addon.QuestRepository and Addon.QuestRepository:GetSetting(key) == true
end

local function CreateMapMarkerRow(tab, contentParent, name, labelText, settingKey)
    local row = WINDOW_MANAGER:CreateControl(name, contentParent, CT_CONTROL)
    row:SetDimensions(495, 24)
    row:SetHidden(true)

    local label = WINDOW_MANAGER:CreateControl(name .. "_Label", row, CT_LABEL)
    label:SetDimensions(150, 22)
    label:SetAnchor(LEFT, row, LEFT, 0, 0)
    if label.SetFont then label:SetFont("ZoFontWinH4") end
    if label.SetColor then label:SetColor(0.77, 0.76, 0.62, 1) end
    label:SetText(labelText)
    row._label = label

    local chk = Addon.JournalWidgets.CreateCheckButton(name .. "_Chk", row, "", function(isChecked)
        if not tab.selectedQuestId then return end
        local q = Addon.QuestRepository:GetQuestById(tab.selectedQuestId)
        if not q then return end
        Addon.QuestRepository:SetQuestMapVisibility(q.id, settingKey, isChecked)
        ZO_CheckButton_SetLabelText(row._chk, Addon.Locale:Get(isChecked and "MAP_MARKER_STATE_SHOW" or "MAP_MARKER_STATE_OFF"))
        Addon.WorldMapArea:RefreshPins()
    end)
    chk:SetAnchor(LEFT, label, RIGHT, 12, 0)
    row._chk = chk
    return row
end

local function BuildDetailMapControls(tab, contentParent, panelName)
    local objText = tab.detailObjText

    local mapHeader = CreateDetailLabel(contentParent, panelName .. "_DetailMapMarkersHeader", 500, 24, "ZoFontWinH3", objText, BOTTOMLEFT, -25, 14)
    if mapHeader.SetColor then mapHeader:SetColor(1, 1, 1, 1) end
    if mapHeader.SetModifyTextType then mapHeader:SetModifyTextType(MODIFY_TEXT_TYPE_UPPERCASE) end
    mapHeader:SetText(Addon.Locale:Get("LABEL_MAP_MARKERS_HEADER"))
    mapHeader:SetHidden(true)
    tab.detailMapMarkersHeader = mapHeader

    tab.mapMarkerSearchRow = CreateMapMarkerRow(
        tab, contentParent, panelName .. "_MapMarkerSearchRow",
        Addon.Locale:Get("MAP_MARKER_ROW_SEARCH"), "showSearchAreas"
    )
    tab.mapMarkerLocationRow = CreateMapMarkerRow(
        tab, contentParent, panelName .. "_MapMarkerLocationRow",
        Addon.Locale:Get("MAP_MARKER_ROW_LOCATION"), "showLocationAreas"
    )
    tab.mapMarkerDiscoveryRow = CreateMapMarkerRow(
        tab, contentParent, panelName .. "_MapMarkerDiscoveryRow",
        Addon.Locale:Get("MAP_MARKER_ROW_DISCOVERY"), "showDiscoveryAreas"
    )
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

local function ResolveShowOnMapTarget(tab, detailMode, editorMode)
    if tab.viewMode == editorMode then
        local draft = Addon.QuestRepository:GetDraft()
        if Addon.WorldMapArea:HasMapLocation(draft) then
            return draft
        end
        return nil
    end
    if tab.viewMode == detailMode and tab.selectedQuestId ~= nil then
        local q = Addon.QuestRepository:GetQuestById(tab.selectedQuestId)
        if Addon.WorldMapArea:HasMapLocation(q) then
            return q
        end
        return nil
    end
    return nil
end

local function RegisterAbandonDialogAndKeybinds(tab, pane, parent, panelName)
    local DETAIL_MODE = tab.VIEW_MODE.DETAIL
    local EDITOR_MODE = tab.VIEW_MODE.EDITOR

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
        if (tab.viewMode ~= DETAIL_MODE and tab.viewMode ~= EDITOR_MODE) or not tab.selectedQuestId then
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
            local target = ResolveShowOnMapTarget(tab, DETAIL_MODE, EDITOR_MODE)
            if target then
                local targetIndex = (tab.viewMode == EDITOR_MODE) and tab.selectedTargetIndex or nil
                Addon.WorldMapArea:ShowQuestOnMap(target, targetIndex)
            end
        end,
        visible = function()
            return ResolveShowOnMapTarget(tab, DETAIL_MODE, EDITOR_MODE) ~= nil
        end,
        enabled = function()
            return ResolveShowOnMapTarget(tab, DETAIL_MODE, EDITOR_MODE) ~= nil
        end,
    }
    tab.keybindStripDescriptor = {
        alignment = KEYBIND_STRIP_ALIGN_CENTER,
        tab.abandonQuestDescriptor,
        tab.showOnMapDescriptor,
    }

    local showOnMapParent = parent or pane
    local showOnMapBtn = WINDOW_MANAGER.CreateControlFromVirtual
        and WINDOW_MANAGER:CreateControlFromVirtual(panelName .. "_ShowOnMap", showOnMapParent, "ZO_KeybindButton")
        or WINDOW_MANAGER:CreateControl(panelName .. "_ShowOnMap", showOnMapParent, CT_CONTROL)
    ApplyTemplateToControl(showOnMapBtn, "ZO_KeybindButton_Keyboard_Template")
    if showOnMapBtn.SetKeybindButtonDescriptor then
        showOnMapBtn:SetKeybindButtonDescriptor(tab.showOnMapDescriptor)
    end
    showOnMapBtn:SetAnchor(TOPLEFT, showOnMapParent, BOTTOMLEFT, 0, 0)
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
    BuildDetailMapControls(tab, contentParent, panelName)
    BuildDetailActionButtons(tab, contentParent, panelName)
    RegisterAbandonDialogAndKeybinds(tab, pane, parent, panelName)
end

local function FormatPreparedStatusText(quest)
    local lifecycle = Addon.QuestRepository:GetQuestLifecycle(quest)
    local resolution, pInfo = Addon.QuestRepository:GetQuestResolution(quest)
    local recLabel = (type(quest.recipientAccount) == "string" and quest.recipientAccount ~= "")
        and quest.recipientAccount
        or Addon.Locale:Get("LABEL_NO_RECIPIENT")

    if lifecycle == Addon.Constants.QUEST_LIFECYCLE.DRAFT then
        return Addon.Locale:Get("PREPARED_STATUS_DRAFT", recLabel)
    elseif resolution == "completed" and type(pInfo) == "table" then
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
    elseif resolution == "failed" and type(pInfo) == "table" then
        local who = (pInfo.senderDisplayName and pInfo.senderDisplayName ~= "") and pInfo.senderDisplayName or recLabel
        local charPart = (pInfo.characterName and pInfo.characterName ~= "") and (" (" .. pInfo.characterName .. ")") or ""
        local stealthPart = (pInfo.wasDetected == true) and (" " .. Addon.Locale:Get("VALIDATE_STEALTH_DETECTED")) or ""
        return Addon.Locale:Get("PREPARED_STATUS_FAILED", who .. charPart .. stealthPart)
    elseif resolution == "accepted" and type(pInfo) == "table" then
        local who = (pInfo.senderDisplayName and pInfo.senderDisplayName ~= "") and pInfo.senderDisplayName or recLabel
        local charPart = (pInfo.characterName and pInfo.characterName ~= "") and (" (" .. pInfo.characterName .. ")") or ""
        return Addon.Locale:Get("PREPARED_STATUS_ACCEPTED", who .. charPart)
    elseif resolution == "rejected" and type(pInfo) == "table" then
        local who = (pInfo.senderDisplayName and pInfo.senderDisplayName ~= "") and pInfo.senderDisplayName or recLabel
        local charPart = (pInfo.characterName and pInfo.characterName ~= "") and (" (" .. pInfo.characterName .. ")") or ""
        return Addon.Locale:Get("PREPARED_STATUS_REJECTED", who .. charPart)
    end
    return Addon.Locale:Get("PREPARED_STATUS_SENT", (pInfo and pInfo.recipient) or recLabel)
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
    else
        local resolution = Addon.QuestRepository:GetQuestResolution(selectedQuest)
        if resolution == nil then
            tab.detailStatus:SetText(Addon.Locale:Get("STATUS_PENDING"))
        elseif resolution == "failed" or selectedQuest.failed then
            tab.detailStatus:SetText(Addon.Locale:Get("STATUS_FAILED"))
            tab.btnActivate:SetText(activateLabel)
        elseif isCurrentActive then
            tab.detailStatus:SetText(Addon.Locale:Get("STATUS_ACTIVE"))
            tab.btnActivate:SetText(deactivateLabel)
        elseif resolution == "completed" or selectedQuest.completed then
            tab.detailStatus:SetText(Addon.Locale:Get("STATUS_COMPLETED"))
            tab.btnActivate:SetText(activateLabel)
        else
            tab.detailStatus:SetText(Addon.Locale:Get("STATUS_AVAILABLE"))
            tab.btnActivate:SetText(activateLabel)
        end
    end
end

local function AppendTargetObjectiveLines(objLines, selectedQuest, isMasterSummary, pInfo, isSentCompleted, bullet)
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
        elseif isMasterSummary and Addon.QuestRepository:HasTargetLocation(t) then
            local locKey = t.locationRequired and "TARGET_DETAIL_LOC_REQUIRED" or "TARGET_DETAIL_LOC_OPTIONAL"
            line = line .. Addon.Locale:Get(locKey)
        end
        objLines[i] = line
    end
    if totalTargets > maxVisibleObjLines then
        objLines[maxVisibleObjLines] = string.format("... (+%d)", totalTargets - limit)
    end
end

local function ResolveStealthStatusKey(selectedQuest, isSentCompleted, isSentFailed, pInfo)
    local modes = Addon.Constants.STEALTH_MODE
    local stealthMode = Addon.QuestDraftStore:NormalizeStealthMode(selectedQuest.stealthMode, selectedQuest.requireUndetected)
    if stealthMode == modes.DISABLED then
        return nil
    end
    local wasDetected = selectedQuest.wasDetected
    if (isSentCompleted or isSentFailed) and pInfo and pInfo.wasDetected ~= nil then
        wasDetected = pInfo.wasDetected
    end
    if stealthMode == modes.REQUIRED then
        if (selectedQuest.failed or isSentFailed) and wasDetected then
            return "STEALTH_STATUS_REQUIRED_FAILED"
        elseif wasDetected then
            return "STEALTH_STATUS_REQUIRED_DETECTED"
        end
        return "STEALTH_STATUS_REQUIRED_UNDETECTED"
    end
    return wasDetected and "STEALTH_STATUS_OPTIONAL_DETECTED" or "STEALTH_STATUS_OPTIONAL_UNDETECTED"
end

local function BuildMissionDetailLines(selectedQuest, bullet)
    local lines = {}
    local hideRecommended = (selectedQuest.recommendHideMapAreas == true) or (selectedQuest.hideMapArea == true)
    if hideRecommended then
        table.insert(lines, bullet .. Addon.Locale:Get("DETAIL_MAP_MARKERS_NOT_RECOMMENDED"))
    end
    local stealthKey = ResolveStealthStatusKey(selectedQuest, false, false, nil)
    if stealthKey then
        table.insert(lines, bullet .. Addon.Locale:Get(stealthKey))
    end
    return lines
end

local function AppendExtraObjectiveLines(objLines, selectedQuest, isMasterSummary, pInfo, isSentCompleted, isSentFailed, bullet)
    local discoveries = selectedQuest.discoveries or {}
    if #discoveries > 0 then
        if isMasterSummary then
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

    if isMasterSummary then
        local modes = Addon.Constants.STEALTH_MODE
        local stealthMode = Addon.QuestDraftStore:NormalizeStealthMode(selectedQuest.stealthMode, selectedQuest.requireUndetected)
        if stealthMode == modes.DISABLED then
            table.insert(objLines, bullet .. Addon.Locale:Get("MASTER_STEALTH_DISABLED"))
        elseif isSentCompleted or isSentFailed or (selectedQuest.failed == true) then
            local stealthKey = ResolveStealthStatusKey(selectedQuest, isSentCompleted, isSentFailed, pInfo)
            if stealthKey then
                table.insert(objLines, bullet .. Addon.Locale:Get(stealthKey))
            end
        else
            local masterStealthKey = (stealthMode == modes.REQUIRED) and "MASTER_STEALTH_REQUIRED" or "MASTER_STEALTH_OPTIONAL"
            table.insert(objLines, bullet .. Addon.Locale:Get(masterStealthKey))
        end

        if selectedQuest.clue and selectedQuest.clue ~= "" then
            local clueLine = Addon.Locale:Get("DIALOGUE_DETAIL_CLUE_FORMAT", selectedQuest.clue):gsub("^•%s*", bullet)
            table.insert(objLines, clueLine)
        end
        local dialogues = selectedQuest.dialogues or {}
        if #dialogues > 0 then
            local maxNpcs = (Addon.Constants and Addon.Constants.DIALOGUE and Addon.Constants.DIALOGUE.MAX_NPCS) or 4
            local dlgLine = Addon.Locale:Get("DIALOGUE_DETAIL_NPCS_FORMAT", #dialogues, maxNpcs):gsub("^•%s*", bullet)
            table.insert(objLines, dlgLine)
        end
        local hideRecommended = (selectedQuest.recommendHideMapAreas == true) or (selectedQuest.hideMapArea == true)
        local mapRecKey = hideRecommended and "MASTER_MAP_MARKERS_HIDE" or "MASTER_MAP_MARKERS_SHOW"
        local mapRecLine = Addon.Locale:Get(mapRecKey):gsub("^•%s*", bullet)
        table.insert(objLines, mapRecLine)
    end
end

local function BuildObjectiveLines(selectedQuest, isPrepared, isCurrentActive)
    local objLines = {}
    local bullet = "|t16:16:/esoui/art/miscellaneous/bullet.dds|t "
    local lifecycle = Addon.QuestRepository:GetQuestLifecycle(selectedQuest)
    local resolution, pInfo
    if isPrepared then
        resolution, pInfo = Addon.QuestRepository:GetQuestResolution(selectedQuest)
    end
    local isMasterSummary = isPrepared and not isCurrentActive
    local isSentCompleted = isPrepared and lifecycle == Addon.Constants.QUEST_LIFECYCLE.SENT and resolution == "completed" and type(pInfo) == "table"
    local isSentFailed = isPrepared and lifecycle == Addon.Constants.QUEST_LIFECYCLE.SENT and resolution == "failed" and type(pInfo) == "table"

    AppendTargetObjectiveLines(objLines, selectedQuest, isMasterSummary, pInfo, isSentCompleted, bullet)
    AppendExtraObjectiveLines(objLines, selectedQuest, isMasterSummary, pInfo, isSentCompleted, isSentFailed, bullet)

    return objLines
end

local function UpdateDetailMapControls(tab, selectedQuest, isOffered, isPrepared, isCurrentActive)
    local needsMigration = isPrepared and (selectedQuest.needsMigration == true)
    local showToggles = (not isOffered) and (not needsMigration) and ((not isPrepared) or isCurrentActive)

    local rows = {
        {
            row = tab.mapMarkerSearchRow,
            visible = showToggles and Addon.QuestRepository:HasQuestSearchAreas(selectedQuest),
            key = "showSearchAreas",
        },
        {
            row = tab.mapMarkerLocationRow,
            visible = showToggles and Addon.QuestRepository:HasQuestTargetLocation(selectedQuest),
            key = "showLocationAreas",
        },
        {
            row = tab.mapMarkerDiscoveryRow,
            visible = showToggles and Addon.QuestRepository:HasQuestDiscoveryPoints(selectedQuest),
            key = "showDiscoveryAreas",
        },
    }

    local prevControl = tab.detailMapMarkersHeader
    local visibleCount = 0
    for _, entry in ipairs(rows) do
        local row = entry.row
        if row then
            if entry.visible then
                local isOn = IsQuestMapOptionEnabled(selectedQuest, entry.key)
                row:ClearAnchors()
                if prevControl == tab.detailMapMarkersHeader then
                    row:SetAnchor(TOPLEFT, tab.detailMapMarkersHeader, BOTTOMLEFT, 25, 8)
                else
                    row:SetAnchor(TOPLEFT, prevControl, BOTTOMLEFT, 0, 6)
                end
                ZO_CheckButton_SetCheckState(row._chk, isOn)
                ZO_CheckButton_SetLabelText(row._chk, Addon.Locale:Get(isOn and "MAP_MARKER_STATE_SHOW" or "MAP_MARKER_STATE_OFF"))
                row:SetHidden(false)
                prevControl = row
                visibleCount = visibleCount + 1
            else
                row:SetHidden(true)
            end
        end
    end

    if visibleCount > 0 and tab.detailMapMarkersHeader then
        tab.detailMapMarkersHeader:ClearAnchors()
        tab.detailMapMarkersHeader:SetAnchor(TOPLEFT, tab.detailObjText, BOTTOMLEFT, -25, 14)
        tab.detailMapMarkersHeader:SetHidden(false)
        return prevControl, -25, 14, 38 + (visibleCount * 30)
    end

    if tab.detailMapMarkersHeader then
        tab.detailMapMarkersHeader:SetHidden(true)
    end
    return tab.detailObjText, -25, 16, 0
end

local function UpdateDetailActionButtons(tab, selectedQuest, isOffered, isPrepared, anchorControl, offsetX, offsetY)
    tab:UpdateShowOnMapVisibility()
    tab.btnActivate:ClearAnchors()
    tab.btnActivate:SetAnchor(TOPLEFT, anchorControl, BOTTOMLEFT, offsetX, offsetY)
    if tab.btnAcceptOffered then
        tab.btnAcceptOffered:ClearAnchors()
        tab.btnAcceptOffered:SetAnchor(TOPLEFT, anchorControl, BOTTOMLEFT, offsetX, offsetY)
    end
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
            tab.btnReset:SetAnchor(TOPLEFT, anchorControl, BOTTOMLEFT, offsetX, offsetY)
        end
    end

    if tab.keybindStripDescriptor then
        KEYBIND_STRIP:UpdateKeybindButtonGroup(tab.keybindStripDescriptor)
    end
end

local function RenderEmptyDetailPane(tab)
    if tab.detailIcon then
        tab.detailIcon:SetHidden(true)
    end
    if tab.detailTitle and tab.detailTitleParent then
        tab.detailTitle:ClearAnchors()
        tab.detailTitle:SetAnchor(TOPLEFT, tab.detailTitleParent, TOPLEFT, 0, 0)
        tab.detailTitle:SetDimensions(500, 34)
    end
    tab.detailTitle:SetText(Addon.Locale:Get("TAB_TITLE"))
    tab.detailStatus:SetText(Addon.Locale:Get("EMPTY_QUEST_LIST"))
    tab.detailFrom:SetText("")
    tab.detailTo:SetText("")
    tab.detailLocation:SetText("")
    tab.detailDescBody:SetText("")
    tab.detailObjHeader:SetHidden(true)
    tab.detailObjText:SetText("")
    if tab.detailMissionHeader then tab.detailMissionHeader:SetHidden(true) end
    if tab.detailMissionText then
        tab.detailMissionText:SetText("")
        tab.detailMissionText:SetHidden(true)
    end
    if tab.detailMapMarkersHeader then tab.detailMapMarkersHeader:SetHidden(true) end
    if tab.mapMarkerSearchRow then tab.mapMarkerSearchRow:SetHidden(true) end
    if tab.mapMarkerLocationRow then tab.mapMarkerLocationRow:SetHidden(true) end
    if tab.mapMarkerDiscoveryRow then tab.mapMarkerDiscoveryRow:SetHidden(true) end
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
    local iconTex = Addon.QuestDraftStore and Addon.QuestDraftStore:GetQuestIconTexture(selectedQuest.icon) or nil
    if tab.detailIcon and tab.detailTitleParent then
        if iconTex then
            tab.detailIcon:SetTexture(iconTex)
            tab.detailIcon:SetHidden(false)
            tab.detailTitle:ClearAnchors()
            tab.detailTitle:SetAnchor(TOPLEFT, tab.detailIcon, TOPRIGHT, 8, -2)
            tab.detailTitle:SetDimensions(464, 34)
        else
            tab.detailIcon:SetHidden(true)
            tab.detailTitle:ClearAnchors()
            tab.detailTitle:SetAnchor(TOPLEFT, tab.detailTitleParent, TOPLEFT, 0, 0)
            tab.detailTitle:SetDimensions(500, 34)
        end
    end
    tab.detailTitle:SetText((selectedQuest.title or ""):upper())

    local isPrepared = Addon.QuestRepository:IsPreparedQuest(selectedQuest)
    local isOffered = Addon.QuestRepository:IsOfferedQuest(selectedQuest)
    local isCurrentActive = (activeQuest and activeQuest.id == selectedQuest.id)
    local isPlayerView = (not isPrepared) or isCurrentActive

    local bullet = "|t16:16:/esoui/art/miscellaneous/bullet.dds|t "
    local missionHeight = 0
    if isPlayerView and tab.detailMissionHeader and tab.detailMissionText then
        local missionLines = BuildMissionDetailLines(selectedQuest, bullet)
        if #missionLines > 0 then
            tab.detailMissionHeader:SetHidden(false)
            tab.detailMissionText:SetDimensions(495, 0)
            tab.detailMissionText:SetText(table.concat(missionLines, "\n"))
            local mTextHeight = tab.detailMissionText.GetTextHeight and tab.detailMissionText:GetTextHeight()
            local mBoxHeight = mTextHeight and (mTextHeight + 12) or (#missionLines * 24)
            mBoxHeight = math.max(24, mBoxHeight)
            tab.detailMissionText:SetDimensions(495, mBoxHeight)
            tab.detailMissionText:SetHidden(false)
            tab.detailObjHeader:ClearAnchors()
            tab.detailObjHeader:SetAnchor(TOPLEFT, tab.detailMissionText, BOTTOMLEFT, -25, 14)
            missionHeight = 38 + mBoxHeight
        else
            tab.detailMissionHeader:SetHidden(true)
            tab.detailMissionText:SetText("")
            tab.detailMissionText:SetHidden(true)
            tab.detailObjHeader:ClearAnchors()
            tab.detailObjHeader:SetAnchor(TOPLEFT, tab.detailDivider, BOTTOMLEFT, 0, 10)
        end
    else
        if tab.detailMissionHeader then tab.detailMissionHeader:SetHidden(true) end
        if tab.detailMissionText then
            tab.detailMissionText:SetText("")
            tab.detailMissionText:SetHidden(true)
        end
        if tab.detailDivider then
            tab.detailObjHeader:ClearAnchors()
            tab.detailObjHeader:SetAnchor(TOPLEFT, tab.detailDivider, BOTTOMLEFT, 0, 10)
        end
    end

    tab.detailObjHeader:SetText(Addon.Locale:Get(isPlayerView and "LABEL_OBJECTIVE_HEADER" or "LABEL_MISSION_DETAILS_HEADER"))

    ApplyDetailStatusAndActivateLabel(tab, selectedQuest, isOffered, isPrepared, isCurrentActive)
    local statusText = tab.detailStatus:GetText() or ""
    tab.detailStatus:SetDimensions(500, 0)
    local statusHeight = tab.detailStatus.GetTextHeight and tab.detailStatus:GetTextHeight()
    if not statusHeight then
        local _, newlines = statusText:gsub("\n", "\n")
        statusHeight = (newlines + 1) * 24
    end
    statusHeight = math.max(24, statusHeight)
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

    local objLines = BuildObjectiveLines(selectedQuest, isPrepared, isCurrentActive)
    tab.detailObjText:SetDimensions(495, 0)
    tab.detailObjText:SetText(table.concat(objLines, "\n"))
    local textHeight = tab.detailObjText.GetTextHeight and tab.detailObjText:GetTextHeight()
    local objHeight = textHeight and (textHeight + 16) or (#objLines * 24)
    tab.detailObjText:SetDimensions(495, math.max(32, objHeight))
    local anchorControl, offsetX, offsetY, extraMapHeight = UpdateDetailMapControls(tab, selectedQuest, isOffered, isPrepared, isCurrentActive)
    if tab.detailScrollChild and tab.detailScrollChild.SetDimensions then
        tab.detailScrollChild:SetDimensions(526, math.max(650, 645 + missionHeight + objHeight + math.max(0, statusHeight - 24) + extraMapHeight))
    end

    UpdateDetailActionButtons(tab, selectedQuest, isOffered, isPrepared, anchorControl, offsetX, offsetY)
end
