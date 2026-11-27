-- Ref: docs/adr/0001-arquitectura-modular-zero-dependency-y-savedvars-por-personaje.md
-- Ref: docs/adr/0003-integracion-nativa-ui-diario-mapa-y-hud.md
-- Ref: docs/adr/0004-objetivos-multiples-inferidos-por-reticula.md
-- Ref: docs/adr/0006-puntos-de-descubrimiento-ocultos.md
-- Ref: docs/adr/0007-dialogos-inyectados-en-npcs-nativos.md
-- Ref: docs/adr/0014-areas-por-objetivo-mensajes-eliminacion-y-visibilidad-mapa.md
-- Ref: docs/adr/0016-limites-texto-y-entidades-presupuesto-correo.md

RPQuest = RPQuest or {}
local Addon = RPQuest

Addon.JournalEditorSections = {}
local EditorSections = Addon.JournalEditorSections

local RADIUS_TIERS = {
    { key = "TINY", labelKey = "BTN_RADIUS_TINY" },
    { key = "SMALL", labelKey = "BTN_RADIUS_SMALL" },
    { key = "MEDIUM", labelKey = "BTN_RADIUS_MEDIUM" },
    { key = "LARGE", labelKey = "BTN_RADIUS_LARGE" },
    { key = "HUGE", labelKey = "BTN_RADIUS_HUGE" },
}

local function PopulateRadiusComboBox(dropdownControl, radiiTable, entryField, onSelect)
    local combo = ZO_ComboBox_ObjectFromContainer(dropdownControl)
    if not combo then
        return nil
    end
    combo:SetSortsItems(false)
    for _, tier in ipairs(RADIUS_TIERS) do
        local radiusVal = radiiTable[tier.key]
        local entry = combo:CreateItemEntry(Addon.Locale:Get(tier.labelKey), function()
            onSelect(radiusVal)
        end)
        entry[entryField] = radiusVal
        combo:AddItem(entry)
    end
    return combo
end

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

    local body = WINDOW_MANAGER:CreateControl(panelName .. "_EdBody_" .. key, formParent, CT_SCROLL)
    body:SetDimensions(510, bodyHeight)
    body:SetAnchor(TOPLEFT, headerBtn, BOTTOMLEFT, 0, 10)

    local isCollapsed = tab.editorSectionsCollapsed and tab.editorSectionsCollapsed[key] and true or false
    local isOpen = not isCollapsed
    local timeline = ANIMATION_MANAGER:CreateTimelineFromVirtual("ZO_TreeOpenAnimation", body)
    body:SetAlpha(isOpen and 1 or 0)

    local sec = {
        key = key,
        localeKey = localeKey,
        divider = divider,
        headerBtn = headerBtn,
        body = body,
        bodyHeight = bodyHeight,
        timeline = timeline,
        isOpen = isOpen,
        openPercentage = isOpen and 1 or 0,
    }
    table.insert(tab.editorSections, sec)
    tab.editorSectionsByKey[key] = sec
    return sec
end

