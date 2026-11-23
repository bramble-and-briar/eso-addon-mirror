-- Ref: docs/adr/0001-arquitectura-modular-zero-dependency-y-savedvars-por-personaje.md
-- Ref: docs/adr/0003-integracion-nativa-ui-diario-mapa-y-hud.md
-- Ref: docs/adr/0004-objetivos-multiples-inferidos-por-reticula.md
-- Ref: docs/adr/0006-puntos-de-descubrimiento-ocultos.md
-- Ref: docs/adr/0007-dialogos-inyectados-en-npcs-nativos.md

RPQuest = RPQuest or {}
local Addon = RPQuest

Addon.JournalEditorSections = {}
local EditorSections = Addon.JournalEditorSections

function EditorSections.CreateAccordionSection(tab, formParent, panelName, key, localeKey, bodyHeight)
    local divider = WINDOW_MANAGER:CreateControl(panelName .. "_EdDiv_" .. key, formParent, CT_TEXTURE)
    divider:SetDimensions(512, 4)
    divider:SetTexture(Addon.Constants.UI.DIVIDER_TEXTURE)

    local headerBtn = WINDOW_MANAGER:CreateControl(panelName .. "_EdHdr_" .. key, formParent, CT_BUTTON)
    headerBtn:SetDimensions(510, 28)
    headerBtn:SetMouseEnabled(true)
    headerBtn:SetFont("ZoFontGameBold")
    if headerBtn.SetHorizontalAlignment then
        headerBtn:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    end
    headerBtn:SetNormalFontColor(0.91, 0.83, 0.63, 1)
    headerBtn:SetMouseOverFontColor(1, 1, 1, 1)

    local hdrBg = WINDOW_MANAGER:CreateControl(panelName .. "_EdHdrBg_" .. key, headerBtn, CT_BACKDROP)
    hdrBg:SetDimensions(510, 28)
    hdrBg:SetAnchor(TOPLEFT, headerBtn, TOPLEFT, 0, 0)
    hdrBg:SetCenterColor(0.08, 0.08, 0.10, 0.65)
    hdrBg:SetEdgeColor(0.45, 0.39, 0.24, 0.55)

    headerBtn:SetHandler("OnClicked", function()
        PlaySound(SOUNDS.DEFAULT_CLICK)
        tab:ToggleEditorSection(key)
    end)

    local body = WINDOW_MANAGER:CreateControl(panelName .. "_EdBody_" .. key, formParent, CT_CONTROL)
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
    table.insert(tab.editorSections, sec)
    tab.editorSectionsByKey[key] = sec
    return sec
end

function EditorSections.BuildBaseFields(tab, formParent, panelName)
    local CreateEditBox = Addon.JournalWidgets.CreateEditBoxWithBackdrop

    local lblTitle = WINDOW_MANAGER:CreateControl(panelName .. "_LblInputTitle", formParent, CT_LABEL)
    lblTitle:SetAnchor(TOPLEFT, formParent, TOPLEFT, 0, 0)
    if lblTitle.SetFont then lblTitle:SetFont("ZoFontGameBold") end
    lblTitle:SetText(Addon.Locale:Get("LABEL_INPUT_TITLE"))
    tab.lblInputTitle = lblTitle

    local titleBg, titleEdit = CreateEditBox(
        panelName .. "_TitleEdit", formParent, 510, 30, 90, false,
        function(val) Addon.QuestRepository:UpdateDraftFields({ title = val }, true) end
    )
    titleBg:SetAnchor(TOPLEFT, formParent, TOPLEFT, 0, 22)
    tab.titleBg = titleBg
    tab.titleEdit = titleEdit

    local lblDesc = WINDOW_MANAGER:CreateControl(panelName .. "_LblInputDesc", formParent, CT_LABEL)
    lblDesc:SetAnchor(TOPLEFT, formParent, TOPLEFT, 0, 64)
    if lblDesc.SetFont then lblDesc:SetFont("ZoFontGameBold") end
    lblDesc:SetText(Addon.Locale:Get("LABEL_INPUT_DESCRIPTION"))
    tab.lblInputDesc = lblDesc

    local descBg, descEdit = CreateEditBox(
        panelName .. "_DescEdit", formParent, 510, 72, 400, true,
        function(val) Addon.QuestRepository:UpdateDraftFields({ description = val }, true) end
    )
    descBg:SetAnchor(TOPLEFT, formParent, TOPLEFT, 0, 86)
    tab.descBg = descBg
    tab.descEdit = descEdit

    local lblRecipient = WINDOW_MANAGER:CreateControl(panelName .. "_LblInputRecipient", formParent, CT_LABEL)
    lblRecipient:SetAnchor(TOPLEFT, formParent, TOPLEFT, 0, 166)
    if lblRecipient.SetFont then lblRecipient:SetFont("ZoFontGameBold") end
    lblRecipient:SetText(Addon.Locale:Get("LABEL_INPUT_RECIPIENT"))
    tab.lblInputRecipient = lblRecipient

    local recipientBg, recipientEdit = CreateEditBox(
        panelName .. "_RecipientEdit", formParent, 250, 30, 64, false,
        function(val) Addon.QuestRepository:UpdateDraftFields({ recipientAccount = val }, true) end
    )
    recipientBg:SetAnchor(TOPLEFT, formParent, TOPLEFT, 0, 188)
    tab.recipientBg = recipientBg
    tab.recipientEdit = recipientEdit

    local lblRecipientChar = WINDOW_MANAGER:CreateControl(panelName .. "_LblInputRecipientChar", formParent, CT_LABEL)
    lblRecipientChar:SetAnchor(TOPLEFT, formParent, TOPLEFT, 260, 166)
    if lblRecipientChar.SetFont then lblRecipientChar:SetFont("ZoFontGameBold") end
    lblRecipientChar:SetText(Addon.Locale:Get("LABEL_INPUT_RECIPIENT_CHAR"))
    tab.lblInputRecipientChar = lblRecipientChar

    local recipientCharBg, recipientCharEdit = CreateEditBox(
        panelName .. "_RecipientCharEdit", formParent, 250, 30, 64, false,
        function(val) Addon.QuestRepository:UpdateDraftFields({ recipientCharacterName = val }, true) end
    )
    recipientCharBg:SetAnchor(TOPLEFT, formParent, TOPLEFT, 260, 188)
    tab.recipientCharBg = recipientCharBg
    tab.recipientCharEdit = recipientCharEdit
