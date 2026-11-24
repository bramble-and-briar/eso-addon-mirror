-- Ref: docs/adr/0001-arquitectura-modular-zero-dependency-y-savedvars-por-personaje.md
-- Ref: docs/adr/0003-integracion-nativa-ui-diario-mapa-y-hud.md
-- Ref: docs/adr/0011-flujo-solo-correo-1-a-1-y-eliminacion-codigos-manuales.md

RPQuest = RPQuest or {}
local Addon = RPQuest

Addon.JournalMailSendPane = {}
local MailSendPane = Addon.JournalMailSendPane

local CreateStyledButton = Addon.JournalWidgets.CreateStyledButton
local CreateEditBoxWithBackdrop = Addon.JournalWidgets.CreateEditBoxWithBackdrop

function MailSendPane.Build(tab, parent)
    local panelName = Addon.JournalWidgets.PANEL_NAME
    local pane = WINDOW_MANAGER:CreateControl(panelName .. "_MailSendPane", parent, CT_CONTROL)
    pane:SetDimensions(550, 580)
    pane:SetAnchor(TOPLEFT, parent, TOPLEFT, 0, 0)
    pane:SetHidden(true)
    tab.mailSendPane = pane

    local header = WINDOW_MANAGER:CreateControl(panelName .. "_MailSendHeader", pane, CT_LABEL)
    header:SetDimensions(520, 30)
    header:SetAnchor(TOPLEFT, pane, TOPLEFT, 0, 0)
    if header.SetFont then header:SetFont("ZoFontWinH2") end
    if header.SetColor then header:SetColor(0.95, 0.88, 0.65, 1) end
    tab.mailSendHeader = header

    local lblRec = WINDOW_MANAGER:CreateControl(panelName .. "_MailRecLbl", pane, CT_LABEL)
    lblRec:SetDimensions(520, 22)
    lblRec:SetAnchor(TOPLEFT, pane, TOPLEFT, 0, 44)
    if lblRec.SetFont then lblRec:SetFont("ZoFontGameBold") end
    lblRec:SetText(Addon.Locale:Get("MAIL_RECIPIENTS_LABEL"))

    local recBg, recEdit = CreateEditBoxWithBackdrop(
        panelName .. "_MailRecEdit", pane, 510, 32, 200, false, nil, false
    )
    recBg:SetAnchor(TOPLEFT, pane, TOPLEFT, 0, 68)
    tab.mailRecEdit = recEdit

    local lblRole = WINDOW_MANAGER:CreateControl(panelName .. "_MailRoleLbl", pane, CT_LABEL)
    lblRole:SetDimensions(520, 22)
    lblRole:SetAnchor(TOPLEFT, pane, TOPLEFT, 0, 114)
    if lblRole.SetFont then lblRole:SetFont("ZoFontGameBold") end
    lblRole:SetText(Addon.Locale:Get("MAIL_ROLE_MSG_LABEL"))

    local roleBg, roleEdit = CreateEditBoxWithBackdrop(
        panelName .. "_MailRoleEdit", pane, 510, 110, 700, true, function()
            tab:RefreshMailSendCounter()
        end, false
    )
    roleBg:SetAnchor(TOPLEFT, pane, TOPLEFT, 0, 138)
    tab.mailRoleEdit = roleEdit

    local lblCounter = WINDOW_MANAGER:CreateControl(panelName .. "_MailCounterLbl", pane, CT_LABEL)
    lblCounter:SetDimensions(510, 44)
    lblCounter:SetAnchor(TOPLEFT, pane, TOPLEFT, 0, 256)
    if lblCounter.SetFont then lblCounter:SetFont("ZoFontGame") end
    tab.mailCounterLabel = lblCounter

    local lblStatus = WINDOW_MANAGER:CreateControl(panelName .. "_MailSendStatusLbl", pane, CT_LABEL)
    lblStatus:SetDimensions(510, 28)
    lblStatus:SetAnchor(TOPLEFT, pane, TOPLEFT, 0, 304)
    if lblStatus.SetFont then lblStatus:SetFont("ZoFontGameBold") end
    tab.mailSendStatusLabel = lblStatus

    tab.btnConfirmMailSend = CreateStyledButton(panelName .. "_BtnConfirmMailSend", pane, 165, 36, Addon.Locale:Get("BTN_MAIL_SEND_CONFIRM"), function()
        tab:OnConfirmSendMailClicked()
    end)
    tab.btnConfirmMailSend:SetAnchor(TOPLEFT, pane, TOPLEFT, 0, 340)

    tab.btnCancelMailSend = CreateStyledButton(panelName .. "_BtnCancelMailSend", pane, 155, 36, Addon.Locale:Get("BTN_CANCEL"), function()
        tab.viewMode = tab.VIEW_MODE.DETAIL
        tab:Refresh()
    end)
    tab.btnCancelMailSend:SetAnchor(TOPLEFT, pane, TOPLEFT, 175, 340)
end