function EditorSections.BuildBaseFields(tab, formParent, panelName)
    local CreateEditBox = Addon.JournalWidgets.CreateEditBoxWithBackdrop
    local limits = Addon.Constants.TEXT_LIMITS

    local lblTitle = WINDOW_MANAGER:CreateControl(panelName .. "_LblInputTitle", formParent, CT_LABEL)
    lblTitle:SetAnchor(TOPLEFT, formParent, TOPLEFT, 0, 0)
    if lblTitle.SetFont then lblTitle:SetFont("ZoFontGameBold") end
    lblTitle:SetText(Addon.Locale:Get("LABEL_INPUT_TITLE"))
    tab.lblInputTitle = lblTitle

    local titleBg, titleEdit = CreateEditBox(
        panelName .. "_TitleEdit", formParent, 510, 30, limits.TITLE, false,
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
        panelName .. "_DescEdit", formParent, 510, 72, limits.DESCRIPTION, true,
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
        panelName .. "_RecipientEdit", formParent, 250, 30, limits.ACCOUNT_NAME, false,
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
        panelName .. "_RecipientCharEdit", formParent, 250, 30, limits.CHARACTER_NAME, false,
        function(val) Addon.QuestRepository:UpdateDraftFields({ recipientCharacterName = val }, true) end
    )
    recipientCharBg:SetAnchor(TOPLEFT, formParent, TOPLEFT, 260, 188)
    tab.recipientCharBg = recipientCharBg
    tab.recipientCharEdit = recipientCharEdit

    local lblSenderChar = WINDOW_MANAGER:CreateControl(panelName .. "_LblInputSenderChar", formParent, CT_LABEL)
    lblSenderChar:SetAnchor(TOPLEFT, formParent, TOPLEFT, 0, 228)
    if lblSenderChar.SetFont then lblSenderChar:SetFont("ZoFontGameBold") end
    lblSenderChar:SetText(Addon.Locale:Get("LABEL_INPUT_SENDER_CHAR"))
    tab.lblInputSenderChar = lblSenderChar

    local senderCharDropdown = WINDOW_MANAGER:CreateControlFromVirtual(panelName .. "_SenderCharDropdown", formParent, "ZO_ComboBox")
    senderCharDropdown:SetDimensions(250, 28)
    senderCharDropdown:SetAnchor(TOPLEFT, formParent, TOPLEFT, 0, 250)
    tab.senderCharDropdown = senderCharDropdown

    local senderCharCombo = ZO_ComboBox_ObjectFromContainer(senderCharDropdown)
    if senderCharCombo then
        senderCharCombo:SetSortsItems(false)
        tab.senderCharComboBox = senderCharCombo
    end

    local lblQuestIcon = WINDOW_MANAGER:CreateControl(panelName .. "_LblQuestIcon", formParent, CT_LABEL)
    lblQuestIcon:SetAnchor(TOPLEFT, formParent, TOPLEFT, 260, 228)
    if lblQuestIcon.SetFont then lblQuestIcon:SetFont("ZoFontGameBold") end
    lblQuestIcon:SetText(Addon.Locale:Get("LABEL_QUEST_ICON"))
    tab.lblQuestIcon = lblQuestIcon

    local iconDropdown = WINDOW_MANAGER:CreateControlFromVirtual(panelName .. "_QuestIconDropdown", formParent, "ZO_ComboBox")
    iconDropdown:SetDimensions(250, 28)
    iconDropdown:SetAnchor(TOPLEFT, formParent, TOPLEFT, 260, 250)
    tab.questIconDropdown = iconDropdown

    local iconCombo = ZO_ComboBox_ObjectFromContainer(iconDropdown)
    if iconCombo then
        iconCombo:SetSortsItems(false)
        local noneEntry = iconCombo:CreateItemEntry(Addon.Locale:Get("OPT_QUEST_ICON_NONE"), function()
            Addon.QuestRepository:UpdateDraftFields({ icon = "none" })
        end)
        noneEntry.questIconId = ""
        iconCombo:AddItem(noneEntry)

        for _, iconEntry in ipairs(Addon.Constants.QUEST_ICONS or {}) do
            local label = string.format("|t18:18:%s|t %s", iconEntry.texture, Addon.Locale:Get(iconEntry.localeKey))
            local entry = iconCombo:CreateItemEntry(label, function()
                Addon.QuestRepository:UpdateDraftFields({ icon = iconEntry.id })
            end)
            entry.questIconId = iconEntry.id
            iconCombo:AddItem(entry)
        end
        tab.questIconComboBox = iconCombo
    end
end