end

function EditorSections.BuildTargetAreaControls(tab, targetBody, panelName)
    local CreateStyledButton = Addon.JournalWidgets.CreateStyledButton

    local lblCapturedTarget = WINDOW_MANAGER:CreateControl(panelName .. "_LblCapturedTarget", targetBody, CT_LABEL)
    lblCapturedTarget:SetDimensions(360, 28)
    lblCapturedTarget:SetAnchor(TOPLEFT, targetBody, TOPLEFT, 4, 2)
    if lblCapturedTarget.SetFont then lblCapturedTarget:SetFont("ZoFontGame") end
    tab.lblCapturedTarget = lblCapturedTarget

    tab.btnClearTargets = CreateStyledButton(panelName .. "_BtnClearTargets", targetBody, 140, 24, Addon.Locale:Get("BTN_CLEAR_TARGETS"), function()
        tab.selectedTargetIndex = nil
        Addon.QuestRepository:ClearDraftTargets()
    end)
    tab.btnClearTargets:SetAnchor(TOPLEFT, targetBody, TOPLEFT, 370, 0)
    tab.btnClearTargets:SetHidden(true)

    local lblAreaSize = WINDOW_MANAGER:CreateControl(panelName .. "_LblAreaSize", targetBody, CT_LABEL)
    lblAreaSize:SetAnchor(TOPLEFT, targetBody, TOPLEFT, 0, 36)
    if lblAreaSize.SetFont then lblAreaSize:SetFont("ZoFontGameBold") end
    lblAreaSize:SetText(Addon.Locale:Get("LABEL_AREA_SIZE"))
    tab.lblAreaSize = lblAreaSize

    local radii = Addon.Constants.AREA_RADIUS
    tab.btnRadiusSmall = CreateStyledButton(panelName .. "_BtnRadSmall", targetBody, 110, 26, "", function()
        Addon.QuestRepository:UpdateDraftFields({ areaRadius = radii.SMALL })
    end)
    tab.btnRadiusSmall:SetAnchor(TOPLEFT, targetBody, TOPLEFT, 0, 58)

    tab.btnRadiusMedium = CreateStyledButton(panelName .. "_BtnRadMedium", targetBody, 110, 26, "", function()
        Addon.QuestRepository:UpdateDraftFields({ areaRadius = radii.MEDIUM })
    end)
    tab.btnRadiusMedium:SetAnchor(TOPLEFT, targetBody, TOPLEFT, 120, 58)

    tab.btnRadiusLarge = CreateStyledButton(panelName .. "_BtnRadLarge", targetBody, 110, 26, "", function()
        Addon.QuestRepository:UpdateDraftFields({ areaRadius = radii.LARGE })
    end)
    tab.btnRadiusLarge:SetAnchor(TOPLEFT, targetBody, TOPLEFT, 240, 58)

    tab.btnHideMapArea = CreateStyledButton(panelName .. "_BtnHideMapArea", targetBody, 280, 26, Addon.Locale:Get("OPT_HIDE_MAP_AREA"), function()
        local d = Addon.QuestRepository:GetDraft()
        Addon.QuestRepository:UpdateDraftFields({ hideMapArea = not (d and d.hideMapArea) })
    end)
    tab.btnHideMapArea:SetAnchor(TOPLEFT, targetBody, TOPLEFT, 0, 94)