function MailSendPane.OnTransportEvent(tab, evType, payload)
    if evType == "MAIL_SEND_PROGRESS" and tab.mailSendStatusLabel and type(payload) == "table" then
        tab.mailSendStatusLabel:SetText(Addon.Locale:Get("MAIL_SENDING_PROGRESS", payload.current, payload.total, payload.to or ""))
    elseif evType == "MAIL_SEND_ERROR" and tab.mailSendStatusLabel and type(payload) == "table" then
        if type(payload.message) == "string" and payload.message ~= "" then
            tab.mailSendStatusLabel:SetText(payload.message)
        end
    elseif evType == "MAIL_SEND_COMPLETE" and type(payload) == "table" then
        local msg = (payload.failed and payload.failed > 0)
            and Addon.Locale:Get("MAIL_SEND_DONE_ERRORS", payload.sent, payload.total, payload.failed)
            or Addon.Locale:Get("MAIL_SEND_DONE", payload.sent, payload.total)
        if tab.mailSendStatusLabel then
            tab.mailSendStatusLabel:SetText(msg)
        end
        Addon.Announcements:ShowAlert(msg, (payload.failed or 0) > 0)
    elseif evType == "MAIL_COMPLETION_SENT" and type(payload) == "table" then
        Addon.Announcements:ShowAlert(Addon.Locale:Get("ALERT_MAIL_COMPLETION_SENT", payload.to or ""), false)
        if tab.viewMode == tab.VIEW_MODE.DETAIL then
            tab:RefreshDetailPane()
        end
    end
end

function MailSendPane.SendSelectedPrepared(tab)
    local quest = tab.selectedQuestId and Addon.QuestRepository:GetQuestById(tab.selectedQuestId)
    if not quest then return false end
    if quest.needsMigration then
        Addon.Announcements:ShowAlert(Addon.Locale:Get("ERR_QUEST_NEEDS_MIGRATION"), true)
        return false
    end
    if not Addon.QuestRepository:HasPlayableObjectives(quest) then
        Addon.Announcements:ShowAlert(Addon.Locale:Get("ERR_MISSING_TARGET"), true)
        return false
    end
    local recipient = type(quest.recipientAccount) == "string"
        and quest.recipientAccount:gsub("^%s+", ""):gsub("%s+$", "")
        or ""
    if recipient ~= "" and Addon.MailTransport then
        local ok, errKey = Addon.MailTransport:SendQuestToRecipients(quest, recipient, "")
        if ok then
            Addon.Announcements:ShowAlert(Addon.Locale:Get("ALERT_MAIL_SENDING_TO", quest.title or "", recipient), false)
            return true
        elseif errKey then
            Addon.Announcements:ShowAlert(Addon.Locale:Get(errKey), true)
            return false
        end
    end
    tab:OpenMailSendView()
    return false
end

function MailSendPane.OpenView(tab)
    local quest = tab.selectedQuestId and Addon.QuestRepository:GetQuestById(tab.selectedQuestId)
    if not quest then return end
    tab._mailSendQuestId = quest.id
    tab.viewMode = tab.VIEW_MODE.MAIL_SEND
    if tab.mailRecEdit then
        tab.mailRecEdit:SetText(quest.recipientAccount or "")
    end
    if tab.mailSendHeader then
        tab.mailSendHeader:SetText(Addon.Locale:Get("MAIL_SEND_TITLE", quest.title or ""))
    end
    if tab.mailSendStatusLabel then
        tab.mailSendStatusLabel:SetText("")
    end
    tab:Refresh()
    tab:RefreshMailSendCounter()
end

function MailSendPane.RefreshCounter(tab)
    if not Addon.MailTransport or not tab.mailCounterLabel then return end
    local quest = tab._mailSendQuestId and Addon.QuestRepository:GetQuestById(tab._mailSendQuestId)
    if not quest then return end
    local code = Addon.QuestRepository:ExportQuestToCode(quest.id) or ""
    local roleMsg = tab.mailRoleEdit and tab.mailRoleEdit:GetText() or ""
    local plan = Addon.MailTransport:BuildQuestMailPackets(roleMsg, code, quest.title)
    if plan.partCount == 1 then
        tab.mailCounterLabel:SetText(Addon.Locale:Get("MAIL_CHAR_COUNTER", plan.totalLen, plan.maxLen))
    elseif plan.fits then
        tab.mailCounterLabel:SetText(Addon.Locale:Get("MAIL_CHAR_COUNTER_MULTI", plan.totalLen, plan.partCount, plan.maxParts))
    else
        tab.mailCounterLabel:SetText(Addon.Locale:Get("MAIL_CHAR_COUNTER_OVER", plan.totalLen, plan.maxTotalChars, plan.maxParts))
    end
end

function MailSendPane.OnConfirmSendClicked(tab)
    if not Addon.MailTransport then return end
    local quest = tab._mailSendQuestId and Addon.QuestRepository:GetQuestById(tab._mailSendQuestId)
    if not quest then return end
    local rawRec = tab.mailRecEdit and tab.mailRecEdit:GetText() or ""
    local roleMsg = tab.mailRoleEdit and tab.mailRoleEdit:GetText() or ""
    local ok, errKey = Addon.MailTransport:SendQuestToRecipients(quest, rawRec, roleMsg)
    if not ok and errKey then
        local errMsg = Addon.Locale:Get(errKey)
        if tab.mailSendStatusLabel then
            tab.mailSendStatusLabel:SetText("|cFF4444" .. errMsg .. "|r")
        end
        Addon.Announcements:ShowAlert(errMsg, true)
    end
end