function EditorSections.BuildTargetAreaControls(tab, targetBody, panelName)
    local CreateIconButton = Addon.JournalWidgets.CreateIconButton
    local CreateCheckButton = Addon.JournalWidgets.CreateCheckButton

    local targetDropdown = WINDOW_MANAGER:CreateControlFromVirtual(panelName .. "_TargetDropdown", targetBody, "ZO_ComboBox")
    targetDropdown:SetDimensions(436, 28)
    targetDropdown:SetAnchor(TOPLEFT, targetBody, TOPLEFT, 0, 0)
    tab.targetDropdown = targetDropdown

    local targetCombo = ZO_ComboBox_ObjectFromContainer(targetDropdown)
    if targetCombo then
        targetCombo:SetSortsItems(false)
        tab.targetComboBox = targetCombo
    end

    tab.btnRemoveTarget = CreateIconButton(
        panelName .. "_BtnRemoveTarget", targetBody, 28,
        "/esoui/art/buttons/decline_up.dds",
        "/esoui/art/buttons/decline_down.dds",
        "/esoui/art/buttons/decline_over.dds",
        "/esoui/art/buttons/decline_disabled.dds",
        Addon.Locale:Get("TOOLTIP_REMOVE_TARGET"),
        function()
            local idx = tab.selectedTargetIndex
            if not idx then return end
            local draft = Addon.QuestRepository:RemoveDraftTarget(idx)
            local total = draft and #(draft.targets or {}) or 0
            tab.selectedTargetIndex = (total > 0) and math.min(idx, total) or nil
            tab:RefreshEditorPane()
        end
    )
    tab.btnRemoveTarget:SetAnchor(TOPLEFT, targetBody, TOPLEFT, 444, 0)

    tab.btnClearTargets = CreateIconButton(
        panelName .. "_BtnClearTargets", targetBody, 28,
        "/esoui/art/inventory/inventory_tabicon_trash_up.dds",
        "/esoui/art/inventory/inventory_tabicon_trash_down.dds",
        "/esoui/art/inventory/inventory_tabicon_trash_over.dds",
        nil,
        Addon.Locale:Get("TOOLTIP_CLEAR_TARGETS"),
        function()
            tab.selectedTargetIndex = nil
            Addon.QuestRepository:ClearDraftTargets()
        end
    )
    tab.btnClearTargets:SetAnchor(TOPLEFT, targetBody, TOPLEFT, 478, 0)

    tab.chkTargetOptional = CreateCheckButton(
        panelName .. "_ChkTargetOptional", targetBody,
        Addon.Locale:Get("CHK_TARGET_OPTIONAL"),
        function(isChecked)
            local idx = tab.selectedTargetIndex
            if idx then
                Addon.QuestRepository:UpdateDraftTarget(idx, { optional = isChecked })
            end
        end
    )
    tab.chkTargetOptional:SetAnchor(TOPLEFT, targetBody, TOPLEFT, 2, 36)

    local lblAreaSize = WINDOW_MANAGER:CreateControl(panelName .. "_LblAreaSize", targetBody, CT_LABEL)
    lblAreaSize:SetAnchor(TOPLEFT, targetBody, TOPLEFT, 0, 66)
    if lblAreaSize.SetFont then lblAreaSize:SetFont("ZoFontGameBold") end
    lblAreaSize:SetText(Addon.Locale:Get("LABEL_AREA_SIZE"))
    tab.lblAreaSize = lblAreaSize

    local areaSizeDropdown = WINDOW_MANAGER:CreateControlFromVirtual(panelName .. "_AreaSizeDropdown", targetBody, "ZO_ComboBox")
    areaSizeDropdown:SetDimensions(220, 28)
    areaSizeDropdown:SetAnchor(TOPLEFT, targetBody, TOPLEFT, 0, 88)
    tab.areaSizeDropdown = areaSizeDropdown

    tab.areaSizeComboBox = PopulateRadiusComboBox(areaSizeDropdown, Addon.Constants.AREA_RADIUS, "areaRadius", function(radiusVal)
        local idx = tab.selectedTargetIndex
        if idx then
            Addon.QuestRepository:UpdateDraftTarget(idx, { areaRadius = radiusVal })
        end
    end)
end