end

local function BuildTargetNavControls(tab, targetBody, panelName)
    local CreateStyledButton = Addon.JournalWidgets.CreateStyledButton
    local CycleIndex = Addon.JournalWidgets.CycleIndex

    tab.btnTargetPrev = CreateStyledButton(panelName .. "_BtnTargetPrev", targetBody, 28, 24, "<", function()
        local total = #(Addon.QuestRepository:GetDraft().targets or {})
        local nextIdx = CycleIndex(tab.selectedTargetIndex, total, -1)
        if nextIdx then tab.selectedTargetIndex = nextIdx; tab:RefreshEditorPane() end
    end)
    tab.btnTargetPrev:SetAnchor(TOPLEFT, targetBody, TOPLEFT, 0, 130)
    tab.btnTargetPrev:SetHidden(true)

    local lblTargetCfgIndex = WINDOW_MANAGER:CreateControl(panelName .. "_LblTargetCfgIndex", targetBody, CT_LABEL)
    lblTargetCfgIndex:SetDimensions(300, 24)
    lblTargetCfgIndex:SetAnchor(TOPLEFT, targetBody, TOPLEFT, 34, 132)
    if lblTargetCfgIndex.SetFont then lblTargetCfgIndex:SetFont("ZoFontGameBold") end
    lblTargetCfgIndex:SetHidden(true)
    tab.lblTargetCfgIndex = lblTargetCfgIndex

    tab.btnTargetOptional = CreateStyledButton(panelName .. "_BtnTargetOptional", targetBody, 134, 24, "", function()
        local idx = tab.selectedTargetIndex
        local draft = Addon.QuestRepository:GetDraft()
        local target = idx and draft.targets and draft.targets[idx]
        if target then Addon.QuestRepository:UpdateDraftTarget(idx, { optional = target.optional ~= true }) end
    end)
    tab.btnTargetOptional:SetAnchor(TOPLEFT, targetBody, TOPLEFT, 340, 130)
    tab.btnTargetOptional:SetHidden(true)

    tab.btnTargetNext = CreateStyledButton(panelName .. "_BtnTargetNext", targetBody, 28, 24, ">", function()
        local total = #(Addon.QuestRepository:GetDraft().targets or {})
        local nextIdx = CycleIndex(tab.selectedTargetIndex, total, 1)
        if nextIdx then tab.selectedTargetIndex = nextIdx; tab:RefreshEditorPane() end
    end)
    tab.btnTargetNext:SetAnchor(TOPLEFT, targetBody, TOPLEFT, 480, 130)
    tab.btnTargetNext:SetHidden(true)
end

local function BuildTargetLocationControls(tab, targetBody, panelName)
    local CreateStyledButton = Addon.JournalWidgets.CreateStyledButton
    local CreateEditBox = Addon.JournalWidgets.CreateEditBoxWithBackdrop

    tab.btnCaptureTargetLoc = CreateStyledButton(panelName .. "_BtnCaptureTargetLoc", targetBody, 136, 24, Addon.Locale:Get("BTN_CAPTURE_TARGET_LOC"), function()
        local idx = tab.selectedTargetIndex
        local draft = Addon.QuestRepository:GetDraft()
        if not (idx and draft.targets and draft.targets[idx]) then return end
        local zoneId, worldX, _, worldZ = GetUnitWorldPosition("player")
        if not zoneId or zoneId == 0 or not worldX or not worldZ then
            Addon.Announcements:ShowAlert(Addon.Locale:Get("ALERT_DISCOVERY_INVALID_POS"), true)
            return
        end
        local updated = Addon.QuestRepository:CaptureDraftTargetLocation(idx, zoneId, worldX, worldZ)
        if updated then
            local meters = math.floor((updated.radius or Addon.Constants.DISCOVERY_RADIUS.MEDIUM) / 100)
            Addon.Announcements:ShowAlert(Addon.Locale:Get("ALERT_TARGET_LOC_CAPTURED", updated.name or "", meters), false)
        end
    end)
    tab.btnCaptureTargetLoc:SetAnchor(TOPLEFT, targetBody, TOPLEFT, 0, 160)
    tab.btnCaptureTargetLoc:SetHidden(true)

    tab.btnClearTargetLoc = CreateStyledButton(panelName .. "_BtnClearTargetLoc", targetBody, 114, 24, Addon.Locale:Get("BTN_CLEAR_TARGET_LOC"), function()
        if tab.selectedTargetIndex then Addon.QuestRepository:ClearDraftTargetLocation(tab.selectedTargetIndex) end
    end)
    tab.btnClearTargetLoc:SetAnchor(TOPLEFT, targetBody, TOPLEFT, 144, 160)
    tab.btnClearTargetLoc:SetHidden(true)

    tab.btnTargetLocRequired = CreateStyledButton(panelName .. "_BtnTargetLocReq", targetBody, 170, 24, "", function()
        local idx = tab.selectedTargetIndex
        local draft = Addon.QuestRepository:GetDraft()
        local target = idx and draft.targets and draft.targets[idx]
        if target then Addon.QuestRepository:UpdateDraftTarget(idx, { locationRequired = target.locationRequired ~= true }) end
    end)
    tab.btnTargetLocRequired:SetAnchor(TOPLEFT, targetBody, TOPLEFT, 266, 160)
    tab.btnTargetLocRequired:SetHidden(true)

    local discRadii = Addon.Constants.DISCOVERY_RADIUS
    local function SetTargetLocRad(rad)
        if tab.selectedTargetIndex then Addon.QuestRepository:UpdateDraftTarget(tab.selectedTargetIndex, { radius = rad }) end
    end

    tab.btnTargetRadSmall = CreateStyledButton(panelName .. "_BtnTargetRadSmall", targetBody, 68, 22, "", function() SetTargetLocRad(discRadii.SMALL) end)
    tab.btnTargetRadSmall:SetAnchor(TOPLEFT, targetBody, TOPLEFT, 0, 190)
    tab.btnTargetRadSmall:SetHidden(true)

    tab.btnTargetRadMedium = CreateStyledButton(panelName .. "_BtnTargetRadMedium", targetBody, 68, 22, "", function() SetTargetLocRad(discRadii.MEDIUM) end)
    tab.btnTargetRadMedium:SetAnchor(TOPLEFT, targetBody, TOPLEFT, 74, 190)
    tab.btnTargetRadMedium:SetHidden(true)

    tab.btnTargetRadLarge = CreateStyledButton(panelName .. "_BtnTargetRadLarge", targetBody, 68, 22, "", function() SetTargetLocRad(discRadii.LARGE) end)
    tab.btnTargetRadLarge:SetAnchor(TOPLEFT, targetBody, TOPLEFT, 148, 190)
    tab.btnTargetRadLarge:SetHidden(true)

    local lblTargetLocStatus = WINDOW_MANAGER:CreateControl(panelName .. "_LblTargetLocStatus", targetBody, CT_LABEL)
    lblTargetLocStatus:SetDimensions(286, 22)
    lblTargetLocStatus:SetAnchor(TOPLEFT, targetBody, TOPLEFT, 224, 192)
    if lblTargetLocStatus.SetFont then lblTargetLocStatus:SetFont("ZoFontGame") end
    lblTargetLocStatus:SetHidden(true)
    tab.lblTargetLocStatus = lblTargetLocStatus

    local targetCustomBg, targetCustomEdit = CreateEditBox(
        panelName .. "_TargetCustomMsgEdit", targetBody, 510, 30, 160, false,
        function(val)
            if tab.selectedTargetIndex then
                Addon.QuestRepository:UpdateDraftTarget(tab.selectedTargetIndex, { customMessage = val }, true)
            end
        end,
        Addon.Locale:Get("HINT_TARGET_CUSTOM_MSG")
    )
    targetCustomBg:SetAnchor(TOPLEFT, targetBody, TOPLEFT, 0, 218)
    targetCustomBg:SetHidden(true)
    tab.targetCustomBg = targetCustomBg
    tab.targetCustomEdit = targetCustomEdit
end

function EditorSections.BuildTargetConfigControls(tab, targetBody, panelName)
    BuildTargetNavControls(tab, targetBody, panelName)
    BuildTargetLocationControls(tab, targetBody, panelName)
end