local function BuildTargetLocationControls(tab, targetBody, panelName)
    local CreateStyledButton = Addon.JournalWidgets.CreateStyledButton
    local CreateIconButton = Addon.JournalWidgets.CreateIconButton
    local CreateCheckButton = Addon.JournalWidgets.CreateCheckButton
    local CreateEditBox = Addon.JournalWidgets.CreateEditBoxWithBackdrop

    local locDivider = WINDOW_MANAGER:CreateControl(panelName .. "_TargetLocDivider", targetBody, CT_TEXTURE)
    locDivider:SetDimensions(510, 4)
    locDivider:SetAnchor(TOPLEFT, targetBody, TOPLEFT, 0, 128)
    locDivider:SetTexture(Addon.Constants.UI.DIVIDER_TEXTURE)
    tab.targetLocDivider = locDivider

    local lblLocHeader = WINDOW_MANAGER:CreateControl(panelName .. "_LblTargetLocHeader", targetBody, CT_LABEL)
    lblLocHeader:SetAnchor(TOPLEFT, targetBody, TOPLEFT, 0, 140)
    if lblLocHeader.SetFont then lblLocHeader:SetFont("ZoFontGameBold") end
    lblLocHeader:SetText(Addon.Locale:Get("LABEL_TARGET_LOC_SECTION"))
    tab.lblTargetLocHeader = lblLocHeader

    tab.chkTargetLocRequired = CreateCheckButton(
        panelName .. "_ChkTargetLocRequired", targetBody,
        Addon.Locale:Get("CHK_TARGET_LOC_REQUIRED"),
        function(isChecked)
            local idx = tab.selectedTargetIndex
            if idx then
                Addon.QuestRepository:UpdateDraftTarget(idx, { locationRequired = isChecked })
            end
        end
    )
    tab.chkTargetLocRequired:SetAnchor(TOPLEFT, targetBody, TOPLEFT, 110, 141)

    local lblLocNote = WINDOW_MANAGER:CreateControl(panelName .. "_LblTargetLocNote", targetBody, CT_LABEL)
    lblLocNote:SetDimensions(510, 34)
    lblLocNote:SetAnchor(TOPLEFT, targetBody, TOPLEFT, 0, 166)
    if lblLocNote.SetFont then lblLocNote:SetFont("ZoFontGameSmall") end
    if lblLocNote.SetColor then lblLocNote:SetColor(0.76, 0.76, 0.76, 1) end
    lblLocNote:SetText(Addon.Locale:Get("NOTE_TARGET_LOC_REQUIRED"))
    tab.lblTargetLocNote = lblLocNote

    tab.btnCaptureTargetLoc = CreateStyledButton(panelName .. "_BtnCaptureTargetLoc", targetBody, 140, 28, Addon.Locale:Get("BTN_CAPTURE_TARGET_LOC"), function()
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
    tab.btnCaptureTargetLoc:SetAnchor(TOPLEFT, targetBody, TOPLEFT, 0, 206)

    tab.btnClearTargetLoc = CreateIconButton(
        panelName .. "_BtnClearTargetLoc", targetBody, 28,
        "/esoui/art/buttons/decline_up.dds",
        "/esoui/art/buttons/decline_down.dds",
        "/esoui/art/buttons/decline_over.dds",
        "/esoui/art/buttons/decline_disabled.dds",
        Addon.Locale:Get("TOOLTIP_CLEAR_TARGET_LOC"),
        function()
            if tab.selectedTargetIndex then
                Addon.QuestRepository:ClearDraftTargetLocation(tab.selectedTargetIndex)
            end
        end
    )
    tab.btnClearTargetLoc:SetAnchor(TOPLEFT, targetBody, TOPLEFT, 148, 206)

    local locRadDropdown = WINDOW_MANAGER:CreateControlFromVirtual(panelName .. "_TargetLocRadDropdown", targetBody, "ZO_ComboBox")
    locRadDropdown:SetDimensions(180, 28)
    locRadDropdown:SetAnchor(TOPLEFT, targetBody, TOPLEFT, 184, 206)
    tab.targetLocRadDropdown = locRadDropdown

    tab.targetLocRadComboBox = PopulateRadiusComboBox(locRadDropdown, Addon.Constants.DISCOVERY_RADIUS, "locRadius", function(radiusVal)
        if tab.selectedTargetIndex then
            Addon.QuestRepository:UpdateDraftTarget(tab.selectedTargetIndex, { radius = radiusVal })
        end
    end)

    local lblTargetCustomMsg = WINDOW_MANAGER:CreateControl(panelName .. "_LblTargetCustomMsg", targetBody, CT_LABEL)
    lblTargetCustomMsg:SetAnchor(TOPLEFT, targetBody, TOPLEFT, 0, 246)
    if lblTargetCustomMsg.SetFont then lblTargetCustomMsg:SetFont("ZoFontGameBold") end
    lblTargetCustomMsg:SetText(Addon.Locale:Get("OPT_TARGET_MSG_ELIMINATION"))
    tab.lblTargetCustomMsg = lblTargetCustomMsg

    local targetCustomBg, targetCustomEdit = CreateEditBox(
        panelName .. "_TargetCustomMsgEdit", targetBody, 510, 30, Addon.Constants.TEXT_LIMITS.SHORT_MESSAGE, false,
        function(val)
            local idx = tab.selectedTargetIndex
            if idx then
                Addon.QuestRepository:UpdateDraftTarget(idx, { customMessage = val }, true)
            end
        end
    )
    targetCustomBg:SetAnchor(TOPLEFT, targetBody, TOPLEFT, 0, 266)
    tab.targetCustomBg = targetCustomBg
    tab.targetCustomEdit = targetCustomEdit

    local lblTargetInLocMsg = WINDOW_MANAGER:CreateControl(panelName .. "_LblTargetInLocMsg", targetBody, CT_LABEL)
    lblTargetInLocMsg:SetAnchor(TOPLEFT, targetBody, TOPLEFT, 0, 304)
    if lblTargetInLocMsg.SetFont then lblTargetInLocMsg:SetFont("ZoFontGameBold") end
    lblTargetInLocMsg:SetText(Addon.Locale:Get("OPT_TARGET_MSG_IN_LOCATION"))
    tab.lblTargetInLocMsg = lblTargetInLocMsg

    local targetInLocBg, targetInLocEdit = CreateEditBox(
        panelName .. "_TargetInLocMsgEdit", targetBody, 510, 30, Addon.Constants.TEXT_LIMITS.SHORT_MESSAGE, false,
        function(val)
            local idx = tab.selectedTargetIndex
            if idx then
                Addon.QuestRepository:UpdateDraftTarget(idx, { customMessageInLocation = val }, true)
            end
        end
    )
    targetInLocBg:SetAnchor(TOPLEFT, targetBody, TOPLEFT, 0, 324)
    tab.targetInLocBg = targetInLocBg
    tab.targetInLocEdit = targetInLocEdit
end

function EditorSections.BuildTargetConfigControls(tab, targetBody, panelName)
    BuildTargetLocationControls(tab, targetBody, panelName)
end

function EditorSections.BuildDiscoveryControls(tab, discBody, panelName)
    local CreateIconButton = Addon.JournalWidgets.CreateIconButton

    local function MoveSelectedDiscovery(delta)
        local idx = tab.selectedDiscoveryIndex
        if not idx then return end
        local _, newIdx = Addon.QuestRepository:MoveDraftDiscoveryPoint(idx, delta)
        if newIdx then
            tab.selectedDiscoveryIndex = newIdx
            tab:RefreshEditorPane()
        end
    end

    tab.btnCaptureDiscovery = CreateIconButton(
        panelName .. "_BtnCaptureDiscovery", discBody, 28,
        "/esoui/art/buttons/plus_up.dds",
        "/esoui/art/buttons/plus_down.dds",
        "/esoui/art/buttons/plus_over.dds",
        "/esoui/art/buttons/plus_disabled.dds",
        Addon.Locale:Get("TOOLTIP_ADD_DISCOVERY"),
        function()
            local draft = Addon.QuestRepository:GetDraft()
            local hasExisting = #(draft.discoveries or {}) > 0
            local msgText = (not hasExisting and tab.discoveryMsgEdit) and tab.discoveryMsgEdit:GetText() or nil
            local updatedDraft, countOrErr = Addon.TargetCapture:CaptureDiscoveryPoint(msgText)
            if updatedDraft and type(countOrErr) == "number" and countOrErr > 0 then
                tab.selectedDiscoveryIndex = countOrErr
                Addon.QuestRepository:UpdateDraftFields({ discoveryMessage = "" }, true)
                tab:RefreshEditorPane()
            end
        end
    )
    tab.btnCaptureDiscovery:SetAnchor(TOPLEFT, discBody, TOPLEFT, 0, 0)

    local discoveryDropdown = WINDOW_MANAGER:CreateControlFromVirtual(panelName .. "_DiscoveryDropdown", discBody, "ZO_ComboBox")
    discoveryDropdown:SetDimensions(404, 28)
    discoveryDropdown:SetAnchor(TOPLEFT, discBody, TOPLEFT, 34, 0)
    tab.discoveryDropdown = discoveryDropdown

    local discCombo = ZO_ComboBox_ObjectFromContainer(discoveryDropdown)
    if discCombo then
        discCombo:SetSortsItems(false)
        tab.discoveryComboBox = discCombo
    end

    tab.btnRemoveDiscovery = CreateIconButton(
        panelName .. "_BtnRemoveDiscovery", discBody, 28,
        "/esoui/art/buttons/decline_up.dds",
        "/esoui/art/buttons/decline_down.dds",
        "/esoui/art/buttons/decline_over.dds",
        "/esoui/art/buttons/decline_disabled.dds",
        Addon.Locale:Get("TOOLTIP_REMOVE_DISCOVERY"),
        function()
            local idx = tab.selectedDiscoveryIndex
            if not idx then return end
            local draft = Addon.QuestRepository:RemoveDraftDiscoveryPoint(idx)
            local total = draft and #(draft.discoveries or {}) or 0
            tab.selectedDiscoveryIndex = (total == 0) and nil or math.min(idx, total)
            tab:RefreshEditorPane()
        end
    )
    tab.btnRemoveDiscovery:SetAnchor(TOPLEFT, discBody, TOPLEFT, 444, 0)

    tab.btnClearDiscoveries = CreateIconButton(
        panelName .. "_BtnClearDiscoveries", discBody, 28,
        "/esoui/art/inventory/inventory_tabicon_trash_up.dds",
        "/esoui/art/inventory/inventory_tabicon_trash_down.dds",
        "/esoui/art/inventory/inventory_tabicon_trash_over.dds",
        nil,
        Addon.Locale:Get("TOOLTIP_CLEAR_DISCOVERIES"),
        function()
            tab.selectedDiscoveryIndex = nil
            Addon.QuestRepository:ClearDraftDiscoveries()
        end
    )
    tab.btnClearDiscoveries:SetAnchor(TOPLEFT, discBody, TOPLEFT, 478, 0)

    tab.btnMoveDiscoveryUp = CreateIconButton(
        panelName .. "_BtnMoveDiscoveryUp", discBody, 28,
        "/esoui/art/buttons/large_uparrow_up.dds",
        "/esoui/art/buttons/large_uparrow_down.dds",
        "/esoui/art/buttons/large_uparrow_over.dds",
        "/esoui/art/buttons/large_uparrow_disabled.dds",
        Addon.Locale:Get("TOOLTIP_MOVE_DISCOVERY_UP"),
        function()
            MoveSelectedDiscovery(-1)
        end
    )
    tab.btnMoveDiscoveryUp:SetAnchor(TOPLEFT, discBody, TOPLEFT, 444, 36)

    tab.btnMoveDiscoveryDown = CreateIconButton(
        panelName .. "_BtnMoveDiscoveryDown", discBody, 28,
        "/esoui/art/buttons/large_downarrow_up.dds",
        "/esoui/art/buttons/large_downarrow_down.dds",
        "/esoui/art/buttons/large_downarrow_over.dds",
        "/esoui/art/buttons/large_downarrow_disabled.dds",
        Addon.Locale:Get("TOOLTIP_MOVE_DISCOVERY_DOWN"),
        function()
            MoveSelectedDiscovery(1)
        end
    )
    tab.btnMoveDiscoveryDown:SetAnchor(TOPLEFT, discBody, TOPLEFT, 478, 36)
end

function EditorSections.BuildDiscoveryInputs(tab, discBody, panelName)
    local CreateEditBox = Addon.JournalWidgets.CreateEditBoxWithBackdrop
    local CreateCheckButton = Addon.JournalWidgets.CreateCheckButton

    local function SetDiscRad(radius)
        local draft = Addon.QuestRepository:GetDraft()
        local idx = tab.selectedDiscoveryIndex
        if idx and draft.discoveries and draft.discoveries[idx] then
            Addon.QuestRepository:UpdateDraftDiscoveryPoint(idx, { radius = radius })
        else
            Addon.QuestRepository:UpdateDraftFields({ discoveryRadius = radius })
        end
    end

    local discRadDropdown = WINDOW_MANAGER:CreateControlFromVirtual(panelName .. "_DiscRadDropdown", discBody, "ZO_ComboBox")
    discRadDropdown:SetDimensions(220, 28)
    discRadDropdown:SetAnchor(TOPLEFT, discBody, TOPLEFT, 0, 36)
    tab.discRadDropdown = discRadDropdown

    tab.discRadComboBox = PopulateRadiusComboBox(discRadDropdown, Addon.Constants.DISCOVERY_RADIUS, "discRadius", function(radiusVal)
        SetDiscRad(radiusVal)
    end)

    tab.chkDiscoveryRequired = CreateCheckButton(
        panelName .. "_ChkDiscoveryRequired", discBody,
        Addon.Locale:Get("CHK_OBJECTIVE_REQUIRED"),
        function(isChecked)
            local idx = tab.selectedDiscoveryIndex
            if idx then
                Addon.QuestRepository:UpdateDraftDiscoveryPoint(idx, { required = isChecked })
            end
        end
    )
    tab.chkDiscoveryRequired:SetAnchor(TOPLEFT, discBody, TOPLEFT, 232, 40)

    tab.chkDiscoverySequential = CreateCheckButton(
        panelName .. "_ChkDiscoverySequential", discBody,
        Addon.Locale:Get("CHK_DISCOVERY_SEQUENTIAL"),
        function(isChecked)
            Addon.QuestRepository:UpdateDraftFields({ sequentialDiscoveries = isChecked })
        end
    )
    tab.chkDiscoverySequential:SetAnchor(TOPLEFT, discBody, TOPLEFT, 2, 72)

    local lblDiscoveryMsg = WINDOW_MANAGER:CreateControl(panelName .. "_LblDiscoveryMsg", discBody, CT_LABEL)
    lblDiscoveryMsg:SetAnchor(TOPLEFT, discBody, TOPLEFT, 0, 100)
    if lblDiscoveryMsg.SetFont then lblDiscoveryMsg:SetFont("ZoFontGameBold") end
    lblDiscoveryMsg:SetText(Addon.Locale:Get("LABEL_DISCOVERY_MSG"))
    tab.lblDiscoveryMsg = lblDiscoveryMsg

    local discMsgBg, discMsgEdit = CreateEditBox(
        panelName .. "_DiscoveryMsgEdit", discBody, 510, 52, Addon.Constants.TEXT_LIMITS.SHORT_MESSAGE, true,
        function(val)
            local draft = Addon.QuestRepository:GetDraft()
            local idx = tab.selectedDiscoveryIndex
            if idx and draft.discoveries and draft.discoveries[idx] then
                Addon.QuestRepository:UpdateDraftDiscoveryPoint(idx, { message = val }, true)
                Addon.JournalEditorPane.RefreshDiscoveryDropdown(tab, draft)
                Addon.JournalEditorPane.RefreshDiscoveryMessageIndicator(tab, draft)
                Addon.JournalEditorPane.LayoutSections(tab)
            else
                Addon.QuestRepository:UpdateDraftFields({ discoveryMessage = val }, true)
            end
        end
    )
    discMsgBg:SetAnchor(TOPLEFT, discBody, TOPLEFT, 0, 122)
    tab.discoveryMsgBg = discMsgBg
    tab.discoveryMsgEdit = discMsgEdit
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
    local CreateCheckButton = Addon.JournalWidgets.CreateCheckButton

    local lblLastNpc = WINDOW_MANAGER:CreateControl(panelName .. "_LblLastNpc", dlgBody, CT_LABEL)
    lblLastNpc:SetDimensions(506, 22)
    lblLastNpc:SetAnchor(TOPLEFT, dlgBody, TOPLEFT, 4, 34)
    if lblLastNpc.SetFont then lblLastNpc:SetFont("ZoFontGame") end
    tab.lblLastNpc = lblLastNpc

    local lblSelectedNpc = WINDOW_MANAGER:CreateControl(panelName .. "_LblSelectedNpc", dlgBody, CT_LABEL)
    lblSelectedNpc:SetDimensions(506, 22)
    lblSelectedNpc:SetAnchor(TOPLEFT, dlgBody, TOPLEFT, 4, 58)
    if lblSelectedNpc.SetFont then lblSelectedNpc:SetFont("ZoFontGameBold") end
    if lblSelectedNpc.SetMaxLineCount then lblSelectedNpc:SetMaxLineCount(1) end
    if lblSelectedNpc.SetWrapMode then lblSelectedNpc:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS) end
    lblSelectedNpc:SetHidden(true)
    tab.lblSelectedNpc = lblSelectedNpc

    tab.chkDialogueRequired = CreateCheckButton(
        panelName .. "_ChkDialogueRequired", dlgBody,
        Addon.Locale:Get("CHK_OBJECTIVE_REQUIRED"),
        function(isChecked)
            local idx = tab.selectedDialogueIndex
            if idx then
                Addon.QuestRepository:UpdateDraftDialogue(idx, { required = isChecked })
            end
        end
    )
    tab.chkDialogueRequired:SetAnchor(TOPLEFT, dlgBody, TOPLEFT, 2, 84)

    local lblClue = WINDOW_MANAGER:CreateControl(panelName .. "_LblInputClue", dlgBody, CT_LABEL)
    lblClue:SetAnchor(TOPLEFT, dlgBody, TOPLEFT, 0, 112)
    if lblClue.SetFont then lblClue:SetFont("ZoFontGameBold") end
    lblClue:SetText(Addon.Locale:Get("LABEL_INPUT_CLUE"))
    tab.lblInputClue = lblClue

    local clueBg, clueEdit = CreateEditBox(
        panelName .. "_ClueEdit", dlgBody, 510, 30, Addon.Constants.TEXT_LIMITS.DIALOGUE_OPTION, false,
        function(val)
            local draft = Addon.QuestRepository:GetDraft()
            local idx = tab.selectedDialogueIndex
            if idx and draft.dialogues and draft.dialogues[idx] then
                Addon.QuestRepository:UpdateDraftDialogue(idx, { clue = val }, true)
            end
        end
    )
    clueBg:SetAnchor(TOPLEFT, dlgBody, TOPLEFT, 0, 134)
    tab.clueBg = clueBg
    tab.clueEdit = clueEdit

    local lblDlgResponse = WINDOW_MANAGER:CreateControl(panelName .. "_LblDlgResponse", dlgBody, CT_LABEL)
    lblDlgResponse:SetAnchor(TOPLEFT, dlgBody, TOPLEFT, 0, 174)
    if lblDlgResponse.SetFont then lblDlgResponse:SetFont("ZoFontGameBold") end
    lblDlgResponse:SetText(Addon.Locale:Get("LABEL_DIALOGUE_RESPONSE"))
    tab.lblDlgResponse = lblDlgResponse

    local dlgResponseBg, dlgResponseEdit = CreateEditBox(
        panelName .. "_DlgResponseEdit", dlgBody, 510, 52, Addon.Constants.TEXT_LIMITS.DIALOGUE_RESPONSE, true,
        function(val)
            local draft = Addon.QuestRepository:GetDraft()
            local idx = tab.selectedDialogueIndex
            if idx and draft.dialogues and draft.dialogues[idx] then
                Addon.QuestRepository:UpdateDraftDialogue(idx, { response = val }, true)
            end
        end
    )
    dlgResponseBg:SetAnchor(TOPLEFT, dlgBody, TOPLEFT, 0, 196)
    tab.dlgResponseBg = dlgResponseBg
    tab.dlgResponseEdit = dlgResponseEdit

    local lblCapturedDialogues = WINDOW_MANAGER:CreateControl(panelName .. "_LblCapturedDialogues", dlgBody, CT_LABEL)
    lblCapturedDialogues:SetDimensions(506, 40)
    lblCapturedDialogues:SetAnchor(TOPLEFT, dlgBody, TOPLEFT, 4, 256)
    if lblCapturedDialogues.SetFont then lblCapturedDialogues:SetFont("ZoFontGame") end
    tab.lblCapturedDialogues = lblCapturedDialogues