function EditorSections.BuildDiscoveryControls(tab, discBody, panelName)
    local CreateStyledButton = Addon.JournalWidgets.CreateStyledButton
    local CycleIndex = Addon.JournalWidgets.CycleIndex

    tab.btnCaptureDiscovery = CreateStyledButton(panelName .. "_BtnCaptureDiscovery", discBody, 130, 26, Addon.Locale:Get("BTN_CAPTURE_DISCOVERY"), function()
        local draft = Addon.QuestRepository:GetDraft()
        local hasExisting = #(draft.discoveries or {}) > 0
        local msgText = (not hasExisting and tab.discoveryMsgEdit) and tab.discoveryMsgEdit:GetText() or nil
        local _, count = Addon.TargetCapture:CaptureDiscoveryPoint(msgText)
        if count and count > 0 then
            tab.selectedDiscoveryIndex = count
            Addon.QuestRepository:UpdateDraftFields({ discoveryMessage = "" }, true)
            tab:RefreshEditorPane()
        end
    end)
    tab.btnCaptureDiscovery:SetAnchor(TOPLEFT, discBody, TOPLEFT, 0, 0)

    tab.btnClearDiscoveries = CreateStyledButton(panelName .. "_BtnClearDiscoveries", discBody, 100, 26, Addon.Locale:Get("BTN_CLEAR_DISCOVERIES"), function()
        tab.selectedDiscoveryIndex = nil
        Addon.QuestRepository:ClearDraftDiscoveries()
    end)
    tab.btnClearDiscoveries:SetAnchor(TOPLEFT, discBody, TOPLEFT, 140, 0)
    tab.btnClearDiscoveries:SetHidden(true)

    tab.btnDiscPrev = CreateStyledButton(panelName .. "_BtnDiscPrev", discBody, 28, 26, "<", function()
        local total = #(Addon.QuestRepository:GetDraft().discoveries or {})
        local nextIdx = CycleIndex(tab.selectedDiscoveryIndex, total, -1)
        if nextIdx then tab.selectedDiscoveryIndex = nextIdx; tab:RefreshEditorPane() end
    end)
    tab.btnDiscPrev:SetAnchor(TOPLEFT, discBody, TOPLEFT, 256, 0)
    tab.btnDiscPrev:SetHidden(true)

    local lblDiscIndex = WINDOW_MANAGER:CreateControl(panelName .. "_LblDiscIndex", discBody, CT_LABEL)
    lblDiscIndex:SetDimensions(66, 26)
    lblDiscIndex:SetAnchor(TOPLEFT, discBody, TOPLEFT, 288, 3)
    if lblDiscIndex.SetFont then lblDiscIndex:SetFont("ZoFontGameBold") end
    if lblDiscIndex.SetHorizontalAlignment then lblDiscIndex:SetHorizontalAlignment(TEXT_ALIGN_CENTER) end
    lblDiscIndex:SetHidden(true)
    tab.lblDiscIndex = lblDiscIndex

    tab.btnDiscNext = CreateStyledButton(panelName .. "_BtnDiscNext", discBody, 28, 26, ">", function()
        local total = #(Addon.QuestRepository:GetDraft().discoveries or {})
        local nextIdx = CycleIndex(tab.selectedDiscoveryIndex, total, 1)
        if nextIdx then tab.selectedDiscoveryIndex = nextIdx; tab:RefreshEditorPane() end
    end)
    tab.btnDiscNext:SetAnchor(TOPLEFT, discBody, TOPLEFT, 358, 0)
    tab.btnDiscNext:SetHidden(true)

    tab.btnDiscRemove = CreateStyledButton(panelName .. "_BtnDiscRemove", discBody, 114, 26, Addon.Locale:Get("BTN_REMOVE_DISCOVERY"), function()
        local idx = tab.selectedDiscoveryIndex
        if not idx then return end
        local draft = Addon.QuestRepository:RemoveDraftDiscoveryPoint(idx)
        local total = draft and #(draft.discoveries or {}) or 0
        tab.selectedDiscoveryIndex = (total == 0) and nil or math.min(idx, total)
        tab:RefreshEditorPane()
    end)
    tab.btnDiscRemove:SetAnchor(TOPLEFT, discBody, TOPLEFT, 396, 0)
    tab.btnDiscRemove:SetHidden(true)
end

function EditorSections.BuildDiscoveryInputs(tab, discBody, panelName)
    local CreateStyledButton = Addon.JournalWidgets.CreateStyledButton
    local CreateEditBox = Addon.JournalWidgets.CreateEditBoxWithBackdrop

    local function SetDiscRad(radius)
        local draft = Addon.QuestRepository:GetDraft()
        local idx = tab.selectedDiscoveryIndex
        if idx and draft.discoveries and draft.discoveries[idx] then
            Addon.QuestRepository:UpdateDraftDiscoveryPoint(idx, { radius = radius })
        else
            Addon.QuestRepository:UpdateDraftFields({ discoveryRadius = radius })
        end
    end

    local discRadii = Addon.Constants.DISCOVERY_RADIUS
    tab.btnDiscRadSmall = CreateStyledButton(panelName .. "_BtnDiscRadSmall", discBody, 68, 24, "", function() SetDiscRad(discRadii.SMALL) end)
    tab.btnDiscRadSmall:SetAnchor(TOPLEFT, discBody, TOPLEFT, 0, 36)

    tab.btnDiscRadMedium = CreateStyledButton(panelName .. "_BtnDiscRadMedium", discBody, 68, 24, "", function() SetDiscRad(discRadii.MEDIUM) end)
    tab.btnDiscRadMedium:SetAnchor(TOPLEFT, discBody, TOPLEFT, 74, 36)

    tab.btnDiscRadLarge = CreateStyledButton(panelName .. "_BtnDiscRadLarge", discBody, 68, 24, "", function() SetDiscRad(discRadii.LARGE) end)
    tab.btnDiscRadLarge:SetAnchor(TOPLEFT, discBody, TOPLEFT, 148, 36)

    local discMsgBg, discMsgEdit = CreateEditBox(
        panelName .. "_DiscoveryMsgEdit", discBody, 510, 30, 160, false,
        function(val)
            local draft = Addon.QuestRepository:GetDraft()
            local idx = tab.selectedDiscoveryIndex
            if idx and draft.discoveries and draft.discoveries[idx] then
                Addon.QuestRepository:UpdateDraftDiscoveryPoint(idx, { message = val }, true)
            else
                Addon.QuestRepository:UpdateDraftFields({ discoveryMessage = val }, true)
            end
        end
    )
    discMsgBg:SetAnchor(TOPLEFT, discBody, TOPLEFT, 0, 68)
    tab.discoveryMsgBg = discMsgBg
    tab.discoveryMsgEdit = discMsgEdit

    local lblCapturedDiscoveries = WINDOW_MANAGER:CreateControl(panelName .. "_LblCapturedDiscoveries", discBody, CT_LABEL)
    lblCapturedDiscoveries:SetDimensions(510, 32)
    lblCapturedDiscoveries:SetAnchor(TOPLEFT, discBody, TOPLEFT, 4, 106)
    if lblCapturedDiscoveries.SetFont then lblCapturedDiscoveries:SetFont("ZoFontGame") end
    tab.lblCapturedDiscoveries = lblCapturedDiscoveries
end

function EditorSections.BuildDialogueControls(tab, dlgBody, panelName)
    local CreateStyledButton = Addon.JournalWidgets.CreateStyledButton
    local CycleIndex = Addon.JournalWidgets.CycleIndex

    tab.btnAddLastNpc = CreateStyledButton(panelName .. "_BtnAddLastNpc", dlgBody, 130, 26, Addon.Locale:Get("BTN_ADD_LAST_NPC"), function()
        local preDraft = Addon.QuestRepository:GetDraft()
        local isFirst = #(preDraft.dialogues or {}) == 0
        local initResp = (isFirst and tab.dlgResponseEdit and tab.dlgResponseEdit:GetText()) or ""
        local initClue = (isFirst and tab.clueEdit and tab.clueEdit:GetText()) or ""
        local _, resultOrErr = Addon.QuestRepository:AddDraftDialogueFromLastNpc(initResp, initClue)
        if type(resultOrErr) == "number" then
            tab.selectedDialogueIndex = resultOrErr
            local entry = (Addon.QuestRepository:GetDraft().dialogues or {})[resultOrErr]
            if entry then
                Addon.Announcements:ShowAlert(Addon.Locale:Get("ALERT_DIALOGUE_ADDED", entry.npcName), false)
            end
            tab:RefreshEditorPane()
        elseif type(resultOrErr) == "string" then
            Addon.Announcements:ShowAlert(resultOrErr, true)
        end
    end)
    tab.btnAddLastNpc:SetAnchor(TOPLEFT, dlgBody, TOPLEFT, 0, 0)

    tab.btnClearDialogues = CreateStyledButton(panelName .. "_BtnClearDialogues", dlgBody, 100, 26, Addon.Locale:Get("BTN_CLEAR_DIALOGUES"), function()
        tab.selectedDialogueIndex = nil
        Addon.QuestRepository:ClearDraftDialogues()
    end)
    tab.btnClearDialogues:SetAnchor(TOPLEFT, dlgBody, TOPLEFT, 140, 0)
    tab.btnClearDialogues:SetHidden(true)

    tab.btnDlgPrev = CreateStyledButton(panelName .. "_BtnDlgPrev", dlgBody, 28, 26, "<", function()
        local count = #(Addon.QuestRepository:GetDraft().dialogues or {})
        local nextIdx = CycleIndex(tab.selectedDialogueIndex, count, -1)
        if nextIdx then tab.selectedDialogueIndex = nextIdx; tab:RefreshEditorPane() end
    end)
    tab.btnDlgPrev:SetAnchor(TOPLEFT, dlgBody, TOPLEFT, 256, 0)
    tab.btnDlgPrev:SetHidden(true)

    local lblDlgIndex = WINDOW_MANAGER:CreateControl(panelName .. "_LblDlgIndex", dlgBody, CT_LABEL)
    lblDlgIndex:SetDimensions(60, 26)
    lblDlgIndex:SetAnchor(TOPLEFT, dlgBody, TOPLEFT, 288, 3)
    if lblDlgIndex.SetFont then lblDlgIndex:SetFont("ZoFontGameBold") end
    if lblDlgIndex.SetHorizontalAlignment then lblDlgIndex:SetHorizontalAlignment(TEXT_ALIGN_CENTER) end
    lblDlgIndex:SetHidden(true)
    tab.lblDlgIndex = lblDlgIndex

    tab.btnDlgNext = CreateStyledButton(panelName .. "_BtnDlgNext", dlgBody, 28, 26, ">", function()
        local count = #(Addon.QuestRepository:GetDraft().dialogues or {})
        local nextIdx = CycleIndex(tab.selectedDialogueIndex, count, 1)
        if nextIdx then tab.selectedDialogueIndex = nextIdx; tab:RefreshEditorPane() end
    end)
    tab.btnDlgNext:SetAnchor(TOPLEFT, dlgBody, TOPLEFT, 352, 0)
    tab.btnDlgNext:SetHidden(true)

    tab.btnDlgRemove = CreateStyledButton(panelName .. "_BtnDlgRemove", dlgBody, 28, 26, "X", function()
        local idx = tab.selectedDialogueIndex
        if not idx then return end
        Addon.QuestRepository:RemoveDraftDialogue(idx)
        local count = #(Addon.QuestRepository:GetDraft().dialogues or {})
        tab.selectedDialogueIndex = (count > 0) and math.min(idx, count) or nil
        tab:RefreshEditorPane()
    end)
    tab.btnDlgRemove:SetAnchor(TOPLEFT, dlgBody, TOPLEFT, 388, 0)
    tab.btnDlgRemove:SetHidden(true)