end

function EditorSections.BuildOptionsSection(tab, optBody, panelName)
    local CreateEditBox = Addon.JournalWidgets.CreateEditBoxWithBackdrop

    local lblCompletionMsg = WINDOW_MANAGER:CreateControl(panelName .. "_LblInputCompletionMsg", optBody, CT_LABEL)
    lblCompletionMsg:SetAnchor(TOPLEFT, optBody, TOPLEFT, 0, 0)
    if lblCompletionMsg.SetFont then lblCompletionMsg:SetFont("ZoFontGameBold") end
    lblCompletionMsg:SetText(Addon.Locale:Get("LABEL_INPUT_COMPLETION_MSG"))
    tab.lblInputCompletionMsg = lblCompletionMsg

    local compBg, compEdit = CreateEditBox(
        panelName .. "_CompletionEdit", optBody, 510, 30, Addon.Constants.TEXT_LIMITS.SHORT_MESSAGE, false,
        function(val) Addon.QuestRepository:UpdateDraftFields({ completionMessage = val }, true) end
    )
    compBg:SetAnchor(TOPLEFT, optBody, TOPLEFT, 0, 22)
    tab.completionBg = compBg
    tab.completionEdit = compEdit

    local optDivider1 = WINDOW_MANAGER:CreateControl(panelName .. "_OptionsDivider1", optBody, CT_TEXTURE)
    optDivider1:SetDimensions(510, 4)
    optDivider1:SetAnchor(TOPLEFT, optBody, TOPLEFT, 0, 64)
    optDivider1:SetTexture(Addon.Constants.UI.DIVIDER_TEXTURE)
    if optDivider1.SetAlpha then optDivider1:SetAlpha(0.5) end
    tab.optionsDivider1 = optDivider1

    local lblStealth = WINDOW_MANAGER:CreateControl(panelName .. "_LblStealthMode", optBody, CT_LABEL)
    lblStealth:SetAnchor(TOPLEFT, optBody, TOPLEFT, 0, 78)
    if lblStealth.SetFont then lblStealth:SetFont("ZoFontGameBold") end
    lblStealth:SetText(Addon.Locale:Get("LABEL_STEALTH_MODE"))
    tab.lblStealthMode = lblStealth

    local stealthDropdown = WINDOW_MANAGER:CreateControlFromVirtual(panelName .. "_StealthDropdown", optBody, "ZO_ComboBox")
    stealthDropdown:SetDimensions(510, 28)
    stealthDropdown:SetAnchor(TOPLEFT, optBody, TOPLEFT, 0, 100)
    tab.stealthDropdown = stealthDropdown

    local combo = ZO_ComboBox_ObjectFromContainer(stealthDropdown)
    if combo then
        combo:SetSortsItems(false)
        local modes = Addon.Constants.STEALTH_MODE
        local options = {
            { mode = modes.DISABLED, label = Addon.Locale:Get("OPT_STEALTH_DISABLED") },
            { mode = modes.OPTIONAL, label = Addon.Locale:Get("OPT_STEALTH_OPTIONAL") },
            { mode = modes.REQUIRED, label = Addon.Locale:Get("OPT_STEALTH_REQUIRED") },
        }
        for _, opt in ipairs(options) do
            local entry = combo:CreateItemEntry(opt.label, function()
                Addon.QuestRepository:UpdateDraftFields({ stealthMode = opt.mode })
            end)
            entry.stealthMode = opt.mode
            combo:AddItem(entry)
        end
        tab.stealthComboBox = combo
    end

    local optDivider2 = WINDOW_MANAGER:CreateControl(panelName .. "_OptionsDivider2", optBody, CT_TEXTURE)
    optDivider2:SetDimensions(510, 4)
    optDivider2:SetAnchor(TOPLEFT, optBody, TOPLEFT, 0, 140)
    optDivider2:SetTexture(Addon.Constants.UI.DIVIDER_TEXTURE)
    if optDivider2.SetAlpha then optDivider2:SetAlpha(0.5) end
    tab.optionsDivider2 = optDivider2

    tab.chkHideMapArea = Addon.JournalWidgets.CreateCheckButton(
        panelName .. "_ChkHideMapArea", optBody,
        Addon.Locale:Get("OPT_HIDE_MAP_AREA"),
        function(isChecked)
            Addon.QuestRepository:UpdateDraftFields({ recommendHideMapAreas = isChecked })
        end
    )
    tab.chkHideMapArea:SetAnchor(TOPLEFT, optBody, TOPLEFT, 2, 154)
end

function EditorSections.BuildFooterButtons(tab, pane, panelName)
    local CreateStyledButton = Addon.JournalWidgets.CreateStyledButton

    tab.btnSaveEditor = CreateStyledButton(panelName .. "_BtnSaveEditor", pane, 180, 34, Addon.Locale:Get("BTN_SAVE"), function()
        tab:OnSaveDraftClicked()
    end)
    tab.btnSaveEditor:SetAnchor(TOPLEFT, pane, TOPLEFT, 0, 514)
end