end

function EditorSections.BuildDialogueInputs(tab, dlgBody, panelName)
    local CreateEditBox = Addon.JournalWidgets.CreateEditBoxWithBackdrop

    local lblLastNpc = WINDOW_MANAGER:CreateControl(panelName .. "_LblLastNpc", dlgBody, CT_LABEL)
    lblLastNpc:SetDimensions(250, 22)
    lblLastNpc:SetAnchor(TOPLEFT, dlgBody, TOPLEFT, 4, 34)
    if lblLastNpc.SetFont then lblLastNpc:SetFont("ZoFontGame") end
    tab.lblLastNpc = lblLastNpc

    local lblSelectedNpc = WINDOW_MANAGER:CreateControl(panelName .. "_LblSelectedNpc", dlgBody, CT_LABEL)
    lblSelectedNpc:SetDimensions(250, 22)
    lblSelectedNpc:SetAnchor(TOPLEFT, dlgBody, TOPLEFT, 258, 34)
    if lblSelectedNpc.SetFont then lblSelectedNpc:SetFont("ZoFontGameBold") end
    if lblSelectedNpc.SetHorizontalAlignment then lblSelectedNpc:SetHorizontalAlignment(TEXT_ALIGN_RIGHT) end
    lblSelectedNpc:SetHidden(true)
    tab.lblSelectedNpc = lblSelectedNpc

    local lblClue = WINDOW_MANAGER:CreateControl(panelName .. "_LblInputClue", dlgBody, CT_LABEL)
    lblClue:SetAnchor(TOPLEFT, dlgBody, TOPLEFT, 0, 64)
    if lblClue.SetFont then lblClue:SetFont("ZoFontGameBold") end
    lblClue:SetText(Addon.Locale:Get("LABEL_INPUT_CLUE"))
    tab.lblInputClue = lblClue

    local clueBg, clueEdit = CreateEditBox(
        panelName .. "_ClueEdit", dlgBody, 510, 30, 100, false,
        function(val)
            local draft = Addon.QuestRepository:GetDraft()
            local idx = tab.selectedDialogueIndex
            if idx and draft.dialogues and draft.dialogues[idx] then
                Addon.QuestRepository:UpdateDraftDialogue(idx, { clue = val }, true)
            end
        end
    )
    clueBg:SetAnchor(TOPLEFT, dlgBody, TOPLEFT, 0, 86)
    tab.clueBg = clueBg
    tab.clueEdit = clueEdit

    local lblDlgResponse = WINDOW_MANAGER:CreateControl(panelName .. "_LblDlgResponse", dlgBody, CT_LABEL)
    lblDlgResponse:SetAnchor(TOPLEFT, dlgBody, TOPLEFT, 0, 126)
    if lblDlgResponse.SetFont then lblDlgResponse:SetFont("ZoFontGameBold") end
    lblDlgResponse:SetText(Addon.Locale:Get("LABEL_DIALOGUE_RESPONSE"))
    tab.lblDlgResponse = lblDlgResponse

    local dlgResponseBg, dlgResponseEdit = CreateEditBox(
        panelName .. "_DlgResponseEdit", dlgBody, 510, 52, 300, true,
        function(val)
            local draft = Addon.QuestRepository:GetDraft()
            local idx = tab.selectedDialogueIndex
            if idx and draft.dialogues and draft.dialogues[idx] then
                Addon.QuestRepository:UpdateDraftDialogue(idx, { response = val }, true)
            end
        end
    )
    dlgResponseBg:SetAnchor(TOPLEFT, dlgBody, TOPLEFT, 0, 148)
    tab.dlgResponseBg = dlgResponseBg
    tab.dlgResponseEdit = dlgResponseEdit

    local lblCapturedDialogues = WINDOW_MANAGER:CreateControl(panelName .. "_LblCapturedDialogues", dlgBody, CT_LABEL)
    lblCapturedDialogues:SetDimensions(510, 28)
    lblCapturedDialogues:SetAnchor(TOPLEFT, dlgBody, TOPLEFT, 4, 208)
    if lblCapturedDialogues.SetFont then lblCapturedDialogues:SetFont("ZoFontGame") end
    tab.lblCapturedDialogues = lblCapturedDialogues
end

function EditorSections.BuildOptionsSection(tab, optBody, panelName)
    local CreateStyledButton = Addon.JournalWidgets.CreateStyledButton
    local CreateEditBox = Addon.JournalWidgets.CreateEditBoxWithBackdrop

    local lblCompletionMsg = WINDOW_MANAGER:CreateControl(panelName .. "_LblInputCompletionMsg", optBody, CT_LABEL)
    lblCompletionMsg:SetAnchor(TOPLEFT, optBody, TOPLEFT, 0, 0)
    if lblCompletionMsg.SetFont then lblCompletionMsg:SetFont("ZoFontGameBold") end
    lblCompletionMsg:SetText(Addon.Locale:Get("LABEL_INPUT_COMPLETION_MSG"))
    tab.lblInputCompletionMsg = lblCompletionMsg

    local compBg, compEdit = CreateEditBox(
        panelName .. "_CompletionEdit", optBody, 510, 30, 140, false,
        function(val) Addon.QuestRepository:UpdateDraftFields({ completionMessage = val }, true) end
    )
    compBg:SetAnchor(TOPLEFT, optBody, TOPLEFT, 0, 22)
    tab.completionBg = compBg
    tab.completionEdit = compEdit

    tab.btnRequireUndetected = CreateStyledButton(panelName .. "_BtnRequireUndetected", optBody, 280, 26, Addon.Locale:Get("OPT_REQUIRE_UNDETECTED"), function()
        local d = Addon.QuestRepository:GetDraft()
        Addon.QuestRepository:UpdateDraftFields({ requireUndetected = not (d and d.requireUndetected) })
    end)
    tab.btnRequireUndetected:SetAnchor(TOPLEFT, optBody, TOPLEFT, 0, 62)
end

function EditorSections.BuildFooterButtons(tab, pane, panelName)
    local CreateStyledButton = Addon.JournalWidgets.CreateStyledButton

    tab.btnSaveEditor = CreateStyledButton(panelName .. "_BtnSaveEditor", pane, 180, 34, Addon.Locale:Get("BTN_SAVE"), function()
        tab:OnSaveDraftClicked()
    end)
    tab.btnSaveEditor:SetAnchor(TOPLEFT, pane, TOPLEFT, 0, 514)

    tab.btnCancelEditor = CreateStyledButton(panelName .. "_BtnCancelEditor", pane, 150, 34, Addon.Locale:Get("BTN_CANCEL"), function()
        tab.viewMode = tab.VIEW_MODE.DETAIL
        Addon.QuestRepository:ResetDraft()
        tab:ClearEditorInputs()
        tab:Refresh()
    end)
    tab.btnCancelEditor:SetAnchor(TOPLEFT, pane, TOPLEFT, 195, 514)

    tab.btnShowMapEditor = CreateStyledButton(panelName .. "_BtnShowMapEditor", pane, 155, 34, Addon.Locale:Get("BTN_SHOW_ON_MAP"), function()
        local draft = Addon.QuestRepository:GetDraft()
        if draft and draft.mapId and draft.mapId > 0 then
            Addon.WorldMapArea:ShowQuestOnMap(draft)
        end
    end)
    tab.btnShowMapEditor:SetAnchor(TOPLEFT, pane, TOPLEFT, 360, 514)
    tab.btnShowMapEditor:SetHidden(true)
end
